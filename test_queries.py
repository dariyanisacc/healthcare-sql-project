#!/usr/bin/env python3
"""
Simple Python script to test database queries
"""

import psycopg2
import pandas as pd
from tabulate import tabulate

# Database connection
conn = psycopg2.connect(
    dbname="healthcare_clinical",
    user="dariyanjones",  # Change to your username
    host="localhost"
)

def run_query(query, title):
    """Run a query and display results"""
    print(f"\n{'='*60}")
    print(f"{title}")
    print('='*60)
    
    df = pd.read_sql_query(query, conn)
    print(tabulate(df.head(10), headers='keys', tablefmt='grid'))
    print(f"Total rows: {len(df)}")
    return df

# Test queries
queries = [
    (
        "SELECT * FROM clinical.v_current_census ORDER BY occupancy_rate DESC",
        "Current Hospital Census"
    ),
    (
        """
        SELECT 
            p.mrn,
            p.first_name || ' ' || p.last_name as patient_name,
            COUNT(DISTINCT d.diagnosis_id) as diagnosis_count,
            COUNT(DISTINCT ma.admin_id) as medication_count,
            COUNT(DISTINCT lr.lab_id) as lab_count
        FROM clinical.patients p
        JOIN clinical.encounters e ON p.patient_id = e.patient_id
        LEFT JOIN clinical.diagnoses d ON e.encounter_id = d.encounter_id
        LEFT JOIN clinical.medication_administrations ma ON e.encounter_id = ma.encounter_id
        LEFT JOIN clinical.lab_results lr ON e.encounter_id = lr.encounter_id
        WHERE e.encounter_status = 'Active'
        GROUP BY p.patient_id, p.mrn, p.first_name, p.last_name
        ORDER BY diagnosis_count DESC
        LIMIT 10
        """,
        "Active Patients with Most Complex Cases"
    ),
    (
        """
        SELECT 
            test_name,
            COUNT(*) as critical_count,
            AVG(CAST(result_value AS FLOAT)) as avg_value,
            MIN(CAST(result_value AS FLOAT)) as min_value,
            MAX(CAST(result_value AS FLOAT)) as max_value
        FROM clinical.lab_results
        WHERE abnormal_flag IN ('Critical High', 'Critical Low')
            AND resulted_date > CURRENT_DATE - INTERVAL '7 days'
            AND result_value ~ '^[0-9.]+$'  -- Only numeric values
        GROUP BY test_name
        ORDER BY critical_count DESC
        """,
        "Critical Lab Values in Past Week"
    ),
    (
        """
        SELECT 
            m.medication_name,
            COUNT(DISTINCT ma.encounter_id) as patient_count,
            COUNT(*) as admin_count,
            SUM(CASE WHEN ma.admin_status = 'Given' THEN 1 ELSE 0 END) as given_count,
            SUM(CASE WHEN ma.admin_status != 'Given' THEN 1 ELSE 0 END) as missed_count,
            ROUND(100.0 * SUM(CASE WHEN ma.admin_status = 'Given' THEN 1 ELSE 0 END) / COUNT(*), 2) as compliance_rate
        FROM clinical.medication_administrations ma
        JOIN clinical.medications m ON ma.medication_id = m.medication_id
        JOIN clinical.encounters e ON ma.encounter_id = e.encounter_id
        WHERE e.encounter_status = 'Active'
            AND ma.admin_date > CURRENT_TIMESTAMP - INTERVAL '24 hours'
        GROUP BY m.medication_name
        HAVING COUNT(*) > 5
        ORDER BY compliance_rate ASC, admin_count DESC
        """,
        "Medication Compliance (Last 24 Hours)"
    ),
    (
        """
        WITH avg_los AS (
            SELECT 
                icd10_code,
                diagnosis_description,
                COUNT(DISTINCT e.encounter_id) as encounter_count,
                AVG(EXTRACT(EPOCH FROM (e.discharge_date - e.admit_date))/86400) as avg_los_days,
                STDDEV(EXTRACT(EPOCH FROM (e.discharge_date - e.admit_date))/86400) as stddev_los_days
            FROM clinical.diagnoses d
            JOIN clinical.encounters e ON d.encounter_id = e.encounter_id
            WHERE d.diagnosis_type = 'Primary'
                AND e.discharge_date IS NOT NULL
                AND e.encounter_type = 'Inpatient'
            GROUP BY icd10_code, diagnosis_description
            HAVING COUNT(DISTINCT e.encounter_id) >= 5
        )
        SELECT 
            icd10_code,
            diagnosis_description,
            encounter_count,
            ROUND(avg_los_days::numeric, 2) as avg_los_days,
            ROUND(stddev_los_days::numeric, 2) as stddev_los_days
        FROM avg_los
        ORDER BY avg_los_days DESC
        LIMIT 10
        """,
        "Average Length of Stay by Primary Diagnosis"
    )
]

# Run all queries
for query, title in queries:
    try:
        df = run_query(query, title)
    except Exception as e:
        print(f"Error: {e}")

# Interactive mode
print("\n" + "="*60)
print("INTERACTIVE MODE")
print("="*60)
print("Enter SQL queries (type 'exit' to quit):")

while True:
    try:
        query = input("\nsql> ")
        if query.lower() == 'exit':
            break
        
        if query.strip():
            df = pd.read_sql_query(query, conn)
            print(tabulate(df.head(20), headers='keys', tablefmt='grid'))
            print(f"Rows returned: {len(df)}")
    except Exception as e:
        print(f"Error: {e}")

conn.close()
print("Goodbye!")