"""Add Multicaixa payment reference fields to invoices

Revision ID: 0004
Revises: 0003
Create Date: 2026-07-12 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0004"
down_revision: Union[str, None] = "0003"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute("ALTER TABLE invoices ADD COLUMN IF NOT EXISTS multicaixa_entity VARCHAR(20)")
    op.execute("ALTER TABLE invoices ADD COLUMN IF NOT EXISTS multicaixa_ref VARCHAR(20)")


def downgrade() -> None:
    op.drop_column("invoices", "multicaixa_ref")
    op.drop_column("invoices", "multicaixa_entity")
