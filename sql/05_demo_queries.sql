-- Healthcare Clinical Database Demo Queries
-- Version: 1.0
-- Description: Example queries showcasing clinical analytics capabilities

SET search_path TO clinical, public;

-- ============================================
-- OPERATIONAL QUERIES
-- ============================================

-- 1. Current Hospital Census by Unit
\echo '1. CURRENT HOSPITAL CENSUS BY UNIT'
\echo '=================================='
SELECT * FROM v_current_census;
\echo ''

-- 2. Active High-Risk Patients
\echo '2. HIGH ACUITY PATIENTS REQUIRING IMMEDIATE ATTENTION'
\echo '===================================================='
SELECT 
    patient_name,
    mrn,
    unit_code,
    room_number,
    acuity_level,
    total_acuity_score,
    vital_instability_score,
    critical_lab_score
FROM v_patient_acuity
WHERE acuity_level IN ('CRITICAL', 'HIGH')
ORDER BY total_acuity_score DESC
LIMIT 10;
\echo ''

-- 3. Patients Meeting Sepsis Criteria
\echo '3. SEPSIS SCREENING - PATIENTS MEETING SIRS CRITERIA'
\echo '==================================================='
SELECT 
    patient_name,
    mrn,
    unit_code,
    room_number,
    sirs_score,
    temperature_f,
    heart_rate,
    respiratory_rate,
    wbc
FROM v_sepsis_screening
ORDER BY sirs_score DESC
LIMIT 10;
\echo ''

-- ============================================
-- QUALITY METRICS
-- ============================================

-- 4. 30-Day Readmission Analysis
\echo '4. 30-DAY READMISSIONS BY PRIMARY DIAGNOSIS'
\echo '==========================================='
WITH readmit_summary AS (
    SELECT 
        initial_diagnosis,
        initial_diagnosis_desc,
        COUNT(*) as readmission_count,
        ROUND(AVG(days_to_readmit), 1) as avg_days_to_readmit
    FROM v_30day_readmissions
    GROUP BY initial_diagnosis, initial_diagnosis_desc
)
SELECT * FROM readmit_summary
ORDER BY readmission_count DESC
LIMIT 10;
\echo ''

-- 5. Average Length of Stay by Diagnosis
\echo '5. LENGTH OF STAY ANALYSIS - TOP 10 DIAGNOSES'
\echo '============================================='
SELECT 
    diagnosis_description,
    encounter_count,
    avg_los_days,
    median_los_days,
    min_los_days,
    max_los_days
FROM v_los_by_diagnosis
ORDER BY encounter_count DESC
LIMIT 10;
\echo ''

-- ============================================
-- SAFETY MONITORING
-- ============================================

-- 6. High Fall Risk Patients
\echo '6. HIGH FALL RISK PATIENTS BY UNIT'
\echo '=================================='
SELECT 
    unit_code,
    COUNT(*) as high_risk_count,
    STRING_AGG(patient_name || ' (Room ' || room_number || ')', ', ') as patients
FROM v_high_fall_risk
GROUP BY unit_code
ORDER BY high_risk_count DESC;
\echo ''

-- 7. Critical Lab Values Pending Review
\echo '7. CRITICAL LAB VALUES - LAST 4 HOURS'
\echo '====================================='
SELECT 
    patient_name,
    unit_code,
    room_number,
    test_name,
    result,
    abnormal_flag,
    ROUND(minutes_since_result::numeric, 0) || ' min ago' as time_since_result
FROM v_critical_labs
WHERE minutes_since_result <= 240
ORDER BY minutes_since_result
LIMIT 15;
\echo ''

-- ============================================
-- MEDICATION SAFETY
-- ============================================

-- 8. High-Alert Medications Currently Active
\echo '8. HIGH-ALERT MEDICATIONS IN USE'
\echo '================================'
SELECT 
    medication_name,
    controlled_substance_schedule,
    COUNT(DISTINCT encounter_id) as patient_count,
    SUM(doses_last_24h) as total_doses_24h
FROM v_high_alert_medications
GROUP BY medication_name, controlled_substance_schedule
ORDER BY controlled_substance_schedule NULLS LAST, patient_count DESC;
\echo ''

-- 9. Missed Medication Doses (Last 24 Hours)
\echo '9. MISSED MEDICATION DOSES - LAST 24 HOURS'
\echo '=========================================='
SELECT 
    u.unit_code,
    COUNT(*) as missed_doses,
    COUNT(DISTINCT ma.encounter_id) as affected_patients,
    STRING_AGG(DISTINCT ma.hold_reason, ', ') as reasons
FROM medication_administrations ma
INNER JOIN encounters e ON ma.encounter_id = e.encounter_id
INNER JOIN units u ON e.current_unit_id = u.unit_id
WHERE ma.admin_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
    AND ma.admin_status IN ('Held', 'Not Given', 'Refused')
    AND e.encounter_status = 'Active'
GROUP BY u.unit_code
ORDER BY missed_doses DESC;
\echo ''

-- ============================================
-- PROVIDER METRICS
-- ============================================

-- 10. Provider Workload Distribution
\echo '10. PROVIDER WORKLOAD - ATTENDING PHYSICIANS'
\echo '==========================================='
SELECT 
    provider_name,
    title,
    specialty,
    active_patients,
    icu_patients,
    ROUND(icu_patients::numeric / NULLIF(active_patients, 0) * 100, 1) as pct_icu,
    units_covered
FROM v_provider_workload
WHERE title IN ('MD', 'DO')
ORDER BY active_patients DESC
LIMIT 10;
\echo ''

-- ============================================
-- NURSING METRICS
-- ============================================

-- 11. Nursing Assessment Compliance
\echo '11. NURSING ASSESSMENT COMPLIANCE BY UNIT'
\echo '========================================'
WITH assessment_stats AS (
    SELECT 
        u.unit_code,
        u.unit_name,
        COUNT(DISTINCT e.encounter_id) as active_encounters,
        COUNT(DISTINCT na.encounter_id) as assessed_encounters,
        MAX(na.assessment_date) as last_assessment
    FROM units u
    INNER JOIN encounters e ON u.unit_id = e.current_unit_id
    LEFT JOIN nursing_assessments na ON e.encounter_id = na.encounter_id
        AND na.assessment_date >= CURRENT_TIMESTAMP - INTERVAL '12 hours'
    WHERE e.encounter_status = 'Active'
    GROUP BY u.unit_code, u.unit_name
)
SELECT 
    unit_code,
    unit_name,
    active_encounters,
    assessed_encounters,
    ROUND(assessed_encounters::numeric / NULLIF(active_encounters, 0) * 100, 1) as compliance_rate,
    COALESCE(EXTRACT(HOURS FROM (CURRENT_TIMESTAMP - last_assessment))::TEXT || ' hours ago', 'Never') as last_assessment_time
FROM assessment_stats
ORDER BY compliance_rate;
\echo ''

-- ============================================
-- PATIENT FLOW METRICS
-- ============================================

-- 12. ED Boarding Time Analysis
\echo '12. EMERGENCY DEPARTMENT BOARDING TIMES'
\echo '======================================'
SELECT 
    p.first_name || ' ' || p.last_name as patient_name,
    e.encounter_number,
    e.admit_date,
    EXTRACT(HOURS FROM (CURRENT_TIMESTAMP - e.admit_date)) as hours_in_ed,
    e.chief_complaint
FROM encounters e
INNER JOIN patients p ON e.patient_id = p.patient_id
WHERE e.encounter_status = 'Active'
    AND e.encounter_type = 'Emergency'
    AND e.current_unit_id = (SELECT unit_id FROM units WHERE unit_code = 'ED')
    AND e.admit_date < CURRENT_TIMESTAMP - INTERVAL '4 hours'
ORDER BY hours_in_ed DESC;
\echo ''

-- ============================================
-- CLINICAL DECISION SUPPORT
-- ============================================

-- 13. Patients Due for Vital Signs
\echo '13. PATIENTS OVERDUE FOR VITAL SIGNS'
\echo '===================================='
WITH last_vitals AS (
    SELECT 
        e.encounter_id,
        p.first_name || ' ' || p.last_name as patient_name,
        u.unit_code,
        e.room_number,
        MAX(v.recorded_date) as last_vital_time,
        CASE 
            WHEN u.unit_type IN ('ICU', 'MICU', 'SICU', 'CCU') THEN 1
            WHEN u.unit_type = 'ED' THEN 2
            ELSE 4
        END as required_frequency_hours
    FROM encounters e
    INNER JOIN patients p ON e.patient_id = p.patient_id
    INNER JOIN units u ON e.current_unit_id = u.unit_id
    LEFT JOIN vital_signs v ON e.encounter_id = v.encounter_id
    WHERE e.encounter_status = 'Active'
    GROUP BY e.encounter_id, p.first_name, p.last_name, u.unit_code, u.unit_type, e.room_number
)
SELECT 
    patient_name,
    unit_code,
    room_number,
    COALESCE(EXTRACT(HOURS FROM (CURRENT_TIMESTAMP - last_vital_time))::TEXT || ' hours ago', 'Never recorded') as last_vitals,
    required_frequency_hours || ' hours' as required_frequency
FROM last_vitals
WHERE last_vital_time IS NULL 
   OR last_vital_time < CURRENT_TIMESTAMP - (required_frequency_hours || ' hours')::INTERVAL
ORDER BY unit_code, room_number;
\echo ''

-- ============================================
-- SUMMARY STATISTICS
-- ============================================

-- 14. Hospital Dashboard Summary
\echo '14. HOSPITAL DASHBOARD SUMMARY'
\echo '=============================='
SELECT 
    (SELECT COUNT(*) FROM encounters WHERE encounter_status = 'Active') as active_encounters,
    (SELECT COUNT(*) FROM encounters WHERE encounter_status = 'Active' AND encounter_type = 'Inpatient') as inpatients,
    (SELECT COUNT(*) FROM encounters WHERE encounter_status = 'Active' AND encounter_type = 'Emergency') as ed_patients,
    (SELECT ROUND(AVG(occupancy_rate), 1) FROM v_current_census) as avg_occupancy_rate,
    (SELECT COUNT(*) FROM v_sepsis_screening) as sepsis_alerts,
    (SELECT COUNT(*) FROM v_critical_labs WHERE minutes_since_result <= 60) as critical_labs_last_hour,
    (SELECT COUNT(*) FROM v_high_fall_risk) as high_fall_risk_patients,
    (SELECT COUNT(DISTINCT patient_id) FROM v_30day_readmissions WHERE initial_discharge >= CURRENT_DATE - 30) as readmissions_last_30days;
\echo ''

\echo 'Query execution complete.';