#!/usr/bin/env python3
"""
Synthetic Healthcare Data Generator
Generates HIPAA-compliant synthetic data for the clinical database
"""

import csv
import random
import os
from datetime import datetime, timedelta
from faker import Faker
import hashlib

# Initialize Faker with seed for reproducibility
fake = Faker()
Faker.seed(12345)
random.seed(12345)

# Output directory
OUTPUT_DIR = '../data/raw'
os.makedirs(OUTPUT_DIR, exist_ok=True)

# Configuration
NUM_PATIENTS = 1000
NUM_PROVIDERS = 50
NUM_UNITS = 15
NUM_MEDICATIONS = 200
ENCOUNTERS_PER_PATIENT = (1, 5)  # Random range

# Common medical data
SPECIALTIES = [
    'Internal Medicine', 'Emergency Medicine', 'Critical Care', 'Cardiology',
    'Pulmonology', 'Nephrology', 'Gastroenterology', 'Neurology', 'Surgery',
    'Orthopedics', 'Anesthesiology', 'Nursing', 'Pharmacy'
]

UNIT_TYPES = [
    ('ICU', 'Intensive Care Unit', 20),
    ('MICU', 'Medical ICU', 16),
    ('SICU', 'Surgical ICU', 16),
    ('CCU', 'Cardiac Care Unit', 12),
    ('ED', 'Emergency Department', 30),
    ('PACU', 'Post-Anesthesia Care Unit', 10),
    ('OR', 'Operating Room', 8),
    ('L&D', 'Labor & Delivery', 15),
    ('NICU', 'Neonatal ICU', 20),
    ('MS1', 'Medical Surgical 1', 30),
    ('MS2', 'Medical Surgical 2', 30),
    ('MS3', 'Medical Surgical 3', 30),
    ('TELE', 'Telemetry', 24),
    ('ONCO', 'Oncology', 20),
    ('ORTHO', 'Orthopedics', 25)
]

# Common diagnoses (ICD-10 codes)
DIAGNOSES = [
    ('I10', 'Essential (primary) hypertension'),
    ('E11.9', 'Type 2 diabetes mellitus without complications'),
    ('J44.1', 'Chronic obstructive pulmonary disease with acute exacerbation'),
    ('N18.3', 'Chronic kidney disease, stage 3'),
    ('I50.9', 'Heart failure, unspecified'),
    ('J18.9', 'Pneumonia, unspecified organism'),
    ('A41.9', 'Sepsis, unspecified organism'),
    ('N39.0', 'Urinary tract infection, site not specified'),
    ('K92.2', 'Gastrointestinal hemorrhage, unspecified'),
    ('I21.9', 'Acute myocardial infarction, unspecified'),
    ('I63.9', 'Cerebral infarction, unspecified'),
    ('E87.6', 'Hypokalemia'),
    ('D64.9', 'Anemia, unspecified'),
    ('F32.9', 'Major depressive disorder, single episode'),
    ('M79.3', 'Myalgia'),
    ('R50.9', 'Fever, unspecified'),
    ('R06.02', 'Shortness of breath'),
    ('R07.9', 'Chest pain, unspecified'),
    ('R42', 'Dizziness and giddiness'),
    ('G93.1', 'Anoxic brain damage, not elsewhere classified')
]

# Common medications
MEDICATION_LIST = [
    ('Acetaminophen', 'Acetaminophen', 'Tylenol', 'Analgesic', None, 'PO', 'tablet'),
    ('Aspirin', 'Aspirin', 'Bayer', 'Antiplatelet', None, 'PO', 'tablet'),
    ('Atorvastatin', 'Atorvastatin', 'Lipitor', 'Statin', None, 'PO', 'tablet'),
    ('Metoprolol', 'Metoprolol', 'Lopressor', 'Beta Blocker', None, 'PO', 'tablet'),
    ('Lisinopril', 'Lisinopril', 'Prinivil', 'ACE Inhibitor', None, 'PO', 'tablet'),
    ('Furosemide', 'Furosemide', 'Lasix', 'Loop Diuretic', None, 'IV', 'injection'),
    ('Warfarin', 'Warfarin', 'Coumadin', 'Anticoagulant', None, 'PO', 'tablet'),
    ('Insulin Regular', 'Insulin Regular', 'Humulin R', 'Insulin', None, 'SubQ', 'injection'),
    ('Morphine', 'Morphine', 'MS Contin', 'Opioid', 'II', 'IV', 'injection'),
    ('Fentanyl', 'Fentanyl', 'Sublimaze', 'Opioid', 'II', 'IV', 'injection'),
    ('Midazolam', 'Midazolam', 'Versed', 'Benzodiazepine', 'IV', 'IV', 'injection'),
    ('Propofol', 'Propofol', 'Diprivan', 'Anesthetic', None, 'IV', 'injection'),
    ('Vancomycin', 'Vancomycin', 'Vancocin', 'Antibiotic', None, 'IV', 'injection'),
    ('Piperacillin-Tazobactam', 'Piperacillin-Tazobactam', 'Zosyn', 'Antibiotic', None, 'IV', 'injection'),
    ('Ceftriaxone', 'Ceftriaxone', 'Rocephin', 'Antibiotic', None, 'IV', 'injection'),
    ('Heparin', 'Heparin', 'Heparin', 'Anticoagulant', None, 'SubQ', 'injection'),
    ('Enoxaparin', 'Enoxaparin', 'Lovenox', 'Anticoagulant', None, 'SubQ', 'injection'),
    ('Omeprazole', 'Omeprazole', 'Prilosec', 'Proton Pump Inhibitor', None, 'PO', 'capsule'),
    ('Ondansetron', 'Ondansetron', 'Zofran', 'Antiemetic', None, 'IV', 'injection'),
    ('Metformin', 'Metformin', 'Glucophage', 'Antidiabetic', None, 'PO', 'tablet')
]

# Lab tests (LOINC codes)
LAB_TESTS = [
    ('2160-0', 'Creatinine', 'Chemistry', 'mg/dL', 0.6, 1.2),
    ('2823-3', 'Potassium', 'Chemistry', 'mEq/L', 3.5, 5.0),
    ('2951-2', 'Sodium', 'Chemistry', 'mEq/L', 136, 145),
    ('2028-9', 'CO2', 'Chemistry', 'mEq/L', 22, 28),
    ('1742-6', 'ALT', 'Chemistry', 'U/L', 10, 40),
    ('1920-8', 'AST', 'Chemistry', 'U/L', 10, 34),
    ('1975-2', 'Bilirubin Total', 'Chemistry', 'mg/dL', 0.3, 1.2),
    ('2085-9', 'HDL Cholesterol', 'Chemistry', 'mg/dL', 40, 60),
    ('2093-3', 'Cholesterol Total', 'Chemistry', 'mg/dL', 100, 200),
    ('2571-8', 'Triglycerides', 'Chemistry', 'mg/dL', 50, 150),
    ('789-8', 'Erythrocytes', 'Hematology', 'x10^6/uL', 4.2, 5.4),
    ('6690-2', 'WBC', 'Hematology', 'x10^3/uL', 4.5, 11.0),
    ('777-3', 'Platelets', 'Hematology', 'x10^3/uL', 150, 400),
    ('718-7', 'Hemoglobin', 'Hematology', 'g/dL', 12.0, 16.0),
    ('4544-3', 'Hematocrit', 'Hematology', '%', 36, 46),
    ('1988-5', 'CRP', 'Immunology', 'mg/L', 0, 3),
    ('2532-0', 'LDH', 'Chemistry', 'U/L', 140, 280),
    ('2345-7', 'Glucose', 'Chemistry', 'mg/dL', 70, 110),
    ('6768-6', 'Alkaline Phosphatase', 'Chemistry', 'U/L', 44, 147),
    ('1759-0', 'Albumin', 'Chemistry', 'g/dL', 3.5, 5.0)
]

def generate_mrn():
    """Generate a unique MRN"""
    return f"MRN{random.randint(100000, 999999)}"

def generate_npi():
    """Generate a valid-looking NPI number"""
    return f"{random.randint(1000000000, 9999999999)}"

def generate_ssn_last4():
    """Generate last 4 digits of SSN"""
    return f"{random.randint(1000, 9999)}"

def generate_phone():
    """Generate phone number"""
    return fake.phone_number()

def generate_patients():
    """Generate patient data"""
    patients = []
    mrns = set()
    
    for i in range(NUM_PATIENTS):
        # Ensure unique MRN
        mrn = generate_mrn()
        while mrn in mrns:
            mrn = generate_mrn()
        mrns.add(mrn)
        
        # Generate demographics
        sex = random.choice(['M', 'F'])
        if sex == 'M':
            first_name = fake.first_name_male()
        else:
            first_name = fake.first_name_female()
        
        patient = {
            'patient_id': i + 1,
            'mrn': mrn,
            'first_name': first_name,
            'last_name': fake.last_name(),
            'middle_name': fake.first_name() if random.random() > 0.3 else '',
            'date_of_birth': fake.date_of_birth(minimum_age=18, maximum_age=95),
            'sex': sex,
            'race': random.choice(['White', 'Black', 'Asian', 'Hispanic', 'Other']),
            'ethnicity': random.choice(['Hispanic', 'Non-Hispanic']),
            'primary_language': random.choice(['English', 'Spanish', 'Chinese', 'Vietnamese', 'Arabic']),
            'ssn_last4': generate_ssn_last4(),
            'street_address': fake.street_address(),
            'city': fake.city(),
            'state': fake.state_abbr(),
            'zip_code': fake.zipcode(),
            'phone_primary': generate_phone(),
            'phone_secondary': generate_phone() if random.random() > 0.5 else '',
            'email': fake.email(),
            'emergency_contact_name': fake.name(),
            'emergency_contact_relationship': random.choice(['Spouse', 'Parent', 'Child', 'Sibling', 'Friend']),
            'emergency_contact_phone': generate_phone(),
            'insurance_provider': random.choice(['Blue Cross', 'Aetna', 'UnitedHealth', 'Cigna', 'Medicare', 'Medicaid']),
            'insurance_policy_number': fake.bothify(text='POL#########'),
            'created_at': fake.date_time_between(start_date='-2y', end_date='now'),
            'is_active': True
        }
        patients.append(patient)
    
    return patients

def generate_providers():
    """Generate provider data"""
    providers = []
    npis = set()
    
    titles = ['MD', 'DO', 'NP', 'PA', 'RN', 'PharmD']
    
    for i in range(NUM_PROVIDERS):
        # Ensure unique NPI
        npi = generate_npi()
        while npi in npis:
            npi = generate_npi()
        npis.add(npi)
        
        title = random.choice(titles)
        
        provider = {
            'provider_id': i + 1,
            'npi': npi,
            'first_name': fake.first_name(),
            'last_name': fake.last_name(),
            'middle_name': fake.first_name() if random.random() > 0.5 else '',
            'title': title,
            'specialty': random.choice(SPECIALTIES),
            'department': random.choice(['Medicine', 'Surgery', 'Emergency', 'ICU', 'Pediatrics']),
            'phone': generate_phone(),
            'email': fake.email(),
            'pager': fake.bothify(text='####'),
            'hire_date': fake.date_between(start_date='-10y', end_date='-6m'),
            'is_active': True
        }
        providers.append(provider)
    
    return providers

def generate_units():
    """Generate hospital units"""
    units = []
    
    for i, (code, name, beds) in enumerate(UNIT_TYPES):
        unit = {
            'unit_id': i + 1,
            'unit_code': code,
            'unit_name': name,
            'unit_type': code,
            'floor': random.choice(['1', '2', '3', '4', '5', 'B', 'G']),
            'building': random.choice(['Main', 'North', 'South', 'East', 'West']),
            'phone': fake.bothify(text='555-####'),
            'total_beds': beds,
            'is_active': True
        }
        units.append(unit)
    
    return units

def generate_medications():
    """Generate medication formulary"""
    medications = []
    
    for i, med_data in enumerate(MEDICATION_LIST):
        medication = {
            'medication_id': i + 1,
            'medication_name': med_data[0],
            'generic_name': med_data[1],
            'brand_name': med_data[2],
            'medication_class': med_data[3],
            'controlled_substance_schedule': med_data[4],
            'default_route': med_data[5],
            'default_form': med_data[6],
            'is_high_alert': med_data[0] in ['Insulin Regular', 'Heparin', 'Warfarin', 'Morphine', 'Fentanyl'],
            'is_active': True
        }
        medications.append(medication)
    
    # Add more random medications
    for i in range(len(MEDICATION_LIST), NUM_MEDICATIONS):
        medication = {
            'medication_id': i + 1,
            'medication_name': fake.word().capitalize() + random.choice(['azole', 'mycin', 'cillin', 'pril', 'olol']),
            'generic_name': fake.word().capitalize() + random.choice(['azole', 'mycin', 'cillin', 'pril', 'olol']),
            'brand_name': fake.company().split()[0] + random.choice(['ex', 'in', 'ol', 'an']),
            'medication_class': random.choice(['Antibiotic', 'Analgesic', 'Antihypertensive', 'Anticoagulant']),
            'controlled_substance_schedule': None,
            'default_route': random.choice(['PO', 'IV', 'IM', 'SubQ', 'Topical']),
            'default_form': random.choice(['tablet', 'capsule', 'injection', 'cream', 'solution']),
            'is_high_alert': False,
            'is_active': True
        }
        medications.append(medication)
    
    return medications

def write_csv(filename, data, fieldnames):
    """Write data to CSV file"""
    filepath = os.path.join(OUTPUT_DIR, filename)
    with open(filepath, 'w', newline='') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(data)
    print(f"Generated {filename} with {len(data)} records")

def main():
    """Main function to generate all data"""
    print("Generating synthetic healthcare data...")
    
    # Generate base data
    patients = generate_patients()
    providers = generate_providers()
    units = generate_units()
    medications = generate_medications()
    
    # Write base data
    write_csv('patients.csv', patients, patients[0].keys())
    write_csv('providers.csv', providers, providers[0].keys())
    write_csv('units.csv', units, units[0].keys())
    write_csv('medications.csv', medications, medications[0].keys())
    
    print("\nBase data generation complete!")
    print(f"Generated {NUM_PATIENTS} patients")
    print(f"Generated {NUM_PROVIDERS} providers")
    print(f"Generated {len(units)} units")
    print(f"Generated {NUM_MEDICATIONS} medications")
    
    print("\nNote: Run generate_encounters.py next to create encounter-related data")

if __name__ == "__main__":
    main()