"""Align website CMS tables with platform-level (no school_id) model.

Revision ID: 0014
Revises: 0013
"""

from typing import Sequence, Union

import sqlalchemy as sa
from alembic import op

revision: str = "0014"
down_revision: Union[str, None] = "0013"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # --- website_settings ---
    _drop_fk_if_exists("website_settings", "website_settings_school_id_fkey")
    _drop_column_if_exists("website_settings", "school_id")

    # --- website_pages ---
    _drop_fk_if_exists("website_pages", "website_pages_school_id_fkey")
    _drop_column_if_exists("website_pages", "school_id")
    _add_column_if_not_exists("website_pages", sa.Column("sort_order", sa.Integer, server_default=sa.text("0")))

    # --- website_sections ---
    _drop_fk_if_exists("website_sections", "website_sections_school_id_fkey")
    _drop_column_if_exists("website_sections", "school_id")
    _add_column_if_not_exists("website_sections", sa.Column("name", sa.String(200), nullable=False, server_default=""))
    _add_column_if_not_exists("website_sections", sa.Column("is_visible", sa.Boolean, server_default=sa.text("true")))
    # Rename "order" -> "sort_order" if the old column exists
    _rename_column_if_exists("website_sections", "order", "sort_order")

    # --- website_media ---
    _drop_fk_if_exists("website_media", "website_media_school_id_fkey")
    _drop_column_if_exists("website_media", "school_id")
    _add_column_if_not_exists("website_media", sa.Column("category", sa.String(50), server_default=sa.text("'general'")))
    _rename_column_if_exists("website_media", "size_bytes", "file_size")


def downgrade() -> None:
    # Restore school_id columns and FKs (for rollback)
    _add_column_if_not_exists(
        "website_settings",
        sa.Column("school_id", sa.dialects.postgresql.UUID(as_uuid=True)),
    )
    _add_column_if_not_exists(
        "website_pages",
        sa.Column("school_id", sa.dialects.postgresql.UUID(as_uuid=True)),
    )
    _add_column_if_not_exists(
        "website_sections",
        sa.Column("school_id", sa.dialects.postgresql.UUID(as_uuid=True)),
    )
    _add_column_if_not_exists(
        "website_media",
        sa.Column("school_id", sa.dialects.postgresql.UUID(as_uuid=True)),
    )


# --- helpers ---

def _drop_fk_if_exists(table: str, fk_name: str) -> None:
    conn = op.get_bind()
    result = conn.execute(
        sa.text(
            "SELECT 1 FROM information_schema.table_constraints "
            "WHERE constraint_name = :name AND table_name = :table "
            "AND constraint_schema = current_schema()"
        ),
        {"name": fk_name, "table": table},
    )
    if result.fetchone():
        op.drop_constraint(fk_name, table, type_="foreignkey")


def _drop_column_if_exists(table: str, column: str) -> None:
    conn = op.get_bind()
    result = conn.execute(
        sa.text(
            "SELECT 1 FROM information_schema.columns "
            "WHERE table_name = :table AND column_name = :col "
            "AND table_schema = current_schema()"
        ),
        {"table": table, "col": column},
    )
    if result.fetchone():
        op.drop_column(table, column)


def _add_column_if_not_exists(table: str, column: sa.Column) -> None:
    conn = op.get_bind()
    result = conn.execute(
        sa.text(
            "SELECT 1 FROM information_schema.columns "
            "WHERE table_name = :table AND column_name = :col "
            "AND table_schema = current_schema()"
        ),
        {"table": table, "col": column.name},
    )
    if not result.fetchone():
        op.add_column(table, column)


def _rename_column_if_exists(table: str, old_name: str, new_name: str) -> None:
    conn = op.get_bind()
    has_old = conn.execute(
        sa.text(
            "SELECT 1 FROM information_schema.columns "
            "WHERE table_name = :table AND column_name = :col "
            "AND table_schema = current_schema()"
        ),
        {"table": table, "col": old_name},
    ).fetchone()
    has_new = conn.execute(
        sa.text(
            "SELECT 1 FROM information_schema.columns "
            "WHERE table_name = :table AND column_name = :col "
            "AND table_schema = current_schema()"
        ),
        {"table": table, "col": new_name},
    ).fetchone()
    if has_old and not has_new:
        op.alter_column(table, old_name, new_column_name=new_name)
