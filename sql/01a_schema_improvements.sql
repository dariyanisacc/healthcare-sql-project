-- Healthcare Clinical Database Schema Improvements
-- Version: 1.1
-- Description: Adds CASCADE constraints, lookup tables, and additional CHECK constraints

SET search_path TO clinical, public;

-- ============================================
-- LOOKUP TABLES FOR ENUMS
-- ============================================

-- Encounter Type Lookup
CREATE TABLE encounter_types (
    encounter_type_id SERIAL PRIMARY KEY,
    encounter_type_code VARCHAR(20) UNIQUE NOT NULL,
    encounter_type_name VARCHAR(50) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE
);

INSERT INTO encounter_types (encounter_type_code, encounter_type_name, description) VALUES
('IP', 'Inpatient', 'Patient admitted to hospital for overnight stay'),
('OP', 'Outpatient', 'Patient visit without overnight stay'),
('ED', 'Emergency', 'Emergency department visit'),
('OBS', 'Observation', 'Patient under observation status');

-- Unit Type Lookup
CREATE TABLE unit_types (
    unit_type_id SERIAL PRIMARY KEY,
    unit_type_code VARCHAR(20) UNIQUE NOT NULL,
    unit_type_name VARCHAR(50) NOT NULL,
    acuity_level INTEGER CHECK (acuity_level BETWEEN 1 AND 5),
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE
);

INSERT INTO unit_types (unit_type_code, unit_type_name, acuity_level, description) VALUES
('ICU', 'Intensive Care Unit', 5, 'Critical care for severely ill patients'),
('MEDSURG', 'Medical-Surgical', 2, 'General medical and surgical care'),
('ED', 'Emergency Department', 4, 'Emergency and urgent care'),
('PACU', 'Post-Anesthesia Care Unit', 3, 'Recovery after surgery'),
('OR', 'Operating Room', 4, 'Surgical procedures'),
('L&D', 'Labor & Delivery', 3, 'Maternity care'),
('NICU', 'Neonatal ICU', 5, 'Critical care for newborns'),
('PEDS', 'Pediatrics', 2, 'General pediatric care'),
('PSYCH', 'Psychiatry', 2, 'Mental health unit'),
('REHAB', 'Rehabilitation', 1, 'Physical therapy and rehabilitation');

-- Admin Status Lookup
CREATE TABLE admin_status_types (
    admin_status_id SERIAL PRIMARY KEY,
    admin_status_code VARCHAR(20) UNIQUE NOT NULL,
    admin_status_name VARCHAR(50) NOT NULL,
    requires_reason BOOLEAN DEFAULT FALSE
);

INSERT INTO admin_status_types (admin_status_code, admin_status_name, requires_reason) VALUES
('GIVEN', 'Given', FALSE),
('HELD', 'Held', TRUE),
('REFUSED', 'Refused', TRUE),
('NOTGIVEN', 'Not Given', TRUE);

-- ============================================
-- ALTER EXISTING TABLES TO USE LOOKUPS
-- ============================================

-- First add the new columns
ALTER TABLE encounters ADD COLUMN encounter_type_id INTEGER;
ALTER TABLE units ADD COLUMN unit_type_id INTEGER;
ALTER TABLE medication_administrations ADD COLUMN admin_status_id INTEGER;

-- Populate the new columns based on existing data
UPDATE encounters e 
SET encounter_type_id = et.encounter_type_id 
FROM encounter_types et 
WHERE CASE 
    WHEN e.encounter_type = 'Inpatient' THEN 'IP'
    WHEN e.encounter_type = 'Outpatient' THEN 'OP'
    WHEN e.encounter_type = 'Emergency' THEN 'ED'
    WHEN e.encounter_type = 'Observation' THEN 'OBS'
END = et.encounter_type_code;

UPDATE units u 
SET unit_type_id = ut.unit_type_id 
FROM unit_types ut 
WHERE u.unit_type = ut.unit_type_name 
   OR (u.unit_type = 'Med-Surg' AND ut.unit_type_code = 'MEDSURG');

UPDATE medication_administrations ma 
SET admin_status_id = ast.admin_status_id 
FROM admin_status_types ast 
WHERE CASE 
    WHEN ma.admin_status = 'Given' THEN 'GIVEN'
    WHEN ma.admin_status = 'Held' THEN 'HELD'
    WHEN ma.admin_status = 'Refused' THEN 'REFUSED'
    WHEN ma.admin_status = 'Not Given' THEN 'NOTGIVEN'
END = ast.admin_status_code;

-- ============================================
-- DROP OLD CONSTRAINTS AND ADD CASCADE
-- ============================================

-- Drop existing foreign key constraints
ALTER TABLE encounters DROP CONSTRAINT IF EXISTS encounters_patient_id_fkey;
ALTER TABLE encounters DROP CONSTRAINT IF EXISTS encounters_current_unit_id_fkey;
ALTER TABLE diagnoses DROP CONSTRAINT IF EXISTS diagnoses_encounter_id_fkey;
ALTER TABLE allergies DROP CONSTRAINT IF EXISTS allergies_patient_id_fkey;
ALTER TABLE medication_administrations DROP CONSTRAINT IF EXISTS medication_administrations_encounter_id_fkey;
ALTER TABLE medication_administrations DROP CONSTRAINT IF EXISTS medication_administrations_medication_id_fkey;
ALTER TABLE lab_results DROP CONSTRAINT IF EXISTS lab_results_encounter_id_fkey;
ALTER TABLE vital_signs DROP CONSTRAINT IF EXISTS vital_signs_encounter_id_fkey;
ALTER TABLE nursing_assessments DROP CONSTRAINT IF EXISTS nursing_assessments_encounter_id_fkey;

-- Add foreign key constraints with CASCADE options
ALTER TABLE encounters ADD CONSTRAINT encounters_patient_id_fkey 
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id) 
    ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE encounters ADD CONSTRAINT encounters_current_unit_id_fkey 
    FOREIGN KEY (current_unit_id) REFERENCES units(unit_id) 
    ON UPDATE CASCADE ON DELETE SET NULL;

ALTER TABLE encounters ADD CONSTRAINT encounters_encounter_type_id_fkey 
    FOREIGN KEY (encounter_type_id) REFERENCES encounter_types(encounter_type_id) 
    ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE units ADD CONSTRAINT units_unit_type_id_fkey 
    FOREIGN KEY (unit_type_id) REFERENCES unit_types(unit_type_id) 
    ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE diagnoses ADD CONSTRAINT diagnoses_encounter_id_fkey 
    FOREIGN KEY (encounter_id) REFERENCES encounters(encounter_id) 
    ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE allergies ADD CONSTRAINT allergies_patient_id_fkey 
    FOREIGN KEY (patient_id) REFERENCES patients(patient_id) 
    ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE medication_administrations ADD CONSTRAINT medication_administrations_encounter_id_fkey 
    FOREIGN KEY (encounter_id) REFERENCES encounters(encounter_id) 
    ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE medication_administrations ADD CONSTRAINT medication_administrations_medication_id_fkey 
    FOREIGN KEY (medication_id) REFERENCES medications(medication_id) 
    ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE medication_administrations ADD CONSTRAINT medication_administrations_admin_status_id_fkey 
    FOREIGN KEY (admin_status_id) REFERENCES admin_status_types(admin_status_id) 
    ON UPDATE CASCADE ON DELETE RESTRICT;

ALTER TABLE lab_results ADD CONSTRAINT lab_results_encounter_id_fkey 
    FOREIGN KEY (encounter_id) REFERENCES encounters(encounter_id) 
    ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE vital_signs ADD CONSTRAINT vital_signs_encounter_id_fkey 
    FOREIGN KEY (encounter_id) REFERENCES encounters(encounter_id) 
    ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE nursing_assessments ADD CONSTRAINT nursing_assessments_encounter_id_fkey 
    FOREIGN KEY (encounter_id) REFERENCES encounters(encounter_id) 
    ON UPDATE CASCADE ON DELETE CASCADE;

-- ============================================
-- ADDITIONAL CHECK CONSTRAINTS
-- ============================================

-- Vital signs range checks (already exist, but let's add more)
ALTER TABLE vital_signs 
    ADD CONSTRAINT valid_weight CHECK (weight_kg IS NULL OR (weight_kg > 0 AND weight_kg < 1000)),
    ADD CONSTRAINT valid_height CHECK (height_cm IS NULL OR (height_cm > 0 AND height_cm < 300)),
    ADD CONSTRAINT valid_bmi CHECK (bmi IS NULL OR (bmi > 10 AND bmi < 100));

-- Lab results constraints
ALTER TABLE lab_results 
    ADD CONSTRAINT valid_reference_range CHECK (
        (reference_range_low IS NULL AND reference_range_high IS NULL) OR
        (reference_range_low < reference_range_high)
    );

-- Encounter date constraints
ALTER TABLE encounters 
    ADD CONSTRAINT valid_discharge_date CHECK (
        discharge_date IS NULL OR discharge_date >= admit_date
    );

-- Nursing assessment constraints
ALTER TABLE nursing_assessments 
    ADD CONSTRAINT valid_fall_risk_score CHECK (
        fall_risk_score IS NULL OR (fall_risk_score >= 0 AND fall_risk_score <= 25)
    ),
    ADD CONSTRAINT valid_braden_score CHECK (
        braden_score IS NULL OR (braden_score >= 6 AND braden_score <= 23)
    );

-- Provider constraints
ALTER TABLE providers 
    ADD CONSTRAINT valid_npi_format CHECK (
        npi IS NULL OR npi ~ '^\d{10}$'
    );

-- ============================================
-- PERFORMANCE INDEXES FOR LOOKUP TABLES
-- ============================================

CREATE INDEX idx_encounters_encounter_type_id ON encounters(encounter_type_id);
CREATE INDEX idx_units_unit_type_id ON units(unit_type_id);
CREATE INDEX idx_medication_administrations_admin_status_id ON medication_administrations(admin_status_id);

-- ============================================
-- UPDATE VIEWS TO USE LOOKUP TABLES
-- ============================================

-- Create improved census view using lookup tables
CREATE OR REPLACE VIEW v_current_census_improved AS
WITH unit_census AS (
    SELECT 
        u.unit_id,
        u.unit_code,
        u.unit_name,
        ut.unit_type_name,
        ut.acuity_level,
        u.total_beds,
        COUNT(DISTINCT e.patient_id) as patient_count
    FROM units u
    INNER JOIN unit_types ut ON u.unit_type_id = ut.unit_type_id
    LEFT JOIN encounters e ON u.unit_id = e.current_unit_id 
        AND e.encounter_status = 'Active'
    WHERE u.is_active = TRUE
    GROUP BY u.unit_id, u.unit_code, u.unit_name, ut.unit_type_name, ut.acuity_level, u.total_beds
)
SELECT 
    unit_code,
    unit_name,
    unit_type_name,
    acuity_level,
    patient_count,
    total_beds,
    ROUND((patient_count::NUMERIC / NULLIF(total_beds, 0) * 100), 1) as occupancy_rate
FROM unit_census
ORDER BY acuity_level DESC, unit_code;

-- ============================================
-- MIGRATION NOTES
-- ============================================
COMMENT ON TABLE encounter_types IS 'Lookup table for encounter types with standardized codes';
COMMENT ON TABLE unit_types IS 'Lookup table for unit types with acuity levels';
COMMENT ON TABLE admin_status_types IS 'Lookup table for medication administration statuses';

-- Note: After verifying data migration, the old varchar columns can be dropped:
-- ALTER TABLE encounters DROP COLUMN encounter_type;
-- ALTER TABLE units DROP COLUMN unit_type;
-- ALTER TABLE medication_administrations DROP COLUMN admin_status;