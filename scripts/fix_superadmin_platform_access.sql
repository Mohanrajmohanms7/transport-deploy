-- =============================================================================
-- FleetFlow / Transport ERP — ONE-TIME AWS FIX
-- Purpose: create/fix Super Admin login for Platform Admin (/platform-admin)
-- Safe: does NOT wipe company data. Idempotent (safe to run more than once).
--
-- Logins after this script:
--   Username: superadmin
--   Password: Super@123
--   Role:     SUPER_ADMIN  → Platform Admin
--
-- Also ensures bootstrap user "admin" keeps working:
--   Username: admin
--   Password: Admin@123
--   Role:     SUPER_ADMIN  (so login does not trap on /setup only)
--
-- Run on EC2:
--   docker exec -i transport-postgres psql -U transport_admin -d transport_erp \
--     < scripts/fix_superadmin_platform_access.sql
-- =============================================================================

BEGIN;

-- 1) Ensure SUPER_ADMIN role exists
INSERT INTO app_roles (code, name, description, status, created_by, is_deleted, version)
SELECT 'SUPER_ADMIN', 'Super Administrator', 'Full platform access', 'ACTIVE', 'SYSTEM', false, 0
WHERE NOT EXISTS (
  SELECT 1 FROM app_roles WHERE code = 'SUPER_ADMIN' AND is_deleted = false
);

-- 2) Pick any existing company + HO branch (bootstrap DEMO or AKS)
--    If none exist, create a minimal owner company.
INSERT INTO companies (code, name, description, status, country, created_by, is_deleted, version)
SELECT 'OWNER', 'FleetFlow Owner', 'Platform owner company', 'ACTIVE', 'India', 'SYSTEM', false, 0
WHERE NOT EXISTS (
  SELECT 1 FROM companies WHERE is_deleted = false
);

INSERT INTO branches (code, name, description, status, company_id, created_by, is_deleted, version)
SELECT 'HO', 'Head Office', 'Default branch', 'ACTIVE', c.id, 'SYSTEM', false, 0
FROM companies c
WHERE c.is_deleted = false
  AND NOT EXISTS (
    SELECT 1 FROM branches b WHERE b.company_id = c.id AND b.is_deleted = false
  )
ORDER BY c.id
LIMIT 1;

-- 3) Upsert superadmin (BCrypt for Super@123 — same as local seed)
INSERT INTO app_users (
  code, name, description, username, password, email, phone,
  status, company_id, branch_id, created_by, is_deleted, version,
  force_password_change, failed_login_attempts
)
SELECT
  'EMP_SUPER',
  'Platform Super Admin',
  'SaaS owner login',
  'superadmin',
  '$2a$10$Vl/4./c4M1XobrFkf0punuArItZwEn/9WdgrrEULy..MzyVvuiyda',
  'superadmin@fleetflow.local',
  NULL,
  'ACTIVE',
  c.id,
  b.id,
  'SYSTEM',
  false,
  0,
  false,
  0
FROM companies c
JOIN branches b ON b.company_id = c.id AND b.is_deleted = false
WHERE c.is_deleted = false
  AND NOT EXISTS (
    SELECT 1 FROM app_users u WHERE u.username = 'superadmin' AND u.is_deleted = false
  )
ORDER BY c.id, b.id
LIMIT 1;

-- If superadmin already exists, reset password + activate
UPDATE app_users
SET password = '$2a$10$Vl/4./c4M1XobrFkf0punuArItZwEn/9WdgrrEULy..MzyVvuiyda',
    status = 'ACTIVE',
    force_password_change = false,
    failed_login_attempts = 0,
    is_deleted = false,
    updated_by = 'SYSTEM',
    updated_date = CURRENT_TIMESTAMP
WHERE username = 'superadmin';

-- 4) Attach SUPER_ADMIN role to superadmin
INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM app_users u
CROSS JOIN app_roles r
WHERE u.username = 'superadmin'
  AND u.is_deleted = false
  AND r.code = 'SUPER_ADMIN'
  AND r.is_deleted = false
  AND NOT EXISTS (
    SELECT 1 FROM user_roles ur WHERE ur.user_id = u.id AND ur.role_id = r.id
  );

-- 5) Keep "admin" usable too (password Admin@123) + SUPER_ADMIN role
--    BCrypt for Admin@123 from local seed
UPDATE app_users
SET password = '$2a$10$y3k6HDGua0Xkk4qPHXFlve2qjjf6t.tGpljCHEkLzEkDvpSREn8Je',
    status = 'ACTIVE',
    force_password_change = false,
    failed_login_attempts = 0,
    updated_by = 'SYSTEM',
    updated_date = CURRENT_TIMESTAMP
WHERE username = 'admin'
  AND is_deleted = false;

INSERT INTO user_roles (user_id, role_id)
SELECT u.id, r.id
FROM app_users u
CROSS JOIN app_roles r
WHERE u.username = 'admin'
  AND u.is_deleted = false
  AND r.code = 'SUPER_ADMIN'
  AND r.is_deleted = false
  AND NOT EXISTS (
    SELECT 1 FROM user_roles ur WHERE ur.user_id = u.id AND ur.role_id = r.id
  );

COMMIT;

-- 6) Verify
SELECT u.id, u.username, u.status, r.code AS role
FROM app_users u
LEFT JOIN user_roles ur ON ur.user_id = u.id
LEFT JOIN app_roles r ON r.id = ur.role_id
WHERE u.username IN ('superadmin', 'admin')
  AND u.is_deleted = false
ORDER BY u.username, r.code;
