# DBeaver Setup Guide

Wire your running Postgres instance into DBeaver CE so you can poke around the tables, browse ER diagrams, and run ad-hoc queries with autocomplete.

## 1. Install (or update) DBeaver on macOS

| Option | Command / Action |
|--------|------------------|
| Homebrew (quickest) | `brew install --cask dbeaver-community` |
| DMG download | Grab the latest "macOS – Intel/Apple Silicon" DMG from https://dbeaver.io/download/ and drag the app into Applications. |

**Tip**: If you already have DBeaver but it's older than ~3 months, choose DBeaver ▸ Check for Updates… to pull the newest drivers and UI fixes before you connect.

## 2. Collect the connection details

From the Docker Compose recipe we set up:

| Setting | Value |
|---------|-------|
| Host | localhost |
| Port | 5432 |
| Database | healthcare_clinical |
| Username | postgres |
| Password | postgres |

(If you installed Postgres via Homebrew instead of Docker, the host/port are the same; user/password default to your macOS username with no password unless you changed pg_hba.conf).

## 3. Create the connection in DBeaver

1. **Launch DBeaver**
   - Open Spotlight (⌘ Space) → type "DBeaver".

2. **New Database Connection**
   - Click the plug-plus icon in the top-left …or…
   - Database ▸ New Connection…

3. **Choose the driver**
   - Select PostgreSQL from the gallery.
   - On first use DBeaver will prompt to download the Postgres driver JAR—click Download (takes ~5 seconds).

4. **Fill in parameters**

   | Field | What to enter |
   |-------|---------------|
   | Host | localhost |
   | Port | 5432 |
   | Database | healthcare_clinical |
   | Username | postgres |
   | Password | postgres |
   | Save password | ✔ (unless you prefer to enter it each time) |

5. **Test Connection**
   - Hit Test Connection.
   - You should see "Connected (PostgreSQL 16.x on localhost:5432)".
   - If it fails: make sure the containers are running (`docker compose ps`) and that no VPN/firewall is blocking localhost:5432.

6. **Finish**
   - Click Finish to add it to your Database Navigator panel (left side).

## 4. Explore like a pro

| What you want | Where in DBeaver |
|---------------|------------------|
| Browse tables & views | ► expand the connection → Schemas ▸ clinical ▸ Tables / Views |
| Quick row peek | Right-click a table → Read Data (or View Data). |
| Entity-relationship diagram | Right-click Schemas ▸ clinical → ER Diagram (auto-generates from FK metadata). |
| Autocomplete & docs | Start typing `SELECT * FROM vit...` in the SQL Editor; press Ctrl + Space for suggestions and table DDL preview. |
| Export to CSV/Excel | After running a query, right-click the result grid → Export Resultset. |
| Generate DDL scripts | Right-click object → Generate SQL → pick DDL or Insert scripts. |

## 5. Sample Queries to Try

```sql
-- Current hospital census
SELECT * FROM clinical.v_current_census ORDER BY occupancy_rate DESC;

-- High-risk patients
SELECT 
    p.mrn,
    p.first_name || ' ' || p.last_name as patient_name,
    pa.acuity_score,
    pa.acuity_level
FROM clinical.v_patient_acuity pa
JOIN clinical.patients p ON pa.patient_id = p.patient_id
WHERE pa.acuity_level IN ('High', 'Critical')
ORDER BY pa.acuity_score DESC
LIMIT 20;

-- Recent critical labs
SELECT * FROM clinical.v_critical_labs 
WHERE resulted_date > NOW() - INTERVAL '24 hours'
ORDER BY resulted_date DESC;

-- 30-day readmissions
SELECT * FROM clinical.v_30day_readmissions 
ORDER BY days_between_admissions
LIMIT 20;
```

## 6. (Optional) Point-and-click data generator

You already have the Python Faker scripts, but DBeaver can insert sample rows if you like:

1. Right-click a table → Generate Mock Data.
2. For each column, choose built-in generators (names, timestamps, ranges).
3. Click Preview then Generate.

## 7. Common hiccups & cures

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Driver mismatch error | Switching between Postgres 15 ↔ 16 containers | Open the connection → Edit Driver Settings → Download/Update… to get the correct JDBC version. |
| Timeout on Test Connection | Docker DB not ready | `docker compose logs -f db` until you see "database system is ready to accept connections". |
| "No schema shown" | Connected as the wrong database | Double-check you entered healthcare_clinical (default is postgres, which is mostly empty). |

## You're wired in!

From here you can browse vitals, tweak constraints, or write window-function-heavy queries with syntax coloring and execution plans. If you want to layer dbt, Metabase, or Superset on top of the same container, just reuse these host/port creds.