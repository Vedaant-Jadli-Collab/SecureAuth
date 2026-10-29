-- =====================================================================
-- 01_schema.sql | Secure Authentication & User Management System
-- BACSE202 Database Systems | Oracle 12c or later
-- 8 related tables with PK, FK, UNIQUE, NOT NULL, CHECK, DEFAULT
-- =====================================================================

-- Clean up so the script can be re-run
BEGIN
  FOR t IN (SELECT table_name FROM user_tables
            WHERE table_name IN ('AUDIT_TRAIL','SESSIONS','LOGIN_HISTORY',
                                 'ROLE_PERMISSIONS','USER_ROLES',
                                 'PERMISSIONS','ROLES','USERS')) LOOP
    EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
  END LOOP;
END;
/

CREATE TABLE users (
  user_id         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  username        VARCHAR2(50)  NOT NULL UNIQUE,
  email           VARCHAR2(100) NOT NULL UNIQUE,
  password_hash   VARCHAR2(255) NOT NULL,
  full_name       VARCHAR2(100) NOT NULL,
  account_status  VARCHAR2(10)  DEFAULT 'ACTIVE' NOT NULL
                  CHECK (account_status IN ('ACTIVE','INACTIVE','LOCKED','SUSPENDED')),
  failed_attempts NUMBER(3)     DEFAULT 0 NOT NULL CHECK (failed_attempts >= 0),
  created_date    DATE          DEFAULT SYSDATE NOT NULL
);

CREATE TABLE roles (
  role_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  role_name    VARCHAR2(30)  NOT NULL UNIQUE,
  description  VARCHAR2(200)
);

CREATE TABLE permissions (
  perm_id        NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  perm_name      VARCHAR2(40) NOT NULL UNIQUE,
  resource_type  VARCHAR2(10) NOT NULL
                 CHECK (resource_type IN ('READ','WRITE','DELETE','ADMIN'))
);

-- Junction table: Users M:N Roles
CREATE TABLE user_roles (
  user_id        NUMBER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  role_id        NUMBER NOT NULL REFERENCES roles(role_id) ON DELETE CASCADE,
  assigned_date  DATE DEFAULT SYSDATE NOT NULL,
  CONSTRAINT pk_user_roles PRIMARY KEY (user_id, role_id)
);

-- Junction table: Roles M:N Permissions
CREATE TABLE role_permissions (
  role_id  NUMBER NOT NULL REFERENCES roles(role_id) ON DELETE CASCADE,
  perm_id  NUMBER NOT NULL REFERENCES permissions(perm_id) ON DELETE CASCADE,
  CONSTRAINT pk_role_permissions PRIMARY KEY (role_id, perm_id)
);

-- Users 1:N Login attempts
CREATE TABLE login_history (
  login_id       NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id        NUMBER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  login_time     DATE DEFAULT SYSDATE NOT NULL,
  ip_address     VARCHAR2(45),
  login_status   VARCHAR2(10) NOT NULL CHECK (login_status IN ('SUCCESS','FAILED')),
  failure_reason VARCHAR2(100)
);

-- Login 1:N Sessions, Users 1:N Sessions
CREATE TABLE sessions (
  session_id    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id       NUMBER NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  login_id      NUMBER REFERENCES login_history(login_id) ON DELETE SET NULL,
  session_token VARCHAR2(64) NOT NULL UNIQUE,
  start_time    DATE DEFAULT SYSDATE NOT NULL,
  expiry_time   DATE NOT NULL,
  is_active     CHAR(1) DEFAULT 'Y' NOT NULL CHECK (is_active IN ('Y','N')),
  CONSTRAINT chk_session_time CHECK (expiry_time > start_time)
);

-- Security events and system changes (merges security logs and audit trail)
CREATE TABLE audit_trail (
  audit_id     NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id      NUMBER REFERENCES users(user_id) ON DELETE SET NULL,
  event_type   VARCHAR2(30) NOT NULL,
  target_table VARCHAR2(30),
  old_value    VARCHAR2(100),
  new_value    VARCHAR2(100),
  event_time   DATE DEFAULT SYSDATE NOT NULL
);
