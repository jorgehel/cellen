"""Add trip_authorizations and trip_authorization_responses tables

Revision ID: 0005
Revises: 0004
Create Date: 2026-07-12 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0005"
down_revision: Union[str, None] = "0004"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "trip_authorizations",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("school_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("created_by", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("title", sa.VARCHAR(255), nullable=False),
        sa.Column("description", sa.TEXT, nullable=True),
        sa.Column("trip_date", sa.DATE, nullable=False),
        sa.Column("destination", sa.VARCHAR(255), nullable=True),
        sa.Column("departure_time", sa.TIME, nullable=True),
        sa.Column("return_time", sa.TIME, nullable=True),
        sa.Column("deadline_date", sa.DATE, nullable=True),
        sa.Column("target_turma_id", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column(
            "created_at",
            sa.TIMESTAMP(timezone=True),
            server_default=sa.text("now()"),
            nullable=True,
        ),
        sa.ForeignKeyConstraint(["school_id"], ["schools.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["created_by"], ["employees.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["target_turma_id"], ["turmas.id"], ondelete="SET NULL"),
    )
    op.create_index("ix_trip_authorizations_school_id", "trip_authorizations", ["school_id"])

    op.create_table(
        "trip_authorization_responses",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("authorization_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("school_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("child_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("guardian_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("authorized", sa.BOOLEAN, nullable=False),
        sa.Column("notes", sa.TEXT, nullable=True),
        sa.Column(
            "responded_at",
            sa.TIMESTAMP(timezone=True),
            server_default=sa.text("now()"),
            nullable=True,
        ),
        sa.ForeignKeyConstraint(
            ["authorization_id"], ["trip_authorizations.id"], ondelete="CASCADE"
        ),
        sa.ForeignKeyConstraint(["school_id"], ["schools.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["child_id"], ["children.id"], ondelete="RESTRICT"),
        sa.ForeignKeyConstraint(["guardian_id"], ["guardians.id"], ondelete="RESTRICT"),
        sa.UniqueConstraint("authorization_id", "child_id", name="uq_trip_response_auth_child"),
    )
    op.create_index(
        "ix_trip_authorization_responses_school_id",
        "trip_authorization_responses",
        ["school_id"],
    )


def downgrade() -> None:
    op.drop_table("trip_authorization_responses")
    op.drop_table("trip_authorizations")
