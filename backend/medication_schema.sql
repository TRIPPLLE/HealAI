-- Medication Management Schema

-- Enable UUID extension if not enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Medication Details
CREATE TABLE medications (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users ON DELETE CASCADE NOT NULL,
    name TEXT NOT NULL,
    dosage TEXT NOT NULL,
    frequency TEXT NOT NULL, -- 'daily', 'weekly', 'custom'
    scheduled_times TIME[] NOT NULL, -- Array of times, e.g., {'08:00', '20:00'}
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Adherence Logs
CREATE TABLE medication_adherence (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users ON DELETE CASCADE NOT NULL,
    medication_id UUID REFERENCES medications ON DELETE CASCADE NOT NULL,
    scheduled_time TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('taken', 'missed', 'skipped')),
    actual_intake_time TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- RLS Policies
ALTER TABLE medications ENABLE ROW LEVEL SECURITY;
ALTER TABLE medication_adherence ENABLE ROW LEVEL SECURITY;

-- Medications Policies
CREATE POLICY "Users can manage their own medications" ON medications
FOR ALL USING (auth.uid() = user_id);

-- Adherence Policies
CREATE POLICY "Users can manage their own adherence logs" ON medication_adherence
FOR ALL USING (auth.uid() = user_id);

-- Indexes for performance
CREATE INDEX idx_medications_user ON medications(user_id);
CREATE INDEX idx_adherence_user_scheduled ON medication_adherence(user_id, scheduled_time DESC);
CREATE INDEX idx_adherence_medication_id ON medication_adherence(medication_id);
