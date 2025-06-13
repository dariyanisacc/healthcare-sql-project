-- Healthcare Clinical Database Performance Analysis
-- Version: 1.0
-- Description: EXPLAIN ANALYZE key queries to identify optimization opportunities

SET search_path TO clinical, public;

\echo '============================================'
\echo 'PERFORMANCE ANALYSIS OF KEY QUERIES'
\echo '============================================'
\echo ''

-- Enable timing
\timing on

-- ============================================
-- 1. CURRENT CENSUS QUERY
-- ============================================
\echo '1. ANALYZING CURRENT CENSUS QUERY'
\echo '---------------------------------'
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT 
    u.unit_code,
    u.unit_name,
    COUNT(DISTINCT e.patient_id) as patient_count,
    u.total_beds,
    ROUND((COUNT(DISTINCT e.patient_id)::NUMERIC / u.total_beds * 100), 1) as occupancy_rate
FROM units u
LEFT JOIN encounters e ON u.unit_id = e.current_unit_id 
    AND e.encounter_status = 'Active'
GROUP BY u.unit_id, u.unit_code, u.unit_name, u.total_beds
ORDER BY u.unit_code;
\echo ''

-- ============================================
-- 2. 30-DAY READMISSION QUERY
-- ============================================
\echo '2. ANALYZING 30-DAY READMISSION QUERY'
\echo '-------------------------------------'
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
WITH readmissions AS (
    SELECT 
        p.patient_id,
        e1.encounter_id as initial_encounter_id,
        e1.discharge_date as initial_discharge,
        e2.encounter_id as readmit_encounter_id,
        e2.admit_date as readmit_date
    FROM encounters e1
    INNER JOIN encounters e2 ON e1.patient_id = e2.patient_id
        AND e2.admit_date > e1.discharge_date
        AND e2.admit_date <= e1.discharge_date + INTERVAL '30 days'
        AND e1.encounter_id < e2.encounter_id
    INNER JOIN patients p ON e1.patient_id = p.patient_id
    WHERE e1.discharge_date IS NOT NULL
        AND e1.encounter_type = 'Inpatient'
        AND e2.encounter_type = 'Inpatient'
    LIMIT 100
)
SELECT COUNT(*) FROM readmissions;
\echo ''

-- ============================================
-- 3. SEPSIS SCREENING QUERY
-- ============================================
\echo '3. ANALYZING SEPSIS SCREENING QUERY'
\echo '-----------------------------------'
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
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
        lr.result_value
    FROM lab_results lr
    WHERE lr.test_name = 'WBC'
        AND lr.collected_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
    ORDER BY lr.encounter_id, lr.test_name, lr.collected_date DESC
)
SELECT COUNT(*)
FROM encounters e
INNER JOIN latest_vitals lv ON e.encounter_id = lv.encounter_id
LEFT JOIN latest_labs ll ON e.encounter_id = ll.encounter_id
WHERE e.encounter_status = 'Active'
    AND (lv.temperature_f > 100.4 OR lv.heart_rate > 90);
\echo ''

-- ============================================
-- 4. MEDICATION ADMINISTRATION RECORD QUERY
-- ============================================
\echo '4. ANALYZING MAR QUERY FOR ACTIVE PATIENTS'
\echo '------------------------------------------'
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT 
    e.encounter_id,
    p.mrn,
    m.medication_name,
    ma.admin_date,
    ma.admin_status
FROM medication_administrations ma
INNER JOIN encounters e ON ma.encounter_id = e.encounter_id
INNER JOIN patients p ON e.patient_id = p.patient_id
INNER JOIN medications m ON ma.medication_id = m.medication_id
WHERE e.encounter_status = 'Active'
    AND ma.admin_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY e.encounter_id, ma.admin_date DESC
LIMIT 1000;
\echo ''

-- ============================================
-- 5. CRITICAL LAB VALUES QUERY
-- ============================================
\echo '5. ANALYZING CRITICAL LAB VALUES QUERY'
\echo '--------------------------------------'
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT 
    e.encounter_id,
    p.mrn,
    lr.test_name,
    lr.result_value,
    lr.abnormal_flag,
    lr.resulted_date
FROM lab_results lr
INNER JOIN encounters e ON lr.encounter_id = e.encounter_id
INNER JOIN patients p ON e.patient_id = p.patient_id
WHERE e.encounter_status = 'Active'
    AND lr.abnormal_flag IN ('Critical Low', 'Critical High')
    AND lr.resulted_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY lr.resulted_date DESC;
\echo ''

-- ============================================
-- 6. PATIENT ACUITY SCORING QUERY
-- ============================================
\echo '6. ANALYZING PATIENT ACUITY SCORING'
\echo '-----------------------------------'
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
WITH acuity_factors AS (
    SELECT 
        e.encounter_id,
        -- Vital signs score
        (SELECT COUNT(*) FROM vital_signs v 
         WHERE v.encounter_id = e.encounter_id 
         AND v.recorded_date >= CURRENT_TIMESTAMP - INTERVAL '4 hours'
         AND (v.heart_rate > 110 OR v.oxygen_saturation < 92)) as vital_score,
        -- High alert meds score
        (SELECT COUNT(DISTINCT m.medication_id) 
         FROM medication_administrations ma
         INNER JOIN medications m ON ma.medication_id = m.medication_id
         WHERE ma.encounter_id = e.encounter_id
         AND ma.admin_date >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
         AND m.is_high_alert = TRUE) as med_score
    FROM encounters e
    WHERE e.encounter_status = 'Active'
    LIMIT 100
)
SELECT * FROM acuity_factors WHERE vital_score > 0 OR med_score > 0;
\echo ''

-- ============================================
-- INDEX USAGE STATISTICS
-- ============================================
\echo '7. INDEX USAGE STATISTICS'
\echo '-------------------------'
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch,
    CASE 
        WHEN idx_scan = 0 THEN 'UNUSED'
        WHEN idx_scan < 100 THEN 'RARELY USED'
        WHEN idx_scan < 1000 THEN 'OCCASIONALLY USED'
        ELSE 'FREQUENTLY USED'
    END as usage_category
FROM pg_stat_user_indexes
WHERE schemaname = 'clinical'
ORDER BY idx_scan DESC;
\echo ''

-- ============================================
-- TABLE SIZE AND STATISTICS
-- ============================================
\echo '8. TABLE SIZES AND ROW COUNTS'
\echo '------------------------------'
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as total_size,
    n_live_tup as row_count,
    n_dead_tup as dead_rows,
    last_vacuum,
    last_analyze
FROM pg_stat_user_tables
WHERE schemaname = 'clinical'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
\echo ''

-- ============================================
-- SLOW QUERY IDENTIFICATION
-- ============================================
\echo '9. IDENTIFYING POTENTIAL SLOW QUERIES'
\echo '-------------------------------------'
\echo 'Checking for missing indexes on foreign keys...'
SELECT 
    tc.table_name,
    kcu.column_name,
    'CREATE INDEX idx_' || tc.table_name || '_' || kcu.column_name || 
    ' ON clinical.' || tc.table_name || '(' || kcu.column_name || ');' as suggested_index
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu 
    ON tc.constraint_name = kcu.constraint_name
LEFT JOIN pg_indexes i 
    ON i.schemaname = 'clinical' 
    AND i.tablename = tc.table_name 
    AND i.indexdef LIKE '%' || kcu.column_name || '%'
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_schema = 'clinical'
    AND i.indexname IS NULL;
\echo ''

-- ============================================
-- RECOMMENDATIONS
-- ============================================
\echo '10. PERFORMANCE RECOMMENDATIONS'
\echo '-------------------------------'
\echo '1. Consider partitioning large tables (lab_results, vital_signs) by date'
\echo '2. Add covering indexes for frequently joined columns'
\echo '3. Use materialized views for complex aggregations'
\echo '4. Enable pg_stat_statements for query performance tracking'
\echo '5. Set up regular VACUUM and ANALYZE schedules'
\echo ''

\timing off