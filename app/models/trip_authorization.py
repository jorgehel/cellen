import uuid
from datetime import date, datetime, time
from typing import Optional

from sqlalchemy import Boolean, Date, DateTime, ForeignKey, Index, Text, Time, UniqueConstraint, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base


class TripAuthorization(Base):
    __tablename__ = "trip_authorizations"
    __table_args__ = (
        Index("ix_trip_authorizations_school_id", "school_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    school_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("schools.id", ondelete="RESTRICT"), nullable=False
    )
    created_by: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("employees.id", ondelete="RESTRICT"), nullable=False
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    description: Mapped[Optional[str]] = mapped_column(Text)
    trip_date: Mapped[date] = mapped_column(Date, nullable=False)
    destination: Mapped[Optional[str]] = mapped_column(String(255))
    departure_time: Mapped[Optional[time]] = mapped_column(Time)
    return_time: Mapped[Optional[time]] = mapped_column(Time)
    deadline_date: Mapped[Optional[date]] = mapped_column(Date)
    target_turma_id: Mapped[Optional[uuid.UUID]] = mapped_column(
        UUID(as_uuid=True), ForeignKey("turmas.id", ondelete="SET NULL"), nullable=True
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class TripAuthorizationResponse(Base):
    __tablename__ = "trip_authorization_responses"
    __table_args__ = (
        UniqueConstraint("authorization_id", "child_id", name="uq_trip_response_auth_child"),
        Index("ix_trip_authorization_responses_school_id", "school_id"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    authorization_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("trip_authorizations.id", ondelete="CASCADE"), nullable=False
    )
    school_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("schools.id", ondelete="RESTRICT"), nullable=False
    )
    child_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("children.id", ondelete="RESTRICT"), nullable=False
    )
    guardian_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("guardians.id", ondelete="RESTRICT"), nullable=False
    )
    authorized: Mapped[bool] = mapped_column(Boolean, nullable=False)
    notes: Mapped[Optional[str]] = mapped_column(Text)
    responded_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
