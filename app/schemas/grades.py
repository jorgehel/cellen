import uuid
from datetime import datetime
from decimal import Decimal
from typing import Optional

from pydantic import BaseModel, ConfigDict, field_validator


# ─── Subject ─────────────────────────────────────────────────────────────────

class SubjectCreate(BaseModel):
    name: str
    code: Optional[str] = None
    order: int = 0


class SubjectUpdate(BaseModel):
    name: Optional[str] = None
    code: Optional[str] = None
    order: Optional[int] = None
    is_active: Optional[bool] = None


class SubjectResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    school_id: uuid.UUID
    name: str
    code: Optional[str]
    order: int
    is_active: bool
    created_at: datetime
    updated_at: datetime


# ─── TurmaSubject ─────────────────────────────────────────────────────────────

class TurmaSubjectCreate(BaseModel):
    turma_id: uuid.UUID
    subject_id: uuid.UUID
    school_year_id: uuid.UUID
    teacher_id: Optional[uuid.UUID] = None


class TurmaSubjectUpdate(BaseModel):
    teacher_id: Optional[uuid.UUID] = None
    is_locked: Optional[bool] = None


class TurmaSubjectResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    turma_id: uuid.UUID
    subject_id: uuid.UUID
    school_year_id: uuid.UUID
    teacher_id: Optional[uuid.UUID]
    is_locked: bool

    # denormalized for convenience
    subject_name: Optional[str] = None
    subject_code: Optional[str] = None
    teacher_name: Optional[str] = None


# ─── Mark ─────────────────────────────────────────────────────────────────────

class MarkUpsert(BaseModel):
    enrollment_id: uuid.UUID
    subject_id: uuid.UUID
    trimester: int
    mac_grade: Optional[Decimal] = None
    exam_grade: Optional[Decimal] = None
    final_grade: Optional[Decimal] = None   # if None, computed automatically
    notes: Optional[str] = None

    @field_validator("trimester")
    @classmethod
    def check_trimester(cls, v: int) -> int:
        if v not in (1, 2, 3):
            raise ValueError("trimester must be 1, 2 or 3")
        return v


class MarkBulkUpsert(BaseModel):
    marks: list[MarkUpsert]


class MarkResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    enrollment_id: uuid.UUID
    subject_id: uuid.UUID
    trimester: int
    mac_grade: Optional[Decimal]
    exam_grade: Optional[Decimal]
    final_grade: Optional[Decimal]
    notes: Optional[str]
    updated_at: datetime


# ─── Report card aggregated views ────────────────────────────────────────────

class ReportCardSubjectRow(BaseModel):
    subject_id: str
    subject_name: str
    subject_code: Optional[str]
    t1_mac: Optional[Decimal] = None
    t1_exam: Optional[Decimal] = None
    t1_final: Optional[Decimal] = None
    t2_mac: Optional[Decimal] = None
    t2_exam: Optional[Decimal] = None
    t2_final: Optional[Decimal] = None
    t3_mac: Optional[Decimal] = None
    t3_exam: Optional[Decimal] = None
    t3_final: Optional[Decimal] = None
    annual_average: Optional[Decimal] = None
    passed: Optional[bool] = None   # True if annual_average >= 10


class ReportCard(BaseModel):
    enrollment_id: str
    child_name: str
    turma_name: str
    school_year: str
    subjects: list[ReportCardSubjectRow]
    overall_average: Optional[Decimal] = None
    promoted: Optional[bool] = None   # True if all subjects passed


class ClassMarkRow(BaseModel):
    """One row in the class marks table (teacher grade-entry view)."""
    enrollment_id: str
    child_name: str
    mac_grade: Optional[Decimal] = None
    exam_grade: Optional[Decimal] = None
    final_grade: Optional[Decimal] = None
    notes: Optional[str] = None
    mark_id: Optional[str] = None
