# macOS Setup Guide

## One-time prep

| What | Command / Action | Notes |
|------|------------------|-------|
| Install Docker Desktop | https://www.docker.com/products/docker-desktop/ | Accept the networking prompts; default settings are fine. |
| Install Homebrew (if needed) | `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` | Makes the next two steps easy. |
| Install Git & Python 3 | `brew install git python` | Brew puts python3 and pip3 on your path. |

## 1. Get the code onto your Mac

```bash
# Clone from GitHub
git clone https://github.com/dariyanisacc/healthcare-sql-project.git
cd healthcare-sql-project

# Or unzip if you have the archive
unzip healthcare-sql-project-main.zip
cd healthcare-sql-project-main
```

## 2. Spin up Postgres 16 + pgAdmin with Docker Compose

### Apple Silicon M-series only
Open `docker-compose.yml` and add this under the Postgres service if it isn't there already:
```yaml
platform: linux/arm64
```

### Fire it up
```bash
docker compose up -d        # first run will download images
```

Containers:
- **db** → Postgres 16 exposed on localhost:5432
- **pgadmin** → pgAdmin web UI on http://localhost:5050

### Check status
```bash
docker compose ps          # both services should be "running"
```

## 3. Load the schema & sample data

```bash
# 3-A: Create a Python venv for the data-gen scripts
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt        # Faker, psycopg, etc.

# 3-B: Point env vars at the running Postgres
export PGHOST=localhost PGPORT=5432 PGUSER=postgres PGPASSWORD=postgres
export PGDATABASE=healthcare_clinical

# 3-C: Build schema
psql -f sql/01_schema.sql
psql -f sql/02_indexes.sql

# 3-D: Generate & insert synthetic data
cd scripts
python generate_data.py
python generate_encounters_parallel.py  # or generate_encounters.py
cd ..

# 3-E: Load data and create views
psql -f sql/03_seed.sql
psql -f sql/04_views.sql
```

## 4. Run the automated tests (pgTAP)

```bash
psql -c "CREATE EXTENSION IF NOT EXISTS pgtap;"
psql -f tests/test_schema.sql
psql -f tests/test_data_integrity.sql
```

Green = everything wired up correctly.

## 5. Using the database day-to-day

| Task | How |
|------|-----|
| Connect via psql | `psql -h localhost -U postgres healthcare_clinical` |
| Open pgAdmin | Browser → http://localhost:5050 |
| Stop the stack | `docker compose down` |
| Wipe & rebuild quickly | `docker compose down -v && docker compose up --build -d` |

## 6. Optional local-only install (no Docker)

If you'd rather keep it ultra-native:

```bash
brew install postgresql@16
brew services start postgresql@16       # auto-launch on boot

createdb healthcare_clinical
psql -f sql/01_schema.sql -d healthcare_clinical
# …continue with the same steps as above
```

## 7. Common hiccups & fixes

| Symptom | Fix |
|---------|-----|
| "cannot connect to Postgres on port 5432" | Docker not fully started → open Docker Desktop & wait until the whale icon stops bouncing. |
| Apple Silicon image mismatch | Add `platform: linux/arm64` (or `linux/amd64`) under each service in docker-compose.yml. |
| psql: command not found | `brew install libpq` then `brew link --force libpq` or use the container: `docker exec -it healthcare-postgres psql -U postgres`. |
| Faker script crawls | Use the parallel version: `python generate_encounters_parallel.py` |

That's it! Once the containers are up and data's loaded, you can query vitals (`SELECT * FROM clinical.vital_signs LIMIT 20;`), fetch KPIs from the analytic views, or hit pgAdmin for a point-and-click tour.