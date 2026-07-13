import uuid
from datetime import date, datetime
from typing import Optional

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Index, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class TripAuthorization(Base):
    """Per-child trip authorization sent to parent for approval."""
    __tablename__ = "trip_authorizations"
    __table_args__ = (
        Index("ix_trip_authorizations_school_id", "school_id"),
        Index("ix_trip_authorizations_child_id", "child_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    school_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("schools.id", ondelete="RESTRICT"), nullable=False
    )
    child_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("children.id", ondelete="RESTRICT"), nullable=False
    )
    created_by: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="RESTRICT"), nullable=False
    )
    destination: Mapped[str] = mapped_column(String(255), nullable=False)
    trip_date: Mapped[date] = mapped_column(Date, nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text)
    # Parent response: None / "pending" / "approved" / "denied"
    parent_response: Mapped[Optional[str]] = mapped_column(String(20), nullable=True, default=None)
    response_date: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    # ID of the guardian who responded
    responded_by: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("guardians.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), server_default=func.now())
