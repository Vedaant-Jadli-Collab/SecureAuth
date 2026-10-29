-- =====================================================================
-- 04_queries.sql | 15+ SELECT queries, DML, and TCL
-- =====================================================================
SET LINESIZE 200 PAGESIZE 100

-- Q1. Simple: all users
SELECT user_id, username, email, account_status FROM users ORDER BY username;

-- Q2. Join: users with their roles
SELECT u.username, r.role_name
FROM users u
JOIN user_roles ur ON ur.user_id = u.user_id
JOIN roles r       ON r.role_id  = ur.role_id
ORDER BY u.username;

-- Q3. Multi-table join: permissions held by a given user (alice)
SELECT DISTINCT p.perm_name
FROM users u
JOIN user_roles ur      ON ur.user_id = u.user_id
JOIN role_permissions rp ON rp.role_id = ur.role_id
JOIN permissions p      ON p.perm_id  = rp.perm_id
WHERE u.username = 'alice';

-- Q4. Aggregation: number of users per role
SELECT r.role_name, COUNT(ur.user_id) AS user_count
FROM roles r
LEFT JOIN user_roles ur ON ur.role_id = r.role_id
GROUP BY r.role_name
ORDER BY user_count DESC, r.role_name;

-- Q5. HAVING: roles with more than 2 permissions
SELECT r.role_name, COUNT(*) AS perm_count
FROM role_permissions rp
JOIN roles r ON r.role_id = rp.role_id
GROUP BY r.role_name
HAVING COUNT(*) > 2;

-- Q6. Filter on status: locked accounts
SELECT username, failed_attempts FROM users WHERE account_status = 'LOCKED';

-- Q7. Subquery with IN: users who logged in successfully in the last 7 days
SELECT username FROM users
WHERE user_id IN (
  SELECT user_id FROM login_history
  WHERE login_status = 'SUCCESS' AND login_time >= SYSDATE - 7
);

-- Q8. Nested subquery: users who hold no ADMIN role (NOT IN)
SELECT username FROM users
WHERE user_id NOT IN (
  SELECT ur.user_id FROM user_roles ur
  JOIN roles r ON r.role_id = ur.role_id
  WHERE r.role_name = 'ADMIN'
);

-- Q9. Correlated subquery: each user's most recent login
SELECT u.username,
       (SELECT MAX(l.login_time) FROM login_history l WHERE l.user_id = u.user_id) AS last_login
FROM users u
ORDER BY last_login DESC NULLS LAST;

-- Q10. EXISTS: users with at least one failed login
SELECT u.username FROM users u
WHERE EXISTS (
  SELECT 1 FROM login_history l
  WHERE l.user_id = u.user_id AND l.login_status = 'FAILED'
);

-- Q11. Set operation: users who are ADMIN or SECURITY_OFFICER
SELECT u.username FROM users u JOIN user_roles ur ON ur.user_id = u.user_id
JOIN roles r ON r.role_id = ur.role_id WHERE r.role_name = 'ADMIN'
UNION
SELECT u.username FROM users u JOIN user_roles ur ON ur.user_id = u.user_id
JOIN roles r ON r.role_id = ur.role_id WHERE r.role_name = 'SECURITY_OFFICER';

-- Q12. MINUS: permissions the ADMIN role has but GUEST does not
SELECT p.perm_name FROM role_permissions rp
JOIN roles r ON r.role_id = rp.role_id
JOIN permissions p ON p.perm_id = rp.perm_id
WHERE r.role_name = 'ADMIN'
MINUS
SELECT p.perm_name FROM role_permissions rp
JOIN roles r ON r.role_id = rp.role_id
JOIN permissions p ON p.perm_id = rp.perm_id
WHERE r.role_name = 'GUEST';

-- Q13. Function call: does each user hold DELETE_USER? (user-defined function)
SELECT username, fn_has_permission(user_id, 'DELETE_USER') AS can_delete_users
FROM users ORDER BY username;

-- Q14. Function call: login success rate per user (user-defined function)
SELECT username, fn_success_rate(user_id) AS success_pct
FROM users ORDER BY success_pct DESC;

-- Q15. SQL built-in functions: formatted timestamps and NVL
SELECT UPPER(u.username) AS user_name,
       NVL(TO_CHAR(l.login_time, 'DD-MON-YYYY HH24:MI'), 'Never') AS login_at,
       NVL(l.failure_reason, 'None') AS reason
FROM users u
LEFT JOIN login_history l ON l.user_id = u.user_id AND l.login_status = 'FAILED';

-- Q16. Aggregation over audit trail
SELECT event_type, COUNT(*) AS event_count
FROM audit_trail
GROUP BY event_type
ORDER BY event_count DESC;

-- Q17. Top-N: 3 users with the most failed attempts
SELECT username, failed_attempts FROM users
ORDER BY failed_attempts DESC
FETCH FIRST 3 ROWS ONLY;

-- Q18. Sessions still marked active
SELECT s.session_token, u.username, s.expiry_time
FROM sessions s JOIN users u ON u.user_id = s.user_id
WHERE s.is_active = 'Y';

-- =====================================================================
-- DML demonstration + TCL
-- =====================================================================

-- INSERT: a new login attempt (fires trg_login_failure)
INSERT INTO login_history (user_id, ip_address, login_status, failure_reason)
VALUES ((SELECT user_id FROM users WHERE username = 'bob'), '10.0.0.8', 'FAILED', 'Wrong password');

-- UPDATE: change a user's full name
UPDATE users SET full_name = 'Robert Mehta' WHERE username = 'bob';

-- DELETE: remove inactive sessions older than 30 days
DELETE FROM sessions WHERE is_active = 'N' AND start_time < SYSDATE - 30;

-- TCL: savepoint, rollback to savepoint, then commit
SAVEPOINT before_unlock;
UPDATE users SET account_status = 'ACTIVE', failed_attempts = 0 WHERE username = 'eve';
ROLLBACK TO before_unlock;   -- eve stays LOCKED
COMMIT;

-- Run the cursor procedure and the procedures/functions
SET SERVEROUTPUT ON
EXEC sp_expire_sessions;
EXEC sp_register_user('newuser', 'newuser@example.com', 'hash_new', 'New User', 'ANALYST');
EXEC sp_set_account_status(
  (SELECT user_id FROM users WHERE username = 'eve'), 'ACTIVE');
SELECT fn_has_permission((SELECT user_id FROM users WHERE username = 'eve'), 'VIEW_USERS') FROM dual;
