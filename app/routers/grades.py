"""K-12 grades and marks router.

Endpoints:
  Subjects (admin)
    GET    /grades/subjects
    POST   /grades/subjects
    PATCH  /grades/subjects/{subject_id}

  TurmaSubjects — subject-teacher-turma assignments (admin)
    GET    /grades/turma-subjects
    POST   /grades/turma-subjects
    PATCH  /grades/turma-subjects/{ts_id}
    DELETE /grades/turma-subjects/{ts_id}

  Marks (teacher / admin)
    GET    /grades/marks          ?turma_id=&subject_id=&trimester=&school_year_id=
    POST   /grades/marks/bulk     upsert many marks at once
    GET    /grades/report-card    ?enrollment_id=   full boletim for one student
    GET    /grades/class-report   ?turma_id=&school_year_id=  all students all subjects
    GET    /grades/my-report-card                  parent: own child's boletim
"""
import uuid
from decimal import Decimal, ROUND_HALF_UP
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user, get_school_id, require_school_admin
from app.models.academic import Enrollment, Schedule, SchoolYear, Turma
from app.models.employee import Employee
from app.models.grades import Mark, Subject, TurmaSubject
from app.models.person import Child
from app.models.user import User
from app.schemas.grades import (
    ClassMarkRow,
    MarkBulkUpsert,
    MarkResponse,
    ReportCard,
    ReportCardSubjectRow,
    SubjectCreate,
    SubjectResponse,
    SubjectUpdate,
    TurmaSubjectCreate,
    TurmaSubjectResponse,
    TurmaSubjectUpdate,
)

router = APIRouter(prefix="/grades", tags=["Grades"])


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _compute_final(mac: Optional[Decimal], exam: Optional[Decimal]) -> Optional[Decimal]:
    """Angola formula: MAC×60% + PE×40%, rounded to 1 decimal."""
    if mac is not None and exam is not None:
        raw = mac * Decimal("0.6") + exam * Decimal("0.4")
        return raw.quantize(Decimal("0.1"), rounding=ROUND_HALF_UP)
    if mac is not None:
        return mac
    if exam is not None:
        return exam
    return None


def _annual_avg(finals: list[Optional[Decimal]]) -> Optional[Decimal]:
    values = [f for f in finals if f is not None]
    if not values:
        return None
    return (sum(values, Decimal("0")) / Decimal(len(values))).quantize(
        Decimal("0.1"), rounding=ROUND_HALF_UP
    )


# ─── Subjects ─────────────────────────────────────────────────────────────────

@router.get("/subjects", response_model=list[SubjectResponse])
async def list_subjects(
    include_inactive: bool = False,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    _=Depends(get_current_user),
):
    q = select(Subject).where(Subject.school_id == school_id)
    if not include_inactive:
        q = q.where(Subject.is_active.is_(True))
    q = q.order_by(Subject.order, Subject.name)
    result = await db.execute(q)
    return result.scalars().all()


@router.post("/subjects", response_model=SubjectResponse, status_code=status.HTTP_201_CREATED)
async def create_subject(
    body: SubjectCreate,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    _=Depends(require_school_admin),
):
    subj = Subject(school_id=school_id, **body.model_dump())
    db.add(subj)
    await db.commit()
    await db.refresh(subj)
    return subj


@router.patch("/subjects/{subject_id}", response_model=SubjectResponse)
async def update_subject(
    subject_id: uuid.UUID,
    body: SubjectUpdate,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    _=Depends(require_school_admin),
):
    result = await db.execute(
        select(Subject).where(Subject.id == subject_id, Subject.school_id == school_id)
    )
    subj = result.scalar_one_or_none()
    if subj is None:
        raise HTTPException(status_code=404, detail="Subject not found")
    for k, v in body.model_dump(exclude_unset=True).items():
        setattr(subj, k, v)
    await db.commit()
    await db.refresh(subj)
    return subj


# ─── TurmaSubjects ────────────────────────────────────────────────────────────

@router.get("/turma-subjects", response_model=list[TurmaSubjectResponse])
async def list_turma_subjects(
    turma_id: Optional[uuid.UUID] = None,
    school_year_id: Optional[uuid.UUID] = None,
    teacher_id: Optional[uuid.UUID] = None,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    _=Depends(get_current_user),
):
    q = select(TurmaSubject, Subject, Employee).join(
        Subject, Subject.id == TurmaSubject.subject_id
    ).outerjoin(
        Employee, Employee.id == TurmaSubject.teacher_id
    ).where(TurmaSubject.school_id == school_id)

    if turma_id:
        q = q.where(TurmaSubject.turma_id == turma_id)
    if school_year_id:
        q = q.where(TurmaSubject.school_year_id == school_year_id)
    if teacher_id:
        q = q.where(TurmaSubject.teacher_id == teacher_id)

    q = q.order_by(Subject.order, Subject.name)
    rows = (await db.execute(q)).all()

    out = []
    for ts, subj, emp in rows:
        teacher_name = None
        if emp:
            teacher_name = f"{emp.first_name} {emp.last_name}"
        out.append(TurmaSubjectResponse(
            id=ts.id,
            turma_id=ts.turma_id,
            subject_id=ts.subject_id,
            school_year_id=ts.school_year_id,
            teacher_id=ts.teacher_id,
            is_locked=ts.is_locked,
            subject_name=subj.name,
            subject_code=subj.code,
            teacher_name=teacher_name,
        ))
    return out


@router.post("/turma-subjects", response_model=TurmaSubjectResponse, status_code=status.HTTP_201_CREATED)
async def create_turma_subject(
    body: TurmaSubjectCreate,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    _=Depends(require_school_admin),
):
    ts = TurmaSubject(school_id=school_id, **body.model_dump())
    db.add(ts)
    try:
        await db.commit()
        await db.refresh(ts)
    except Exception:
        await db.rollback()
        raise HTTPException(status_code=400, detail="Assignment already exists for this turma/subject/year")

    # Denormalize
    subj = (await db.execute(select(Subject).where(Subject.id == ts.subject_id))).scalar_one_or_none()
    emp = None
    if ts.teacher_id:
        emp = (await db.execute(select(Employee).where(Employee.id == ts.teacher_id))).scalar_one_or_none()

    return TurmaSubjectResponse(
        id=ts.id,
        turma_id=ts.turma_id,
        subject_id=ts.subject_id,
        school_year_id=ts.school_year_id,
        teacher_id=ts.teacher_id,
        is_locked=ts.is_locked,
        subject_name=subj.name if subj else None,
        subject_code=subj.code if subj else None,
        teacher_name=f"{emp.first_name} {emp.last_name}" if emp else None,
    )


@router.patch("/turma-subjects/{ts_id}", response_model=TurmaSubjectResponse)
async def update_turma_subject(
    ts_id: uuid.UUID,
    body: TurmaSubjectUpdate,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    _=Depends(require_school_admin),
):
    result = await db.execute(
        select(TurmaSubject).where(TurmaSubject.id == ts_id, TurmaSubject.school_id == school_id)
    )
    ts = result.scalar_one_or_none()
    if ts is None:
        raise HTTPException(status_code=404, detail="Assignment not found")
    for k, v in body.model_dump(exclude_unset=True).items():
        setattr(ts, k, v)
    await db.commit()
    await db.refresh(ts)

    subj = (await db.execute(select(Subject).where(Subject.id == ts.subject_id))).scalar_one_or_none()
    emp = None
    if ts.teacher_id:
        emp = (await db.execute(select(Employee).where(Employee.id == ts.teacher_id))).scalar_one_or_none()
    return TurmaSubjectResponse(
        id=ts.id,
        turma_id=ts.turma_id,
        subject_id=ts.subject_id,
        school_year_id=ts.school_year_id,
        teacher_id=ts.teacher_id,
        is_locked=ts.is_locked,
        subject_name=subj.name if subj else None,
        subject_code=subj.code if subj else None,
        teacher_name=f"{emp.first_name} {emp.last_name}" if emp else None,
    )


@router.delete("/turma-subjects/{ts_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_turma_subject(
    ts_id: uuid.UUID,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    _=Depends(require_school_admin),
):
    await db.execute(
        delete(TurmaSubject).where(TurmaSubject.id == ts_id, TurmaSubject.school_id == school_id)
    )
    await db.commit()


# ─── Marks ────────────────────────────────────────────────────────────────────

@router.get("/marks", response_model=list[ClassMarkRow])
async def list_marks(
    turma_id: uuid.UUID,
    subject_id: uuid.UUID,
    trimester: int,
    school_year_id: Optional[uuid.UUID] = None,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    _=Depends(get_current_user),
):
    """Return all marks for one class session (turma × subject × trimester)."""
    if trimester not in (1, 2, 3):
        raise HTTPException(status_code=422, detail="trimester must be 1, 2 or 3")

    # Get enrollments for this turma/year
    enroll_q = (
        select(Enrollment, Child)
        .join(Child, Child.id == Enrollment.child_id)
        .join(Schedule, Schedule.id == Enrollment.schedule_id)
        .where(
            Enrollment.school_id == school_id,
            Schedule.turma_id == turma_id,
            Enrollment.status.in_(["active", "pending"]),
        )
    )
    if school_year_id:
        enroll_q = enroll_q.where(Enrollment.school_year_id == school_year_id)

    enroll_rows = (await db.execute(enroll_q)).all()

    # Existing marks indexed by enrollment_id
    enrollment_ids = [e.id for e, _ in enroll_rows]
    marks_map: dict[uuid.UUID, Mark] = {}
    if enrollment_ids:
        marks_result = await db.execute(
            select(Mark).where(
                Mark.subject_id == subject_id,
                Mark.trimester == trimester,
                Mark.enrollment_id.in_(enrollment_ids),
            )
        )
        for m in marks_result.scalars().all():
            marks_map[m.enrollment_id] = m

    out = []
    for enrollment, child in sorted(enroll_rows, key=lambda r: (r[1].last_name or "", r[1].first_name or "")):
        mark = marks_map.get(enrollment.id)
        out.append(ClassMarkRow(
            enrollment_id=str(enrollment.id),
            child_name=f"{child.first_name} {child.last_name}",
            mac_grade=mark.mac_grade if mark else None,
            exam_grade=mark.exam_grade if mark else None,
            final_grade=mark.final_grade if mark else None,
            notes=mark.notes if mark else None,
            mark_id=str(mark.id) if mark else None,
        ))
    return out


@router.post("/marks/bulk", response_model=list[MarkResponse])
async def bulk_upsert_marks(
    body: MarkBulkUpsert,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Upsert multiple marks at once (teacher grade entry)."""
    # Resolve teacher employee id
    recorder_id: Optional[uuid.UUID] = None
    if current_user.employee_id:
        recorder_id = current_user.employee_id

    saved: list[Mark] = []
    for m in body.marks:
        # Verify enrollment belongs to this school
        enroll = (await db.execute(
            select(Enrollment).where(
                Enrollment.id == m.enrollment_id,
                Enrollment.school_id == school_id,
            )
        )).scalar_one_or_none()
        if enroll is None:
            continue   # skip invalid

        # Compute final if not overridden
        final = m.final_grade if m.final_grade is not None else _compute_final(m.mac_grade, m.exam_grade)

        # Try to find existing mark
        existing = (await db.execute(
            select(Mark).where(
                Mark.enrollment_id == m.enrollment_id,
                Mark.subject_id == m.subject_id,
                Mark.trimester == m.trimester,
            )
        )).scalar_one_or_none()

        if existing:
            existing.mac_grade = m.mac_grade
            existing.exam_grade = m.exam_grade
            existing.final_grade = final
            existing.notes = m.notes
            if recorder_id:
                existing.recorded_by = recorder_id
            saved.append(existing)
        else:
            new_mark = Mark(
                school_id=school_id,
                enrollment_id=m.enrollment_id,
                subject_id=m.subject_id,
                trimester=m.trimester,
                mac_grade=m.mac_grade,
                exam_grade=m.exam_grade,
                final_grade=final,
                notes=m.notes,
                recorded_by=recorder_id,
            )
            db.add(new_mark)
            saved.append(new_mark)

    await db.commit()
    for mark in saved:
        await db.refresh(mark)
    return saved


# ─── Report card ─────────────────────────────────────────────────────────────

async def _build_report_card(db: AsyncSession, enrollment: Enrollment, school_id: uuid.UUID) -> ReportCard:
    """Build a full boletim for one enrollment."""
    child = (await db.execute(select(Child).where(Child.id == enrollment.child_id))).scalar_one()
    # turma via schedule
    schedule = (await db.execute(select(Schedule).where(Schedule.id == enrollment.schedule_id))).scalar_one()
    turma = (await db.execute(select(Turma).where(Turma.id == schedule.turma_id))).scalar_one()
    school_year = (await db.execute(select(SchoolYear).where(SchoolYear.id == enrollment.school_year_id))).scalar_one()

    # All active subjects for this school
    subjects = (await db.execute(
        select(Subject).where(Subject.school_id == school_id, Subject.is_active.is_(True))
        .order_by(Subject.order, Subject.name)
    )).scalars().all()

    # All marks for this enrollment
    marks = (await db.execute(
        select(Mark).where(Mark.enrollment_id == enrollment.id)
    )).scalars().all()

    # Index marks: subject_id → trimester → Mark
    marks_index: dict[uuid.UUID, dict[int, Mark]] = {}
    for m in marks:
        marks_index.setdefault(m.subject_id, {})[m.trimester] = m

    rows: list[ReportCardSubjectRow] = []
    for subj in subjects:
        sm = marks_index.get(subj.id, {})
        t1 = sm.get(1)
        t2 = sm.get(2)
        t3 = sm.get(3)
        t1_final = t1.final_grade if t1 else None
        t2_final = t2.final_grade if t2 else None
        t3_final = t3.final_grade if t3 else None
        avg = _annual_avg([t1_final, t2_final, t3_final])
        rows.append(ReportCardSubjectRow(
            subject_id=str(subj.id),
            subject_name=subj.name,
            subject_code=subj.code,
            t1_mac=t1.mac_grade if t1 else None,
            t1_exam=t1.exam_grade if t1 else None,
            t1_final=t1_final,
            t2_mac=t2.mac_grade if t2 else None,
            t2_exam=t2.exam_grade if t2 else None,
            t2_final=t2_final,
            t3_mac=t3.mac_grade if t3 else None,
            t3_exam=t3.exam_grade if t3 else None,
            t3_final=t3_final,
            annual_average=avg,
            passed=bool(avg is not None and avg >= 10),
        ))

    # Only include subjects that have at least one grade
    rows_with_data = [r for r in rows if any(
        v is not None for v in [r.t1_final, r.t2_final, r.t3_final]
    )]
    if not rows_with_data:
        rows_with_data = rows  # show all if no data yet

    avgs = [r.annual_average for r in rows_with_data if r.annual_average is not None]
    overall = _annual_avg(avgs) if avgs else None
    promoted = all(r.passed for r in rows_with_data if r.annual_average is not None) if avgs else None

    return ReportCard(
        enrollment_id=str(enrollment.id),
        child_name=f"{child.first_name} {child.last_name}",
        turma_name=turma.name,
        school_year=school_year.year_label,
        subjects=rows_with_data,
        overall_average=overall,
        promoted=promoted,
    )


@router.get("/report-card", response_model=ReportCard)
async def get_report_card(
    enrollment_id: uuid.UUID,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    _=Depends(get_current_user),
):
    enrollment = (await db.execute(
        select(Enrollment).where(
            Enrollment.id == enrollment_id,
            Enrollment.school_id == school_id,
        )
    )).scalar_one_or_none()
    if enrollment is None:
        raise HTTPException(status_code=404, detail="Enrollment not found")
    return await _build_report_card(db, enrollment, school_id)


@router.get("/my-report-card", response_model=ReportCard)
async def get_my_report_card(
    school_year_id: Optional[uuid.UUID] = None,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Parent: fetch their child's report card (assumes one active enrollment)."""
    if not current_user.guardian_id:
        raise HTTPException(status_code=403, detail="Only guardians can access this endpoint")

    from app.models.person import ChildGuardian
    # Find children of this guardian
    cg_rows = (await db.execute(
        select(ChildGuardian).where(
            ChildGuardian.guardian_id == current_user.guardian_id,
            ChildGuardian.school_id == school_id,
        )
    )).scalars().all()
    if not cg_rows:
        raise HTTPException(status_code=404, detail="No children found")

    child_ids = [cg.child_id for cg in cg_rows]

    enroll_q = select(Enrollment).where(
        Enrollment.child_id.in_(child_ids),
        Enrollment.school_id == school_id,
        Enrollment.status.in_(["active", "pending"]),
    )
    if school_year_id:
        enroll_q = enroll_q.where(Enrollment.school_year_id == school_year_id)

    enrollment = (await db.execute(enroll_q)).scalars().first()
    if enrollment is None:
        raise HTTPException(status_code=404, detail="No active enrollment found")
    return await _build_report_card(db, enrollment, school_id)


@router.get("/class-report")
async def get_class_report(
    turma_id: uuid.UUID,
    school_year_id: Optional[uuid.UUID] = None,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    _=Depends(get_current_user),
):
    """Return report cards for all students in a turma."""
    enroll_q = (
        select(Enrollment)
        .join(Schedule, Schedule.id == Enrollment.schedule_id)
        .where(
            Enrollment.school_id == school_id,
            Schedule.turma_id == turma_id,
            Enrollment.status.in_(["active", "pending"]),
        )
    )
    if school_year_id:
        enroll_q = enroll_q.where(Enrollment.school_year_id == school_year_id)

    enrollments = (await db.execute(enroll_q)).scalars().all()
    return [await _build_report_card(db, e, school_id) for e in enrollments]
