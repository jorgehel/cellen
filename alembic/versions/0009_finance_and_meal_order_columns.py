"""Add missing columns: billing_guardian_id/lines on invoices,
is_voided/void_reason on expenses, status/reverse_reason on payments,
quantity on meal_orders. Also make invoices.issued_by nullable.

Revision ID: 0009
Revises: 0008
Create Date: 2026-07-13 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op
from sqlalchemy.dialects import postgresql

revision: str = "0009"
down_revision: Union[str, None] = "0008"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── invoices: new columns ─────────────────────────────────────────────────
    op.execute(
        "ALTER TABLE invoices "
        "ADD COLUMN IF NOT EXISTS billing_guardian_id UUID REFERENCES guardians(id) ON DELETE SET NULL"
    )
    op.execute(
        "ALTER TABLE invoices "
        "ADD COLUMN IF NOT EXISTS lines JSONB"
    )
    # Make issued_by nullable (was NOT NULL in the original schema)
    op.execute(
        "ALTER TABLE invoices ALTER COLUMN issued_by DROP NOT NULL"
    )

    # ── expenses: void support ────────────────────────────────────────────────
    op.execute(
        "ALTER TABLE expenses "
        "ADD COLUMN IF NOT EXISTS is_voided BOOLEAN NOT NULL DEFAULT FALSE"
    )
    op.execute(
        "ALTER TABLE expenses "
        "ADD COLUMN IF NOT EXISTS void_reason TEXT"
    )

    # ── payments: reversal support ────────────────────────────────────────────
    op.execute(
        "ALTER TABLE payments "
        "ADD COLUMN IF NOT EXISTS status VARCHAR(20) NOT NULL DEFAULT 'normal'"
    )
    op.execute(
        "ALTER TABLE payments "
        "ADD COLUMN IF NOT EXISTS reverse_reason TEXT"
    )

    # ── meal_orders: quantity ─────────────────────────────────────────────────
    op.execute(
        "ALTER TABLE meal_orders "
        "ADD COLUMN IF NOT EXISTS quantity INTEGER NOT NULL DEFAULT 1"
    )


def downgrade() -> None:
    op.execute("ALTER TABLE meal_orders DROP COLUMN IF EXISTS quantity")
    op.execute("ALTER TABLE payments DROP COLUMN IF EXISTS reverse_reason")
    op.execute("ALTER TABLE payments DROP COLUMN IF EXISTS status")
    op.execute("ALTER TABLE expenses DROP COLUMN IF EXISTS void_reason")
    op.execute("ALTER TABLE expenses DROP COLUMN IF EXISTS is_voided")
    op.execute("ALTER TABLE invoices DROP COLUMN IF EXISTS lines")
    op.execute("ALTER TABLE invoices DROP COLUMN IF EXISTS billing_guardian_id")
