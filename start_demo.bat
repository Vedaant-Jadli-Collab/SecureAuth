@echo off
REM start_demo.bat | Starts the Oracle container and the SecureAuth console (Windows)
REM Before the first run: docker run -d --name oracle-xe -p 1522:1521 -e ORACLE_PASSWORD=YourPassword gvenzl/oracle-xe:21-slim

echo Starting Oracle container...
docker start oracle-xe
echo Wait until "DATABASE IS READY TO USE" appears in: docker logs oracle-xe
pause

cd /d "%~dp0"
if not exist .venv (
  python -m venv .venv
  call .venv\Scripts\activate.bat
  pip install -r requirements.txt
) else (
  call .venv\Scripts\activate.bat
)

set ORA_USER=system
set ORA_PASS=YourPassword
set ORA_DSN=localhost:1522/XEPDB1

streamlit run app.py
pause
