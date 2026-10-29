# SecureAuth: Secure Authentication & User Management (BACSE202)

A database project that stores users, roles, permissions, logins, sessions and audit events in Oracle, with PL/SQL rules (account locking, status auditing, session expiry) and a Streamlit web console.

## Files

| File | What it does |
|---|---|
| 01_schema.sql | Creates 8 tables with primary keys, foreign keys, UNIQUE, NOT NULL, CHECK and DEFAULT constraints |
| 02_data.sql | Sample data (invented users, roles, permissions, logins, sessions and audit entries) |
| 03_plsql.sql | 2 procedures, 2 functions, 1 cursor procedure, 2 triggers |
| 04_queries.sql | 18 SELECT queries, INSERT/UPDATE/DELETE examples, SAVEPOINT/ROLLBACK/COMMIT |
| app.py | Streamlit web console (Home, Users, Register user, Roles and permissions, Login activity, Sessions, Audit log, Reports) |
| requirements.txt | Python packages: oracledb, streamlit, pandas |
| start_demo.bat | Windows script that starts Docker, activates the environment and runs the console |
| ER_Diagram_and_Report_Notes.html | ER diagram, notation key, normalisation table and report notes |
| PROJECT_GUIDE.md | One-page summary of the project |

## 1. Start the database (Oracle in Docker)

```
docker run -d --name oracle-xe -p 1522:1521 -e ORACLE_PASSWORD=YourPassword gvenzl/oracle-xe:21-slim
```

Wait until the logs show `DATABASE IS READY TO USE`:

```
docker logs -f oracle-xe
```

The host port is 1522 because port 1521 may already be in use on Windows.

## 2. Create and load the tables

Copy the SQL files into the container, then run them in order:

```
docker cp 01_schema.sql oracle-xe:/tmp/
docker exec -i oracle-xe sqlplus -s system/YourPassword@localhost:1521/XEPDB1 @/tmp/01_schema.sql
```

Repeat for `02_data.sql`, `03_plsql.sql` and `04_queries.sql` (run `04_queries.sql` only once, and set `SET SERVEROUTPUT ON` first if you want to see output from the PL/SQL blocks).

## 3. Run the web console

Windows PowerShell:

```
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
$env:ORA_USER="system"
$env:ORA_PASS="YourPassword"
$env:ORA_DSN="localhost:1522/XEPDB1"
streamlit run app.py
```

Then open http://localhost:8501 in a browser.

The password is read from an environment variable, not from the code. Do not put real passwords in any file that is shared.

## Notes

- All data is sample data. Names and emails use the reserved `example.com` domain.
- The console has no sign-in page. It is a demonstration of the database rules.
