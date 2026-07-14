"""Create billing_items table and add missing columns to contracts

Revision ID: 0011
Revises: 0010
Create Date: 2026-07-13 01:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0011"
down_revision: Union[str, None] = "0010"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Create billing_items table
    op.create_table(
        "billing_items",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("school_id", postgresql.UUID(as_uuid=True), nullable=False),
        sa.Column("code", sa.String(50), nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("unit_price", sa.Numeric(10, 2), nullable=False, server_default="0"),
        sa.Column("iva_rate", sa.Numeric(5, 2), nullable=False, server_default="0"),
        sa.Column("iva_exemption_reason", sa.String(10), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.text("now()"), nullable=True),
        sa.ForeignKeyConstraint(["school_id"], ["schools.id"], ondelete="RESTRICT"),
        sa.UniqueConstraint("school_id", "code", name="uq_billing_items_school_code"),
    )
    op.create_index("ix_billing_items_school_id", "billing_items", ["school_id"])

    # Add missing columns to contracts
    op.execute(
        "ALTER TABLE contracts ADD COLUMN IF NOT EXISTS unit_price NUMERIC(10,2)"
    )
    op.execute(
        "ALTER TABLE contracts ADD COLUMN IF NOT EXISTS billing_item_id UUID REFERENCES billing_items(id) ON DELETE SET NULL"
    )


def downgrade() -> None:
    op.execute("ALTER TABLE contracts DROP COLUMN IF EXISTS billing_item_id")
    op.execute("ALTER TABLE contracts DROP COLUMN IF EXISTS unit_price")
    op.drop_table("billing_items")
