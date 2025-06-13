#!/usr/bin/env python3
"""
Parallelized version of encounter data generation using concurrent.futures
Generates encounter-related data 3-4x faster than sequential version
"""

import csv
import random
import os
from datetime import datetime, timedelta
from faker import Faker
from concurrent.futures import ProcessPoolExecutor, as_completed
import multiprocessing

# Initialize Faker with seed for reproducibility
fake = Faker()
Faker.seed(12345)
random.seed(12345)

# Configuration
OUTPUT_DIR = '../data/raw'
NUM_PATIENTS = 1000
NUM_PROVIDERS = 50
NUM_UNITS = 15
NUM_MEDICATIONS = 200
NUM_WORKERS = multiprocessing.cpu_count()  # Use all available cores

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

# Other constants
CHIEF_COMPLAINTS = [
    'Chest pain', 'Shortness of breath', 'Abdominal pain', 'Fever',
    'Headache', 'Back pain', 'Dizziness', 'Nausea and vomiting',
    'Weakness', 'Cough', 'Altered mental status', 'Fall',
    'Syncope', 'Palpitations', 'Leg swelling', 'Difficulty urinating'
]

ADMISSION_SOURCES = [
    'Emergency Department', 'Direct Admission', 'Transfer from Hospital',
    'Physician Referral', 'Walk-in', 'Transfer from SNF'
]

DISCHARGE_DISPOSITIONS = [
    'Home', 'Home with Home Health', 'Skilled Nursing Facility',
    'Rehabilitation Facility', 'Transferred to Hospital',
    'Left Against Medical Advice', 'Expired', 'Hospice'
]

def generate_encounter_number():
    """Generate unique encounter number"""
    return f"ENC{fake.bothify(text='########')}"

def process_patient_batch(patient_range):
    """Process a batch of patients - returns encounters and diagnoses"""
    # Re-seed random for each process to ensure reproducibility
    random.seed(12345 + patient_range[0])
    local_fake = Faker()
    local_fake.seed(12345 + patient_range[0])
    
    encounters = []
    all_diagnoses = []
    
    # Calculate starting IDs for this batch
    base_encounter_id = (patient_range[0] - 1) * 5 + 1  # Assume max 5 encounters per patient
    base_diagnosis_id = (patient_range[0] - 1) * 25 + 1  # Assume max 25 diagnoses per patient
    
    encounter_id = base_encounter_id
    diagnosis_id = base_diagnosis_id
    
    for patient_id in range(patient_range[0], patient_range[1]):
        # Each patient has 1-5 encounters
        num_encounters = random.randint(1, 5)
        
        # Start date for this patient's encounters
        start_date = datetime.now() - timedelta(days=730)  # Up to 2 years ago
        
        for _ in range(num_encounters):
            # Determine encounter type
            encounter_type = random.choices(
                ['Inpatient', 'Emergency', 'Outpatient', 'Observation'],
                weights=[40, 30, 20, 10]
            )[0]
            
            # Admit date
            admit_date = local_fake.date_time_between(start_date=start_date, end_date='now')
            
            # Length of stay varies by type
            if encounter_type == 'Inpatient':
                los_days = random.randint(2, 14)
            elif encounter_type == 'Emergency':
                los_days = random.uniform(0.125, 1)  # 3-24 hours
            elif encounter_type == 'Observation':
                los_days = random.uniform(0.5, 2)
            else:  # Outpatient
                los_days = random.uniform(0.042, 0.25)  # 1-6 hours
            
            discharge_date = admit_date + timedelta(days=los_days)
            
            # Determine if still active
            is_active = discharge_date > datetime.now() - timedelta(days=7)
            
            encounter = {
                'encounter_id': encounter_id,
                'patient_id': patient_id,
                'encounter_number': generate_encounter_number(),
                'encounter_type': encounter_type,
                'admit_date': admit_date,
                'discharge_date': None if is_active else discharge_date,
                'admitting_provider_id': random.randint(1, NUM_PROVIDERS),
                'attending_provider_id': random.randint(1, NUM_PROVIDERS),
                'current_unit_id': random.randint(1, NUM_UNITS),
                'room_number': local_fake.bothify(text='###'),
                'bed_number': random.choice(['A', 'B', '1', '2']),
                'chief_complaint': random.choice(CHIEF_COMPLAINTS),
                'admission_source': random.choice(ADMISSION_SOURCES),
                'discharge_disposition': None if is_active else random.choice(DISCHARGE_DISPOSITIONS),
                'encounter_status': 'Active' if is_active else 'Discharged',
                'created_at': admit_date
            }
            encounters.append(encounter)
            
            # Generate diagnoses for this encounter
            num_diagnoses = random.randint(1, 5)
            selected_diagnoses = random.sample(DIAGNOSES, num_diagnoses)
            
            for i, (icd_code, description) in enumerate(selected_diagnoses):
                diagnosis = {
                    'diagnosis_id': diagnosis_id,
                    'encounter_id': encounter_id,
                    'icd10_code': icd_code,
                    'diagnosis_description': description,
                    'diagnosis_type': 'Primary' if i == 0 else 'Secondary',
                    'diagnosed_date': admit_date + timedelta(hours=random.randint(1, 24)),
                    'diagnosed_by_provider_id': random.randint(1, NUM_PROVIDERS),
                    'is_resolved': False if is_active else random.random() > 0.3,
                    'resolved_date': discharge_date if not is_active and random.random() > 0.3 else None
                }
                all_diagnoses.append(diagnosis)
                diagnosis_id += 1
            
            encounter_id += 1
            
            # Update start date for next encounter
            if not is_active:
                start_date = discharge_date + timedelta(days=random.randint(7, 180))
    
    return encounters, all_diagnoses

def process_med_admin_batch(encounters_batch):
    """Process medication administrations for a batch of encounters"""
    random.seed(12345 + encounters_batch[0]['encounter_id'])
    
    med_admins = []
    admin_id_start = encounters_batch[0]['encounter_id'] * 100  # Estimate 100 meds per encounter max
    admin_id = admin_id_start
    
    doses = ['325 mg', '500 mg', '1 g', '5 mg', '10 mg', '20 mg', '40 mg', '80 mg', '100 mg']
    frequencies = ['Daily', 'BID', 'TID', 'QID', 'Q6H', 'Q8H', 'Q12H', 'PRN', 'STAT']
    routes = ['PO', 'IV', 'IM', 'SubQ', 'Topical', 'PR', 'SL']
    
    for encounter in encounters_batch:
        if encounter['encounter_status'] == 'Discharged':
            start_date = datetime.fromisoformat(str(encounter['admit_date']))
            end_date = datetime.fromisoformat(str(encounter['discharge_date']))
            
            num_meds = random.randint(3, 10)
            selected_meds = random.sample(range(1, NUM_MEDICATIONS + 1), num_meds)
            
            for med_id in selected_meds:
                frequency = random.choice(frequencies)
                times_per_day = {'Daily': 1, 'BID': 2, 'TID': 3, 'QID': 4, 
                               'Q6H': 4, 'Q8H': 3, 'Q12H': 2}.get(frequency, random.randint(0, 2))
                
                current_date = start_date
                while current_date < end_date:
                    for time_slot in range(times_per_day):
                        admin_time = current_date + timedelta(hours=time_slot * (24 / times_per_day))
                        
                        if random.random() > 0.95:
                            status = random.choice(['Held', 'Refused', 'Not Given'])
                            hold_reason = 'Patient NPO' if status == 'Held' else 'Patient refused' if status == 'Refused' else 'Medication unavailable'
                        else:
                            status = 'Given'
                            hold_reason = None
                        
                        med_admin = {
                            'admin_id': admin_id,
                            'encounter_id': encounter['encounter_id'],
                            'medication_id': med_id,
                            'ordered_dose': random.choice(doses),
                            'ordered_unit': 'mg',
                            'ordered_route': random.choice(routes),
                            'ordered_frequency': frequency,
                            'admin_date': admin_time,
                            'admin_dose': random.choice(doses),
                            'admin_unit': 'mg',
                            'admin_route': random.choice(routes),
                            'admin_site': 'Left arm' if random.choice(routes) in ['IM', 'SubQ'] else None,
                            'ordering_provider_id': encounter['attending_provider_id'],
                            'administering_provider_id': random.randint(1, NUM_PROVIDERS),
                            'admin_status': status,
                            'hold_reason': hold_reason,
                            'created_at': admin_time
                        }
                        med_admins.append(med_admin)
                        admin_id += 1
                    
                    current_date += timedelta(days=1)
    
    return med_admins

def process_lab_batch(encounters_batch):
    """Process lab results for a batch of encounters"""
    random.seed(12345 + encounters_batch[0]['encounter_id'])
    
    lab_results = []
    lab_id_start = encounters_batch[0]['encounter_id'] * 50  # Estimate 50 labs per encounter max
    lab_id = lab_id_start
    
    for encounter in encounters_batch:
        if encounter['encounter_type'] in ['Inpatient', 'Emergency']:
            start_date = datetime.fromisoformat(str(encounter['admit_date']))
            end_date = datetime.fromisoformat(str(encounter['discharge_date'])) if encounter['encounter_status'] == 'Discharged' else datetime.now()
            
            current_date = start_date
            while current_date < end_date:
                collection_time = current_date.replace(hour=5, minute=0)
                
                # Basic metabolic panel
                for loinc_code, test_name, category, unit, low, high in LAB_TESTS[:8]:
                    if random.random() > 0.8:  # 20% abnormal
                        if random.random() > 0.5:
                            value = round(random.uniform(high, high * 1.3), 2)
                            flag = 'High' if value < high * 1.2 else 'Critical High'
                        else:
                            value = round(random.uniform(low * 0.7, low), 2)
                            flag = 'Low' if value > low * 0.8 else 'Critical Low'
                    else:
                        value = round(random.uniform(low, high), 2)
                        flag = 'Normal'
                    
                    lab_result = {
                        'lab_id': lab_id,
                        'encounter_id': encounter['encounter_id'],
                        'loinc_code': loinc_code,
                        'test_name': test_name,
                        'test_category': category,
                        'result_value': str(value),
                        'result_unit': unit,
                        'result_status': 'Final',
                        'abnormal_flag': flag,
                        'reference_range_low': low,
                        'reference_range_high': high,
                        'collected_date': collection_time,
                        'resulted_date': collection_time + timedelta(hours=2),
                        'ordering_provider_id': encounter['attending_provider_id'],
                        'created_at': collection_time
                    }
                    lab_results.append(lab_result)
                    lab_id += 1
                
                # CBC every other day
                if (current_date - start_date).days % 2 == 0:
                    for loinc_code, test_name, category, unit, low, high in LAB_TESTS[10:15]:
                        value = round(random.uniform(low * 0.9, high * 1.1), 2)
                        flag = 'Normal' if low <= value <= high else 'High' if value > high else 'Low'
                        
                        lab_result = {
                            'lab_id': lab_id,
                            'encounter_id': encounter['encounter_id'],
                            'loinc_code': loinc_code,
                            'test_name': test_name,
                            'test_category': category,
                            'result_value': str(value),
                            'result_unit': unit,
                            'result_status': 'Final',
                            'abnormal_flag': flag,
                            'reference_range_low': low,
                            'reference_range_high': high,
                            'collected_date': collection_time,
                            'resulted_date': collection_time + timedelta(hours=1),
                            'ordering_provider_id': encounter['attending_provider_id'],
                            'created_at': collection_time
                        }
                        lab_results.append(lab_result)
                        lab_id += 1
                
                current_date += timedelta(days=1)
    
    return lab_results

def process_vitals_batch(encounters_batch):
    """Process vital signs for a batch of encounters"""
    random.seed(12345 + encounters_batch[0]['encounter_id'])
    
    vitals = []
    vital_id_start = encounters_batch[0]['encounter_id'] * 200  # Estimate 200 vitals per encounter max
    vital_id = vital_id_start
    
    for encounter in encounters_batch:
        start_date = datetime.fromisoformat(str(encounter['admit_date']))
        end_date = datetime.fromisoformat(str(encounter['discharge_date'])) if encounter['encounter_status'] == 'Discharged' else datetime.now()
        
        hours_between = 1 if encounter['current_unit_id'] <= 4 else 2 if encounter['current_unit_id'] == 5 else 4
        
        current_time = start_date
        while current_time < end_date:
            temp = round(random.gauss(98.6, 0.8), 1)
            hr = int(random.gauss(75, 15))
            rr = int(random.gauss(16, 3))
            bp_sys = int(random.gauss(120, 15))
            bp_dia = int(random.gauss(80, 10))
            o2_sat = int(random.gauss(97, 2))
            pain = random.choice([0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8])
            
            # Ensure values are within valid ranges
            temp = max(90, min(110, temp))
            hr = max(40, min(180, hr))
            rr = max(8, min(40, rr))
            bp_sys = max(70, min(200, bp_sys))
            bp_dia = max(40, min(120, bp_dia))
            o2_sat = max(85, min(100, o2_sat))
            
            vital_sign = {
                'vital_id': vital_id,
                'encounter_id': encounter['encounter_id'],
                'temperature_f': temp,
                'heart_rate': hr,
                'respiratory_rate': rr,
                'blood_pressure_systolic': bp_sys,
                'blood_pressure_diastolic': bp_dia,
                'oxygen_saturation': o2_sat,
                'pain_scale': pain,
                'weight_kg': round(random.gauss(75, 15), 1) if current_time == start_date else None,
                'height_cm': round(random.gauss(170, 10), 1) if current_time == start_date else None,
                'bmi': round(random.gauss(26, 5), 1) if current_time == start_date else None,
                'position': random.choice(['Sitting', 'Supine', 'Standing']),
                'oxygen_delivery': 'Room Air' if o2_sat > 93 else random.choice(['Nasal Cannula', 'Face Mask']),
                'oxygen_flow_rate': None if o2_sat > 93 else random.choice([2, 4, 6]),
                'recorded_date': current_time,
                'recorded_by_provider_id': random.randint(1, NUM_PROVIDERS)
            }
            vitals.append(vital_sign)
            vital_id += 1
            
            current_time += timedelta(hours=hours_between)
    
    return vitals

def process_nursing_batch(encounters_batch):
    """Process nursing assessments for a batch of encounters"""
    random.seed(12345 + encounters_batch[0]['encounter_id'])
    
    assessments = []
    assessment_id_start = encounters_batch[0]['encounter_id'] * 20  # Estimate 20 assessments per encounter max
    assessment_id = assessment_id_start
    
    consciousness_levels = ['Alert', 'Alert', 'Alert', 'Confused', 'Lethargic']
    orientations = ['Person, Place, Time', 'Person, Place', 'Person', 'Confused']
    activity_levels = ['Ambulatory', 'Ambulatory with assistance', 'Chair', 'Bedrest']
    
    for encounter in encounters_batch:
        # Admission assessment
        assessment = {
            'assessment_id': assessment_id,
            'encounter_id': encounter['encounter_id'],
            'assessment_date': encounter['admit_date'],
            'assessment_type': 'Admission',
            'level_of_consciousness': random.choice(consciousness_levels),
            'orientation': random.choice(orientations),
            'fall_risk_score': random.randint(0, 10),
            'fall_risk_level': random.choice(['Low', 'Moderate', 'High']),
            'bed_alarm_on': random.choice([True, False]),
            'restraints_in_use': False,
            'skin_integrity': random.choice(['Intact', 'Intact', 'Intact', 'Impaired']),
            'pressure_ulcer_present': random.random() < 0.1,
            'braden_score': random.randint(15, 23),
            'activity_level': random.choice(activity_levels),
            'gait_steady': random.choice([True, True, False]),
            'assistive_device': random.choice([None, None, 'Walker', 'Cane']),
            'assessment_notes': 'Initial nursing assessment completed.',
            'assessing_provider_id': random.randint(1, NUM_PROVIDERS),
            'created_at': encounter['admit_date']
        }
        assessments.append(assessment)
        assessment_id += 1
        
        # Shift assessments for discharged encounters
        if encounter['encounter_status'] == 'Discharged':
            start_date = datetime.fromisoformat(str(encounter['admit_date']))
            end_date = datetime.fromisoformat(str(encounter['discharge_date']))
            
            current_time = start_date + timedelta(hours=12)
            while current_time < end_date:
                assessment = {
                    'assessment_id': assessment_id,
                    'encounter_id': encounter['encounter_id'],
                    'assessment_date': current_time,
                    'assessment_type': 'Shift',
                    'level_of_consciousness': random.choice(consciousness_levels),
                    'orientation': random.choice(orientations),
                    'fall_risk_score': random.randint(0, 10),
                    'fall_risk_level': random.choice(['Low', 'Moderate', 'High']),
                    'bed_alarm_on': random.choice([True, False]),
                    'restraints_in_use': False,
                    'skin_integrity': random.choice(['Intact', 'Intact', 'Intact', 'Impaired']),
                    'pressure_ulcer_present': random.random() < 0.1,
                    'braden_score': random.randint(15, 23),
                    'activity_level': random.choice(activity_levels),
                    'gait_steady': random.choice([True, True, False]),
                    'assistive_device': random.choice([None, None, 'Walker', 'Cane']),
                    'assessment_notes': f'Shift assessment - {random.choice(["stable", "improving", "no acute distress"])}.',
                    'assessing_provider_id': random.randint(1, NUM_PROVIDERS),
                    'created_at': current_time
                }
                assessments.append(assessment)
                assessment_id += 1
                
                current_time += timedelta(hours=12)
    
    return assessments

def generate_allergies():
    """Generate patient allergies - not parallelized as it's fast"""
    allergies = []
    allergy_id = 1
    
    allergens = [
        ('Penicillin', 'Drug', 'Rash', 'Moderate'),
        ('Sulfa', 'Drug', 'Hives', 'Moderate'),
        ('Morphine', 'Drug', 'Nausea', 'Mild'),
        ('Aspirin', 'Drug', 'GI upset', 'Mild'),
        ('Iodine', 'Drug', 'Anaphylaxis', 'Life-threatening'),
        ('Peanuts', 'Food', 'Anaphylaxis', 'Life-threatening'),
        ('Shellfish', 'Food', 'Hives', 'Moderate'),
        ('Eggs', 'Food', 'GI upset', 'Mild'),
        ('Latex', 'Environmental', 'Rash', 'Moderate'),
        ('Bee stings', 'Environmental', 'Swelling', 'Severe')
    ]
    
    for patient_id in range(1, NUM_PATIENTS + 1):
        if random.random() < 0.3:
            num_allergies = random.randint(1, 3)
            selected_allergies = random.sample(allergens, num_allergies)
            
            for allergen, allergy_type, reaction, severity in selected_allergies:
                allergy = {
                    'allergy_id': allergy_id,
                    'patient_id': patient_id,
                    'allergen': allergen,
                    'allergy_type': allergy_type,
                    'reaction': reaction,
                    'severity': severity,
                    'onset_date': fake.date_between(start_date='-10y', end_date='-1y'),
                    'reported_date': fake.date_time_between(start_date='-1y', end_date='now'),
                    'reported_by_provider_id': random.randint(1, NUM_PROVIDERS),
                    'is_active': True
                }
                allergies.append(allergy)
                allergy_id += 1
    
    return allergies

def write_csv(filename, data, fieldnames):
    """Write data to CSV file"""
    filepath = os.path.join(OUTPUT_DIR, filename)
    with open(filepath, 'w', newline='') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(data)
    print(f"Generated {filename} with {len(data)} records")

def main():
    """Main function to generate encounter data with parallel processing"""
    print(f"Generating encounter-related data using {NUM_WORKERS} CPU cores...")
    print("This should be 3-4x faster than the sequential version...")
    
    # Create patient batches for parallel processing
    batch_size = NUM_PATIENTS // NUM_WORKERS
    patient_batches = []
    for i in range(NUM_WORKERS):
        start = i * batch_size + 1
        end = start + batch_size if i < NUM_WORKERS - 1 else NUM_PATIENTS + 1
        patient_batches.append((start, end))
    
    # Generate encounters and diagnoses in parallel
    print("\nGenerating encounters and diagnoses (parallel)...")
    all_encounters = []
    all_diagnoses = []
    
    with ProcessPoolExecutor(max_workers=NUM_WORKERS) as executor:
        future_to_batch = {executor.submit(process_patient_batch, batch): batch for batch in patient_batches}
        
        for future in as_completed(future_to_batch):
            encounters, diagnoses = future.result()
            all_encounters.extend(encounters)
            all_diagnoses.extend(diagnoses)
    
    # Sort encounters by ID for consistent output
    all_encounters.sort(key=lambda x: x['encounter_id'])
    all_diagnoses.sort(key=lambda x: x['diagnosis_id'])
    
    # Create encounter batches for subsequent processing
    encounter_batch_size = len(all_encounters) // NUM_WORKERS
    encounter_batches = []
    for i in range(NUM_WORKERS):
        start = i * encounter_batch_size
        end = start + encounter_batch_size if i < NUM_WORKERS - 1 else len(all_encounters)
        encounter_batches.append(all_encounters[start:end])
    
    # Process medication administrations in parallel
    print("Generating medication administrations (parallel)...")
    all_med_admins = []
    
    with ProcessPoolExecutor(max_workers=NUM_WORKERS) as executor:
        futures = [executor.submit(process_med_admin_batch, batch) for batch in encounter_batches]
        
        for future in as_completed(futures):
            all_med_admins.extend(future.result())
    
    # Process lab results in parallel
    print("Generating lab results (parallel)...")
    all_lab_results = []
    
    with ProcessPoolExecutor(max_workers=NUM_WORKERS) as executor:
        futures = [executor.submit(process_lab_batch, batch) for batch in encounter_batches]
        
        for future in as_completed(futures):
            all_lab_results.extend(future.result())
    
    # Process vital signs in parallel
    print("Generating vital signs (parallel)...")
    all_vital_signs = []
    
    with ProcessPoolExecutor(max_workers=NUM_WORKERS) as executor:
        futures = [executor.submit(process_vitals_batch, batch) for batch in encounter_batches]
        
        for future in as_completed(futures):
            all_vital_signs.extend(future.result())
    
    # Process nursing assessments in parallel
    print("Generating nursing assessments (parallel)...")
    all_nursing_assessments = []
    
    with ProcessPoolExecutor(max_workers=NUM_WORKERS) as executor:
        futures = [executor.submit(process_nursing_batch, batch) for batch in encounter_batches]
        
        for future in as_completed(futures):
            all_nursing_assessments.extend(future.result())
    
    # Generate allergies (fast enough to not need parallelization)
    print("Generating allergies...")
    allergies = generate_allergies()
    
    # Sort all data by ID for consistent output
    all_med_admins.sort(key=lambda x: x['admin_id'])
    all_lab_results.sort(key=lambda x: x['lab_id'])
    all_vital_signs.sort(key=lambda x: x['vital_id'])
    all_nursing_assessments.sort(key=lambda x: x['assessment_id'])
    
    # Write all data
    print("\nWriting CSV files...")
    write_csv('encounters.csv', all_encounters, all_encounters[0].keys())
    write_csv('diagnoses.csv', all_diagnoses, all_diagnoses[0].keys())
    write_csv('medication_administrations.csv', all_med_admins, all_med_admins[0].keys() if all_med_admins else [])
    write_csv('lab_results.csv', all_lab_results, all_lab_results[0].keys() if all_lab_results else [])
    write_csv('vital_signs.csv', all_vital_signs, all_vital_signs[0].keys() if all_vital_signs else [])
    write_csv('nursing_assessments.csv', all_nursing_assessments, all_nursing_assessments[0].keys() if all_nursing_assessments else [])
    write_csv('allergies.csv', allergies, allergies[0].keys() if allergies else [])
    
    print("\nEncounter data generation complete!")
    print(f"Total encounters: {len(all_encounters)}")
    print(f"Total diagnoses: {len(all_diagnoses)}")
    print(f"Total medication administrations: {len(all_med_admins)}")
    print(f"Total lab results: {len(all_lab_results)}")
    print(f"Total vital signs: {len(all_vital_signs)}")
    print(f"Total nursing assessments: {len(all_nursing_assessments)}")
    print(f"Total allergies: {len(allergies)}")

if __name__ == "__main__":
    main()