-- ResQNet Database Schema for Supabase PostgreSQL
-- Project URL: https://iljgykyxlnkdvdjgxfyx.supabase.co

-- 1. USERS TABLE
CREATE TABLE IF NOT EXISTS users (
    id VARCHAR PRIMARY KEY,
    email VARCHAR UNIQUE NOT NULL,
    name VARCHAR NOT NULL,
    hashed_password VARCHAR NOT NULL,
    role VARCHAR DEFAULT 'CITIZEN',
    created_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);
CREATE INDEX IF NOT EXISTS ix_users_email ON users (email);

-- 2. SHELTERS TABLE
CREATE TABLE IF NOT EXISTS shelters (
    id VARCHAR PRIMARY KEY,
    name VARCHAR NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    capacity INTEGER NOT NULL DEFAULT 100,
    current_occupancy INTEGER NOT NULL DEFAULT 0,
    hazard_rating INTEGER NOT NULL DEFAULT 0,
    equipment_json JSONB DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    vector_clock JSONB DEFAULT '{}'::jsonb
);

-- 3. MEDICAL INFRASTRUCTURE TABLE
CREATE TABLE IF NOT EXISTS medical_infra (
    id VARCHAR PRIMARY KEY,
    name VARCHAR NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    type VARCHAR NOT NULL,
    capacity INTEGER NOT NULL DEFAULT 50
);

-- 4. EMERGENCY CONTACTS TABLE
CREATE TABLE IF NOT EXISTS emergency_contacts (
    id VARCHAR PRIMARY KEY,
    name VARCHAR NOT NULL,
    type VARCHAR NOT NULL,
    phone VARCHAR NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION
);

-- 5. SOS LOGS TABLE
CREATE TABLE IF NOT EXISTS sos_logs (
    id VARCHAR PRIMARY KEY,
    user_id VARCHAR NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    status VARCHAR NOT NULL DEFAULT 'QUEUED',
    timestamp TIMESTAMPTZ DEFAULT timezone('utc'::text, now()),
    synced_bool BOOLEAN DEFAULT TRUE,
    relay_path_json JSONB DEFAULT '[]'::jsonb,
    vector_clock JSONB DEFAULT '{}'::jsonb
);
CREATE INDEX IF NOT EXISTS ix_sos_logs_status ON sos_logs (status);
CREATE INDEX IF NOT EXISTS ix_sos_logs_timestamp ON sos_logs (timestamp);

-- 6. SYNC CONFLICT AUDIT TABLE
CREATE TABLE IF NOT EXISTS sync_conflicts_audit (
    id VARCHAR PRIMARY KEY,
    entity_type VARCHAR NOT NULL,
    entity_id VARCHAR NOT NULL,
    winning_payload JSONB NOT NULL,
    losing_payload JSONB NOT NULL,
    client_id VARCHAR NOT NULL,
    resolved_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now())
);

-- SEED INITIAL DATA
-- Default Responder User (Password: EmergencyPassword2026!)
INSERT INTO users (id, email, name, hashed_password, role, created_at)
VALUES (
    'usr_responder_lead',
    'rescuer@resqnet.org',
    'Rescue Lead',
    'b01c17eb49ae69d44115ad47fe8f0344ba4d96611cfdfb048a1e55902558732e',
    'RESCUER',
    NOW()
) ON CONFLICT (email) DO NOTHING;

-- Initial Shelters
INSERT INTO shelters (id, name, latitude, longitude, capacity, current_occupancy, hazard_rating, equipment_json, updated_at)
VALUES 
('shl_001', 'Civic Community Shelter', 37.7812, -122.4160, 250, 85, 1, '{"generators": 2, "clean_water_liters": 5000, "first_aid_kits": 40, "food_meals": 1200}', NOW()),
('shl_002', 'North Hill High School Shelter', 37.7850, -122.4090, 500, 320, 0, '{"generators": 4, "clean_water_liters": 12000, "first_aid_kits": 100, "food_meals": 3000}', NOW()),
('shl_003', 'Eastside Sports Arena', 37.7650, -122.3950, 400, 385, 2, '{"generators": 3, "clean_water_liters": 4500, "first_aid_kits": 30, "food_meals": 850}', NOW()),
('shl_004', 'South Waterfront Aid Station', 37.7550, -122.4250, 180, 45, 0, '{"generators": 1, "clean_water_liters": 3200, "first_aid_kits": 60, "food_meals": 900}', NOW())
ON CONFLICT (id) DO NOTHING;

-- Initial SOS Logs
INSERT INTO sos_logs (id, user_id, latitude, longitude, status, synced_bool, relay_path_json, timestamp)
VALUES
('sos_101', 'usr_citizen_88', 37.7749, -122.4194, 'QUEUED', TRUE, '["node_alpha", "node_beta"]', NOW()),
('sos_102', 'usr_field_medic_04', 37.7850, -122.4090, 'DISPATCHED', TRUE, '["node_gamma"]', NOW()),
('sos_103', 'usr_responder_12', 37.7690, -122.4280, 'RESOLVED', TRUE, '["node_mesh_01", "node_alpha"]', NOW())
ON CONFLICT (id) DO NOTHING;
