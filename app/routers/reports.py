"""MED (Ministério da Educação) statistical reports.

Produces the standard Angola school census (Levantamento Escolar) data:
  - Quadro I:  Alunos matriculados por turma e sexo
  - Quadro II: Alunos por faixa etária e sexo
  - Quadro III: Pessoal docente por categoria e sexo
  - Quadro IV: Pessoal não-docente por categoria e sexo

GET /reports/med?school_year_id=<uuid>
"""
import uuid
from datetime import date, datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_school_id, require_school_admin
from app.models.academic import Enrollment, SchoolYear, Turma
from app.models.employee import Employee
from app.models.person import Child
from app.models.school import School

router = APIRouter(prefix="/reports", tags=["Reports"])


# ─── Response schemas ─────────────────────────────────────────────────────────

class TurmaRow(BaseModel):
    turma_id: str
    turma_name: str
    level: Optional[str] = None
    total: int
    male: int
    female: int
    unknown: int


class AgeGroupRow(BaseModel):
    group: str
    total: int
    male: int
    female: int


class StaffRow(BaseModel):
    category: str  # "Docente", "Não-docente", "Administrativo"
    total: int
    male: int
    female: int


class MedReportSummary(BaseModel):
    total_enrolled: int
    enrolled_male: int
    enrolled_female: int
    total_turmas: int
    total_teaching_staff: int
    teaching_staff_male: int
    teaching_staff_female: int
    total_non_teaching_staff: int


class MedReport(BaseModel):
    school_name: str
    school_nif: Optional[str]
    school_address: Optional[str]
    school_year: Optional[str]
    generated_at: str
    summary: MedReportSummary
    by_turma: list[TurmaRow]
    by_age_group: list[AgeGroupRow]
    by_staff_category: list[StaffRow]


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _age_group(birth_date: Optional[date]) -> str:
    if birth_date is None:
        return "Desconhecida"
    today = date.today()
    age = today.year - birth_date.year - (
        (today.month, today.day) < (birth_date.month, birth_date.day)
    )
    if age <= 2:
        return "0-2 anos"
    if age <= 3:
        return "3 anos"
    if age <= 4:
        return "4 anos"
    if age == 5:
        return "5 anos"
    if age == 6:
        return "6 anos (Iniciação)"
    return "7+ anos"

_AGE_GROUP_ORDER = ["0-2 anos", "3 anos", "4 anos", "5 anos", "6 anos (Iniciação)", "7+ anos", "Desconhecida"]


# ─── Endpoint ────────────────────────────────────────────────────────────────

@router.get("/med", response_model=MedReport)
async def get_med_report(
    school_year_id: Optional[uuid.UUID] = None,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    _=Depends(require_school_admin),
):
    """Generate a MED-compatible school statistical report."""

    # School info
    school_r = await db.execute(select(School).where(School.id == school_id))
    school = school_r.scalar_one_or_none()
    if school is None:
        raise HTTPException(status_code=404, detail="School not found")

    # Resolve school year label
    year_label: Optional[str] = None
    if school_year_id:
        sy_r = await db.execute(
            select(SchoolYear).where(
                SchoolYear.id == school_year_id,
                SchoolYear.school_id == school_id,
            )
        )
        sy = sy_r.scalar_one_or_none()
        if sy:
            year_label = sy.year_label
    else:
        # Use the active school year
        sy_r = await db.execute(
            select(SchoolYear).where(
                SchoolYear.school_id == school_id,
                SchoolYear.is_active == True,
            )
        )
        sy = sy_r.scalar_one_or_none()
        if sy:
            year_label = sy.year_label
            school_year_id = sy.id

    # ── Enrollments ──────────────────────────────────────────────────────────
    enroll_q = (
        select(Enrollment, Child, Turma)
        .join(Child, Child.id == Enrollment.child_id)
        .join(
            Turma,
            Turma.id == select(Turma.id)
            .select_from(Turma)
            .where(Turma.school_id == school_id)
            .correlate(Enrollment)
            .scalar_subquery(),
            isouter=True,
        )
        .where(
            Enrollment.school_id == school_id,
            Enrollment.status.in_(["active", "pending"]),
        )
    )
    if school_year_id:
        enroll_q = enroll_q.where(Enrollment.school_year_id == school_year_id)

    # Simpler join — go through schedule to turma
    from app.models.academic import Schedule
    enroll_q = (
        select(Enrollment, Child, Turma)
        .join(Child, Child.id == Enrollment.child_id)
        .join(Schedule, Schedule.id == Enrollment.schedule_id)
        .join(Turma, Turma.id == Schedule.turma_id)
        .where(
            Enrollment.school_id == school_id,
            Enrollment.status.in_(["active", "pending"]),
        )
    )
    if school_year_id:
        enroll_q = enroll_q.where(Enrollment.school_year_id == school_year_id)

    enroll_r = await db.execute(enroll_q)
    rows = enroll_r.all()

    # Build turma map and age groups
    turma_map: dict[str, dict] = {}  # turma_id -> counts
    age_group_map: dict[str, dict] = {}

    for enrollment, child, turma in rows:
        tid = str(turma.id)
        if tid not in turma_map:
            turma_map[tid] = {
                "turma_id": tid,
                "turma_name": turma.name,
                "level": getattr(turma, "level", None),
                "total": 0, "male": 0, "female": 0, "unknown": 0,
            }
        turma_map[tid]["total"] += 1
        sex = (child.sex or "").upper()
        if sex == "M":
            turma_map[tid]["male"] += 1
        elif sex == "F":
            turma_map[tid]["female"] += 1
        else:
            turma_map[tid]["unknown"] += 1

        # Age group
        grp = _age_group(child.birth_date)
        if grp not in age_group_map:
            age_group_map[grp] = {"group": grp, "total": 0, "male": 0, "female": 0}
        age_group_map[grp]["total"] += 1
        if sex == "M":
            age_group_map[grp]["male"] += 1
        elif sex == "F":
            age_group_map[grp]["female"] += 1

    by_turma = [TurmaRow(**v) for v in turma_map.values()]
    by_turma.sort(key=lambda r: r.turma_name)

    ordered_ages = sorted(
        age_group_map.values(),
        key=lambda x: _AGE_GROUP_ORDER.index(x["group"])
        if x["group"] in _AGE_GROUP_ORDER else 99,
    )
    by_age_group = [AgeGroupRow(**v) for v in ordered_ages]

    total_enrolled = sum(t.total for t in by_turma)
    enrolled_male = sum(t.male for t in by_turma)
    enrolled_female = sum(t.female for t in by_turma)

    # ── Staff ─────────────────────────────────────────────────────────────────
    staff_r = await db.execute(
        select(Employee.employee_type, Employee.sex)
        .where(
            Employee.school_id == school_id,
            Employee.status == "active",
        )
    )
    staff_rows = staff_r.all()

    staff_map: dict[str, dict] = {}
    for emp_type, sex in staff_rows:
        # Map to human labels
        if emp_type == "teacher":
            cat = "Docente"
        elif emp_type == "admin":
            cat = "Administrativo"
        else:
            cat = "Não-docente"
        if cat not in staff_map:
            staff_map[cat] = {"category": cat, "total": 0, "male": 0, "female": 0}
        staff_map[cat]["total"] += 1
        if (sex or "").upper() == "M":
            staff_map[cat]["male"] += 1
        elif (sex or "").upper() == "F":
            staff_map[cat]["female"] += 1

    by_staff = [StaffRow(**v) for v in staff_map.values()]
    by_staff.sort(key=lambda r: r.category)

    teaching = next((s for s in by_staff if s.category == "Docente"), None)

    summary = MedReportSummary(
        total_enrolled=total_enrolled,
        enrolled_male=enrolled_male,
        enrolled_female=enrolled_female,
        total_turmas=len(turma_map),
        total_teaching_staff=teaching.total if teaching else 0,
        teaching_staff_male=teaching.male if teaching else 0,
        teaching_staff_female=teaching.female if teaching else 0,
        total_non_teaching_staff=sum(
            s.total for s in by_staff if s.category != "Docente"
        ),
    )

    return MedReport(
        school_name=school.name,
        school_nif=school.nif,
        school_address=school.address,
        school_year=year_label,
        generated_at=datetime.now().strftime("%d/%m/%Y %H:%M"),
        summary=summary,
        by_turma=by_turma,
        by_age_group=by_age_group,
        by_staff_category=by_staff,
    )
