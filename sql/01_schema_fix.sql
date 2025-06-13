-- Fix schema issues for data loading
SET search_path TO clinical, public;

-- Increase phone field lengths
ALTER TABLE patients ALTER COLUMN phone_primary TYPE VARCHAR(30);
ALTER TABLE patients ALTER COLUMN phone_secondary TYPE VARCHAR(30);
ALTER TABLE patients ALTER COLUMN emergency_contact_phone TYPE VARCHAR(30);
ALTER TABLE providers ALTER COLUMN phone TYPE VARCHAR(30);
ALTER TABLE units ALTER COLUMN phone TYPE VARCHAR(30);

-- Fix abnormal_flag field length
ALTER TABLE lab_results ALTER COLUMN abnormal_flag TYPE VARCHAR(20);

-- Drop the check constraint on abnormal_flag to allow our values
ALTER TABLE lab_results DROP CONSTRAINT IF EXISTS lab_results_abnormal_flag_check;
ALTER TABLE lab_results ADD CONSTRAINT lab_results_abnormal_flag_check 
    CHECK (abnormal_flag IN ('Normal', 'Low', 'High', 'Critical Low', 'Critical High', 'Abnormal'));