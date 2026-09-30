-- Migration: V007 - Rename email to email_address
-- Risk level: HIGH (BREAKING CHANGE)
-- Backward compatible: NO
-- Impact: API v1 will break, only API v2 will work
-- Rollback strategy: Rename column back

BEGIN;

-- Rename the column (this breaks existing queries!)
ALTER TABLE users RENAME COLUMN email TO email_address;

-- This is a BREAKING CHANGE:
-- - API v1 queries "SELECT email FROM users" will FAIL
-- - API v2 queries "SELECT email_address FROM users" will WORK

COMMIT;
