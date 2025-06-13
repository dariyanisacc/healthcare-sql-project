-- Healthcare Clinical Database Data Seeding
-- Version: 1.0
-- Description: Load synthetic data from CSV files

SET search_path TO clinical, public;

-- ============================================
-- LOAD BASE DATA
-- ============================================

-- Load patients
\echo 'Loading patients...'
\copy patients(patient_id, mrn, first_name, last_name, middle_name, date_of_birth, sex, race, ethnicity, primary_language, ssn_last4, street_address, city, state, zip_code, phone_primary, phone_secondary, email, emergency_contact_name, emergency_contact_relationship, emergency_contact_phone, insurance_provider, insurance_policy_number, created_at, is_active) FROM '../data/raw/patients.csv' WITH CSV HEADER;

-- Load providers
\echo 'Loading providers...'
\copy providers(provider_id, npi, first_name, last_name, middle_name, title, specialty, department, phone, email, pager, hire_date, is_active) FROM '../data/raw/providers.csv' WITH CSV HEADER;

-- Load units
\echo 'Loading units...'
\copy units(unit_id, unit_code, unit_name, unit_type, floor, building, phone, total_beds, is_active) FROM '../data/raw/units.csv' WITH CSV HEADER;

-- Load medications
\echo 'Loading medications...'
\copy medications(medication_id, medication_name, generic_name, brand_name, medication_class, controlled_substance_schedule, default_route, default_form, is_high_alert, is_active) FROM '../data/raw/medications.csv' WITH CSV HEADER;

-- ============================================
-- LOAD ENCOUNTER DATA
-- ============================================

-- Load encounters
\echo 'Loading encounters...'
\copy encounters(encounter_id, patient_id, encounter_number, encounter_type, admit_date, discharge_date, admitting_provider_id, attending_provider_id, current_unit_id, room_number, bed_number, chief_complaint, admission_source, discharge_disposition, encounter_status, created_at) FROM '../data/raw/encounters.csv' WITH CSV HEADER;

-- Load diagnoses
\echo 'Loading diagnoses...'
\copy diagnoses(diagnosis_id, encounter_id, icd10_code, diagnosis_description, diagnosis_type, diagnosed_date, diagnosed_by_provider_id, is_resolved, resolved_date) FROM '../data/raw/diagnoses.csv' WITH CSV HEADER;

-- Load medication administrations
\echo 'Loading medication administrations...'
\copy medication_administrations(admin_id, encounter_id, medication_id, ordered_dose, ordered_unit, ordered_route, ordered_frequency, admin_date, admin_dose, admin_unit, admin_route, admin_site, ordering_provider_id, administering_provider_id, admin_status, hold_reason, created_at) FROM '../data/raw/medication_administrations.csv' WITH CSV HEADER;

-- Load lab results
\echo 'Loading lab results...'
\copy lab_results(lab_id, encounter_id, loinc_code, test_name, test_category, result_value, result_unit, result_status, abnormal_flag, reference_range_low, reference_range_high, collected_date, resulted_date, ordering_provider_id, created_at) FROM '../data/raw/lab_results.csv' WITH CSV HEADER;

-- Load vital signs
\echo 'Loading vital signs...'
\copy vital_signs(vital_id, encounter_id, temperature_f, heart_rate, respiratory_rate, blood_pressure_systolic, blood_pressure_diastolic, oxygen_saturation, pain_scale, weight_kg, height_cm, bmi, position, oxygen_delivery, oxygen_flow_rate, recorded_date, recorded_by_provider_id) FROM '../data/raw/vital_signs.csv' WITH CSV HEADER;

-- Load nursing assessments
\echo 'Loading nursing assessments...'
\copy nursing_assessments(assessment_id, encounter_id, assessment_date, assessment_type, level_of_consciousness, orientation, fall_risk_score, fall_risk_level, bed_alarm_on, restraints_in_use, skin_integrity, pressure_ulcer_present, braden_score, activity_level, gait_steady, assistive_device, assessment_notes, assessing_provider_id, created_at) FROM '../data/raw/nursing_assessments.csv' WITH CSV HEADER;

-- Load allergies
\echo 'Loading allergies...'
\copy allergies(allergy_id, patient_id, allergen, allergy_type, reaction, severity, onset_date, reported_date, reported_by_provider_id, is_active) FROM '../data/raw/allergies.csv' WITH CSV HEADER;

-- ============================================
-- UPDATE SEQUENCES
-- ============================================
-- Reset sequences to continue after loaded data

SELECT setval('patients_patient_id_seq', (SELECT MAX(patient_id) FROM patients));
SELECT setval('providers_provider_id_seq', (SELECT MAX(provider_id) FROM providers));
SELECT setval('units_unit_id_seq', (SELECT MAX(unit_id) FROM units));
SELECT setval('medications_medication_id_seq', (SELECT MAX(medication_id) FROM medications));
SELECT setval('encounters_encounter_id_seq', (SELECT MAX(encounter_id) FROM encounters));
SELECT setval('diagnoses_diagnosis_id_seq', (SELECT MAX(diagnosis_id) FROM diagnoses));
SELECT setval('medication_administrations_admin_id_seq', (SELECT MAX(admin_id) FROM medication_administrations));
SELECT setval('lab_results_lab_id_seq', (SELECT MAX(lab_id) FROM lab_results));
SELECT setval('vital_signs_vital_id_seq', (SELECT MAX(vital_id) FROM vital_signs));
SELECT setval('nursing_assessments_assessment_id_seq', (SELECT MAX(assessment_id) FROM nursing_assessments));
SELECT setval('allergies_allergy_id_seq', (SELECT MAX(allergy_id) FROM allergies));

-- ============================================
-- VERIFY DATA LOADED
-- ============================================
\echo ''
\echo 'Data loading complete. Summary:'
\echo '==============================='
SELECT 'Patients' as table_name, COUNT(*) as record_count FROM patients
UNION ALL
SELECT 'Providers', COUNT(*) FROM providers
UNION ALL
SELECT 'Units', COUNT(*) FROM units
UNION ALL
SELECT 'Medications', COUNT(*) FROM medications
UNION ALL
SELECT 'Encounters', COUNT(*) FROM encounters
UNION ALL
SELECT 'Diagnoses', COUNT(*) FROM diagnoses
UNION ALL
SELECT 'Medication Administrations', COUNT(*) FROM medication_administrations
UNION ALL
SELECT 'Lab Results', COUNT(*) FROM lab_results
UNION ALL
SELECT 'Vital Signs', COUNT(*) FROM vital_signs
UNION ALL
SELECT 'Nursing Assessments', COUNT(*) FROM nursing_assessments
UNION ALL
SELECT 'Allergies', COUNT(*) FROM allergies
ORDER BY table_name;