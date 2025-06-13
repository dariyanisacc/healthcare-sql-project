-- Healthcare Clinical Database Schema
-- Version: 1.0
-- Description: Core clinical entities for patient care tracking

-- Drop existing schema if exists (for development)
DROP SCHEMA IF EXISTS clinical CASCADE;
CREATE SCHEMA clinical;
SET search_path TO clinical, public;

-- ============================================
-- PATIENTS TABLE
-- ============================================
-- Core patient demographics and identification
CREATE TABLE patients (
    patient_id SERIAL PRIMARY KEY,
    mrn VARCHAR(20) UNIQUE NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    middle_name VARCHAR(50),
    date_of_birth DATE NOT NULL,
    sex CHAR(1) CHECK (sex IN ('M', 'F', 'O')),
    race VARCHAR(50),
    ethnicity VARCHAR(50),
    primary_language VARCHAR(20) DEFAULT 'English',
    ssn_last4 CHAR(4),
    
    -- Contact Information
    street_address VARCHAR(100),
    city VARCHAR(50),
    state CHAR(2),
    zip_code VARCHAR(10),
    phone_primary VARCHAR(20),
    phone_secondary VARCHAR(20),
    email VARCHAR(100),
    
    -- Emergency Contact
    emergency_contact_name VARCHAR(100),
    emergency_contact_relationship VARCHAR(50),
    emergency_contact_phone VARCHAR(20),
    
    -- Insurance
    insurance_provider VARCHAR(100),
    insurance_policy_number VARCHAR(50),
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- ============================================
-- PROVIDERS TABLE
-- ============================================
-- Healthcare professionals (doctors, nurses, etc.)
CREATE TABLE providers (
    provider_id SERIAL PRIMARY KEY,
    npi CHAR(10) UNIQUE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    middle_name VARCHAR(50),
    title VARCHAR(20), -- MD, RN, NP, PA, etc.
    specialty VARCHAR(100),
    department VARCHAR(100),
    
    -- Contact
    phone VARCHAR(20),
    email VARCHAR(100),
    pager VARCHAR(20),
    
    -- Metadata
    hire_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- UNITS TABLE
-- ============================================
-- Hospital units/departments
CREATE TABLE units (
    unit_id SERIAL PRIMARY KEY,
    unit_code VARCHAR(20) UNIQUE NOT NULL,
    unit_name VARCHAR(100) NOT NULL,
    unit_type VARCHAR(50), -- ICU, Med-Surg, ED, PACU, OR, etc.
    floor VARCHAR(10),
    building VARCHAR(50),
    phone VARCHAR(20),
    total_beds INTEGER,
    is_active BOOLEAN DEFAULT TRUE
);

-- ============================================
-- ENCOUNTERS TABLE
-- ============================================
-- Patient visits/admissions
CREATE TABLE encounters (
    encounter_id SERIAL PRIMARY KEY,
    patient_id INTEGER NOT NULL REFERENCES patients(patient_id),
    encounter_number VARCHAR(30) UNIQUE NOT NULL,
    encounter_type VARCHAR(20) NOT NULL CHECK (encounter_type IN ('Inpatient', 'Outpatient', 'Emergency', 'Observation')),
    
    -- Admission Info
    admit_date TIMESTAMP NOT NULL,
    discharge_date TIMESTAMP,
    admitting_provider_id INTEGER REFERENCES providers(provider_id),
    attending_provider_id INTEGER REFERENCES providers(provider_id),
    
    -- Location
    current_unit_id INTEGER REFERENCES units(unit_id),
    room_number VARCHAR(20),
    bed_number VARCHAR(10),
    
    -- Clinical Info
    chief_complaint TEXT,
    admission_source VARCHAR(50), -- Emergency Room, Direct Admit, Transfer, etc.
    discharge_disposition VARCHAR(50), -- Home, SNF, Rehab, Expired, AMA, etc.
    
    -- Status
    encounter_status VARCHAR(20) DEFAULT 'Active' CHECK (encounter_status IN ('Active', 'Discharged', 'Cancelled')),
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- DIAGNOSES TABLE
-- ============================================
-- ICD-10 coded diagnoses
CREATE TABLE diagnoses (
    diagnosis_id SERIAL PRIMARY KEY,
    encounter_id INTEGER NOT NULL REFERENCES encounters(encounter_id) ON DELETE CASCADE,
    icd10_code VARCHAR(10) NOT NULL,
    diagnosis_description TEXT NOT NULL,
    diagnosis_type VARCHAR(20) CHECK (diagnosis_type IN ('Primary', 'Secondary', 'Admission', 'Working')),
    diagnosed_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    diagnosed_by_provider_id INTEGER REFERENCES providers(provider_id),
    is_resolved BOOLEAN DEFAULT FALSE,
    resolved_date TIMESTAMP,
    
    -- Ensure unique diagnosis codes per encounter
    UNIQUE(encounter_id, icd10_code, diagnosis_type)
);

-- ============================================
-- MEDICATIONS TABLE
-- ============================================
-- Medication reference/formulary
CREATE TABLE medications (
    medication_id SERIAL PRIMARY KEY,
    medication_name VARCHAR(200) NOT NULL,
    generic_name VARCHAR(200),
    brand_name VARCHAR(200),
    medication_class VARCHAR(100),
    controlled_substance_schedule VARCHAR(10), -- NULL, II, III, IV, V
    default_route VARCHAR(50),
    default_form VARCHAR(50),
    is_high_alert BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    
    UNIQUE(medication_name, generic_name)
);

-- ============================================
-- MEDICATION_ADMINISTRATIONS TABLE
-- ============================================
-- MAR (Medication Administration Record)
CREATE TABLE medication_administrations (
    admin_id SERIAL PRIMARY KEY,
    encounter_id INTEGER NOT NULL REFERENCES encounters(encounter_id) ON DELETE CASCADE,
    medication_id INTEGER NOT NULL REFERENCES medications(medication_id),
    
    -- Order Info
    ordered_dose VARCHAR(50) NOT NULL,
    ordered_unit VARCHAR(20) NOT NULL,
    ordered_route VARCHAR(50) NOT NULL,
    ordered_frequency VARCHAR(50) NOT NULL,
    
    -- Administration Info
    admin_date TIMESTAMP NOT NULL,
    admin_dose VARCHAR(50),
    admin_unit VARCHAR(20),
    admin_route VARCHAR(50),
    admin_site VARCHAR(50), -- For injections
    
    -- Provider Info
    ordering_provider_id INTEGER REFERENCES providers(provider_id),
    administering_provider_id INTEGER REFERENCES providers(provider_id),
    
    -- Status
    admin_status VARCHAR(20) DEFAULT 'Given' CHECK (admin_status IN ('Given', 'Held', 'Refused', 'Not Given')),
    hold_reason TEXT,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- LAB_RESULTS TABLE
-- ============================================
-- Laboratory test results
CREATE TABLE lab_results (
    lab_id SERIAL PRIMARY KEY,
    encounter_id INTEGER NOT NULL REFERENCES encounters(encounter_id) ON DELETE CASCADE,
    
    -- Test Info
    loinc_code VARCHAR(20),
    test_name VARCHAR(200) NOT NULL,
    test_category VARCHAR(100), -- Chemistry, Hematology, Microbiology, etc.
    
    -- Results
    result_value VARCHAR(50),
    result_unit VARCHAR(50),
    result_status VARCHAR(20) CHECK (result_status IN ('Final', 'Preliminary', 'Corrected', 'Cancelled')),
    abnormal_flag VARCHAR(10) CHECK (abnormal_flag IN ('Normal', 'Low', 'High', 'Critical Low', 'Critical High', 'Abnormal')),
    
    -- Reference Range
    reference_range_low NUMERIC,
    reference_range_high NUMERIC,
    
    -- Timing
    collected_date TIMESTAMP NOT NULL,
    resulted_date TIMESTAMP,
    
    -- Provider Info
    ordering_provider_id INTEGER REFERENCES providers(provider_id),
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- VITAL_SIGNS TABLE
-- ============================================
-- Patient vital signs
CREATE TABLE vital_signs (
    vital_id SERIAL PRIMARY KEY,
    encounter_id INTEGER NOT NULL REFERENCES encounters(encounter_id) ON DELETE CASCADE,
    
    -- Vital Sign Values
    temperature_f NUMERIC(4,1),
    heart_rate INTEGER,
    respiratory_rate INTEGER,
    blood_pressure_systolic INTEGER,
    blood_pressure_diastolic INTEGER,
    oxygen_saturation INTEGER,
    pain_scale INTEGER CHECK (pain_scale >= 0 AND pain_scale <= 10),
    
    -- Additional Vitals
    weight_kg NUMERIC(5,2),
    height_cm NUMERIC(5,2),
    bmi NUMERIC(4,1),
    
    -- Context
    position VARCHAR(50), -- Sitting, Standing, Supine, etc.
    oxygen_delivery VARCHAR(50), -- Room Air, Nasal Cannula, Mask, etc.
    oxygen_flow_rate NUMERIC(3,1), -- L/min
    
    -- Metadata
    recorded_date TIMESTAMP NOT NULL,
    recorded_by_provider_id INTEGER REFERENCES providers(provider_id),
    
    -- Validation
    CONSTRAINT valid_temp CHECK (temperature_f IS NULL OR (temperature_f >= 90 AND temperature_f <= 110)),
    CONSTRAINT valid_hr CHECK (heart_rate IS NULL OR (heart_rate >= 20 AND heart_rate <= 300)),
    CONSTRAINT valid_rr CHECK (respiratory_rate IS NULL OR (respiratory_rate >= 4 AND respiratory_rate <= 60)),
    CONSTRAINT valid_bp_sys CHECK (blood_pressure_systolic IS NULL OR (blood_pressure_systolic >= 50 AND blood_pressure_systolic <= 300)),
    CONSTRAINT valid_bp_dia CHECK (blood_pressure_diastolic IS NULL OR (blood_pressure_diastolic >= 20 AND blood_pressure_diastolic <= 200)),
    CONSTRAINT valid_o2_sat CHECK (oxygen_saturation IS NULL OR (oxygen_saturation >= 0 AND oxygen_saturation <= 100))
);

-- ============================================
-- NURSING_ASSESSMENTS TABLE
-- ============================================
-- Nursing documentation
CREATE TABLE nursing_assessments (
    assessment_id SERIAL PRIMARY KEY,
    encounter_id INTEGER NOT NULL REFERENCES encounters(encounter_id) ON DELETE CASCADE,
    assessment_date TIMESTAMP NOT NULL,
    
    -- Assessment Type
    assessment_type VARCHAR(50), -- Admission, Shift, Discharge, Fall Risk, Skin, etc.
    
    -- General Assessment
    level_of_consciousness VARCHAR(50), -- Alert, Confused, Lethargic, Obtunded, etc.
    orientation VARCHAR(50), -- Person, Place, Time, Situation
    
    -- Safety
    fall_risk_score INTEGER,
    fall_risk_level VARCHAR(20), -- Low, Moderate, High
    bed_alarm_on BOOLEAN,
    restraints_in_use BOOLEAN,
    
    -- Skin
    skin_integrity VARCHAR(50), -- Intact, Impaired, etc.
    pressure_ulcer_present BOOLEAN,
    braden_score INTEGER,
    
    -- Activity
    activity_level VARCHAR(50), -- Bedrest, Chair, Ambulatory, etc.
    gait_steady BOOLEAN,
    assistive_device VARCHAR(50),
    
    -- Notes
    assessment_notes TEXT,
    
    -- Provider
    assessing_provider_id INTEGER REFERENCES providers(provider_id),
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================
-- ALLERGIES TABLE
-- ============================================
CREATE TABLE allergies (
    allergy_id SERIAL PRIMARY KEY,
    patient_id INTEGER NOT NULL REFERENCES patients(patient_id),
    allergen VARCHAR(200) NOT NULL,
    allergy_type VARCHAR(50), -- Drug, Food, Environmental, etc.
    reaction VARCHAR(200),
    severity VARCHAR(20) CHECK (severity IN ('Mild', 'Moderate', 'Severe', 'Life-threatening')),
    onset_date DATE,
    reported_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    reported_by_provider_id INTEGER REFERENCES providers(provider_id),
    is_active BOOLEAN DEFAULT TRUE,
    
    UNIQUE(patient_id, allergen)
);

-- ============================================
-- UPDATE TRIGGERS
-- ============================================
-- Auto-update timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_patients_updated_at BEFORE UPDATE ON patients
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_encounters_updated_at BEFORE UPDATE ON encounters
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- COMMENTS
-- ============================================
COMMENT ON SCHEMA clinical IS 'Clinical data warehouse for patient care tracking';
COMMENT ON TABLE patients IS 'Core patient demographics and identification';
COMMENT ON TABLE encounters IS 'Patient visits, admissions, and hospital stays';
COMMENT ON TABLE providers IS 'Healthcare professionals including doctors, nurses, and support staff';
COMMENT ON TABLE diagnoses IS 'ICD-10 coded diagnoses associated with encounters';
COMMENT ON TABLE medications IS 'Medication formulary reference table';
COMMENT ON TABLE medication_administrations IS 'Medication Administration Record (MAR) entries';
COMMENT ON TABLE lab_results IS 'Laboratory test results with LOINC coding';
COMMENT ON TABLE vital_signs IS 'Patient vital sign measurements';
COMMENT ON TABLE nursing_assessments IS 'Nursing documentation and assessments';
COMMENT ON TABLE allergies IS 'Patient allergy records';