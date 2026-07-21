"""Grades and marks models for K-12 academic assessment.

Angola system:
  - Scale: 0–20
  - 3 trimestres per year
  - MAC (Média de Avaliação Contínua) — continuous assessment, weight 60%
  - PE  (Prova Escrita) — written exam, weight 40%
  - Final trimestre grade = MAC×0.6 + PE×0.4  (rounded to 1 decimal)
  - Annual average = (T1 + T2 + T3) / 3
  - Passing: ≥ 10
"""
import uuid
from datetime import datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy import (
    Boolean, DateTime, ForeignKey, Index, Integer, Numeric, String,
    UniqueConstraint, func, CheckConstraint,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class Subject(Base):
    """Disciplina — e.g. Matemática, Língua Portuguesa, Ciências da Natureza."""
    __tablename__ = "subjects"
    __table_args__ = (
        UniqueConstraint("school_id", "name", name="uq_subjects_school_name"),
        Index("ix_subjects_school_id", "school_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    school_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("schools.id", ondelete="RESTRICT"), nullable=False
    )
    name: Mapped[str] = mapped_column(String(150), nullable=False)
    code: Mapped[Optional[str]] = mapped_column(String(20))   # e.g. MAT, LP, CN
    order: Mapped[int] = mapped_column(Integer, default=0)    # display order
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class TurmaSubject(Base):
    """Links a subject to a turma for a given school year, optionally assigning a teacher."""
    __tablename__ = "turma_subjects"
    __table_args__ = (
        UniqueConstraint(
            "school_id", "turma_id", "subject_id", "school_year_id",
            name="uq_turma_subject_year",
        ),
        Index("ix_turma_subjects_school_id", "school_id"),
        Index("ix_turma_subjects_turma_year", "turma_id", "school_year_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    school_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("schools.id", ondelete="RESTRICT"), nullable=False
    )
    turma_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("turmas.id", ondelete="RESTRICT"), nullable=False
    )
    subject_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("subjects.id", ondelete="RESTRICT"), nullable=False
    )
    school_year_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("school_years.id", ondelete="RESTRICT"), nullable=False
    )
    teacher_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("employees.id", ondelete="SET NULL"), nullable=True
    )
    is_locked: Mapped[bool] = mapped_column(Boolean, default=False)  # freeze grade entry

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Mark(Base):
    """Nota — grade for one student in one subject in one trimestre.

    final_grade computation (stored for performance/override):
      - Both mac and exam present  → mac×0.6 + exam×0.4  (rounded 1dp)
      - Only mac                   → mac
      - Only exam                  → exam
      - Teacher may override by setting final_grade directly.
    """
    __tablename__ = "marks"
    __table_args__ = (
        UniqueConstraint(
            "enrollment_id", "subject_id", "trimester",
            name="uq_mark_enrollment_subject_trimester",
        ),
        CheckConstraint("trimester IN (1, 2, 3)", name="ck_marks_trimester"),
        CheckConstraint("mac_grade  IS NULL OR (mac_grade  >= 0 AND mac_grade  <= 20)", name="ck_marks_mac"),
        CheckConstraint("exam_grade IS NULL OR (exam_grade >= 0 AND exam_grade <= 20)", name="ck_marks_exam"),
        CheckConstraint("final_grade IS NULL OR (final_grade >= 0 AND final_grade <= 20)", name="ck_marks_final"),
        Index("ix_marks_school_id", "school_id"),
        Index("ix_marks_enrollment_id", "enrollment_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    school_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("schools.id", ondelete="RESTRICT"), nullable=False
    )
    enrollment_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("enrollments.id", ondelete="RESTRICT"), nullable=False
    )
    subject_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("subjects.id", ondelete="RESTRICT"), nullable=False
    )
    trimester: Mapped[int] = mapped_column(Integer, nullable=False)   # 1 | 2 | 3

    mac_grade: Mapped[Optional[Decimal]] = mapped_column(Numeric(4, 1))   # Avaliação Contínua
    exam_grade: Mapped[Optional[Decimal]] = mapped_column(Numeric(4, 1))  # Prova Escrita
    final_grade: Mapped[Optional[Decimal]] = mapped_column(Numeric(4, 1)) # computed or overridden
    notes: Mapped[Optional[str]] = mapped_column(String(500))

    recorded_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("employees.id", ondelete="SET NULL"), nullable=True
    )

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
