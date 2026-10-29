-- =====================================================================
-- 02_data.sql | Sample data (10+ rows per table)
-- =====================================================================
SET DEFINE OFF;

INSERT INTO roles (role_name, description) VALUES ('ADMIN', 'Full system access');
INSERT INTO roles (role_name, description) VALUES ('MANAGER', 'Manages users and views logs');
INSERT INTO roles (role_name, description) VALUES ('ANALYST', 'Reads reports and user data');
INSERT INTO roles (role_name, description) VALUES ('DEVELOPER', 'Creates and updates user accounts');
INSERT INTO roles (role_name, description) VALUES ('AUDITOR', 'Reads audit trail and logs');
INSERT INTO roles (role_name, description) VALUES ('SUPPORT', 'Helps users with account issues');
INSERT INTO roles (role_name, description) VALUES ('HR', 'Human resources staff');
INSERT INTO roles (role_name, description) VALUES ('FINANCE', 'Finance staff');
INSERT INTO roles (role_name, description) VALUES ('GUEST', 'Read-only limited access');
INSERT INTO roles (role_name, description) VALUES ('SECURITY_OFFICER', 'Monitors logs and sessions');

INSERT INTO permissions (perm_name, resource_type) VALUES ('VIEW_USERS', 'READ');
INSERT INTO permissions (perm_name, resource_type) VALUES ('CREATE_USER', 'WRITE');
INSERT INTO permissions (perm_name, resource_type) VALUES ('UPDATE_USER', 'WRITE');
INSERT INTO permissions (perm_name, resource_type) VALUES ('DELETE_USER', 'DELETE');
INSERT INTO permissions (perm_name, resource_type) VALUES ('MANAGE_ROLES', 'ADMIN');
INSERT INTO permissions (perm_name, resource_type) VALUES ('VIEW_LOGS', 'READ');
INSERT INTO permissions (perm_name, resource_type) VALUES ('VIEW_AUDIT', 'READ');
INSERT INTO permissions (perm_name, resource_type) VALUES ('TERMINATE_SESSION', 'ADMIN');
INSERT INTO permissions (perm_name, resource_type) VALUES ('CHANGE_PASSWORD', 'WRITE');
INSERT INTO permissions (perm_name, resource_type) VALUES ('EXPORT_REPORTS', 'READ');

INSERT INTO users (username, email, password_hash, full_name) VALUES ('alice', 'alice@example.com', 'hash_alice', 'Alice Sharma');
INSERT INTO users (username, email, password_hash, full_name) VALUES ('bob', 'bob@example.com', 'hash_bob', 'Bob Mehta');
INSERT INTO users (username, email, password_hash, full_name) VALUES ('carol', 'carol@example.com', 'hash_carol', 'Carol Nair');
INSERT INTO users (username, email, password_hash, full_name) VALUES ('dev', 'dev@example.com', 'hash_dev', 'Dev Patel');
INSERT INTO users (username, email, password_hash, full_name) VALUES ('eve', 'eve@example.com', 'hash_eve', 'Eve Iyer');
INSERT INTO users (username, email, password_hash, full_name) VALUES ('frank', 'frank@example.com', 'hash_frank', 'Frank Dsouza');
INSERT INTO users (username, email, password_hash, full_name) VALUES ('grace', 'grace@example.com', 'hash_grace', 'Grace Kaur');
INSERT INTO users (username, email, password_hash, full_name) VALUES ('heidi', 'heidi@example.com', 'hash_heidi', 'Heidi Rao');
INSERT INTO users (username, email, password_hash, full_name) VALUES ('ivan', 'ivan@example.com', 'hash_ivan', 'Ivan Khan');
INSERT INTO users (username, email, password_hash, full_name) VALUES ('judy', 'judy@example.com', 'hash_judy', 'Judy Singh');

-- Assign roles (M:N) using lookups, so no hard-coded IDs
INSERT INTO user_roles (user_id, role_id)
SELECT u.user_id, r.role_id FROM (
  SELECT 'alice' un, 'ADMIN' rn FROM dual UNION ALL
  SELECT 'bob', 'MANAGER' FROM dual UNION ALL
  SELECT 'carol', 'ANALYST' FROM dual UNION ALL
  SELECT 'dev', 'DEVELOPER' FROM dual UNION ALL
  SELECT 'dev', 'ANALYST' FROM dual UNION ALL
  SELECT 'eve', 'GUEST' FROM dual UNION ALL
  SELECT 'frank', 'AUDITOR' FROM dual UNION ALL
  SELECT 'grace', 'HR' FROM dual UNION ALL
  SELECT 'heidi', 'SUPPORT' FROM dual UNION ALL
  SELECT 'ivan', 'FINANCE' FROM dual UNION ALL
  SELECT 'judy', 'SECURITY_OFFICER' FROM dual
) m
JOIN users u ON u.username = m.un
JOIN roles r ON r.role_name = m.rn;

-- Assign permissions to roles (M:N)
INSERT INTO role_permissions (role_id, perm_id)
SELECT r.role_id, p.perm_id FROM roles r, permissions p WHERE r.role_name = 'ADMIN';

INSERT INTO role_permissions (role_id, perm_id)
SELECT r.role_id, p.perm_id FROM (
  SELECT 'MANAGER' rn, 'VIEW_USERS' pn FROM dual UNION ALL
  SELECT 'MANAGER', 'UPDATE_USER' FROM dual UNION ALL
  SELECT 'MANAGER', 'VIEW_LOGS' FROM dual UNION ALL
  SELECT 'ANALYST', 'VIEW_USERS' FROM dual UNION ALL
  SELECT 'ANALYST', 'EXPORT_REPORTS' FROM dual UNION ALL
  SELECT 'DEVELOPER', 'CREATE_USER' FROM dual UNION ALL
  SELECT 'DEVELOPER', 'UPDATE_USER' FROM dual UNION ALL
  SELECT 'AUDITOR', 'VIEW_AUDIT' FROM dual UNION ALL
  SELECT 'AUDITOR', 'VIEW_LOGS' FROM dual UNION ALL
  SELECT 'SUPPORT', 'VIEW_USERS' FROM dual UNION ALL
  SELECT 'SECURITY_OFFICER', 'VIEW_LOGS' FROM dual UNION ALL
  SELECT 'SECURITY_OFFICER', 'VIEW_AUDIT' FROM dual UNION ALL
  SELECT 'SECURITY_OFFICER', 'TERMINATE_SESSION' FROM dual UNION ALL
  SELECT 'GUEST', 'VIEW_USERS' FROM dual
) m
JOIN roles r ON r.role_name = m.rn
JOIN permissions p ON p.perm_name = m.pn;

-- Login attempts. The trg_login_failure trigger updates users.failed_attempts.
-- eve's 5th failure locks her account automatically.
INSERT INTO login_history (user_id, login_time, ip_address, login_status, failure_reason)
SELECT u.user_id, SYSDATE - m.hrs/24, m.ip, m.st, m.reason FROM (
  SELECT 'alice' un, 2 hrs, '10.0.0.5' ip, 'SUCCESS' st, CAST(NULL AS VARCHAR2(100)) reason FROM dual UNION ALL
  SELECT 'bob', 120, '10.0.0.8', 'SUCCESS', NULL FROM dual UNION ALL
  SELECT 'carol', 216, '10.0.0.9', 'SUCCESS', NULL FROM dual UNION ALL
  SELECT 'dev', 624, '10.0.1.4', 'SUCCESS', NULL FROM dual UNION ALL
  SELECT 'eve', 720, '172.16.0.3', 'FAILED', 'Wrong password' FROM dual UNION ALL
  SELECT 'eve', 718, '172.16.0.3', 'FAILED', 'Wrong password' FROM dual UNION ALL
  SELECT 'eve', 716, '172.16.0.3', 'FAILED', 'Wrong password' FROM dual UNION ALL
  SELECT 'eve', 714, '172.16.0.3', 'FAILED', 'Wrong password' FROM dual UNION ALL
  SELECT 'eve', 712, '172.16.0.3', 'FAILED', 'Wrong password' FROM dual UNION ALL
  SELECT 'frank', 1200, '10.0.2.7', 'SUCCESS', NULL FROM dual UNION ALL
  SELECT 'grace', 1704, '10.0.3.2', 'SUCCESS', NULL FROM dual UNION ALL
  SELECT 'heidi', 3, '10.0.4.6', 'SUCCESS', NULL FROM dual UNION ALL
  SELECT 'ivan', 6, '10.0.5.1', 'FAILED', 'Wrong password' FROM dual UNION ALL
  SELECT 'ivan', 5, '10.0.5.1', 'SUCCESS', NULL FROM dual UNION ALL
  SELECT 'judy', 1, '10.0.6.9', 'SUCCESS', NULL FROM dual UNION ALL
  SELECT 'alice', 12, '10.0.0.5', 'SUCCESS', NULL FROM dual UNION ALL
  SELECT 'bob', 40, '10.0.0.8', 'SUCCESS', NULL FROM dual
) m
JOIN users u ON u.username = m.un;

-- Sessions created from every successful login (expired, so the cursor procedure has work to do)
INSERT INTO sessions (user_id, login_id, session_token, start_time, expiry_time, is_active)
SELECT user_id, login_id, 'TOK-' || login_id, login_time, login_time + 30/1440, 'Y'
FROM login_history
WHERE login_status = 'SUCCESS';

-- Audit records for user creation and role assignment
INSERT INTO audit_trail (user_id, event_type, target_table, new_value, event_time)
SELECT user_id, 'USER_CREATED', 'USERS', username, created_date FROM users;

INSERT INTO audit_trail (user_id, event_type, target_table, new_value, event_time)
SELECT ur.user_id, 'ROLE_ASSIGNED', 'USER_ROLES', r.role_name, ur.assigned_date
FROM user_roles ur JOIN roles r ON r.role_id = ur.role_id;

COMMIT;
