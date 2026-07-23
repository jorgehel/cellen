"""Add grade_schemes table and flexible mark components.

Revision ID: 0024
Revises: 0023
Create Date: 2026-07-23
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0024"
down_revision = "0023"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── grade_schemes ────────────────────────────────────────────────────────
    op.create_table(
        "grade_schemes",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "school_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("schools.id", ondelete="RESTRICT"),
            nullable=False,
        ),
        sa.Column("name", sa.String(150), nullable=False),
        sa.Column("components", postgresql.JSONB, nullable=False),
        sa.Column("is_default", sa.Boolean, nullable=False, server_default="false"),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
            nullable=False,
        ),
    )
    op.create_index("ix_grade_schemes_school_id", "grade_schemes", ["school_id"])

    # ── turma_subjects: add grade_scheme_id ──────────────────────────────────
    op.add_column(
        "turma_subjects",
        sa.Column(
            "grade_scheme_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("grade_schemes.id", ondelete="SET NULL"),
            nullable=True,
        ),
    )

    # ── marks: add grade_components ──────────────────────────────────────────
    op.add_column(
        "marks",
        sa.Column("grade_components", postgresql.JSONB, nullable=True),
    )

    # ── Seed 3 predefined schemes for every existing school ──────────────────
    op.execute("""
        INSERT INTO grade_schemes (id, school_id, name, components, is_default, created_at)
        SELECT
            gen_random_uuid(), id,
            'MAC + PE (Padrão Angola)',
            '[{"key":"mac","label":"MAC","weight":0.6},{"key":"exam","label":"PE","weight":0.4}]'::jsonb,
            true, now()
        FROM schools
    """)
    op.execute("""
        INSERT INTO grade_schemes (id, school_id, name, components, is_default, created_at)
        SELECT
            gen_random_uuid(), id,
            'Avaliação Contínua (100%)',
            '[{"key":"mac","label":"Avaliação Contínua","weight":1.0}]'::jsonb,
            false, now()
        FROM schools
    """)
    op.execute("""
        INSERT INTO grade_schemes (id, school_id, name, components, is_default, created_at)
        SELECT
            gen_random_uuid(), id,
            'Três Componentes',
            '[{"key":"mac","label":"Testes","weight":0.4},{"key":"exam","label":"Trabalhos","weight":0.3},{"key":"c3","label":"Exame Final","weight":0.3}]'::jsonb,
            false, now()
        FROM schools
    """)


def downgrade() -> None:
    op.drop_column("marks", "grade_components")
    op.drop_column("turma_subjects", "grade_scheme_id")
    op.drop_index("ix_grade_schemes_school_id", table_name="grade_schemes")
    op.drop_table("grade_schemes")
