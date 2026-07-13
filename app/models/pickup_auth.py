import uuid
from datetime import date, datetime
from typing import Optional

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Index, Integer, String, Text, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class PickupAuthorization(Base):
    __tablename__ = "pickup_authorizations"
    __table_args__ = (
        Index("ix_pickup_authorizations_school_id", "school_id"),
        Index("ix_pickup_authorizations_child_id", "child_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    school_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("schools.id", ondelete="RESTRICT"), nullable=False)
    child_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("children.id", ondelete="CASCADE"), nullable=False)
    authorized_person_name: Mapped[str] = mapped_column(String(255), nullable=False)
    relationship: Mapped[Optional[str]] = mapped_column(String(100))
    mobile: Mapped[Optional[str]] = mapped_column(String(50))
    id_card_number: Mapped[Optional[str]] = mapped_column(String(100))
    notes: Mapped[Optional[str]] = mapped_column(Text)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), server_default=func.now())


class MealOrder(Base):
    __tablename__ = "meal_orders"
    __table_args__ = (
        UniqueConstraint("school_id", "child_id", "order_date", "meal_type", name="uq_meal_order_child_date_type"),
        Index("ix_meal_orders_school_id", "school_id"),
        Index("ix_meal_orders_order_date", "order_date"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    school_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("schools.id", ondelete="RESTRICT"), nullable=False)
    child_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("children.id", ondelete="CASCADE"), nullable=False)
    order_date: Mapped[date] = mapped_column(Date, nullable=False)
    meal_type: Mapped[str] = mapped_column(String(50), default="lunch", nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    ordered: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    created_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), server_default=func.now())
