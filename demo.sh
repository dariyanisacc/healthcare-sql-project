#!/bin/bash
# Simple demo script to test the healthcare database

# Add PostgreSQL to PATH
export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"

echo "🏥 Healthcare Clinical Database Demo"
echo "===================================="
echo ""

# Check if database exists
if ! psql -lqt | cut -d \| -f 1 | grep -qw healthcare_clinical; then
    echo "❌ Database 'healthcare_clinical' not found!"
    echo "Run ./setup_and_test.sh first to create and populate the database."
    exit 1
fi

echo "✅ Database found. Running demo queries..."
echo ""

# Demo 1: Current Census
echo "1️⃣ CURRENT HOSPITAL CENSUS"
echo "--------------------------"
psql -d healthcare_clinical -c "
SELECT 
    unit_code,
    unit_name,
    patient_count,
    total_beds,
    occupancy_rate || '%' as occupancy
FROM clinical.v_current_census
ORDER BY occupancy_rate DESC
LIMIT 10;"

echo ""
echo "2️⃣ HIGH-RISK PATIENTS (Acuity Score)"
echo "------------------------------------"
psql -d healthcare_clinical -c "
SELECT 
    p.mrn,
    p.first_name || ' ' || p.last_name as patient_name,
    e.room_number || '-' || e.bed_number as location,
    pa.acuity_score,
    pa.acuity_level
FROM clinical.v_patient_acuity pa
JOIN clinical.patients p ON pa.patient_id = p.patient_id
JOIN clinical.encounters e ON pa.encounter_id = e.encounter_id
WHERE pa.acuity_level IN ('High', 'Critical')
ORDER BY pa.acuity_score DESC
LIMIT 10;"

echo ""
echo "3️⃣ SEPSIS SCREENING ALERTS"
echo "--------------------------"
psql -d healthcare_clinical -c "
SELECT 
    encounter_number,
    patient_name,
    unit_code || '-' || room_number as location,
    sirs_score,
    sirs_status,
    CASE 
        WHEN temp_abnormal = 1 THEN 'Temp: ' || temperature_f || '°F '
        ELSE ''
    END ||
    CASE 
        WHEN hr_abnormal = 1 THEN 'HR: ' || heart_rate || ' '
        ELSE ''
    END ||
    CASE 
        WHEN rr_abnormal = 1 THEN 'RR: ' || respiratory_rate || ' '
        ELSE ''
    END as abnormal_vitals
FROM clinical.v_sepsis_screening
WHERE sirs_status = 'SIRS POSITIVE'
LIMIT 10;"

echo ""
echo "4️⃣ CRITICAL LAB VALUES (Last 24 Hours)"
echo "--------------------------------------"
psql -d healthcare_clinical -c "
SELECT 
    cl.mrn,
    cl.patient_name,
    cl.test_name,
    cl.result_value || ' ' || cl.result_unit as result,
    cl.abnormal_flag,
    cl.reference_range,
    TO_CHAR(cl.resulted_date, 'MM/DD HH24:MI') as resulted_time
FROM clinical.v_critical_labs cl
WHERE cl.resulted_date > NOW() - INTERVAL '24 hours'
ORDER BY cl.resulted_date DESC
LIMIT 10;"

echo ""
echo "5️⃣ 30-DAY READMISSIONS"
echo "----------------------"
psql -d healthcare_clinical -c "
WITH readmit_summary AS (
    SELECT 
        COUNT(*) as total_readmissions,
        COUNT(DISTINCT patient_id) as unique_patients,
        AVG(days_between_admissions) as avg_days_to_readmit
    FROM clinical.v_30day_readmissions
)
SELECT * FROM readmit_summary;"

echo ""
echo "📊 DATABASE STATISTICS"
echo "---------------------"
psql -d healthcare_clinical -c "
SELECT 
    'Patients' as entity,
    COUNT(*) as count
FROM clinical.patients
UNION ALL
SELECT 'Active Encounters', COUNT(*) 
FROM clinical.encounters WHERE encounter_status = 'Active'
UNION ALL
SELECT 'Total Encounters', COUNT(*) 
FROM clinical.encounters
UNION ALL
SELECT 'Medications Given (24h)', COUNT(*) 
FROM clinical.medication_administrations 
WHERE admin_date > NOW() - INTERVAL '24 hours' AND admin_status = 'Given'
UNION ALL
SELECT 'Lab Results (7d)', COUNT(*) 
FROM clinical.lab_results WHERE resulted_date > NOW() - INTERVAL '7 days'
UNION ALL
SELECT 'Vital Signs (24h)', COUNT(*) 
FROM clinical.vital_signs WHERE recorded_date > NOW() - INTERVAL '24 hours';"

echo ""
echo "💡 To explore more:"
echo "   psql -d healthcare_clinical"
echo "   \\dt clinical.*     -- List all tables"
echo "   \\dv clinical.*     -- List all views"
echo ""
echo "📚 Check out sql/05_demo_queries.sql for more examples!"