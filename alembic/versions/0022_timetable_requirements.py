"""Add timetable_requirements and timetable_teacher_constraints tables

Revision ID: 0022
Revises: 0021

- timetable_requirements: solver input cards (subject + teacher + periods/week per class)
- timetable_teacher_constraints: teacher unavailability (day + period blocks)
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects.postgresql import UUID

revision: str = '0022'
down_revision: str = '0021'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'timetable_requirements',
        sa.Column('id', UUID(as_uuid=True), primary_key=True),
        sa.Column('school_id', UUID(as_uuid=True),
                  sa.ForeignKey('schools.id', ondelete='RESTRICT'), nullable=False),
        sa.Column('schedule_id', UUID(as_uuid=True),
                  sa.ForeignKey('schedules.id', ondelete='CASCADE'), nullable=False),
        sa.Column('subject_id', UUID(as_uuid=True),
                  sa.ForeignKey('subjects.id', ondelete='RESTRICT'), nullable=False),
        sa.Column('employee_id', UUID(as_uuid=True),
                  sa.ForeignKey('employees.id', ondelete='RESTRICT'), nullable=False),
        sa.Column('periods_per_week', sa.Integer(), nullable=False, server_default='1'),
        sa.Column('allow_double_period', sa.Boolean(), nullable=False, server_default='false'),
        sa.Column('preferred_time_of_day', sa.String(20), nullable=True),
        sa.Column('created_at', sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column('updated_at', sa.DateTime(timezone=True),
                  server_default=sa.func.now(), onupdate=sa.func.now()),
        sa.UniqueConstraint('schedule_id', 'subject_id', 'employee_id',
                            name='uq_timetable_req_schedule_subject_employee'),
    )
    op.create_index('ix_timetable_requirements_school_id', 'timetable_requirements', ['school_id'])
    op.create_index('ix_timetable_requirements_schedule_id', 'timetable_requirements', ['schedule_id'])

    op.create_table(
        'timetable_teacher_constraints',
        sa.Column('id', sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('school_id', UUID(as_uuid=True),
                  sa.ForeignKey('schools.id', ondelete='RESTRICT'), nullable=False),
        sa.Column('employee_id', UUID(as_uuid=True),
                  sa.ForeignKey('employees.id', ondelete='CASCADE'), nullable=False),
        sa.Column('day_of_week', sa.Integer(), nullable=False),
        sa.Column('period_id', UUID(as_uuid=True),
                  sa.ForeignKey('timetable_periods.id', ondelete='CASCADE'), nullable=False),
        sa.UniqueConstraint('employee_id', 'day_of_week', 'period_id',
                            name='uq_timetable_teacher_constraint'),
    )
    op.create_index('ix_timetable_teacher_constraints_school_id',
                    'timetable_teacher_constraints', ['school_id'])


def downgrade() -> None:
    op.drop_index('ix_timetable_teacher_constraints_school_id',
                  table_name='timetable_teacher_constraints')
    op.drop_table('timetable_teacher_constraints')

    op.drop_index('ix_timetable_requirements_schedule_id', table_name='timetable_requirements')
    op.drop_index('ix_timetable_requirements_school_id', table_name='timetable_requirements')
    op.drop_table('timetable_requirements')
