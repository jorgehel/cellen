"""Add receipt_proof_url to payments — mandatory proof of payment attachment

Revision ID: 0010
Revises: 0009
Create Date: 2026-07-13 00:00:00.000000

"""
from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0010"
down_revision: Union[str, None] = "0009"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.execute(
        "ALTER TABLE payments ADD COLUMN IF NOT EXISTS receipt_proof_url VARCHAR(500)"
    )


def downgrade() -> None:
    op.execute("ALTER TABLE payments DROP COLUMN IF EXISTS receipt_proof_url")
