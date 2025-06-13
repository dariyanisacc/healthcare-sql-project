#!/bin/bash
# Healthcare Clinical Database - Setup and Test Script

set -e  # Exit on error

echo "🏥 Healthcare Clinical Database Setup"
echo "===================================="

# Check if PostgreSQL is installed
if ! command -v psql &> /dev/null; then
    # Check homebrew installation
    if [ -f "/opt/homebrew/opt/postgresql@16/bin/psql" ]; then
        export PATH="/opt/homebrew/opt/postgresql@16/bin:$PATH"
    elif [ -f "/usr/local/opt/postgresql@16/bin/psql" ]; then
        export PATH="/usr/local/opt/postgresql@16/bin:$PATH"
    else
        echo "❌ PostgreSQL is not installed. Please install PostgreSQL first."
        echo "   On macOS: brew install postgresql@16"
        echo "   On Ubuntu: sudo apt-get install postgresql-16"
        exit 1
    fi
fi

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is not installed. Please install Python 3.8+ first."
    exit 1
fi

echo "✅ Prerequisites check passed"
echo ""

# Set up Python environment
echo "📦 Setting up Python environment..."
if [ ! -d "venv" ]; then
    python3 -m venv venv
fi
source venv/bin/activate
pip install -q -r requirements.txt
echo "✅ Python environment ready"
echo ""

# Create database
echo "🗄️  Creating database..."
createdb healthcare_clinical 2>/dev/null || echo "Database already exists"

# Create schema
echo "🏗️  Creating schema..."
psql -d healthcare_clinical -f sql/01_schema.sql -q
psql -d healthcare_clinical -f sql/02_indexes.sql -q
echo "✅ Schema created"
echo ""

# Apply improvements (optional)
read -p "Apply schema improvements (CASCADE constraints, lookup tables)? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🔧 Applying schema improvements..."
    psql -d healthcare_clinical -f sql/01a_schema_improvements.sql -q
    echo "✅ Improvements applied"
fi
echo ""

# Generate data
echo "🎲 Generating synthetic data..."
echo "Choose data generation method:"
echo "1) Standard (sequential) - slower but tested"
echo "2) Parallel (faster) - 3-4x speed improvement"
read -p "Enter choice (1 or 2): " choice

cd scripts
if [ "$choice" = "2" ]; then
    echo "Using parallel generation..."
    python generate_data.py
    python generate_encounters_parallel.py
else
    echo "Using standard generation..."
    python generate_data.py
    python generate_encounters.py
fi
cd ..
echo "✅ Data generated"
echo ""

# Load data
echo "📥 Loading data into database..."
psql -d healthcare_clinical -f sql/03_seed.sql -q
echo "✅ Data loaded"
echo ""

# Create views
echo "👁️  Creating analytics views..."
psql -d healthcare_clinical -f sql/04_views.sql -q
echo "✅ Views created"
echo ""

# Run demo queries
echo "🔍 Running demo queries..."
echo "========================"
psql -d healthcare_clinical -f sql/05_demo_queries.sql

# Interactive mode
echo ""
echo "🎯 Setup complete! What would you like to do?"
echo ""
echo "1) Open psql interactive session"
echo "2) Run performance analysis"
echo "3) Run pgTAP tests"
echo "4) View database statistics"
echo "5) Exit"
echo ""
read -p "Enter choice (1-5): " action

case $action in
    1)
        echo "Opening psql session..."
        echo "Try these commands:"
        echo "  \\dt clinical.*          -- List all tables"
        echo "  \\dv clinical.*          -- List all views"
        echo "  SELECT * FROM clinical.v_current_census;"
        echo "  SELECT * FROM clinical.v_sepsis_screening LIMIT 10;"
        echo ""
        psql -d healthcare_clinical
        ;;
    2)
        echo "Running performance analysis..."
        psql -d healthcare_clinical -f sql/06_performance_analysis.sql
        ;;
    3)
        echo "Running tests..."
        # Install pgTAP if needed
        psql -d healthcare_clinical -c "CREATE EXTENSION IF NOT EXISTS pgtap;" 2>/dev/null || true
        psql -d healthcare_clinical -f tests/test_schema.sql
        psql -d healthcare_clinical -f tests/test_data_integrity.sql
        ;;
    4)
        echo "Database statistics:"
        psql -d healthcare_clinical -c "
            SELECT 
                schemaname,
                tablename,
                pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size,
                n_live_tup as rows
            FROM pg_stat_user_tables
            WHERE schemaname = 'clinical'
            ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;"
        ;;
    5)
        echo "Goodbye! 👋"
        ;;
esac

echo ""
echo "💡 Tips:"
echo "  - Connect to database: psql -d healthcare_clinical"
echo "  - View schema: psql -d healthcare_clinical -c '\\dt clinical.*'"
echo "  - Run queries: psql -d healthcare_clinical -f sql/05_demo_queries.sql"
echo "  - Clean up: dropdb healthcare_clinical"