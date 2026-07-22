import uuid
from datetime import time
from typing import Optional

from pydantic import BaseModel, ConfigDict


# ---------------------------------------------------------------------------
# Period templates
# ---------------------------------------------------------------------------

class PeriodCreate(BaseModel):
    period_number: int
    name: str
    start_time: time
    end_time: time
    is_break: bool = False


class PeriodUpdate(BaseModel):
    name: Optional[str] = None
    start_time: Optional[time] = None
    end_time: Optional[time] = None
    is_break: Optional[bool] = None


class PeriodResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    school_id: uuid.UUID
    period_number: int
    name: str
    start_time: time
    end_time: time
    is_break: bool


# ---------------------------------------------------------------------------
# Timetable grid cell (one slot in the week grid)
# ---------------------------------------------------------------------------

class TimetableCellUpsert(BaseModel):
    """Create or update one cell: turma × day × period → subject × teacher × room."""
    schedule_id: uuid.UUID
    day_of_week: int          # 0=Mon..4=Fri
    period_id: uuid.UUID
    subject_id: Optional[uuid.UUID] = None
    employee_id: Optional[uuid.UUID] = None
    room: Optional[str] = None


class TimetableCellResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    schedule_id: uuid.UUID
    day_of_week: int
    slot_time: time
    period_id: Optional[uuid.UUID] = None
    period_number: Optional[int] = None
    period_name: Optional[str] = None
    subject_id: Optional[uuid.UUID] = None
    subject_name: Optional[str] = None
    subject_code: Optional[str] = None
    employee_id: Optional[uuid.UUID] = None
    employee_name: Optional[str] = None
    room: Optional[str] = None


# ---------------------------------------------------------------------------
# Full week grid for one turma
# ---------------------------------------------------------------------------

class TimetableGridResponse(BaseModel):
    schedule_id: uuid.UUID
    turma_id: uuid.UUID
    turma_name: str
    school_year_id: uuid.UUID
    school_year_label: str
    periods: list[PeriodResponse]
    cells: list[TimetableCellResponse]


# ---------------------------------------------------------------------------
# Teacher's personal timetable
# ---------------------------------------------------------------------------

class TeacherSlot(BaseModel):
    day_of_week: int
    period_id: Optional[uuid.UUID] = None
    period_name: Optional[str] = None
    period_number: Optional[int] = None
    slot_time: time
    subject_name: Optional[str] = None
    turma_name: Optional[str] = None
    room: Optional[str] = None
    schedule_id: uuid.UUID


# ---------------------------------------------------------------------------
# Timetable requirements (solver input cards)
# ---------------------------------------------------------------------------

class RequirementCreate(BaseModel):
    schedule_id: uuid.UUID
    subject_id: uuid.UUID
    employee_id: uuid.UUID
    periods_per_week: int = 1
    allow_double_period: bool = False
    preferred_time_of_day: Optional[str] = None   # 'morning' | 'afternoon' | None


class RequirementUpdate(BaseModel):
    employee_id: Optional[uuid.UUID] = None
    periods_per_week: Optional[int] = None
    allow_double_period: Optional[bool] = None
    preferred_time_of_day: Optional[str] = None


class RequirementResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    schedule_id: uuid.UUID
    subject_id: uuid.UUID
    subject_name: Optional[str] = None
    subject_code: Optional[str] = None
    employee_id: uuid.UUID
    employee_name: Optional[str] = None
    periods_per_week: int
    allow_double_period: bool
    preferred_time_of_day: Optional[str] = None


# ---------------------------------------------------------------------------
# Teacher unavailability constraints
# ---------------------------------------------------------------------------

class TeacherConstraintCreate(BaseModel):
    employee_id: uuid.UUID
    day_of_week: int       # 0=Mon..4=Fri
    period_id: uuid.UUID


class TeacherConstraintResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    employee_id: uuid.UUID
    day_of_week: int
    period_id: uuid.UUID


# ---------------------------------------------------------------------------
# Solver generate / apply
# ---------------------------------------------------------------------------

class GenerateRequest(BaseModel):
    """Run the solver for one or more class schedules simultaneously."""
    schedule_ids: list[uuid.UUID]


class GeneratedCell(BaseModel):
    schedule_id: uuid.UUID
    day_of_week: int
    period_id: uuid.UUID
    subject_id: uuid.UUID
    subject_name: Optional[str] = None
    employee_id: uuid.UUID
    employee_name: Optional[str] = None


class GenerateConflict(BaseModel):
    requirement_id: uuid.UUID
    subject_name: str
    employee_name: str
    periods_requested: int
    periods_assigned: int
    reason: str


class GenerateResponse(BaseModel):
    """Preview of the proposed timetable — nothing is written to DB yet."""
    status: str   # 'optimal' | 'feasible' | 'partial' | 'infeasible'
    cells: list[GeneratedCell]
    conflicts: list[GenerateConflict]


class ApplyRequest(BaseModel):
    """Write a previously-previewed set of cells to the database."""
    schedule_ids: list[uuid.UUID]
    cells: list[GeneratedCell]
    replace_existing: bool = True   # if True, clears existing slots first
