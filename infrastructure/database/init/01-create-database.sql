-- =====================================================
-- PDF CONVERTER DATABASE INITIALIZATION SCRIPT
-- =====================================================
-- This script creates the complete database schema for
-- the Enterprise PDF Converter system
-- =====================================================

-- Connect to the default database first
\c postgres;

-- Create the main application database
DROP DATABASE IF EXISTS pdf_converter_db;
CREATE DATABASE pdf_converter_db;

-- Connect to our application database
\c pdf_converter_db;

-- =====================================================
-- EXTENSIONS
-- =====================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";      -- UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";       -- Encryption functions
CREATE EXTENSION IF NOT EXISTS "pg_trgm";        -- Text search optimization
CREATE EXTENSION IF NOT EXISTS "btree_gin";      -- GIN indexes for better performance

-- =====================================================
-- CUSTOM TYPES
-- =====================================================
CREATE TYPE user_role AS ENUM ('user', 'admin', 'enterprise');
CREATE TYPE file_status AS ENUM ('uploaded', 'processing', 'completed', 'failed', 'deleted');
CREATE TYPE conversion_status AS ENUM ('pending', 'processing', 'completed', 'failed', 'cancelled');
CREATE TYPE notification_type AS ENUM ('conversion_completed', 'conversion_failed', 'system_update', 'quota_warning');
CREATE TYPE file_type AS ENUM ('pdf', 'doc', 'docx', 'txt', 'rtf', 'html', 'xml', 'jpg', 'jpeg', 'png', 'gif', 'bmp', 'tiff');

-- =====================================================
-- USERS TABLE
-- =====================================================
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    role user_role DEFAULT 'user',
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    verification_token VARCHAR(255),
    reset_token VARCHAR(255),
    reset_token_expires TIMESTAMP,
    last_login TIMESTAMP,
    login_count INTEGER DEFAULT 0,
    quota_limit BIGINT DEFAULT 104857600, -- 100MB default quota
    quota_used BIGINT DEFAULT 0,
    subscription_plan VARCHAR(50) DEFAULT 'free',
    subscription_expires TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- USER SESSIONS TABLE
-- =====================================================
CREATE TABLE user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    session_token VARCHAR(255) UNIQUE NOT NULL,
    refresh_token VARCHAR(255) UNIQUE,
    ip_address INET,
    user_agent TEXT,
    is_mobile BOOLEAN DEFAULT FALSE,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_accessed TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- API KEYS TABLE (for mobile and third-party integration)
-- =====================================================
CREATE TABLE api_keys (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    key_name VARCHAR(100) NOT NULL,
    api_key VARCHAR(64) UNIQUE NOT NULL,
    api_secret VARCHAR(128) NOT NULL,
    permissions JSONB DEFAULT '[]',
    rate_limit INTEGER DEFAULT 1000, -- requests per hour
    is_active BOOLEAN DEFAULT TRUE,
    last_used TIMESTAMP,
    expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- FILES TABLE
-- =====================================================
CREATE TABLE files (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    original_filename VARCHAR(255) NOT NULL,
    stored_filename VARCHAR(255) NOT NULL,
    file_path VARCHAR(500) NOT NULL,
    file_type file_type NOT NULL,
    file_size BIGINT NOT NULL,
    mime_type VARCHAR(100),
    checksum VARCHAR(64), -- SHA-256 hash
    storage_bucket VARCHAR(100) DEFAULT 'pdf-converter-files',
    status file_status DEFAULT 'uploaded',
    metadata JSONB DEFAULT '{}', -- Store additional file metadata
    uploaded_from VARCHAR(50) DEFAULT 'web', -- 'web', 'mobile', 'api'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP -- For temporary files
);

-- =====================================================
-- CONVERSION JOBS TABLE
-- =====================================================
CREATE TABLE conversion_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    input_file_id UUID REFERENCES files(id) ON DELETE CASCADE,
    output_file_id UUID REFERENCES files(id) ON DELETE SET NULL,
    job_type VARCHAR(50) DEFAULT 'to_pdf',
    status conversion_status DEFAULT 'pending',
    priority INTEGER DEFAULT 5, -- 1 (highest) to 10 (lowest)
    progress INTEGER DEFAULT 0, -- 0-100
    error_message TEXT,
    error_code VARCHAR(50),
    conversion_options JSONB DEFAULT '{}', -- Quality, page size, etc.
    processing_time INTEGER, -- seconds
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- NOTIFICATIONS TABLE
-- =====================================================
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    conversion_job_id UUID REFERENCES conversion_jobs(id) ON DELETE CASCADE,
    type notification_type NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    data JSONB DEFAULT '{}', -- Additional notification data
    is_read BOOLEAN DEFAULT FALSE,
    sent_via JSONB DEFAULT '{}', -- email, push, websocket status
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMP
);

-- =====================================================
-- USER ACTIVITY LOG TABLE
-- =====================================================
CREATE TABLE user_activity (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    action VARCHAR(100) NOT NULL, -- login, upload, convert, download, etc.
    resource_type VARCHAR(50), -- file, conversion, account
    resource_id UUID,
    details JSONB DEFAULT '{}',
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- SYSTEM SETTINGS TABLE
-- =====================================================
CREATE TABLE system_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key VARCHAR(100) UNIQUE NOT NULL,
    value JSONB NOT NULL,
    description TEXT,
    is_public BOOLEAN DEFAULT FALSE, -- Can be read by frontend
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- FILE SHARES TABLE (for sharing converted files)
-- =====================================================
CREATE TABLE file_shares (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    file_id UUID REFERENCES files(id) ON DELETE CASCADE,
    user_id UUID REFERENCES files(user_id) ON DELETE CASCADE,
    share_token VARCHAR(64) UNIQUE NOT NULL,
    password_hash VARCHAR(255), -- Optional password protection
    max_downloads INTEGER DEFAULT 10,
    download_count INTEGER DEFAULT 0,
    expires_at TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- WEBHOOK ENDPOINTS TABLE (for enterprise users)
-- =====================================================
CREATE TABLE webhook_endpoints (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    url VARCHAR(500) NOT NULL,
    secret VARCHAR(100), -- For webhook signature verification
    events JSONB DEFAULT '[]', -- Which events to send
    is_active BOOLEAN DEFAULT TRUE,
    last_success TIMESTAMP,
    last_failure TIMESTAMP,
    failure_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Users table indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_is_active ON users(is_active);
CREATE INDEX idx_users_created_at ON users(created_at);

-- Sessions table indexes
CREATE INDEX idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX idx_user_sessions_token ON user_sessions(session_token);
CREATE INDEX idx_user_sessions_expires ON user_sessions(expires_at);

-- API Keys table indexes
CREATE INDEX idx_api_keys_user_id ON api_keys(user_id);
CREATE INDEX idx_api_keys_key ON api_keys(api_key);
CREATE INDEX idx_api_keys_active ON api_keys(is_active);

-- Files table indexes
CREATE INDEX idx_files_user_id ON files(user_id);
CREATE INDEX idx_files_status ON files(status);
CREATE INDEX idx_files_file_type ON files(file_type);
CREATE INDEX idx_files_created_at ON files(created_at);
CREATE INDEX idx_files_checksum ON files(checksum);
CREATE INDEX idx_files_expires_at ON files(expires_at) WHERE expires_at IS NOT NULL;

-- Conversion jobs table indexes
CREATE INDEX idx_conversion_jobs_user_id ON conversion_jobs(user_id);
CREATE INDEX idx_conversion_jobs_input_file ON conversion_jobs(input_file_id);
CREATE INDEX idx_conversion_jobs_status ON conversion_jobs(status);
CREATE INDEX idx_conversion_jobs_priority ON conversion_jobs(priority);
CREATE INDEX idx_conversion_jobs_created_at ON conversion_jobs(created_at);
CREATE INDEX idx_conversion_jobs_status_priority ON conversion_jobs(status, priority) WHERE status IN ('pending', 'processing');

-- Notifications table indexes
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_job_id ON notifications(conversion_job_id);
CREATE INDEX idx_notifications_unread ON notifications(user_id, is_read) WHERE is_read = FALSE;
CREATE INDEX idx_notifications_created_at ON notifications(created_at);

-- Activity log indexes
CREATE INDEX idx_user_activity_user_id ON user_activity(user_id);
CREATE INDEX idx_user_activity_action ON user_activity(action);
CREATE INDEX idx_user_activity_created_at ON user_activity(created_at);

-- System settings indexes
CREATE INDEX idx_system_settings_key ON system_settings(key);
CREATE INDEX idx_system_settings_public ON system_settings(is_public);

-- File shares indexes
CREATE INDEX idx_file_shares_file_id ON file_shares(file_id);
CREATE INDEX idx_file_shares_token ON file_shares(share_token);
CREATE INDEX idx_file_shares_active ON file_shares(is_active);
CREATE INDEX idx_file_shares_expires ON file_shares(expires_at) WHERE expires_at IS NOT NULL;

-- Webhook endpoints indexes
CREATE INDEX idx_webhook_endpoints_user_id ON webhook_endpoints(user_id);
CREATE INDEX idx_webhook_endpoints_active ON webhook_endpoints(is_active);

-- =====================================================
-- TRIGGERS FOR UPDATED_AT TIMESTAMPS
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply triggers to all tables with updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_files_updated_at BEFORE UPDATE ON files FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_conversion_jobs_updated_at BEFORE UPDATE ON conversion_jobs FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_system_settings_updated_at BEFORE UPDATE ON system_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- INSERT DEFAULT SYSTEM SETTINGS
-- =====================================================
INSERT INTO system_settings (key, value, description, is_public) VALUES
('max_file_size', '52428800', 'Maximum file size in bytes (50MB)', true),
('allowed_file_types', '["pdf","doc","docx","txt","rtf","html","xml","jpg","jpeg","png","gif","bmp","tiff"]', 'Allowed file types for upload', true),
('conversion_timeout', '300', 'Conversion timeout in seconds', false),
('cleanup_interval', '86400', 'File cleanup interval in seconds (24 hours)', false),
('free_quota_limit', '104857600', 'Free user quota limit in bytes (100MB)', true),
('premium_quota_limit', '1073741824', 'Premium user quota limit in bytes (1GB)', true),
('max_concurrent_conversions', '10', 'Maximum concurrent conversion jobs', false),
('notification_retention_days', '30', 'Days to keep notifications', false),
('temp_file_retention_hours', '24', 'Hours to keep temporary files', false);

-- =====================================================
-- CREATE DEFAULT ADMIN USER
-- =====================================================
-- Password: admin123 (hashed with bcrypt)
-- Change this in production!
INSERT INTO users (
    email, 
    password_hash, 
    first_name, 
    last_name, 
    role, 
    is_active, 
    is_verified,
    quota_limit,
    subscription_plan
) VALUES (
    'admin@pdfconverter.local',
    '$2b$10$CwTycUXWue0Thq9StjUM0uJ8HdRHMjhHlnQ7Lz4j4qlNzQ6FHFq6m',
    'System',
    'Administrator',
    'admin',
    TRUE,
    TRUE,
    10737418240, -- 10GB
    'enterprise'
);

-- =====================================================
-- FUNCTIONS FOR COMMON OPERATIONS
-- =====================================================

-- Function to get user quota usage
CREATE OR REPLACE FUNCTION get_user_quota_usage(user_uuid UUID)
RETURNS BIGINT AS $$
BEGIN
    RETURN COALESCE(
        (SELECT SUM(file_size) 
         FROM files 
         WHERE user_id = user_uuid 
         AND status != 'deleted'), 
        0
    );
END;
$$ LANGUAGE plpgsql;

-- Function to check if user can upload file
CREATE OR REPLACE FUNCTION can_user_upload(user_uuid UUID, file_size_bytes BIGINT)
RETURNS BOOLEAN AS $$
DECLARE
    user_quota_limit BIGINT;
    current_usage BIGINT;
BEGIN
    SELECT quota_limit INTO user_quota_limit FROM users WHERE id = user_uuid;
    SELECT get_user_quota_usage(user_uuid) INTO current_usage;
    
    RETURN (current_usage + file_size_bytes) <= user_quota_limit;
END;
$$ LANGUAGE plpgsql;

-- Function to cleanup expired files
CREATE OR REPLACE FUNCTION cleanup_expired_files()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    UPDATE files 
    SET status = 'deleted'
    WHERE expires_at < CURRENT_TIMESTAMP 
    AND status != 'deleted';
    
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- VIEWS FOR COMMON QUERIES
-- =====================================================

-- View for active conversion jobs with user info
CREATE VIEW active_conversions AS
SELECT 
    cj.id,
    cj.status,
    cj.priority,
    cj.progress,
    cj.created_at,
    cj.started_at,
    u.email as user_email,
    f.original_filename,
    f.file_size
FROM conversion_jobs cj
JOIN users u ON cj.user_id = u.id
JOIN files f ON cj.input_file_id = f.id
WHERE cj.status IN ('pending', 'processing')
ORDER BY cj.priority ASC, cj.created_at ASC;

-- View for user statistics
CREATE VIEW user_stats AS
SELECT 
    u.id,
    u.email,
    u.role,
    u.created_at,
    COUNT(DISTINCT f.id) as total_files,
    COUNT(DISTINCT cj.id) as total_conversions,
    COALESCE(SUM(f.file_size), 0) as storage_used,
    u.quota_limit,
    u.last_login
FROM users u
LEFT JOIN files f ON u.id = f.user_id AND f.status != 'deleted'
LEFT JOIN conversion_jobs cj ON u.id = cj.user_id
GROUP BY u.id, u.email, u.role, u.created_at, u.quota_limit, u.last_login;

-- =====================================================
-- GRANTS AND PERMISSIONS
-- =====================================================

-- Create application user
DO $$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'app_user') THEN
      CREATE ROLE app_user LOGIN PASSWORD 'AppSecure2024!';
   END IF;
END
$$;

-- Grant permissions
GRANT CONNECT ON DATABASE pdf_converter_db TO app_user;
GRANT USAGE ON SCHEMA public TO app_user;
GRANT CREATE ON SCHEMA public TO app_user;

-- Grant table permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_user;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_user;

-- Grant permissions on views
GRANT SELECT ON active_conversions TO app_user;
GRANT SELECT ON user_stats TO app_user;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION get_user_quota_usage(UUID) TO app_user;
GRANT EXECUTE ON FUNCTION can_user_upload(UUID, BIGINT) TO app_user;
GRANT EXECUTE ON FUNCTION cleanup_expired_files() TO app_user;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO app_user;

-- =====================================================
-- COMPLETION MESSAGE
-- =====================================================
\echo ''
\echo '✅ PDF Converter database initialization completed!'
\echo ''
\echo '📊 Created tables:'
\echo '  • users (with admin user)'
\echo '  • user_sessions'
\echo '  • api_keys'
\echo '  • files'
\echo '  • conversion_jobs'
\echo '  • notifications'
\echo '  • user_activity'
\echo '  • system_settings'
\echo '  • file_shares'
\echo '  • webhook_endpoints'
\echo ''
\echo '🔧 Created functions:'
\echo '  • get_user_quota_usage()'
\echo '  • can_user_upload()'
\echo '  • cleanup_expired_files()'
\echo ''
\echo '👁️  Created views:'
\echo '  • active_conversions'
\echo '  • user_stats'
\echo ''
\echo '🔑 Default admin credentials:'
\echo '  Email: admin@pdfconverter.local'
\echo '  Password: admin123'
\echo '  ⚠️  CHANGE THIS IN PRODUCTION!'
\echo ''