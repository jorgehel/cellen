import uuid
from datetime import datetime
from decimal import Decimal
from typing import Optional

from sqlalchemy import Boolean, DateTime, ForeignKey, Index, Numeric, String, Text, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class BillingItem(Base):
    """Service catalog — reusable items referenced by contracts and invoice lines."""
    __tablename__ = "billing_items"
    __table_args__ = (
        UniqueConstraint("school_id", "code", name="uq_billing_items_school_code"),
        Index("ix_billing_items_school_id", "school_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    school_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("schools.id", ondelete="RESTRICT"), nullable=False
    )
    code: Mapped[str] = mapped_column(String(50), nullable=False)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    unit_price: Mapped[Decimal] = mapped_column(Numeric(10, 2), nullable=False, default=Decimal("0"))
    iva_rate: Mapped[Decimal] = mapped_column(Numeric(5, 2), nullable=False, default=Decimal("0"))
    iva_exemption_reason: Mapped[Optional[str]] = mapped_column(String(10), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[Optional[datetime]] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
