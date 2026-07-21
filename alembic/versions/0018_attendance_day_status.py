"""Add attendance_day_statuses table (GAP-01)

Revision ID: 0018
Revises: 0017

Adds:
- attendance_day_statuses table for daily status (present/absent/excused/late)
  without requiring a check-in/check-out log entry.
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0018"
down_revision = "0017"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "attendance_day_statuses",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("school_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("schools.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("child_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("children.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("status_date", sa.Date, nullable=False),
        sa.Column("status", sa.String(20), nullable=False),
        sa.Column("notes", sa.Text, nullable=True),
        sa.Column("recorded_by", postgresql.UUID(as_uuid=True), sa.ForeignKey("employees.id", ondelete="RESTRICT"), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.UniqueConstraint("school_id", "child_id", "status_date", name="uq_day_status_school_child_date"),
    )
    op.create_index("ix_attendance_day_statuses_school_id", "attendance_day_statuses", ["school_id"])
    op.create_index("ix_attendance_day_statuses_child_id", "attendance_day_statuses", ["child_id"])
    op.create_index("ix_attendance_day_statuses_status_date", "attendance_day_statuses", ["status_date"])


def downgrade() -> None:
    op.drop_index("ix_attendance_day_statuses_status_date", table_name="attendance_day_statuses")
    op.drop_index("ix_attendance_day_statuses_child_id", table_name="attendance_day_statuses")
    op.drop_index("ix_attendance_day_statuses_school_id", table_name="attendance_day_statuses")
    op.drop_table("attendance_day_statuses")
