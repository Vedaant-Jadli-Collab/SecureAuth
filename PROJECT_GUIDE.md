# SecureAuth: Secure Authentication & User Management

**Course:** BACSE202 Database Systems
**Team:** [Member 1 name and reg. no.], [Member 2 name and reg. no.]

## Idea

A database that tracks who the users are, what they are allowed to do, and what they have done. It locks accounts after 5 failed logins, records every status change automatically, and closes expired sessions.

## What We Built

- **Database:** 8 tables (6 strong entities and 2 junction tables for many-to-many links)
- **Business logic (PL/SQL):** 2 procedures, 2 functions, 1 cursor, 2 triggers
- **Queries:** 18 reporting queries plus insert, update, delete and transaction examples
- **Web console:** 9 pages built with Python and Streamlit

## Tools

Oracle Database 21c XE (in Docker), SQL*Plus, Python, Streamlit, python-oracledb, pandas.

## Data

All data is sample data we created. Names and emails are invented (using example.com), IP addresses are made up, and roles and permissions were designed by us.

## Similar Systems

- **Okta, Auth0, Microsoft Entra ID, Keycloak:** real identity and sign-in platforms
- **Oracle APEX, Adminer, pgAdmin:** database admin tools

Those products also handle sign-in pages, multi-factor authentication and single sign-on. SecureAuth focuses only on the database design and rules.

## Limitations

- No sign-in page; the console doesn't check who is using it
- Sample data only
- Schema is 3NF except for two transitive dependencies, explained in the report

## Team Contributions

| Member | Work done |
|---|---|
| | |
| | |
