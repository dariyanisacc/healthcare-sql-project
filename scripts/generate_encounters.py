#!/usr/bin/env python3
"""
Generate encounter-related data (encounters, diagnoses, meds, labs, vitals)
Must run generate_data.py first to create base data
"""

import csv
import random
import os
from datetime import datetime, timedelta
from faker import Faker

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

# Load the data we already generated
def load_csv(filename):
    filepath = os.path.join(OUTPUT_DIR, filename)
    with open(filepath, 'r') as f:
        return list(csv.DictReader(f))

# Common diagnoses (ICD-10 codes) - repeated from generate_data.py
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

# Chief complaints
CHIEF_COMPLAINTS = [
    'Chest pain', 'Shortness of breath', 'Abdominal pain', 'Fever',
    'Headache', 'Back pain', 'Dizziness', 'Nausea and vomiting',
    'Weakness', 'Cough', 'Altered mental status', 'Fall',
    'Syncope', 'Palpitations', 'Leg swelling', 'Difficulty urinating'
]

# Admission sources
ADMISSION_SOURCES = [
    'Emergency Department', 'Direct Admission', 'Transfer from Hospital',
    'Physician Referral', 'Walk-in', 'Transfer from SNF'
]

# Discharge dispositions
DISCHARGE_DISPOSITIONS = [
    'Home', 'Home with Home Health', 'Skilled Nursing Facility',
    'Rehabilitation Facility', 'Transferred to Hospital',
    'Left Against Medical Advice', 'Expired', 'Hospice'
]

def generate_encounter_number():
    """Generate unique encounter number"""
    return f"ENC{fake.bothify(text='########')}"

def generate_encounters():
    """Generate encounters for all patients"""
    encounters = []
    all_diagnoses = []
    encounter_id = 1
    diagnosis_id = 1
    
    for patient_id in range(1, NUM_PATIENTS + 1):
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
            admit_date = fake.date_time_between(start_date=start_date, end_date='now')
            
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
                'room_number': fake.bothify(text='###'),
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

def generate_medication_administrations(encounters):
    """Generate medication administration records"""
    med_admins = []
    admin_id = 1
    
    # Common doses and frequencies
    doses = ['325 mg', '500 mg', '1 g', '5 mg', '10 mg', '20 mg', '40 mg', '80 mg', '100 mg']
    frequencies = ['Daily', 'BID', 'TID', 'QID', 'Q6H', 'Q8H', 'Q12H', 'PRN', 'STAT']
    routes = ['PO', 'IV', 'IM', 'SubQ', 'Topical', 'PR', 'SL']
    
    for encounter in encounters:
        if encounter['encounter_status'] == 'Discharged':
            # Generate meds throughout the stay
            start_date = datetime.fromisoformat(str(encounter['admit_date']))
            end_date = datetime.fromisoformat(str(encounter['discharge_date']))
            
            # Number of different medications
            num_meds = random.randint(3, 10)
            selected_meds = random.sample(range(1, NUM_MEDICATIONS + 1), num_meds)
            
            for med_id in selected_meds:
                # Frequency determines number of administrations
                frequency = random.choice(frequencies)
                
                if frequency == 'Daily':
                    times_per_day = 1
                elif frequency == 'BID':
                    times_per_day = 2
                elif frequency == 'TID':
                    times_per_day = 3
                elif frequency == 'QID':
                    times_per_day = 4
                elif frequency == 'Q6H':
                    times_per_day = 4
                elif frequency == 'Q8H':
                    times_per_day = 3
                elif frequency == 'Q12H':
                    times_per_day = 2
                else:  # PRN or STAT
                    times_per_day = random.randint(0, 2)
                
                # Generate administrations
                current_date = start_date
                while current_date < end_date:
                    for time_slot in range(times_per_day):
                        admin_time = current_date + timedelta(hours=time_slot * (24 / times_per_day))
                        
                        # Occasionally miss a dose
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

def generate_lab_results(encounters):
    """Generate lab results"""
    lab_results = []
    lab_id = 1
    
    for encounter in encounters:
        if encounter['encounter_type'] in ['Inpatient', 'Emergency']:
            start_date = datetime.fromisoformat(str(encounter['admit_date']))
            
            if encounter['encounter_status'] == 'Discharged':
                end_date = datetime.fromisoformat(str(encounter['discharge_date']))
            else:
                end_date = datetime.now()
            
            # Generate daily labs for inpatients
            current_date = start_date
            while current_date < end_date:
                # Morning labs
                collection_time = current_date.replace(hour=5, minute=0)
                
                # Basic metabolic panel
                for loinc_code, test_name, category, unit, low, high in LAB_TESTS[:8]:
                    # Generate result with some abnormals
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

def generate_vital_signs(encounters):
    """Generate vital signs"""
    vitals = []
    vital_id = 1
    
    for encounter in encounters:
        start_date = datetime.fromisoformat(str(encounter['admit_date']))
        
        if encounter['encounter_status'] == 'Discharged':
            end_date = datetime.fromisoformat(str(encounter['discharge_date']))
        else:
            end_date = datetime.now()
        
        # Frequency based on unit type
        if encounter['current_unit_id'] <= 4:  # ICU units
            hours_between = 1
        elif encounter['current_unit_id'] == 5:  # ED
            hours_between = 2
        else:  # Regular units
            hours_between = 4
        
        current_time = start_date
        while current_time < end_date:
            # Generate vitals with some variation
            temp = round(random.gauss(98.6, 0.8), 1)
            hr = int(random.gauss(75, 15))
            rr = int(random.gauss(16, 3))
            bp_sys = int(random.gauss(120, 15))
            bp_dia = int(random.gauss(80, 10))
            o2_sat = int(random.gauss(97, 2))
            pain = random.choice([0, 0, 0, 1, 2, 3, 4, 5, 6, 7, 8])  # Most patients have low pain
            
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

def generate_nursing_assessments(encounters):
    """Generate nursing assessments"""
    assessments = []
    assessment_id = 1
    
    assessment_types = ['Admission', 'Shift', 'Fall Risk', 'Skin', 'Discharge']
    consciousness_levels = ['Alert', 'Alert', 'Alert', 'Confused', 'Lethargic']
    orientations = ['Person, Place, Time', 'Person, Place', 'Person', 'Confused']
    activity_levels = ['Ambulatory', 'Ambulatory with assistance', 'Chair', 'Bedrest']
    
    for encounter in encounters:
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
            
            # Every 12 hours
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
    """Generate patient allergies"""
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
    
    # 30% of patients have allergies
    for patient_id in range(1, NUM_PATIENTS + 1):
        if random.random() < 0.3:
            # 1-3 allergies per patient
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
    """Main function to generate encounter data"""
    print("Generating encounter-related data...")
    print("This may take a few minutes...")
    
    # Generate encounters and related data
    print("\nGenerating encounters and diagnoses...")
    encounters, diagnoses = generate_encounters()
    
    print("Generating medication administrations...")
    med_admins = generate_medication_administrations(encounters)
    
    print("Generating lab results...")
    lab_results = generate_lab_results(encounters)
    
    print("Generating vital signs...")
    vital_signs = generate_vital_signs(encounters)
    
    print("Generating nursing assessments...")
    nursing_assessments = generate_nursing_assessments(encounters)
    
    print("Generating allergies...")
    allergies = generate_allergies()
    
    # Write all data
    print("\nWriting CSV files...")
    write_csv('encounters.csv', encounters, encounters[0].keys())
    write_csv('diagnoses.csv', diagnoses, diagnoses[0].keys())
    write_csv('medication_administrations.csv', med_admins, med_admins[0].keys() if med_admins else [])
    write_csv('lab_results.csv', lab_results, lab_results[0].keys() if lab_results else [])
    write_csv('vital_signs.csv', vital_signs, vital_signs[0].keys() if vital_signs else [])
    write_csv('nursing_assessments.csv', nursing_assessments, nursing_assessments[0].keys() if nursing_assessments else [])
    write_csv('allergies.csv', allergies, allergies[0].keys() if allergies else [])
    
    print("\nEncounter data generation complete!")
    print(f"Total encounters: {len(encounters)}")
    print(f"Total diagnoses: {len(diagnoses)}")
    print(f"Total medication administrations: {len(med_admins)}")
    print(f"Total lab results: {len(lab_results)}")
    print(f"Total vital signs: {len(vital_signs)}")
    print(f"Total nursing assessments: {len(nursing_assessments)}")
    print(f"Total allergies: {len(allergies)}")

if __name__ == "__main__":
    main()