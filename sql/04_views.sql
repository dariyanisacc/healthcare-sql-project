-- Healthcare Clinical Database Analytics Views
-- Version: 1.0
-- Description: Clinical analytics views for common use cases

SET search_path TO clinical, public;

-- ============================================
-- CURRENT CENSUS VIEW
-- ============================================
-- Active patients by unit
CREATE OR REPLACE VIEW v_current_census AS
SELECT 
    u.unit_code,
    u.unit_name,
    u.unit_type,
    COUNT(DISTINCT e.patient_id) as patient_count,
    u.total_beds,
    ROUND((COUNT(DISTINCT e.patient_id)::NUMERIC / u.total_beds * 100), 1) as occupancy_rate
FROM units u
LEFT JOIN encounters e ON u.unit_id = e.current_unit_id 
    AND e.encounter_status = 'Active'
GROUP BY u.unit_id, u.unit_code, u.unit_name, u.unit_type, u.total_beds
ORDER BY u.unit_code;

-- ============================================
-- 30-DAY READMISSION VIEW
-- ============================================
-- Patients readmitted within 30 days
CREATE OR REPLACE VIEW v_30day_readmissions AS
WITH readmissions AS (
    SELECT 
        p.patient_id,
        p.mrn,
        p.first_name,
        p.last_name,
        e1.encounter_id as initial_encounter_id,
        e1.discharge_date as initial_discharge,
        e2.encounter_id as readmit_encounter_id,
        e2.admit_date as readmit_date,
        e2.admit_date - e1.discharge_date as days_to_readmit,
        d1.icd10_code as initial_diagnosis,
        d1.diagnosis_description as initial_diagnosis_desc
    FROM encounters e1
    INNER JOIN encounters e2 ON e1.patient_id = e2.patient_id
        AND e2.admit_date > e1.discharge_date
        AND e2.admit_date <= e1.discharge_date + INTERVAL '30 days'
        AND e1.encounter_id < e2.encounter_id
    INNER JOIN patients p ON e1.patient_id = p.patient_id
    LEFT JOIN diagnoses d1 ON e1.encounter_id = d1.encounter_id 
        AND d1.diagnosis_type = 'Primary'
    WHERE e1.discharge_date IS NOT NULL
        AND e1.encounter_type = 'Inpatient'
        AND e2.encounter_type = 'Inpatient'
)
SELECT * FROM readmissions
ORDER BY initial_discharge DESC;

-- ============================================
-- MEDICATION ADMINISTRATION RECORD (MAR) VIEW
-- ============================================
-- MAR for active encounters
CREATE OR REPLACE VIEW v_active_mar AS
SELECT 
    e.encounter_id,
    e.encounter_number,
    p.mrn,
    p.first_name || ' ' || p.last_name as patient_name,
    u.unit_code,
    e.room_number,
    e.bed_number,
    m.medication_name,
    m.generic_name,
    ma.ordered_dose || ' ' || ma.ordered_unit as dose,
    ma.ordered_route as route,
    ma.ordered_frequency as frequency,
    ma.admin_date,
    ma.admin_status,
    ma.hold_reason,
    prov.first_name || ' ' || prov.last_name as administering_nurse
FROM medication_administrations ma
INNER JOIN encounters e ON ma.encounter_id = e.encounter_id
INNER JOIN patients p ON e.patient_id = p.patient_id
INNER JOIN medications m ON ma.medication_id = m.medication_id
INNER JOIN units u ON e.current_unit_id = u.unit_id
LEFT JOIN providers prov ON ma.administering_provider_id = prov.provider_id
WHERE e.encounter_status = 'Active'
    AND ma.admin_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY e.encounter_id, ma.admin_date DESC;

-- ============================================
-- SEPSIS SCREENING VIEW (SIRS CRITERIA)
-- ============================================
-- Identifies patients meeting SIRS/Sepsis criteria
CREATE OR REPLACE VIEW v_sepsis_screening AS
WITH latest_vitals AS (
    SELECT DISTINCT ON (encounter_id)
        encounter_id,
        temperature_f,
        heart_rate,
        respiratory_rate,
        recorded_date
    FROM vital_signs
    WHERE recorded_date >= CURRENT_TIMESTAMP - INTERVAL '4 hours'
    ORDER BY encounter_id, recorded_date DESC
),
latest_labs AS (
    SELECT DISTINCT ON (lr.encounter_id, lr.test_name)
        lr.encounter_id,
        lr.test_name,
        lr.result_value,
        lr.collected_date
    FROM lab_results lr
    WHERE lr.test_name IN ('WBC', 'Lactate')
        AND lr.collected_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
    ORDER BY lr.encounter_id, lr.test_name, lr.collected_date DESC
),
sirs_criteria AS (
    SELECT 
        e.encounter_id,
        e.encounter_number,
        p.mrn,
        p.first_name || ' ' || p.last_name as patient_name,
        u.unit_code,
        e.room_number,
        lv.temperature_f,
        lv.heart_rate,
        lv.respiratory_rate,
        MAX(CASE WHEN ll.test_name = 'WBC' THEN ll.result_value::NUMERIC END) as wbc,
        -- SIRS criteria flags
        CASE WHEN lv.temperature_f > 100.4 OR lv.temperature_f < 96.8 THEN 1 ELSE 0 END as temp_abnormal,
        CASE WHEN lv.heart_rate > 90 THEN 1 ELSE 0 END as hr_abnormal,
        CASE WHEN lv.respiratory_rate > 20 THEN 1 ELSE 0 END as rr_abnormal,
        CASE WHEN MAX(CASE WHEN ll.test_name = 'WBC' THEN ll.result_value::NUMERIC END) > 12 
             OR MAX(CASE WHEN ll.test_name = 'WBC' THEN ll.result_value::NUMERIC END) < 4 
             THEN 1 ELSE 0 END as wbc_abnormal
    FROM encounters e
    INNER JOIN patients p ON e.patient_id = p.patient_id
    INNER JOIN units u ON e.current_unit_id = u.unit_id
    LEFT JOIN latest_vitals lv ON e.encounter_id = lv.encounter_id
    LEFT JOIN latest_labs ll ON e.encounter_id = ll.encounter_id
    WHERE e.encounter_status = 'Active'
    GROUP BY e.encounter_id, e.encounter_number, p.mrn, p.first_name, p.last_name,
             u.unit_code, e.room_number, lv.temperature_f, lv.heart_rate, lv.respiratory_rate
)
SELECT 
    *,
    temp_abnormal + hr_abnormal + rr_abnormal + wbc_abnormal as sirs_score,
    CASE 
        WHEN temp_abnormal + hr_abnormal + rr_abnormal + wbc_abnormal >= 2 THEN 'SIRS POSITIVE'
        ELSE 'SIRS NEGATIVE'
    END as sirs_status
FROM sirs_criteria
WHERE temp_abnormal + hr_abnormal + rr_abnormal + wbc_abnormal >= 2
ORDER BY sirs_score DESC, unit_code, room_number;

-- ============================================
-- ABNORMAL LAB ALERTS VIEW
-- ============================================
-- Critical lab values requiring immediate attention
CREATE OR REPLACE VIEW v_critical_labs AS
SELECT 
    e.encounter_id,
    e.encounter_number,
    p.mrn,
    p.first_name || ' ' || p.last_name as patient_name,
    u.unit_code,
    e.room_number,
    lr.test_name,
    lr.result_value || ' ' || lr.result_unit as result,
    lr.abnormal_flag,
    lr.reference_range_low || '-' || lr.reference_range_high || ' ' || lr.result_unit as normal_range,
    lr.collected_date,
    lr.resulted_date,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - lr.resulted_date))/60 as minutes_since_result
FROM lab_results lr
INNER JOIN encounters e ON lr.encounter_id = e.encounter_id
INNER JOIN patients p ON e.patient_id = p.patient_id
INNER JOIN units u ON e.current_unit_id = u.unit_id
WHERE e.encounter_status = 'Active'
    AND lr.abnormal_flag IN ('Critical Low', 'Critical High')
    AND lr.resulted_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY lr.resulted_date DESC;

-- ============================================
-- LENGTH OF STAY ANALYSIS VIEW
-- ============================================
-- Average LOS by diagnosis
CREATE OR REPLACE VIEW v_los_by_diagnosis AS
SELECT 
    d.icd10_code,
    d.diagnosis_description,
    COUNT(DISTINCT e.encounter_id) as encounter_count,
    ROUND(AVG(EXTRACT(EPOCH FROM (e.discharge_date - e.admit_date))/86400), 1) as avg_los_days,
    ROUND(MIN(EXTRACT(EPOCH FROM (e.discharge_date - e.admit_date))/86400), 1) as min_los_days,
    ROUND(MAX(EXTRACT(EPOCH FROM (e.discharge_date - e.admit_date))/86400), 1) as max_los_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY EXTRACT(EPOCH FROM (e.discharge_date - e.admit_date))/86400) as median_los_days
FROM encounters e
INNER JOIN diagnoses d ON e.encounter_id = d.encounter_id
WHERE e.discharge_date IS NOT NULL
    AND e.encounter_type = 'Inpatient'
    AND d.diagnosis_type = 'Primary'
GROUP BY d.icd10_code, d.diagnosis_description
HAVING COUNT(DISTINCT e.encounter_id) >= 5
ORDER BY avg_los_days DESC;

-- ============================================
-- PATIENT FALL RISK VIEW
-- ============================================
-- High fall risk patients
CREATE OR REPLACE VIEW v_high_fall_risk AS
SELECT 
    e.encounter_id,
    e.encounter_number,
    p.mrn,
    p.first_name || ' ' || p.last_name as patient_name,
    EXTRACT(YEAR FROM AGE(p.date_of_birth)) as age,
    u.unit_code,
    e.room_number,
    e.bed_number,
    na.fall_risk_score,
    na.fall_risk_level,
    na.bed_alarm_on,
    na.activity_level,
    na.gait_steady,
    na.assistive_device,
    na.assessment_date as last_assessment
FROM nursing_assessments na
INNER JOIN encounters e ON na.encounter_id = e.encounter_id
INNER JOIN patients p ON e.patient_id = p.patient_id
INNER JOIN units u ON e.current_unit_id = u.unit_id
WHERE e.encounter_status = 'Active'
    AND na.fall_risk_level = 'High'
    AND na.assessment_id IN (
        SELECT MAX(assessment_id)
        FROM nursing_assessments na2
        WHERE na2.encounter_id = na.encounter_id
    )
ORDER BY na.fall_risk_score DESC, u.unit_code, e.room_number;

-- ============================================
-- MEDICATION HIGH ALERT VIEW
-- ============================================
-- High-alert medications currently ordered
CREATE OR REPLACE VIEW v_high_alert_medications AS
SELECT 
    e.encounter_id,
    e.encounter_number,
    p.mrn,
    p.first_name || ' ' || p.last_name as patient_name,
    u.unit_code,
    e.room_number,
    m.medication_name,
    m.controlled_substance_schedule,
    ma.ordered_dose || ' ' || ma.ordered_unit as dose,
    ma.ordered_route as route,
    ma.ordered_frequency as frequency,
    MAX(ma.admin_date) as last_admin,
    COUNT(*) as doses_last_24h
FROM medication_administrations ma
INNER JOIN medications m ON ma.medication_id = m.medication_id
INNER JOIN encounters e ON ma.encounter_id = e.encounter_id
INNER JOIN patients p ON e.patient_id = p.patient_id
INNER JOIN units u ON e.current_unit_id = u.unit_id
WHERE e.encounter_status = 'Active'
    AND (m.is_high_alert = TRUE OR m.controlled_substance_schedule IS NOT NULL)
    AND ma.admin_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
GROUP BY e.encounter_id, e.encounter_number, p.mrn, p.first_name, p.last_name,
         u.unit_code, e.room_number, m.medication_name, m.controlled_substance_schedule,
         ma.ordered_dose, ma.ordered_unit, ma.ordered_route, ma.ordered_frequency
ORDER BY m.controlled_substance_schedule NULLS LAST, u.unit_code, e.room_number;

-- ============================================
-- PROVIDER WORKLOAD VIEW
-- ============================================
-- Current provider patient assignments
CREATE OR REPLACE VIEW v_provider_workload AS
SELECT 
    prov.provider_id,
    prov.first_name || ' ' || prov.last_name as provider_name,
    prov.title,
    prov.specialty,
    COUNT(DISTINCT e.encounter_id) as active_patients,
    COUNT(DISTINCT CASE WHEN u.unit_type IN ('ICU', 'MICU', 'SICU', 'CCU') THEN e.encounter_id END) as icu_patients,
    STRING_AGG(DISTINCT u.unit_code, ', ') as units_covered
FROM providers prov
INNER JOIN encounters e ON prov.provider_id = e.attending_provider_id
INNER JOIN units u ON e.current_unit_id = u.unit_id
WHERE e.encounter_status = 'Active'
    AND prov.is_active = TRUE
GROUP BY prov.provider_id, prov.first_name, prov.last_name, prov.title, prov.specialty
ORDER BY active_patients DESC;

-- ============================================
-- PATIENT ACUITY SCORE VIEW
-- ============================================
-- Calculate acuity based on various factors
CREATE OR REPLACE VIEW v_patient_acuity AS
WITH acuity_factors AS (
    SELECT 
        e.encounter_id,
        e.encounter_number,
        p.mrn,
        p.first_name || ' ' || p.last_name as patient_name,
        u.unit_code,
        e.room_number,
        -- Unit type score
        CASE 
            WHEN u.unit_type IN ('ICU', 'MICU', 'SICU') THEN 3
            WHEN u.unit_type IN ('CCU', 'PACU') THEN 2
            WHEN u.unit_type = 'ED' THEN 2
            ELSE 1
        END as unit_score,
        -- Vital signs score (from last 4 hours)
        (SELECT COUNT(*) FROM vital_signs v 
         WHERE v.encounter_id = e.encounter_id 
         AND v.recorded_date >= CURRENT_TIMESTAMP - INTERVAL '4 hours'
         AND (v.heart_rate > 110 OR v.heart_rate < 50 
              OR v.blood_pressure_systolic < 90 OR v.blood_pressure_systolic > 180
              OR v.oxygen_saturation < 92)) as vital_instability_score,
        -- High alert meds score
        (SELECT COUNT(DISTINCT m.medication_id) FROM medication_administrations ma
         INNER JOIN medications m ON ma.medication_id = m.medication_id
         WHERE ma.encounter_id = e.encounter_id
         AND ma.admin_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
         AND (m.is_high_alert = TRUE OR m.controlled_substance_schedule IS NOT NULL)) as high_alert_med_score,
        -- Critical labs score
        (SELECT COUNT(*) FROM lab_results lr
         WHERE lr.encounter_id = e.encounter_id
         AND lr.collected_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
         AND lr.abnormal_flag IN ('Critical Low', 'Critical High')) as critical_lab_score
    FROM encounters e
    INNER JOIN patients p ON e.patient_id = p.patient_id
    INNER JOIN units u ON e.current_unit_id = u.unit_id
    WHERE e.encounter_status = 'Active'
)
SELECT 
    *,
    unit_score + vital_instability_score + high_alert_med_score + critical_lab_score as total_acuity_score,
    CASE 
        WHEN unit_score + vital_instability_score + high_alert_med_score + critical_lab_score >= 7 THEN 'CRITICAL'
        WHEN unit_score + vital_instability_score + high_alert_med_score + critical_lab_score >= 4 THEN 'HIGH'
        WHEN unit_score + vital_instability_score + high_alert_med_score + critical_lab_score >= 2 THEN 'MODERATE'
        ELSE 'LOW'
    END as acuity_level
FROM acuity_factors
ORDER BY total_acuity_score DESC, unit_code, room_number;