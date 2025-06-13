#!/bin/bash
# Docker-based setup script for Healthcare Clinical Database

set -e

echo "🏥 Healthcare Clinical Database - Docker Setup"
echo "============================================="
echo ""

# Detect architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" || "$ARCH" == "aarch64" ]]; then
    echo "🖥️  Detected Apple Silicon (ARM64)"
    PLATFORM="linux/arm64"
else
    echo "🖥️  Detected Intel/AMD (x64)"
    PLATFORM="linux/amd64"
fi

# Update docker-compose.yml with correct platform
echo "📝 Updating docker-compose.yml for your architecture..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS sed syntax
    sed -i '' "s|platform: linux/amd64|platform: $PLATFORM|g" docker-compose.yml
else
    # Linux sed syntax
    sed -i "s|platform: linux/amd64|platform: $PLATFORM|g" docker-compose.yml
fi

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed."
    echo "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop/"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "❌ Docker is not running. Please start Docker Desktop."
    exit 1
fi

echo "✅ Docker is ready"
echo ""

# Start containers
echo "🚀 Starting PostgreSQL and pgAdmin containers..."
docker compose up -d

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
until docker exec healthcare_db pg_isready -U postgres &> /dev/null; do
    sleep 1
done
echo "✅ PostgreSQL is ready"
echo ""

# Set up Python environment
echo "🐍 Setting up Python environment..."
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi
source .venv/bin/activate
pip install -q -r requirements.txt
echo "✅ Python environment ready"
echo ""

# Create schema
echo "🏗️  Creating database schema..."
docker exec -i healthcare_db psql -U postgres -d healthcare_clinical < sql/01_schema.sql
docker exec -i healthcare_db psql -U postgres -d healthcare_clinical < sql/02_indexes.sql
echo "✅ Schema created"
echo ""

# Apply improvements if they exist
if [ -f "sql/01a_schema_improvements.sql" ]; then
    read -p "Apply schema improvements (CASCADE constraints, lookup tables)? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🔧 Applying schema improvements..."
        docker exec -i healthcare_db psql -U postgres -d healthcare_clinical < sql/01a_schema_improvements.sql
        echo "✅ Improvements applied"
    fi
fi
echo ""

# Generate data
echo "🎲 Generating synthetic data..."
echo "Choose data generation method:"
echo "1) Standard (sequential)"
echo "2) Parallel (3-4x faster)"
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
docker exec -i healthcare_db psql -U postgres -d healthcare_clinical < sql/03_seed.sql
echo "✅ Data loaded"
echo ""

# Create views
echo "👁️  Creating analytics views..."
docker exec -i healthcare_db psql -U postgres -d healthcare_clinical < sql/04_views.sql
echo "✅ Views created"
echo ""

# Show summary
echo "📊 Setup Complete!"
echo "=================="
docker exec healthcare_db psql -U postgres -d healthcare_clinical -c "
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
SELECT 'Medications', COUNT(*) 
FROM clinical.medications
UNION ALL
SELECT 'Providers', COUNT(*) 
FROM clinical.providers;"

echo ""
echo "🎯 Access Points:"
echo "================="
echo "PostgreSQL:  localhost:5432 (user: postgres, pass: postgres)"
echo "pgAdmin:     http://localhost:5050 (email: admin@healthcare.local, pass: admin)"
echo ""
echo "🔧 Useful Commands:"
echo "=================="
echo "Connect via psql:     docker exec -it healthcare_db psql -U postgres -d healthcare_clinical"
echo "Stop containers:      docker compose down"
echo "View logs:           docker compose logs -f"
echo "Clean everything:    docker compose down -v"
echo ""
echo "📚 Next Steps:"
echo "=============="
echo "1. Run demo queries:  docker exec -it healthcare_db psql -U postgres -d healthcare_clinical -f /docker-entrypoint-initdb.d/05_demo_queries.sql"
echo "2. Open pgAdmin:      http://localhost:5050"
echo "3. Connect DBeaver:   See docs/DBEAVER_SETUP.md"
echo ""

# Ask if user wants to run demo
read -p "Run demo queries now? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Running demo queries..."
    docker exec -it healthcare_db psql -U postgres -d healthcare_clinical -f /docker-entrypoint-initdb.d/05_demo_queries.sql
fi