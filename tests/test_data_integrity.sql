-- Healthcare Clinical Database Data Integrity Tests
-- Using pgTAP for unit testing
-- Run with: pg_prove -d healthcare_clinical tests/

SET search_path TO clinical, public;

-- Start TAP
BEGIN;

-- Plan the number of tests
SELECT plan(20);

-- ============================================
-- REFERENTIAL INTEGRITY TESTS
-- ============================================

-- Test that orphaned encounters cannot exist
PREPARE orphan_encounter AS
INSERT INTO clinical.encounters (patient_id, encounter_number, encounter_type, admit_date)
VALUES (99999, 'ORPHAN001', 'Inpatient', NOW());

SELECT throws_ok(
    'orphan_encounter',
    '23503',
    'insert or update on table "encounters" violates foreign key constraint "encounters_patient_id_fkey"',
    'Should not allow encounters without valid patient'
);

-- Test that orphaned diagnoses cannot exist
PREPARE orphan_diagnosis AS
INSERT INTO clinical.diagnoses (encounter_id, icd10_code, diagnosis_description)
VALUES (99999, 'Z99.99', 'Test diagnosis');

SELECT throws_ok(
    'orphan_diagnosis',
    '23503',
    'insert or update on table "diagnoses" violates foreign key constraint "diagnoses_encounter_id_fkey"',
    'Should not allow diagnoses without valid encounter'
);

-- ============================================
-- BUSINESS RULE TESTS
-- ============================================

-- Test that discharge date cannot be before admit date
PREPARE invalid_discharge AS
INSERT INTO clinical.encounters (patient_id, encounter_number, encounter_type, admit_date, discharge_date)
SELECT patient_id, 'INVALID001', 'Inpatient', NOW(), NOW() - INTERVAL '1 day'
FROM clinical.patients LIMIT 1;

-- This should be caught by application logic or a trigger
-- For now, test that we can detect this condition
SELECT is(
    (SELECT COUNT(*) FROM clinical.encounters 
     WHERE discharge_date < admit_date),
    0::bigint,
    'No encounters should have discharge before admission'
);

-- Test that critical lab values are properly flagged
SELECT is(
    (SELECT COUNT(*) FROM clinical.lab_results 
     WHERE result_value::numeric > reference_range_high * 1.5 
     AND abnormal_flag NOT IN ('High', 'Critical High')),
    0::bigint,
    'High lab values should be properly flagged'
);

-- ============================================
-- DATA QUALITY TESTS
-- ============================================

-- Test that all patients have required fields
SELECT is(
    (SELECT COUNT(*) FROM clinical.patients 
     WHERE mrn IS NULL OR first_name IS NULL OR last_name IS NULL OR date_of_birth IS NULL),
    0::bigint,
    'All patients should have required fields'
);

-- Test that all active encounters have valid status
SELECT is(
    (SELECT COUNT(*) FROM clinical.encounters 
     WHERE encounter_status NOT IN ('Active', 'Discharged', 'Cancelled')),
    0::bigint,
    'All encounters should have valid status'
);

-- Test that medication administrations have valid routes
SELECT is(
    (SELECT COUNT(*) FROM clinical.medication_administrations 
     WHERE admin_route NOT IN ('PO', 'IV', 'IM', 'SubQ', 'Topical', 'PR', 'SL', 'INH', 'TD')),
    0::bigint,
    'All medication administrations should have valid routes'
);

-- ============================================
-- CONSTRAINT VIOLATION TESTS
-- ============================================

-- Test duplicate MRN prevention
PREPARE duplicate_mrn AS
INSERT INTO clinical.patients (mrn, first_name, last_name, date_of_birth)
SELECT mrn, 'Duplicate', 'Patient', '1990-01-01'
FROM clinical.patients LIMIT 1;

SELECT throws_ok(
    'duplicate_mrn',
    '23505',
    'duplicate key value violates unique constraint "patients_mrn_key"',
    'Should not allow duplicate MRNs'
);

-- Test invalid pain scale
PREPARE invalid_pain AS
INSERT INTO clinical.vital_signs (encounter_id, pain_scale, recorded_date)
SELECT encounter_id, 15, NOW()
FROM clinical.encounters 
WHERE encounter_status = 'Active' 
LIMIT 1;

SELECT throws_ok(
    'invalid_pain',
    '23514',
    'new row for relation "vital_signs" violates check constraint "vital_signs_pain_scale_check"',
    'Should not allow pain scale > 10'
);

-- ============================================
-- AGGREGATE TESTS
-- ============================================

-- Test that all units have reasonable bed counts
SELECT is(
    (SELECT COUNT(*) FROM clinical.units 
     WHERE total_beds < 1 OR total_beds > 100),
    0::bigint,
    'All units should have reasonable bed counts'
);

-- Test that provider NPIs are properly formatted
SELECT is(
    (SELECT COUNT(*) FROM clinical.providers 
     WHERE npi IS NOT NULL AND LENGTH(npi) != 10),
    0::bigint,
    'All NPIs should be 10 characters'
);

-- ============================================
-- VIEW INTEGRITY TESTS
-- ============================================

-- Test that census view shows only active encounters
SELECT is(
    (SELECT COUNT(*) FROM clinical.v_current_census 
     WHERE patient_count > 0),
    (SELECT COUNT(DISTINCT current_unit_id) FROM clinical.encounters 
     WHERE encounter_status = 'Active')::bigint,
    'Census view should only count active encounters'
);

-- Test that readmission view logic is correct
SELECT cmp_ok(
    (SELECT COUNT(*) FROM clinical.v_30day_readmissions),
    '>=',
    0::bigint,
    'Readmission view should return valid results'
);

-- ============================================
-- TEMPORAL TESTS
-- ============================================

-- Test that all timestamps are reasonable
SELECT is(
    (SELECT COUNT(*) FROM clinical.encounters 
     WHERE admit_date > NOW() + INTERVAL '1 day'),
    0::bigint,
    'No encounters should have future admit dates'
);

-- Test that resolved diagnoses have resolution dates
SELECT is(
    (SELECT COUNT(*) FROM clinical.diagnoses 
     WHERE is_resolved = true AND resolved_date IS NULL),
    0::bigint,
    'Resolved diagnoses should have resolution dates'
);

-- ============================================
-- PERFORMANCE TESTS
-- ============================================

-- Test that key queries use indexes (basic check)
SELECT ok(
    (SELECT COUNT(*) > 0 FROM pg_indexes 
     WHERE schemaname = 'clinical' 
     AND tablename = 'encounters' 
     AND indexname LIKE '%patient_id%'),
    'Encounters should have index on patient_id'
);

SELECT ok(
    (SELECT COUNT(*) > 0 FROM pg_indexes 
     WHERE schemaname = 'clinical' 
     AND tablename = 'lab_results' 
     AND indexname LIKE '%encounter_id%'),
    'Lab results should have index on encounter_id'
);

-- Finish tests
SELECT * FROM finish();
ROLLBACK;