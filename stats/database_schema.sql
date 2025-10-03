-- MacroMaster Stats Database Schema
-- Optimized for fast queries and timeline filtering

-- Main executions table
CREATE TABLE IF NOT EXISTS executions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp DATETIME NOT NULL,
    session_id TEXT NOT NULL,
    username TEXT NOT NULL,
    execution_type TEXT NOT NULL, -- 'macro', 'json_profile', 'clear'
    button_key TEXT,
    layer INTEGER NOT NULL,
    execution_time_ms INTEGER NOT NULL,
    total_boxes INTEGER NOT NULL,
    degradation_assignments TEXT, -- Comma-separated list for combinations
    severity_level TEXT,
    canvas_mode TEXT, -- 'wide' or 'narrow'
    session_active_time_ms INTEGER NOT NULL,
    break_mode_active BOOLEAN NOT NULL DEFAULT 0,
    annotation_details TEXT,
    execution_success BOOLEAN NOT NULL DEFAULT 1,
    error_details TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Degradations detail table (normalized for efficient querying)
CREATE TABLE IF NOT EXISTS degradations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    execution_id INTEGER NOT NULL,
    degradation_type TEXT NOT NULL, -- 'smudge', 'glare', 'splashes', etc.
    count INTEGER NOT NULL DEFAULT 1,
    FOREIGN KEY (execution_id) REFERENCES executions(id) ON DELETE CASCADE
);

-- Sessions tracking table
CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id TEXT UNIQUE NOT NULL,
    username TEXT NOT NULL,
    start_time DATETIME NOT NULL,
    end_time DATETIME,
    total_executions INTEGER DEFAULT 0,
    total_boxes INTEGER DEFAULT 0,
    total_active_time_ms INTEGER DEFAULT 0
);

-- Performance indexes for fast queries
CREATE INDEX IF NOT EXISTS idx_executions_timestamp ON executions(timestamp);
CREATE INDEX IF NOT EXISTS idx_executions_session ON executions(session_id);
CREATE INDEX IF NOT EXISTS idx_executions_type ON executions(execution_type);
CREATE INDEX IF NOT EXISTS idx_executions_button ON executions(button_key);
CREATE INDEX IF NOT EXISTS idx_executions_layer ON executions(layer);
CREATE INDEX IF NOT EXISTS idx_degradations_type ON degradations(degradation_type);
CREATE INDEX IF NOT EXISTS idx_degradations_execution ON degradations(execution_id);
CREATE INDEX IF NOT EXISTS idx_sessions_id ON sessions(session_id);

-- View for quick degradation summaries
CREATE VIEW IF NOT EXISTS degradation_summary AS
SELECT
    d.degradation_type,
    SUM(d.count) as total_count,
    COUNT(DISTINCT d.execution_id) as execution_count,
    AVG(e.execution_time_ms) as avg_execution_time
FROM degradations d
JOIN executions e ON d.execution_id = e.id
GROUP BY d.degradation_type;

-- View for execution statistics by time period
CREATE VIEW IF NOT EXISTS hourly_stats AS
SELECT
    strftime('%Y-%m-%d %H:00:00', timestamp) as hour,
    COUNT(*) as executions,
    SUM(total_boxes) as boxes,
    AVG(execution_time_ms) as avg_time_ms,
    execution_type
FROM executions
GROUP BY hour, execution_type
ORDER BY hour DESC;
