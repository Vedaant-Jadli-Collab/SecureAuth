"""
app.py | SecureAuth Console
A Streamlit front end for the Oracle database built for BACSE202 Database Systems.

Run:
  export ORA_USER=system ORA_PASS=yourpassword ORA_DSN=localhost:1521/XEPDB1
  streamlit run app.py
"""
import hashlib
import os
import re
import secrets

import oracledb
import pandas as pd
import streamlit as st

st.set_page_config(page_title="SecureAuth Console", page_icon="🔐", layout="wide",
                   initial_sidebar_state="expanded")

CSS = """
<style>
  @import url('https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;600;700&family=Inter:wght@400;500;600&display=swap');

  .stApp { font-family: 'Inter', system-ui, sans-serif; }
  h1, h2, h3 { font-family: 'Space Grotesk', sans-serif; letter-spacing: -0.02em; }
  .block-container { padding-top: 1.5rem; padding-bottom: 3rem; max-width: 1200px; }

  /* Hide the Deploy button, the main menu and the decorative top bar */
  [data-testid="stAppDeployButton"], [data-testid="stMainMenu"], [data-testid="stToolbarActions"],
  #MainMenu, footer, [data-testid="stDecoration"] { display: none !important; }
  /* Keep the button that reopens a collapsed sidebar */
  div[data-testid="collapsedControl"] { display: block !important; visibility: visible !important; }

  /* ---------- Sidebar ---------- */
  section[data-testid="stSidebar"] {
      background: linear-gradient(180deg, #120a2e 0%, #0a0c1a 100%);
      border-right: 1px solid rgba(167, 139, 250, 0.18);
  }
  section[data-testid="stSidebar"] .brand {
      font-family: 'Space Grotesk', sans-serif; font-size: 1.6rem; font-weight: 700;
      background: linear-gradient(90deg, #c4b5fd, #f9a8d4, #bef264);
      -webkit-background-clip: text; background-clip: text; color: transparent;
  }
  section[data-testid="stSidebar"] .brand-sub { color: #8f88b8; font-size: 0.82rem; margin-bottom: 1rem; }
  section[data-testid="stSidebar"] div[role="radiogroup"] > label {
      padding: 9px 12px; border-radius: 12px; margin: 3px 0; transition: background 0.15s ease;
  }
  section[data-testid="stSidebar"] div[role="radiogroup"] > label:hover {
      background: rgba(167, 139, 250, 0.10);
  }
  section[data-testid="stSidebar"] div[role="radiogroup"] > label:has(input:checked) {
      background: linear-gradient(90deg, rgba(124, 58, 237, 0.45), rgba(219, 39, 119, 0.18));
      box-shadow: inset 3px 0 0 #f472b6;
  }
  section[data-testid="stSidebar"] div[role="radiogroup"] input:checked + div {
      background-color: #f472b6 !important; border-color: #f472b6 !important;
  }
  .status-dot {
      display: inline-block; width: 9px; height: 9px; border-radius: 50%;
      background: #bef264; box-shadow: 0 0 10px #bef264; margin-right: 7px;
  }
  .status-bad { background: #fb7185; box-shadow: 0 0 10px #fb7185; }

  /* ---------- Page banner ---------- */
  .banner {
      background: linear-gradient(120deg, #5b21b6 0%, #a21caf 55%, #db2777 100%);
      border-radius: 22px; padding: 30px 34px; margin-bottom: 1.4rem;
      box-shadow: 0 16px 40px rgba(124, 58, 237, 0.30);
  }
  .banner h1 {
      color: #ffffff; font-size: 2.1rem; font-weight: 700; margin: 0;
      font-family: 'Space Grotesk', sans-serif;
  }
  .banner p { color: rgba(255, 255, 255, 0.88); margin: 6px 0 0 0; font-size: 1.02rem; }
  .intro { color: #cfc8ea; font-size: 1.02rem; line-height: 1.6; }

  /* ---------- Metric cards ---------- */
  div[data-testid="stMetric"] {
      background: #17132b; border: 1px solid rgba(167, 139, 250, 0.22);
      border-radius: 18px; padding: 18px 20px; box-shadow: 0 10px 30px rgba(0, 0, 0, 0.25);
  }
  div[data-testid="stMetricLabel"] p {
      color: #a9a3c9 !important; font-size: 0.82rem; text-transform: uppercase; letter-spacing: 0.06em;
  }
  div[data-testid="stMetricValue"] {
      font-family: 'Space Grotesk', sans-serif; font-size: 2.2rem; font-weight: 700;
      background: linear-gradient(90deg, #c4b5fd, #f9a8d4);
      -webkit-background-clip: text; background-clip: text; color: transparent !important;
  }

  /* ---------- Buttons ---------- */
  div.stButton > button {
      border-radius: 14px; border: 1px solid rgba(167, 139, 250, 0.35);
      background: #17132b; color: #ede9fe; font-weight: 600; padding: 0.65rem 1rem;
      transition: all 0.18s ease;
  }
  div.stButton > button:hover {
      border-color: #f472b6; color: #ffffff; transform: translateY(-2px);
      background: linear-gradient(90deg, #7c3aed, #db2777);
      box-shadow: 0 10px 24px rgba(219, 39, 119, 0.35);
  }
  button[kind="primary"] {
      background: linear-gradient(90deg, #7c3aed, #db2777) !important;
      border: none !important; color: #ffffff !important;
  }
  button[kind="primary"]:hover { filter: brightness(1.08); }

  /* ---------- Tables, tabs, notes ---------- */
  div[data-testid="stDataFrame"] {
      border-radius: 16px; border: 1px solid rgba(167, 139, 250, 0.2); overflow: hidden;
  }
  .stTabs [data-baseweb="tab-highlight"] { background: linear-gradient(90deg, #a78bfa, #f472b6) !important; }
  .section-note { color: #a9a3c9; font-size: 0.9rem; margin-top: -4px; }
</style>
"""
st.markdown(CSS, unsafe_allow_html=True)

ACCOUNT_STATUSES = ["ACTIVE", "INACTIVE", "LOCKED", "SUSPENDED"]


# ---------------------------------------------------------------- database helpers
@st.cache_resource
def get_connection():
    return oracledb.connect(
        user=os.getenv("ORA_USER", "system"),
        password=os.getenv("ORA_PASS", ""),
        dsn=os.getenv("ORA_DSN", "localhost:1521/XEPDB1"),
    )


def conn():
    """Return a live connection, reconnecting if the old one was dropped."""
    try:
        c = get_connection()
        c.ping()
        return c
    except oracledb.Error:
        get_connection.clear()
        return get_connection()


def query(sql, params=None):
    with conn().cursor() as cur:
        cur.execute(sql, params or {})
        cols = [d[0].lower() for d in cur.description]
        return pd.DataFrame(cur.fetchall(), columns=cols)


def run(sql, params=None):
    c = conn()
    with c.cursor() as cur:
        cur.execute(sql, params or {})
    c.commit()


def call_procedure(name, args):
    c = conn()
    with c.cursor() as cur:
        cur.callproc(name, args)
    c.commit()


def call_function(name, return_type, args):
    with conn().cursor() as cur:
        return cur.callfunc(name, return_type, args)


def friendly(err):
    """Turn an Oracle error into a short message for the user."""
    first_line = str(err).split("\n")[0]
    return re.sub(r"^ORA-\d+:\s*", "", first_line)


def user_choices():
    df = query("SELECT user_id, username FROM users ORDER BY username")
    return dict(zip(df["username"], df["user_id"]))


def hash_password(password):
    """PBKDF2-SHA256 with a random salt. Stored as 'salt$hash' (fits VARCHAR2(255))."""
    salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 200_000).hex()
    return f"{salt}${digest}"


def page_header(title, subtitle):
    st.markdown(f'<div class="banner"><h1>{title}</h1><p>{subtitle}</p></div>',
                unsafe_allow_html=True)


def go_to(page_name):
    """Switch pages from a button. Runs before the page redraws."""
    st.session_state["nav"] = page_name


# ---------------------------------------------------------------- pages
def page_home():
    page_header("Welcome to SecureAuth", "Keep your users, roles and access locked in")
    st.markdown('<p class="intro">Create accounts, assign roles, control access, record login '
                'attempts, expire sessions and review the audit trail. Use the menu on the left, '
                'or the quick actions below.</p>', unsafe_allow_html=True)

    s = query("""
        SELECT (SELECT COUNT(*) FROM users)                                 AS users_total,
               (SELECT COUNT(*) FROM users WHERE account_status='ACTIVE')   AS users_active,
               (SELECT COUNT(*) FROM users WHERE account_status='LOCKED')   AS users_locked,
               (SELECT COUNT(*) FROM roles)                                 AS roles_total,
               (SELECT COUNT(*) FROM permissions)                           AS perms_total,
               (SELECT COUNT(*) FROM sessions WHERE is_active='Y')          AS sessions_live,
               (SELECT COUNT(*) FROM login_history WHERE login_status='FAILED') AS failed_logins,
               (SELECT COUNT(*) FROM audit_trail)                           AS audit_events
        FROM dual
    """).iloc[0]

    c1, c2, c3, c4 = st.columns(4)
    c1.metric("Users", int(s["users_total"]), f'{int(s["users_active"])} active')
    c2.metric("Locked accounts", int(s["users_locked"]))
    c3.metric("Live sessions", int(s["sessions_live"]))
    c4.metric("Failed logins", int(s["failed_logins"]))

    c5, c6, c7 = st.columns(3)
    c5.metric("Roles", int(s["roles_total"]))
    c6.metric("Permissions", int(s["perms_total"]))
    c7.metric("Audit events", int(s["audit_events"]))

    st.markdown("### Quick actions")
    a, b, c, d = st.columns(4)
    a.button("Manage users", on_click=go_to, args=("Users",), use_container_width=True)
    b.button("Register a user", on_click=go_to, args=("Register user",), use_container_width=True)
    c.button("Check login activity", on_click=go_to, args=("Login activity",), use_container_width=True)
    d.button("View audit log", on_click=go_to, args=("Audit log",), use_container_width=True)

    st.markdown("### Recent login attempts")
    recent = query("""
        SELECT u.username, l.login_time, l.ip_address, l.login_status, l.failure_reason
        FROM login_history l JOIN users u ON u.user_id = l.user_id
        ORDER BY l.login_time DESC FETCH FIRST 8 ROWS ONLY
    """)
    st.dataframe(recent, use_container_width=True, hide_index=True)


def page_users():
    page_header("Users", "Search, filter and manage every account")

    col_search, col_status = st.columns([2, 3])
    search = col_search.text_input("Search by username, name or email", placeholder="e.g. alice")
    statuses = col_status.multiselect("Account status", ACCOUNT_STATUSES, default=ACCOUNT_STATUSES)

    users = query("""
        SELECT u.user_id, u.username, u.full_name, u.email, u.account_status,
               u.failed_attempts, u.created_date,
               NVL(LISTAGG(r.role_name, ', ') WITHIN GROUP (ORDER BY r.role_name), '-') AS roles
        FROM users u
        LEFT JOIN user_roles ur ON ur.user_id = u.user_id
        LEFT JOIN roles r       ON r.role_id  = ur.role_id
        GROUP BY u.user_id, u.username, u.full_name, u.email, u.account_status,
                 u.failed_attempts, u.created_date
        ORDER BY u.username
    """)

    total = len(users)
    if search:
        mask = (users["username"].str.contains(search, case=False)
                | users["full_name"].str.contains(search, case=False)
                | users["email"].str.contains(search, case=False))
        users = users[mask]
    users = users[users["account_status"].isin(statuses)]

    st.caption(f"Showing {len(users)} of {total} users")
    st.dataframe(users, use_container_width=True, hide_index=True)

    if users.empty:
        return

    st.markdown("### Change account status")
    st.markdown('<p class="section-note">Changing the status runs the sp_set_account_status '
                'procedure. The audit trigger records the change automatically.</p>',
                unsafe_allow_html=True)
    choices = user_choices()
    c1, c2, c3 = st.columns([2, 2, 1])
    target = c1.selectbox("User", list(choices.keys()), key="status_user")
    new_status = c2.selectbox("New status", ACCOUNT_STATUSES, key="status_value")
    c3.write("")
    c3.write("")
    if c3.button("Update status", type="primary", use_container_width=True):
        try:
            call_procedure("sp_set_account_status", [choices[target], new_status])
            st.success(f"{target} is now {new_status}.")
        except oracledb.Error as e:
            st.error(friendly(e))

    with st.expander("Delete a user (cannot be undone)"):
        st.markdown('<p class="section-note">Deleting a user also removes their login history, '
                    'sessions and role assignments (ON DELETE CASCADE).</p>', unsafe_allow_html=True)
        del_target = st.selectbox("User to delete", list(choices.keys()), key="delete_user")
        confirmed = st.checkbox(f"I understand that {del_target} will be permanently deleted")
        if st.button("Delete user", disabled=not confirmed):
            try:
                run("DELETE FROM users WHERE user_id = :id", {"id": choices[del_target]})
                st.success(f"{del_target} was deleted.")
            except oracledb.Error as e:
                st.error(friendly(e))


def page_register():
    page_header("Register user", "Create a new account and assign a role")

    with st.form("register_form", clear_on_submit=False):
        c1, c2 = st.columns(2)
        username = c1.text_input("Username", help="3 to 30 letters, numbers or underscores")
        full_name = c2.text_input("Full name")
        email = c1.text_input("Email")
        role = c2.selectbox("Role", query("SELECT role_name FROM roles ORDER BY role_name")["role_name"])
        password = c1.text_input("Password", type="password", help="At least 8 characters")
        confirm = c2.text_input("Confirm password", type="password")
        submitted = st.form_submit_button("Create account", type="primary")

    if not submitted:
        return

    problems = []
    if not re.fullmatch(r"[A-Za-z0-9_]{3,30}", username or ""):
        problems.append("Username must be 3 to 30 letters, numbers or underscores.")
    if not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email or ""):
        problems.append("Enter a valid email address.")
    if not full_name.strip():
        problems.append("Full name is required.")
    if len(password or "") < 8:
        problems.append("Password must be at least 8 characters.")
    if password != confirm:
        problems.append("Passwords do not match.")

    if problems:
        for p in problems:
            st.error(p)
        return

    try:
        call_procedure("sp_register_user",
                       [username, email, hash_password(password), full_name.strip(), role])
        st.success(f"Account '{username}' created with the {role} role.")
    except oracledb.Error as e:
        st.error(friendly(e))


def page_roles():
    page_header("Roles & permissions", "See who can do what, and check access for any user")

    tab_matrix, tab_check = st.tabs(["Permission matrix", "Check access"])

    with tab_matrix:
        pairs = query("""
            SELECT r.role_name, p.perm_name
            FROM role_permissions rp
            JOIN roles r       ON r.role_id = rp.role_id
            JOIN permissions p ON p.perm_id = rp.perm_id
        """)
        if pairs.empty:
            st.info("No permissions have been assigned to roles yet.")
        else:
            pairs["granted"] = "✔"
            matrix = pairs.pivot(index="perm_name", columns="role_name", values="granted").fillna("")
            st.dataframe(matrix, use_container_width=True)
            st.caption("✔ means the role has that permission.")

    with tab_check:
        st.markdown('<p class="section-note">Uses the fn_has_permission database function.</p>',
                    unsafe_allow_html=True)
        choices = user_choices()
        perms = query("SELECT perm_name FROM permissions ORDER BY perm_name")["perm_name"].tolist()
        c1, c2 = st.columns(2)
        user = c1.selectbox("User", list(choices.keys()), key="access_user")
        perm = c2.selectbox("Permission", perms, key="access_perm")

        if st.button("Check access", type="primary"):
            allowed = call_function("fn_has_permission", str, [choices[user], perm]) == "Y"
            if allowed:
                st.success(f"{user} HAS the {perm} permission.")
            else:
                st.error(f"{user} does NOT have the {perm} permission.")

        held = query("""
            SELECT DISTINCT p.perm_name
            FROM user_roles ur
            JOIN role_permissions rp ON rp.role_id = ur.role_id
            JOIN permissions p       ON p.perm_id  = rp.perm_id
            WHERE ur.user_id = :uid ORDER BY p.perm_name
        """, {"uid": choices[user]})
        st.markdown(f"**All permissions for {user}:**")
        if held.empty:
            st.write("None. This user has no roles.")
        else:
            st.write(", ".join(held["perm_name"].tolist()))


def page_login_activity():
    page_header("Login activity", "Review login attempts and record new ones")

    result_filter = st.radio("Show", ["All", "SUCCESS", "FAILED"], horizontal=True)
    where = "" if result_filter == "All" else "WHERE l.login_status = :st"
    params = {} if result_filter == "All" else {"st": result_filter}
    logins = query(f"""
        SELECT l.login_id, u.username, l.login_time, l.ip_address, l.login_status, l.failure_reason
        FROM login_history l JOIN users u ON u.user_id = l.user_id
        {where}
        ORDER BY l.login_time DESC FETCH FIRST 100 ROWS ONLY
    """, params)
    st.dataframe(logins, use_container_width=True, hide_index=True)

    st.markdown("### Record a login attempt")
    st.markdown('<p class="section-note">Failed attempts count towards the automatic lock: '
                'the fifth failure locks the account.</p>', unsafe_allow_html=True)
    choices = user_choices()
    with st.form("login_form"):
        c1, c2, c3 = st.columns(3)
        user = c1.selectbox("User", list(choices.keys()))
        ip = c2.text_input("IP address", "127.0.0.1")
        outcome = c3.radio("Result", ["SUCCESS", "FAILED"], horizontal=True)
        if st.form_submit_button("Record attempt", type="primary"):
            try:
                run("""INSERT INTO login_history (user_id, ip_address, login_status, failure_reason)
                       VALUES (:uid, :ip, :st, :why)""",
                    {"uid": choices[user], "ip": ip or None, "st": outcome,
                     "why": None if outcome == "SUCCESS" else "Wrong password"})
                st.success(f"{outcome} attempt recorded for {user}.")
            except oracledb.Error as e:
                st.error(friendly(e))


def page_sessions():
    page_header("Sessions", "Active sessions and automatic expiry")

    live = int(query("SELECT COUNT(*) AS n FROM sessions WHERE is_active = 'Y'")["n"].iloc[0])
    st.metric("Active sessions", live)

    st.markdown('<p class="section-note">Sessions past their expiry time are closed by the '
                'sp_expire_sessions cursor procedure.</p>', unsafe_allow_html=True)
    if st.button("Expire old sessions", type="primary"):
        call_procedure("sp_expire_sessions", [])
        after = int(query("SELECT COUNT(*) AS n FROM sessions WHERE is_active = 'Y'")["n"].iloc[0])
        st.success(f"Closed {live - after} expired session(s).")

    show_all = st.toggle("Include closed sessions", value=False)
    where = "" if show_all else "WHERE s.is_active = 'Y'"
    sessions = query(f"""
        SELECT u.username, s.start_time, s.expiry_time, s.is_active, s.session_token
        FROM sessions s JOIN users u ON u.user_id = s.user_id
        {where}
        ORDER BY s.start_time DESC
    """)
    st.dataframe(sessions, use_container_width=True, hide_index=True)


def page_audit():
    page_header("Audit log", "Every status change and system event, recorded automatically")

    types = query("SELECT DISTINCT event_type FROM audit_trail ORDER BY event_type")["event_type"].tolist()
    chosen = st.multiselect("Filter by event type", types)
    where = ("WHERE a.event_type IN (" + ", ".join(f":t{i}" for i in range(len(chosen))) + ")"
             if chosen else "")
    params = {f"t{i}": t for i, t in enumerate(chosen)}
    audit = query(f"""
        SELECT a.audit_id, a.event_time, NVL(u.username, '-') AS username, a.event_type,
               a.target_table, a.old_value, a.new_value
        FROM audit_trail a LEFT JOIN users u ON u.user_id = a.user_id
        {where}
        ORDER BY a.event_time DESC FETCH FIRST 200 ROWS ONLY
    """, params)
    st.caption(f"{len(audit)} event(s) shown (latest 200)")
    st.dataframe(audit, use_container_width=True, hide_index=True)


def page_reports():
    page_header("Reports", "Summary figures calculated in the database")

    left, right = st.columns(2)

    with left:
        st.markdown("### Login success rate by user")
        st.markdown('<p class="section-note">Calculated by the fn_success_rate function.</p>',
                    unsafe_allow_html=True)
        rates = query("SELECT username, fn_success_rate(user_id) AS success_pct FROM users "
                      "ORDER BY success_pct DESC")
        st.dataframe(rates, use_container_width=True, hide_index=True)

    with right:
        st.markdown("### Users per role")
        per_role = query("""
            SELECT r.role_name, COUNT(ur.user_id) AS users_assigned
            FROM roles r LEFT JOIN user_roles ur ON ur.role_id = r.role_id
            GROUP BY r.role_name ORDER BY users_assigned DESC, r.role_name
        """)
        st.dataframe(per_role, use_container_width=True, hide_index=True)

    st.markdown("### Permissions per role")
    st.dataframe(query("""
        SELECT r.role_name, COUNT(rp.perm_id) AS permissions
        FROM roles r LEFT JOIN role_permissions rp ON rp.role_id = r.role_id
        GROUP BY r.role_name ORDER BY permissions DESC, r.role_name
    """), use_container_width=True, hide_index=True)


PAGES = {
    "Home": page_home,
    "Users": page_users,
    "Register user": page_register,
    "Roles & permissions": page_roles,
    "Login activity": page_login_activity,
    "Sessions": page_sessions,
    "Audit log": page_audit,
    "Reports": page_reports,
}


def database_online():
    try:
        conn().ping()
        return True
    except oracledb.Error:
        return False


# ---------------------------------------------------------------- layout
st.session_state.setdefault("nav", "Home")

with st.sidebar:
    st.markdown('<div class="brand">SecureAuth</div>'
                '<div class="brand-sub">User &amp; access management</div>', unsafe_allow_html=True)
    choice = st.radio("Navigate", list(PAGES), key="nav", label_visibility="collapsed")
    st.divider()
    online = database_online()
    dot = "status-dot" if online else "status-dot status-bad"
    label = "Connected to Oracle" if online else "Database offline"
    st.markdown(f'<span class="{dot}"></span>{label}', unsafe_allow_html=True)
    st.caption(os.getenv("ORA_DSN", "localhost:1521/XEPDB1"))

try:
    PAGES[choice]()
except oracledb.Error as e:
    st.error(f"Database error: {friendly(e)}")
    st.info("Check that the Oracle container is running and the connection settings are correct.")
