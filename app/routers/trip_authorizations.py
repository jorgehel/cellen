import uuid
from datetime import date, datetime, time
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user, get_school_id, require_school_admin, require_teacher
from app.models.trip_authorization import TripAuthorization, TripAuthorizationResponse

router = APIRouter(prefix="/trip-authorizations", tags=["Trip Authorizations"])


# ─── Schemas ─────────────────────────────────────────────────────────────────

class TripAuthCreate(BaseModel):
    title: str
    trip_date: date
    destination: Optional[str] = None
    description: Optional[str] = None
    departure_time: Optional[time] = None
    return_time: Optional[time] = None
    deadline_date: Optional[date] = None
    target_turma_id: Optional[uuid.UUID] = None


class TripResponseCreate(BaseModel):
    child_id: uuid.UUID
    authorized: bool
    notes: Optional[str] = None


class TripResponseOut(BaseModel):
    model_config = {"from_attributes": True}
    id: uuid.UUID
    authorization_id: uuid.UUID
    child_id: uuid.UUID
    guardian_id: uuid.UUID
    authorized: bool
    notes: Optional[str] = None
    responded_at: Optional[datetime] = None
    child_name: Optional[str] = None


class TripAuthOut(BaseModel):
    model_config = {"from_attributes": True}
    id: uuid.UUID
    school_id: uuid.UUID
    created_by: uuid.UUID
    title: str
    description: Optional[str] = None
    trip_date: date
    destination: Optional[str] = None
    departure_time: Optional[time] = None
    return_time: Optional[time] = None
    deadline_date: Optional[date] = None
    target_turma_id: Optional[uuid.UUID] = None
    created_at: Optional[datetime] = None
    responses: List[TripResponseOut] = []


# ─── Endpoints ───────────────────────────────────────────────────────────────

@router.get("", response_model=list[TripAuthOut])
async def list_trip_authorizations(
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    query = (
        select(TripAuthorization)
        .where(TripAuthorization.school_id == school_id)
        .order_by(TripAuthorization.trip_date.desc())
    )

    role = getattr(current_user, "_role", "parent")

    # Parents see all trips (they can filter relevant ones on the client)
    # but we enrich responses with child names
    result = await db.execute(query)
    trips = result.scalars().unique().all()

    out = []
    for trip in trips:
        trip_dict = {**trip.__dict__}
        enriched_responses = []
        for r in trip.responses:
            rd = {**r.__dict__}
            # Enrich child name
            from app.models.person import Child
            child_result = await db.execute(select(Child.first_name, Child.last_name).where(Child.id == r.child_id))
            row = child_result.one_or_none()
            rd["child_name"] = f"{row[0]} {row[1]}" if row else None
            enriched_responses.append(rd)
        trip_dict["responses"] = enriched_responses
        out.append(trip_dict)

    return out


@router.post("", response_model=TripAuthOut, status_code=status.HTTP_201_CREATED)
async def create_trip_authorization(
    body: TripAuthCreate,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_teacher),
):
    trip = TripAuthorization(
        school_id=school_id,
        created_by=current_user.id,
        title=body.title,
        trip_date=body.trip_date,
        destination=body.destination,
        description=body.description,
        departure_time=body.departure_time,
        return_time=body.return_time,
        deadline_date=body.deadline_date,
        target_turma_id=body.target_turma_id,
    )
    db.add(trip)
    await db.commit()
    await db.refresh(trip)
    return {**trip.__dict__, "responses": []}


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

    enriched_responses = []
    for r in trip.responses:
        rd = {**r.__dict__}
        from app.models.person import Child
        child_result = await db.execute(select(Child.first_name, Child.last_name).where(Child.id == r.child_id))
        row = child_result.one_or_none()
        rd["child_name"] = f"{row[0]} {row[1]}" if row else None
        enriched_responses.append(rd)

    return {**trip.__dict__, "responses": enriched_responses}


@router.post("/{trip_id}/respond", response_model=TripResponseOut, status_code=status.HTTP_201_CREATED)
async def respond_to_trip_authorization(
    trip_id: uuid.UUID,
    body: TripResponseCreate,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    from app.models.person import ChildGuardian

    # Verify trip exists
    result = await db.execute(
        select(TripAuthorization).where(
            TripAuthorization.id == trip_id,
            TripAuthorization.school_id == school_id,
        )
    )
    trip = result.scalar_one_or_none()
    if trip is None:
        raise HTTPException(status_code=404, detail="Trip authorization not found")

    # Verify caller is a parent/guardian
    guardian_id = getattr(current_user, "guardian_id", None)
    if guardian_id is None:
        raise HTTPException(status_code=403, detail="Only parents can respond to trip authorizations")

    # Verify guardian is linked to the child
    link_result = await db.execute(
        select(ChildGuardian).where(
            ChildGuardian.guardian_id == guardian_id,
            ChildGuardian.child_id == body.child_id,
        )
    )
    if link_result.scalar_one_or_none() is None:
        raise HTTPException(status_code=403, detail="You are not authorized for this child")

    # Check for existing response
    existing = await db.execute(
        select(TripAuthorizationResponse).where(
            TripAuthorizationResponse.authorization_id == trip_id,
            TripAuthorizationResponse.child_id == body.child_id,
        )
    )
    if existing.scalar_one_or_none() is not None:
        raise HTTPException(status_code=409, detail="Response already submitted for this child")

    response = TripAuthorizationResponse(
        authorization_id=trip_id,
        school_id=school_id,
        child_id=body.child_id,
        guardian_id=guardian_id,
        authorized=body.authorized,
        notes=body.notes,
    )
    db.add(response)
    await db.commit()
    await db.refresh(response)

    from app.models.person import Child
    child_result = await db.execute(select(Child.first_name, Child.last_name).where(Child.id == body.child_id))
    row = child_result.one_or_none()

    return {**response.__dict__, "child_name": f"{row[0]} {row[1]}" if row else None}


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
