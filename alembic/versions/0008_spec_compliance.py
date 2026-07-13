"""Spec compliance: attendance logs, schedule temporal validity, absence fields

Revision ID: 0008
Revises: 0007
Create Date: 2026-07-13 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects.postgresql import UUID

revision: str = "0008"
down_revision: Union[str, None] = "0007"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── attendance_logs: new table for log-based check-in/out events ─────────
    op.create_table(
        "attendance_logs",
        sa.Column("id", UUID(as_uuid=True), primary_key=True),
        sa.Column("school_id", UUID(as_uuid=True), sa.ForeignKey("schools.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("child_id", UUID(as_uuid=True), sa.ForeignKey("children.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("recorded_by", UUID(as_uuid=True), sa.ForeignKey("employees.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("attendance_date", sa.Date(), nullable=False),
        sa.Column("event_type", sa.String(20), nullable=False),
        sa.Column("event_time", sa.Time(), nullable=False),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_attendance_logs_school_id", "attendance_logs", ["school_id"])
    op.create_index("ix_attendance_logs_child_date", "attendance_logs", ["school_id", "child_id", "attendance_date"])

    # ── schedules: add temporal validity columns ──────────────────────────────
    op.add_column("schedules", sa.Column("effective_from", sa.Date(), nullable=True))
    op.add_column("schedules", sa.Column("effective_to", sa.Date(), nullable=True))

    # Drop unique constraint that prevented multiple schedules per turma+year
    op.drop_constraint("uq_schedule_turma_year", "schedules", type_="unique")

    # ── schedule_slots: make activity_id nullable ─────────────────────────────
    op.alter_column("schedule_slots", "activity_id", nullable=True)

    # ── absences: add absence_type and notes; make responsible_id nullable ────
    op.add_column("absences", sa.Column("absence_type", sa.String(50), nullable=True))
    op.add_column("absences", sa.Column("notes", sa.Text(), nullable=True))
    op.alter_column("absences", "responsible_id", nullable=True)


def downgrade() -> None:
    op.alter_column("absences", "responsible_id", nullable=False)
    op.drop_column("absences", "notes")
    op.drop_column("absences", "absence_type")

    op.alter_column("schedule_slots", "activity_id", nullable=False)

    op.create_unique_constraint(
        "uq_schedule_turma_year", "schedules", ["school_id", "turma_id", "school_year_id"]
    )
    op.drop_column("schedules", "effective_to")
    op.drop_column("schedules", "effective_from")

    op.drop_index("ix_attendance_logs_child_date", "attendance_logs")
    op.drop_index("ix_attendance_logs_school_id", "attendance_logs")
    op.drop_table("attendance_logs")
