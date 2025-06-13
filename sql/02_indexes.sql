-- Healthcare Clinical Database Indexes
-- Version: 1.0
-- Description: Performance optimization indexes for common query patterns

SET search_path TO clinical, public;

-- ============================================
-- PATIENTS TABLE INDEXES
-- ============================================
-- MRN lookup (already unique, but explicit index for clarity)
CREATE INDEX idx_patients_mrn ON patients(mrn);

-- Name searches
CREATE INDEX idx_patients_last_first_name ON patients(last_name, first_name);

-- DOB for age calculations
CREATE INDEX idx_patients_dob ON patients(date_of_birth);

-- Active patients
CREATE INDEX idx_patients_active ON patients(is_active) WHERE is_active = TRUE;

-- ============================================
-- PROVIDERS TABLE INDEXES
-- ============================================
-- NPI lookup
CREATE INDEX idx_providers_npi ON providers(npi);

-- Name searches
CREATE INDEX idx_providers_last_name ON providers(last_name);

-- Active providers
CREATE INDEX idx_providers_active ON providers(is_active) WHERE is_active = TRUE;

-- Department lookup
CREATE INDEX idx_providers_department ON providers(department);

-- ============================================
-- ENCOUNTERS TABLE INDEXES
-- ============================================
-- Patient encounters lookup (most common query)
CREATE INDEX idx_encounters_patient_id ON encounters(patient_id);

-- Active encounters
CREATE INDEX idx_encounters_active ON encounters(encounter_status) WHERE encounter_status = 'Active';

-- Date range queries
CREATE INDEX idx_encounters_admit_date ON encounters(admit_date);
CREATE INDEX idx_encounters_discharge_date ON encounters(discharge_date);

-- Provider lookups
CREATE INDEX idx_encounters_attending_provider ON encounters(attending_provider_id);

-- Unit census
CREATE INDEX idx_encounters_unit ON encounters(current_unit_id) WHERE encounter_status = 'Active';

-- Composite for patient history
CREATE INDEX idx_encounters_patient_dates ON encounters(patient_id, admit_date DESC);

-- ============================================
-- DIAGNOSES TABLE INDEXES
-- ============================================
-- Encounter diagnoses lookup
CREATE INDEX idx_diagnoses_encounter ON diagnoses(encounter_id);

-- ICD-10 code searches
CREATE INDEX idx_diagnoses_icd10 ON diagnoses(icd10_code);

-- Primary diagnoses
CREATE INDEX idx_diagnoses_primary ON diagnoses(encounter_id) WHERE diagnosis_type = 'Primary';

-- Active diagnoses
CREATE INDEX idx_diagnoses_active ON diagnoses(encounter_id) WHERE is_resolved = FALSE;

-- ============================================
-- MEDICATION_ADMINISTRATIONS TABLE INDEXES
-- ============================================
-- MAR by encounter (most common)
CREATE INDEX idx_med_admin_encounter ON medication_administrations(encounter_id);

-- MAR by date for shift reports
CREATE INDEX idx_med_admin_date ON medication_administrations(admin_date);

-- Composite for MAR queries
CREATE INDEX idx_med_admin_encounter_date ON medication_administrations(encounter_id, admin_date DESC);

-- By medication for drug utilization
CREATE INDEX idx_med_admin_medication ON medication_administrations(medication_id);

-- Provider accountability
CREATE INDEX idx_med_admin_provider ON medication_administrations(administering_provider_id);

-- ============================================
-- LAB_RESULTS TABLE INDEXES
-- ============================================
-- Labs by encounter
CREATE INDEX idx_labs_encounter ON lab_results(encounter_id);

-- Labs by collection date
CREATE INDEX idx_labs_collected_date ON lab_results(collected_date);

-- Composite for patient lab history
CREATE INDEX idx_labs_encounter_collected ON lab_results(encounter_id, collected_date DESC);

-- Abnormal results
CREATE INDEX idx_labs_abnormal ON lab_results(abnormal_flag) 
    WHERE abnormal_flag IN ('Critical Low', 'Critical High');

-- By test type
CREATE INDEX idx_labs_loinc ON lab_results(loinc_code);
CREATE INDEX idx_labs_test_name ON lab_results(test_name);

-- ============================================
-- VITAL_SIGNS TABLE INDEXES
-- ============================================
-- Vitals by encounter
CREATE INDEX idx_vitals_encounter ON vital_signs(encounter_id);

-- Vitals by date for trending
CREATE INDEX idx_vitals_recorded_date ON vital_signs(recorded_date);

-- Composite for vital trends
CREATE INDEX idx_vitals_encounter_date ON vital_signs(encounter_id, recorded_date DESC);

-- Abnormal vital signs (for alerts)
CREATE INDEX idx_vitals_high_temp ON vital_signs(temperature_f) WHERE temperature_f > 100.4;
CREATE INDEX idx_vitals_low_o2 ON vital_signs(oxygen_saturation) WHERE oxygen_saturation < 92;
CREATE INDEX idx_vitals_high_hr ON vital_signs(heart_rate) WHERE heart_rate > 100;
CREATE INDEX idx_vitals_low_bp ON vital_signs(blood_pressure_systolic) WHERE blood_pressure_systolic < 90;

-- ============================================
-- NURSING_ASSESSMENTS TABLE INDEXES
-- ============================================
-- Assessments by encounter
CREATE INDEX idx_nursing_assessment_encounter ON nursing_assessments(encounter_id);

-- Assessments by date
CREATE INDEX idx_nursing_assessment_date ON nursing_assessments(assessment_date);

-- High fall risk patients
CREATE INDEX idx_nursing_assessment_fall_risk ON nursing_assessments(encounter_id) 
    WHERE fall_risk_level = 'High';

-- ============================================
-- ALLERGIES TABLE INDEXES
-- ============================================
-- Allergies by patient
CREATE INDEX idx_allergies_patient ON allergies(patient_id);

-- Active allergies only
CREATE INDEX idx_allergies_active ON allergies(patient_id) WHERE is_active = TRUE;

-- Drug allergies (most critical)
CREATE INDEX idx_allergies_drugs ON allergies(patient_id) 
    WHERE allergy_type = 'Drug' AND is_active = TRUE;

-- ============================================
-- PARTIAL INDEXES FOR COMMON FILTERS
-- ============================================
-- Current inpatients
CREATE INDEX idx_current_inpatients ON encounters(patient_id, current_unit_id)
    WHERE encounter_status = 'Active' AND encounter_type = 'Inpatient';

-- ED patients
CREATE INDEX idx_ed_patients ON encounters(patient_id, admit_date)
    WHERE encounter_type = 'Emergency' AND encounter_status = 'Active';

-- Recent discharges (for readmission tracking)
CREATE INDEX idx_recent_discharges ON encounters(patient_id, discharge_date)
    WHERE discharge_date IS NOT NULL 
    AND discharge_date > CURRENT_DATE - INTERVAL '30 days';

-- ============================================
-- FUNCTION-BASED INDEXES
-- ============================================
-- Age calculation for demographics
CREATE INDEX idx_patients_age ON patients((EXTRACT(YEAR FROM age(date_of_birth))));

-- BMI categories
CREATE INDEX idx_vitals_bmi_category ON vital_signs(
    CASE 
        WHEN bmi < 18.5 THEN 'Underweight'
        WHEN bmi < 25 THEN 'Normal'
        WHEN bmi < 30 THEN 'Overweight'
        ELSE 'Obese'
    END
);

-- ============================================
-- ANALYZE TABLES
-- ============================================
-- Update statistics for query planner
ANALYZE patients;
ANALYZE providers;
ANALYZE units;
ANALYZE encounters;
ANALYZE diagnoses;
ANALYZE medications;
ANALYZE medication_administrations;
ANALYZE lab_results;
ANALYZE vital_signs;
ANALYZE nursing_assessments;
ANALYZE allergies;