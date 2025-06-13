# Database Documentation

## Schema Diagram

The Entity-Relationship Diagram (ERD) for the Clinical Data Warehouse can be generated using the `schema.dbml` file.

### Generating the ER Diagram

1. Go to [dbdiagram.io](https://dbdiagram.io)
2. Click "Create New Diagram"
3. Copy the contents of `schema.dbml`
4. Paste into the editor
5. The diagram will auto-generate
6. Export as PNG using the export button (top right)
7. Save as `schema_diagram.png` in this directory

### Database Design Principles

1. **3NF Normalization**: All tables follow Third Normal Form to minimize redundancy
2. **Industry Standards**: Uses ICD-10 for diagnoses, LOINC for lab tests, NPI for providers
3. **Audit Trail**: Created/updated timestamps on key tables
4. **Referential Integrity**: Foreign key constraints ensure data consistency
5. **Performance**: Strategic indexes on commonly queried columns

### Key Relationships

- **Patients** ← 1:N → **Encounters**: One patient can have multiple hospital visits
- **Encounters** ← 1:N → **Diagnoses**: Each visit can have multiple diagnoses
- **Encounters** ← 1:N → **Medication Administrations**: Multiple meds per visit
- **Encounters** ← 1:N → **Lab Results**: Multiple lab tests per visit
- **Encounters** ← 1:N → **Vital Signs**: Vitals recorded throughout stay
- **Encounters** ← 1:N → **Nursing Assessments**: Regular nursing documentation
- **Patients** ← 1:N → **Allergies**: Patient allergy history