-- =====================================================================
-- 03_plsql.sql | Procedures (2), Functions (2), Cursor, Triggers (2)
-- Run with: SET SERVEROUTPUT ON
-- =====================================================================

-- ---------- PROCEDURE 1: register a user and assign a role ----------
CREATE OR REPLACE PROCEDURE sp_register_user (
  p_username   IN VARCHAR2,
  p_email      IN VARCHAR2,
  p_hash       IN VARCHAR2,
  p_full_name  IN VARCHAR2,
  p_role_name  IN VARCHAR2
) IS
  v_user_id NUMBER;
  v_role_id NUMBER;
BEGIN
  SELECT role_id INTO v_role_id FROM roles WHERE role_name = UPPER(p_role_name);

  INSERT INTO users (username, email, password_hash, full_name)
  VALUES (p_username, p_email, p_hash, p_full_name)
  RETURNING user_id INTO v_user_id;

  INSERT INTO user_roles (user_id, role_id) VALUES (v_user_id, v_role_id);

  INSERT INTO audit_trail (user_id, event_type, target_table, new_value)
  VALUES (v_user_id, 'USER_CREATED', 'USERS', p_username);

  COMMIT;
EXCEPTION
  WHEN NO_DATA_FOUND THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(-20001, 'Role not found: ' || p_role_name);
  WHEN DUP_VAL_ON_INDEX THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(-20002, 'Username or email already exists');
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END sp_register_user;
/

-- ---------- PROCEDURE 2: change account status (fires trg_status_audit) ----------
CREATE OR REPLACE PROCEDURE sp_set_account_status (
  p_user_id IN NUMBER,
  p_status  IN VARCHAR2
) IS
BEGIN
  UPDATE users SET account_status = UPPER(p_status) WHERE user_id = p_user_id;

  IF SQL%ROWCOUNT = 0 THEN
    RAISE_APPLICATION_ERROR(-20003, 'User not found: ' || p_user_id);
  END IF;

  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END sp_set_account_status;
/

-- ---------- CURSOR: expire sessions past their expiry time ----------
CREATE OR REPLACE PROCEDURE sp_expire_sessions IS
  CURSOR c_expired IS
    SELECT session_id, user_id
    FROM sessions
    WHERE is_active = 'Y' AND expiry_time < SYSDATE;

  v_count NUMBER := 0;
BEGIN
  FOR rec IN c_expired LOOP
    UPDATE sessions SET is_active = 'N' WHERE session_id = rec.session_id;

    INSERT INTO audit_trail (user_id, event_type, target_table, old_value, new_value)
    VALUES (rec.user_id, 'SESSION_EXPIRED', 'SESSIONS', 'Y', 'N');

    v_count := v_count + 1;
  END LOOP;

  COMMIT;
  DBMS_OUTPUT.PUT_LINE(v_count || ' session(s) expired');
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END sp_expire_sessions;
/

-- ---------- FUNCTION 1: does this user hold a permission? returns 'Y' or 'N' ----------
CREATE OR REPLACE FUNCTION fn_has_permission (
  p_user_id   IN NUMBER,
  p_perm_name IN VARCHAR2
) RETURN VARCHAR2 IS
  v_cnt NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_cnt
  FROM user_roles ur
  JOIN role_permissions rp ON rp.role_id = ur.role_id
  JOIN permissions p       ON p.perm_id  = rp.perm_id
  WHERE ur.user_id = p_user_id
    AND p.perm_name = UPPER(p_perm_name);

  RETURN CASE WHEN v_cnt > 0 THEN 'Y' ELSE 'N' END;
END fn_has_permission;
/

-- ---------- FUNCTION 2: percentage of successful logins for a user ----------
CREATE OR REPLACE FUNCTION fn_success_rate (
  p_user_id IN NUMBER
) RETURN NUMBER IS
  v_total NUMBER;
  v_ok    NUMBER;
BEGIN
  SELECT COUNT(*), SUM(CASE WHEN login_status = 'SUCCESS' THEN 1 ELSE 0 END)
  INTO v_total, v_ok
  FROM login_history
  WHERE user_id = p_user_id;

  IF v_total = 0 THEN
    RETURN 0;
  END IF;

  RETURN ROUND(100 * v_ok / v_total, 2);
END fn_success_rate;
/

-- ---------- TRIGGER 1: a failed login increments the counter; 5 failures lock the account ----------
CREATE OR REPLACE TRIGGER trg_login_failure
AFTER INSERT ON login_history
FOR EACH ROW
BEGIN
  IF :NEW.login_status = 'FAILED' THEN
    UPDATE users
    SET failed_attempts = failed_attempts + 1,
        account_status  = CASE
                            WHEN failed_attempts + 1 >= 5 AND account_status = 'ACTIVE'
                            THEN 'LOCKED'
                            ELSE account_status
                          END
    WHERE user_id = :NEW.user_id;
  ELSE
    UPDATE users SET failed_attempts = 0 WHERE user_id = :NEW.user_id;
  END IF;
END;
/

-- ---------- TRIGGER 2: log every account status change to the audit trail ----------
CREATE OR REPLACE TRIGGER trg_status_audit
AFTER UPDATE OF account_status ON users
FOR EACH ROW
WHEN (OLD.account_status <> NEW.account_status)
BEGIN
  INSERT INTO audit_trail (user_id, event_type, target_table, old_value, new_value)
  VALUES (:NEW.user_id, 'STATUS_CHANGE', 'USERS', :OLD.account_status, :NEW.account_status);
END;
/
