"""
Tests for miscellaneous endpoints:
  /announcements, /events, /notifications, /incidents,
  /health-events, /appointments, /messages/threads
"""
from datetime import date

from httpx import AsyncClient

from tests.conftest import auth, login, uid


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

async def _school_with_teacher(client: AsyncClient, make_school, prefix: str = "misc"):
    """Create school + teacher employee. Returns (admin_token, teacher_token, slug, child_id)."""
    school, admin_token, slug, _ = await make_school(prefix)

    teacher_username = f"teacher-{uid()}"
    emp_r = await client.post(
        "/employees",
        json={
            "first_name": "Misc",
            "last_name": "Teacher",
            "employee_type": "teacher",
            "username": teacher_username,
            "password": "Teacher1!",
        },
        headers=auth(admin_token),
    )
    assert emp_r.status_code == 201, emp_r.text

    teacher_token = await login(client, teacher_username, "Teacher1!", slug)

    child_r = await client.post(
        "/children",
        json={"cedula": f"C{uid()}", "first_name": "Misc", "last_name": "Child"},
        headers=auth(admin_token),
    )
    assert child_r.status_code == 201, child_r.text
    child_id = child_r.json()["id"]

    return admin_token, teacher_token, slug, child_id


async def _school_with_parent(client: AsyncClient, make_school, prefix: str = "miscp"):
    """Create school + guardian (parent role). Returns (admin_token, parent_token, slug, employee_id)."""
    school, admin_token, slug, _ = await make_school(prefix)

    # Create an employee so appointments have a valid employee_id
    emp_r = await client.post(
        "/employees",
        json={
            "first_name": "Appt",
            "last_name": "Employee",
            "employee_type": "teacher",
            "username": f"teacher-{uid()}",
            "password": "Teacher1!",
        },
        headers=auth(admin_token),
    )
    assert emp_r.status_code == 201, emp_r.text
    employee_id = emp_r.json()["id"]

    parent_username = f"parent-{uid()}"
    grd_r = await client.post(
        "/guardians",
        json={
            "first_name": "Parent",
            "last_name": "User",
            "username": parent_username,
            "password": "Parent1!",
        },
        headers=auth(admin_token),
    )
    assert grd_r.status_code == 201, grd_r.text

    parent_token = await login(client, parent_username, "Parent1!", slug)

    return admin_token, parent_token, slug, employee_id


# ---------------------------------------------------------------------------
# Announcements
# ---------------------------------------------------------------------------

async def test_create_announcement(client: AsyncClient, make_school):
    admin_token, teacher_token, slug, _ = await _school_with_teacher(client, make_school, "ann")
    r = await client.post(
        "/announcements",
        json={"title": "Test Announcement", "body": "Content here", "target": "all"},
        headers=auth(teacher_token),
    )
    assert r.status_code == 201
    assert "id" in r.json()


async def test_list_announcements(client: AsyncClient, make_school):
    admin_token, teacher_token, slug, _ = await _school_with_teacher(client, make_school, "annl")
    await client.post(
        "/announcements",
        json={"title": "List Ann", "body": "Body text", "target": "all"},
        headers=auth(teacher_token),
    )
    r = await client.get("/announcements", headers=auth(teacher_token))
    assert r.status_code == 200
    assert isinstance(r.json(), list)


async def test_announcement_school_isolation(client: AsyncClient, make_school):
    admin_a, teacher_a, slug_a, _ = await _school_with_teacher(client, make_school, "annia")
    admin_b, teacher_b, slug_b, _ = await _school_with_teacher(client, make_school, "annib")

    cr = await client.post(
        "/announcements",
        json={"title": "School A Only", "body": "Secret", "target": "all"},
        headers=auth(teacher_a),
    )
    assert cr.status_code == 201
    ann_id = cr.json()["id"]

    r = await client.get("/announcements", headers=auth(teacher_b))
    assert r.status_code == 200
    ids_b = [a["id"] for a in r.json()]
    assert ann_id not in ids_b


# ---------------------------------------------------------------------------
# Events
# ---------------------------------------------------------------------------

async def test_create_event(client: AsyncClient, make_school):
    admin_token, teacher_token, slug, _ = await _school_with_teacher(client, make_school, "evt")
    r = await client.post(
        "/events/",
        json={"title": "School Party", "start_date": "2025-12-20", "end_date": "2025-12-20"},
        headers=auth(teacher_token),
    )
    assert r.status_code == 201
    assert "id" in r.json()


async def test_list_events(client: AsyncClient, make_school):
    admin_token, teacher_token, slug, _ = await _school_with_teacher(client, make_school, "evtl")
    await client.post(
        "/events/",
        json={"title": "Open Day", "start_date": "2025-11-01", "end_date": "2025-11-01"},
        headers=auth(teacher_token),
    )
    r = await client.get("/events", headers=auth(teacher_token))
    assert r.status_code == 200
    assert isinstance(r.json(), list)


# ---------------------------------------------------------------------------
# Notifications
# ---------------------------------------------------------------------------

async def test_get_notifications(client: AsyncClient, make_school):
    admin_token, teacher_token, slug, _ = await _school_with_teacher(client, make_school, "notif")
    r = await client.get("/notifications", headers=auth(teacher_token))
    assert r.status_code == 200
    assert isinstance(r.json(), list)


async def test_unread_count(client: AsyncClient, make_school):
    admin_token, teacher_token, slug, _ = await _school_with_teacher(client, make_school, "notuc")
    r = await client.get("/notifications/unread-count", headers=auth(teacher_token))
    assert r.status_code == 200
    data = r.json()
    assert "count" in data
    assert isinstance(data["count"], int)


async def test_read_all_notifications(client: AsyncClient, make_school):
    admin_token, teacher_token, slug, _ = await _school_with_teacher(client, make_school, "notra")
    r = await client.put("/notifications/read-all", headers=auth(teacher_token))
    assert r.status_code == 200


# ---------------------------------------------------------------------------
# Incidents
# ---------------------------------------------------------------------------

async def test_create_incident(client: AsyncClient, make_school):
    admin_token, teacher_token, slug, child_id = await _school_with_teacher(
        client, make_school, "inc"
    )
    r = await client.post(
        "/incidents/",
        json={
            "child_id": child_id,
            "description": "Minor fall",
            "incident_date": date.today().isoformat(),
        },
        headers=auth(teacher_token),
    )
    assert r.status_code == 201
    assert "id" in r.json()


async def test_list_incidents(client: AsyncClient, make_school):
    admin_token, teacher_token, slug, child_id = await _school_with_teacher(
        client, make_school, "incl"
    )
    await client.post(
        "/incidents/",
        json={
            "child_id": child_id,
            "description": "Scraped knee",
            "incident_date": date.today().isoformat(),
        },
        headers=auth(teacher_token),
    )
    r = await client.get("/incidents", headers=auth(teacher_token))
    assert r.status_code == 200
    assert isinstance(r.json(), list)


# ---------------------------------------------------------------------------
# Health Events
# ---------------------------------------------------------------------------

async def test_create_health_event(client: AsyncClient, make_school):
    admin_token, teacher_token, slug, child_id = await _school_with_teacher(
        client, make_school, "he"
    )
    r = await client.post(
        "/health-events",
        json={
            "child_id": child_id,
            "event_type": "fever",
            "event_date": date.today().isoformat(),
            "description": "Mild fever observed",
        },
        headers=auth(teacher_token),
    )
    assert r.status_code == 201
    assert "id" in r.json()


async def test_list_health_events(client: AsyncClient, make_school):
    admin_token, teacher_token, slug, child_id = await _school_with_teacher(
        client, make_school, "hel"
    )
    await client.post(
        "/health-events",
        json={
            "child_id": child_id,
            "event_type": "headache",
            "event_date": date.today().isoformat(),
            "description": "Complained of headache",
        },
        headers=auth(teacher_token),
    )
    r = await client.get("/health-events", headers=auth(teacher_token))
    assert r.status_code == 200
    assert isinstance(r.json(), list)


# ---------------------------------------------------------------------------
# Appointments
# ---------------------------------------------------------------------------

async def test_create_appointment(client: AsyncClient, make_school):
    admin_token, parent_token, slug, employee_id = await _school_with_parent(
        client, make_school, "appt"
    )
    r = await client.post(
        "/appointments",
        json={
            "employee_id": employee_id,
            "title": "Parent-Teacher Meeting",
            "proposed_date": "2025-12-01",
        },
        headers=auth(parent_token),
    )
    assert r.status_code == 201
    assert "id" in r.json()


async def test_list_appointments(client: AsyncClient, make_school):
    admin_token, parent_token, slug, employee_id = await _school_with_parent(
        client, make_school, "apptl"
    )
    await client.post(
        "/appointments",
        json={
            "employee_id": employee_id,
            "title": "Follow-up Meeting",
            "proposed_date": "2025-12-05",
        },
        headers=auth(parent_token),
    )
    r = await client.get("/appointments", headers=auth(parent_token))
    assert r.status_code == 200
    assert isinstance(r.json(), list)


# ---------------------------------------------------------------------------
# Appointment role-filter tests (covers the staff-role fix)
# ---------------------------------------------------------------------------

async def _setup_appointment_scenario(client: AsyncClient, make_school, prefix: str):
    """
    Creates a school with:
      - an employee (teacher) whose token is returned
      - a staff employee whose token is returned
      - a parent who creates one appointment targeting the teacher
    Returns a dict with all tokens and IDs.
    """
    school, admin_token, slug, _ = await make_school(prefix)
    hdrs = auth(admin_token)

    # Teacher
    teacher_username = f"tch-{uid()}"
    emp_r = await client.post(
        "/employees",
        json={
            "first_name": "Appt",
            "last_name": "Teacher",
            "employee_type": "teacher",
            "username": teacher_username,
            "password": "Teacher1!",
        },
        headers=hdrs,
    )
    assert emp_r.status_code == 201, emp_r.text
    teacher_employee_id = emp_r.json()["id"]
    teacher_token = await login(client, teacher_username, "Teacher1!", slug)

    # Staff employee (different person, NOT the appointment target)
    staff_username = f"stf-{uid()}"
    staff_r = await client.post(
        "/employees",
        json={
            "first_name": "Appt",
            "last_name": "Staff",
            "employee_type": "staff",
            "username": staff_username,
            "password": "Staff1234!",
        },
        headers=hdrs,
    )
    assert staff_r.status_code == 201, staff_r.text
    staff_token = await login(client, staff_username, "Staff1234!", slug)

    # Parent
    parent_username = f"par-{uid()}"
    grd_r = await client.post(
        "/guardians",
        json={
            "first_name": "Appt",
            "last_name": "Parent",
            "username": parent_username,
            "password": "Parent1!",
        },
        headers=hdrs,
    )
    assert grd_r.status_code == 201, grd_r.text
    parent_token = await login(client, parent_username, "Parent1!", slug)

    # Parent creates appointment targeting the teacher
    appt_r = await client.post(
        "/appointments",
        json={
            "employee_id": teacher_employee_id,
            "title": "Role filter test meeting",
            "proposed_date": "2025-12-10",
        },
        headers=auth(parent_token),
    )
    assert appt_r.status_code == 201, appt_r.text
    appointment_id = appt_r.json()["id"]

    return {
        "admin_token": admin_token,
        "teacher_token": teacher_token,
        "teacher_employee_id": teacher_employee_id,
        "staff_token": staff_token,
        "parent_token": parent_token,
        "appointment_id": appointment_id,
    }


async def test_admin_sees_all_appointments(client: AsyncClient, make_school):
    """School admin sees every appointment regardless of who created it."""
    ctx = await _setup_appointment_scenario(client, make_school, "arole-adm")
    r = await client.get("/appointments", headers=auth(ctx["admin_token"]))
    assert r.status_code == 200
    ids = [a["id"] for a in r.json()]
    assert ctx["appointment_id"] in ids


async def test_teacher_sees_appointments_assigned_to_them(client: AsyncClient, make_school):
    """Teacher sees appointments where they are the target employee."""
    ctx = await _setup_appointment_scenario(client, make_school, "arole-tch")
    r = await client.get("/appointments", headers=auth(ctx["teacher_token"]))
    assert r.status_code == 200
    ids = [a["id"] for a in r.json()]
    assert ctx["appointment_id"] in ids


async def test_staff_not_target_sees_empty(client: AsyncClient, make_school):
    """Staff who is NOT the target employee sees an empty list (no cross-leakage)."""
    ctx = await _setup_appointment_scenario(client, make_school, "arole-stf")
    r = await client.get("/appointments", headers=auth(ctx["staff_token"]))
    assert r.status_code == 200
    ids = [a["id"] for a in r.json()]
    # The staff member is not the target, so they should NOT see this appointment
    assert ctx["appointment_id"] not in ids


async def test_parent_sees_own_appointments_only(client: AsyncClient, make_school):
    """Parent sees only their own requested appointments."""
    ctx = await _setup_appointment_scenario(client, make_school, "arole-par")
    r = await client.get("/appointments", headers=auth(ctx["parent_token"]))
    assert r.status_code == 200
    ids = [a["id"] for a in r.json()]
    assert ctx["appointment_id"] in ids
