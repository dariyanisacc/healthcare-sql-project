#!/bin/bash
# Run all pgTAP tests

set -e

echo "Running Healthcare Clinical Database Tests..."
echo "=========================================="

# Set database connection
DB_NAME=${DB_NAME:-healthcare_clinical}
DB_USER=${DB_USER:-postgres}
DB_HOST=${DB_HOST:-localhost}

# Check if pgTAP is installed
echo "Checking pgTAP installation..."
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "SELECT * FROM pg_extension WHERE extname = 'pgtap';" > /dev/null 2>&1 || {
    echo "Installing pgTAP extension..."
    psql -h $DB_HOST -U $DB_USER -d $DB_NAME -c "CREATE EXTENSION IF NOT EXISTS pgtap;"
}

# Run schema tests
echo ""
echo "Running schema tests..."
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f tests/test_schema.sql

# Run data integrity tests
echo ""
echo "Running data integrity tests..."
psql -h $DB_HOST -U $DB_USER -d $DB_NAME -f tests/test_data_integrity.sql

echo ""
echo "All tests completed!"