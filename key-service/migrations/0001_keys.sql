CREATE TABLE license_keys (
    id TEXT PRIMARY KEY NOT NULL,
    key_hash TEXT NOT NULL UNIQUE CHECK (length(key_hash) = 64),
    last4 TEXT NOT NULL CHECK (length(last4) = 4),
    plan TEXT NOT NULL CHECK (plan IN ('weekly', 'monthly', '60days', 'permanent')),
    created_at INTEGER NOT NULL,
    expires_at INTEGER,
    revoked_at INTEGER,
    CHECK ((plan = 'permanent' AND expires_at IS NULL) OR
           (plan <> 'permanent' AND expires_at IS NOT NULL AND expires_at > created_at))
);

-- UNIQUE(key_hash) supplies the indexed validation lookup.
CREATE TABLE rate_limits (
    ip_hash TEXT PRIMARY KEY NOT NULL,
    window_start INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    attempts INTEGER NOT NULL CHECK (attempts BETWEEN 1 AND 9)
);
CREATE INDEX rate_limits_expiry ON rate_limits(expires_at);
