# 🚀 Quick Start Guide

## Prerequisites
1. PostgreSQL 16+ installed and running
2. Python 3.8+ installed
3. Git installed

## One-Command Setup

```bash
# Clone and setup everything
git clone https://github.com/dariyanisacc/healthcare-sql-project.git
cd healthcare-sql-project
./setup_and_test.sh
```

## Manual Setup (if you prefer step-by-step)

### 1. Install Python dependencies
```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 2. Create and populate database
```bash
# Create database
createdb healthcare_clinical

# Create schema
psql -d healthcare_clinical -f sql/01_schema.sql
psql -d healthcare_clinical -f sql/02_indexes.sql

# Generate synthetic data
cd scripts
python generate_data.py
python generate_encounters.py  # or use generate_encounters_parallel.py for faster generation
cd ..

# Load data
psql -d healthcare_clinical -f sql/03_seed.sql

# Create analytics views
psql -d healthcare_clinical -f sql/04_views.sql
```

### 3. Test the installation
```bash
# Run demo queries
psql -d healthcare_clinical -f sql/05_demo_queries.sql
```

## 🎮 Interactive Exploration

### Connect to database
```bash
psql -d healthcare_clinical
```

### Try these queries:

#### Current hospital census
```sql
SELECT * FROM clinical.v_current_census;
```

#### High-risk patients
```sql
SELECT 
    p.mrn,
    p.first_name || ' ' || p.last_name as patient_name,
    pa.acuity_score,
    pa.acuity_level
FROM clinical.v_patient_acuity pa
JOIN clinical.patients p ON pa.patient_id = p.patient_id
WHERE pa.acuity_level IN ('High', 'Critical')
ORDER BY pa.acuity_score DESC;
```

#### Recent lab alerts
```sql
SELECT * FROM clinical.v_critical_labs 
WHERE resulted_date > NOW() - INTERVAL '24 hours'
ORDER BY resulted_date DESC;
```

#### Medication administration record
```sql
SELECT * FROM clinical.v_active_mar 
WHERE encounter_id = (
    SELECT encounter_id FROM clinical.encounters 
    WHERE encounter_status = 'Active' 
    LIMIT 1
);
```

## 🐳 Docker Alternative

```bash
# Start PostgreSQL and pgAdmin with Docker
docker-compose up -d

# The database will be available at:
# - PostgreSQL: localhost:5432 (user: postgres, pass: postgres)
# - pgAdmin: http://localhost:5050 (email: admin@admin.com, pass: admin)

# Run setup inside container
docker exec -it healthcare-postgres bash
cd /workspace
./setup_and_test.sh
```

## 🧪 Running Tests

```bash
# Install pgTAP extension
psql -d healthcare_clinical -c "CREATE EXTENSION IF NOT EXISTS pgtap;"

# Run tests
psql -d healthcare_clinical -f tests/test_schema.sql
psql -d healthcare_clinical -f tests/test_data_integrity.sql
```

## 📊 Performance Analysis

```bash
# Run EXPLAIN ANALYZE on key queries
psql -d healthcare_clinical -f sql/06_performance_analysis.sql
```

## 🧹 Clean Up

```bash
# Drop the database when done
dropdb healthcare_clinical

# Deactivate Python environment
deactivate
```

## 💡 Common Issues

### PostgreSQL not running?
```bash
# macOS
brew services start postgresql@16

# Linux
sudo systemctl start postgresql
```

### Permission denied?
```bash
# Make scripts executable
chmod +x setup_and_test.sh
chmod +x tests/run_tests.sh
```

### Can't create database?
```bash
# Create with your username
createdb -U $USER healthcare_clinical
```

## 🎯 Next Steps

1. Explore the analytics views in `sql/04_views.sql`
2. Try modifying queries in `sql/05_demo_queries.sql`
3. Check performance with `sql/06_performance_analysis.sql`
4. Review the schema design in `docs/schema.dbml`
5. Run the CI pipeline locally with `act` (GitHub Actions)