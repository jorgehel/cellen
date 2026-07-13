import uuid
from datetime import date, datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user, get_school_id, require_school_admin, require_teacher
from app.models.trip_authorization import TripAuthorization

router = APIRouter(prefix="/trip-authorizations", tags=["Trip Authorizations"])


# ─── Schemas ─────────────────────────────────────────────────────────────────

class TripAuthCreate(BaseModel):
    child_id: uuid.UUID
    destination: str
    trip_date: date
    description: Optional[str] = None


class TripRespondBody(BaseModel):
    response: str  # "approved" or "denied"


class TripAuthOut(BaseModel):
    model_config = {"from_attributes": True}
    id: uuid.UUID
    school_id: uuid.UUID
    child_id: uuid.UUID
    created_by: uuid.UUID
    destination: str
    trip_date: date
    description: Optional[str] = None
    parent_response: Optional[str] = None
    response_date: Optional[datetime] = None
    created_at: Optional[datetime] = None


# ─── Endpoints ───────────────────────────────────────────────────────────────

@router.get("", response_model=list[TripAuthOut])
async def list_trip_authorizations(
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    from app.models.person import ChildGuardian

    role = getattr(current_user, "_role", "parent")
    query = select(TripAuthorization).where(TripAuthorization.school_id == school_id)

    # Parents only see trips for their own children
    if role not in ("school_admin", "platform_admin", "teacher", "staff"):
        guardian_id = getattr(current_user, "guardian_id", None)
        if not guardian_id:
            return []
        child_ids_result = await db.execute(
            select(ChildGuardian.child_id).where(ChildGuardian.guardian_id == guardian_id)
        )
        child_ids = [r[0] for r in child_ids_result.all()]
        if not child_ids:
            return []
        query = query.where(TripAuthorization.child_id.in_(child_ids))

    result = await db.execute(query.order_by(TripAuthorization.trip_date.desc()))
    return result.scalars().all()


@router.post("", response_model=TripAuthOut, status_code=status.HTTP_201_CREATED)
async def create_trip_authorization(
    body: TripAuthCreate,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_teacher),
):
    from app.models.person import Child

    # Verify child exists in this school
    child_result = await db.execute(
        select(Child).where(Child.id == body.child_id, Child.school_id == school_id)
    )
    if child_result.scalar_one_or_none() is None:
        raise HTTPException(status_code=404, detail="Child not found")

    trip = TripAuthorization(
        school_id=school_id,
        created_by=current_user.id,
        child_id=body.child_id,
        destination=body.destination,
        trip_date=body.trip_date,
        description=body.description,
        parent_response=None,
    )
    db.add(trip)
    await db.commit()
    await db.refresh(trip)
    return trip


@router.get("/{trip_id}", response_model=TripAuthOut)
async def get_trip_authorization(
    trip_id: uuid.UUID,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    result = await db.execute(
        select(TripAuthorization).where(
            TripAuthorization.id == trip_id,
            TripAuthorization.school_id == school_id,
        )
    )
    trip = result.scalar_one_or_none()
    if trip is None:
        raise HTTPException(status_code=404, detail="Trip authorization not found")
    return trip


@router.post("/{trip_id}/respond", response_model=TripAuthOut, status_code=status.HTTP_200_OK)
async def respond_to_trip_authorization(
    trip_id: uuid.UUID,
    body: TripRespondBody,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    from app.models.person import ChildGuardian

    if body.response not in ("approved", "denied"):
        raise HTTPException(status_code=422, detail="response must be 'approved' or 'denied'")

    # Load the trip
    result = await db.execute(
        select(TripAuthorization).where(
            TripAuthorization.id == trip_id,
            TripAuthorization.school_id == school_id,
        )
    )
    trip = result.scalar_one_or_none()
    if trip is None:
        raise HTTPException(status_code=404, detail="Trip authorization not found")

    # Verify caller is a parent
    guardian_id = getattr(current_user, "guardian_id", None)
    if guardian_id is None:
        raise HTTPException(status_code=403, detail="Only parents can respond to trip authorizations")

    # Verify guardian is linked to the trip's child
    link_result = await db.execute(
        select(ChildGuardian).where(
            ChildGuardian.guardian_id == guardian_id,
            ChildGuardian.child_id == trip.child_id,
        )
    )
    if link_result.scalar_one_or_none() is None:
        raise HTTPException(status_code=403, detail="You are not authorized for this child's trips")

    # Enforce finality — cannot change a response once given
    if trip.parent_response is not None:
        raise HTTPException(
            status_code=409,
            detail="Trip response is final and cannot be changed",
        )

    trip.parent_response = body.response
    trip.response_date = datetime.utcnow()
    trip.responded_by = guardian_id

    await db.commit()
    await db.refresh(trip)
    return trip


@router.delete("/{trip_id}", status_code=status.HTTP_200_OK)
async def delete_trip_authorization(
    trip_id: uuid.UUID,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    _=Depends(require_school_admin),
):
    result = await db.execute(
        select(TripAuthorization).where(
            TripAuthorization.id == trip_id,
            TripAuthorization.school_id == school_id,
        )
    )
    trip = result.scalar_one_or_none()
    if trip is None:
        raise HTTPException(status_code=404, detail="Trip authorization not found")

    await db.delete(trip)
    await db.commit()
    return {"message": "Trip authorization cancelled"}
