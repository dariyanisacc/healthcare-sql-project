-- Healthcare Clinical Database Schema Tests
-- Using pgTAP for unit testing
-- Run with: pg_prove -d healthcare_clinical tests/

SET search_path TO clinical, public;

-- Start TAP
BEGIN;

-- Plan the number of tests
SELECT plan(30);

-- ============================================
-- SCHEMA TESTS
-- ============================================

-- Test schema exists
SELECT has_schema('clinical', 'Schema clinical should exist');

-- ============================================
-- TABLE EXISTENCE TESTS
-- ============================================

SELECT has_table('clinical', 'patients', 'Table patients should exist');
SELECT has_table('clinical', 'providers', 'Table providers should exist');
SELECT has_table('clinical', 'units', 'Table units should exist');
SELECT has_table('clinical', 'encounters', 'Table encounters should exist');
SELECT has_table('clinical', 'diagnoses', 'Table diagnoses should exist');
SELECT has_table('clinical', 'medications', 'Table medications should exist');
SELECT has_table('clinical', 'medication_administrations', 'Table medication_administrations should exist');
SELECT has_table('clinical', 'lab_results', 'Table lab_results should exist');
SELECT has_table('clinical', 'vital_signs', 'Table vital_signs should exist');
SELECT has_table('clinical', 'nursing_assessments', 'Table nursing_assessments should exist');
SELECT has_table('clinical', 'allergies', 'Table allergies should exist');

-- ============================================
-- PRIMARY KEY TESTS
-- ============================================

SELECT has_pk('clinical', 'patients', 'Table patients should have a primary key');
SELECT has_pk('clinical', 'providers', 'Table providers should have a primary key');
SELECT has_pk('clinical', 'encounters', 'Table encounters should have a primary key');

-- ============================================
-- UNIQUE CONSTRAINT TESTS
-- ============================================

SELECT has_unique('clinical', 'patients', ARRAY['mrn'], 'MRN should be unique');
SELECT has_unique('clinical', 'providers', ARRAY['npi'], 'NPI should be unique when not null');
SELECT has_unique('clinical', 'encounters', ARRAY['encounter_number'], 'Encounter number should be unique');

-- ============================================
-- FOREIGN KEY TESTS
-- ============================================

SELECT has_fk('clinical', 'encounters', 'encounters_patient_id_fkey', 'Encounters should reference patients');
SELECT has_fk('clinical', 'diagnoses', 'diagnoses_encounter_id_fkey', 'Diagnoses should reference encounters');
SELECT has_fk('clinical', 'medication_administrations', 'medication_administrations_encounter_id_fkey', 'Med admin should reference encounters');

-- ============================================
-- CHECK CONSTRAINT TESTS
-- ============================================

-- Test sex constraint
SELECT throws_ok(
    $$INSERT INTO clinical.patients (mrn, first_name, last_name, date_of_birth, sex) 
      VALUES ('TEST001', 'Test', 'Patient', '1990-01-01', 'X')$$,
    '23514',
    'new row for relation "patients" violates check constraint "patients_sex_check"',
    'Should not allow invalid sex values'
);

-- Test encounter status constraint
SELECT throws_ok(
    $$INSERT INTO clinical.encounters (patient_id, encounter_number, encounter_type, admit_date, encounter_status)
      VALUES (1, 'TEST001', 'Inpatient', NOW(), 'Invalid')$$,
    '23514',
    'new row for relation "encounters" violates check constraint "encounters_encounter_status_check"',
    'Should not allow invalid encounter status'
);

-- Test vital signs range constraints
SELECT throws_ok(
    $$INSERT INTO clinical.vital_signs (encounter_id, temperature_f, recorded_date)
      VALUES (1, 150.0, NOW())$$,
    '23514',
    'new row for relation "vital_signs" violates check constraint "valid_temp"',
    'Should not allow temperature > 110F'
);

-- ============================================
-- VIEW EXISTENCE TESTS  
-- ============================================

SELECT has_view('clinical', 'v_current_census', 'View v_current_census should exist');
SELECT has_view('clinical', 'v_30day_readmissions', 'View v_30day_readmissions should exist');
SELECT has_view('clinical', 'v_sepsis_screening', 'View v_sepsis_screening should exist');
SELECT has_view('clinical', 'v_patient_acuity', 'View v_patient_acuity should exist');

-- ============================================
-- TRIGGER TESTS
-- ============================================

SELECT has_trigger('clinical', 'patients', 'update_patients_updated_at', 'Update trigger should exist for patients');
SELECT has_trigger('clinical', 'encounters', 'update_encounters_updated_at', 'Update trigger should exist for encounters');

-- Finish tests
SELECT * FROM finish();
ROLLBACK;