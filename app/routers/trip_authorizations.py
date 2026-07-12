import uuid
from datetime import date, datetime, time
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user, get_school_id, require_school_admin, require_teacher, require_parent
from app.models.trip_authorization import TripAuthorization, TripAuthorizationResponse

router = APIRouter(prefix="/trip-authorizations", tags=["Trip Authorizations"])


# ─── Schemas ─────────────────────────────────────────────────────────────────

class TripAuthCreate(BaseModel):
    title: str
    description: Optional[str] = None
    trip_date: date
    destination: Optional[str] = None
    departure_time: Optional[time] = None
    return_time: Optional[time] = None
    deadline_date: Optional[date] = None
    target_turma_id: Optional[uuid.UUID] = None


class TripAuthResponseCreate(BaseModel):
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
    responded_count: int = 0
    child_response: Optional[bool] = None  # parent's child response


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

    result = await db.execute(query.order_by(TripAuthorization.trip_date.desc()))
    authorizations = result.scalars().all()

    # Get all responses for these authorizations
    auth_ids = [a.id for a in authorizations]
    responses_result = await db.execute(
        select(TripAuthorizationResponse).where(
            TripAuthorizationResponse.authorization_id.in_(auth_ids)
        )
    )
    all_responses = responses_result.scalars().all()
    response_counts = {}
    for r in all_responses:
        response_counts[r.authorization_id] = response_counts.get(r.authorization_id, 0) + 1

    # For parent role: find their guardian_id and linked children
    guardian_child_responses: dict = {}
    if role not in ("school_admin", "platform_admin", "teacher", "staff"):
        guardian_id = getattr(current_user, "guardian_id", None)
        if guardian_id:
            child_ids_result = await db.execute(
                select(ChildGuardian.child_id).where(ChildGuardian.guardian_id == guardian_id)
            )
            child_ids = [r[0] for r in child_ids_result.all()]
            for resp in all_responses:
                if resp.child_id in child_ids:
                    guardian_child_responses[resp.authorization_id] = resp.authorized

    enriched = []
    for a in authorizations:
        enriched.append({
            **a.__dict__,
            "responded_count": response_counts.get(a.id, 0),
            "child_response": guardian_child_responses.get(a.id),
        })

    return enriched


@router.post("", response_model=TripAuthOut, status_code=status.HTTP_201_CREATED)
async def create_trip_authorization(
    body: TripAuthCreate,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_teacher),
):
    employee_id = getattr(current_user, "employee_id", None)
    if employee_id is None:
        raise HTTPException(status_code=400, detail="Current user has no associated employee record")

    auth = TripAuthorization(
        school_id=school_id,
        created_by=employee_id,
        **body.model_dump(),
    )
    db.add(auth)
    await db.commit()
    await db.refresh(auth)
    return {**auth.__dict__, "responded_count": 0, "child_response": None}


@router.get("/{auth_id}", response_model=TripAuthOut)
async def get_trip_authorization(
    auth_id: uuid.UUID,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    _=Depends(get_current_user),
):
    result = await db.execute(
        select(TripAuthorization).where(
            TripAuthorization.id == auth_id,
            TripAuthorization.school_id == school_id,
        )
    )
    auth = result.scalar_one_or_none()
    if auth is None:
        raise HTTPException(status_code=404, detail="Trip authorization not found")

    count_result = await db.execute(
        select(TripAuthorizationResponse).where(
            TripAuthorizationResponse.authorization_id == auth_id
        )
    )
    responded_count = len(count_result.scalars().all())

    return {**auth.__dict__, "responded_count": responded_count, "child_response": None}


@router.post("/{auth_id}/respond", status_code=status.HTTP_200_OK)
async def respond_to_trip_authorization(
    auth_id: uuid.UUID,
    body: TripAuthResponseCreate,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_parent),
):
    from app.models.person import ChildGuardian

    # Verify the authorization exists
    auth_result = await db.execute(
        select(TripAuthorization).where(
            TripAuthorization.id == auth_id,
            TripAuthorization.school_id == school_id,
        )
    )
    if auth_result.scalar_one_or_none() is None:
        raise HTTPException(status_code=404, detail="Trip authorization not found")

    guardian_id = getattr(current_user, "guardian_id", None)
    if guardian_id is None:
        raise HTTPException(status_code=400, detail="Current user has no guardian record")

    # Verify guardian is linked to this child
    link_result = await db.execute(
        select(ChildGuardian).where(
            ChildGuardian.guardian_id == guardian_id,
            ChildGuardian.child_id == body.child_id,
            ChildGuardian.school_id == school_id,
        )
    )
    if link_result.scalar_one_or_none() is None:
        raise HTTPException(status_code=403, detail="Guardian not linked to this child")

    # Upsert response
    existing_result = await db.execute(
        select(TripAuthorizationResponse).where(
            TripAuthorizationResponse.authorization_id == auth_id,
            TripAuthorizationResponse.child_id == body.child_id,
        )
    )
    existing = existing_result.scalar_one_or_none()

    if existing:
        existing.authorized = body.authorized
        existing.notes = body.notes
    else:
        response = TripAuthorizationResponse(
            authorization_id=auth_id,
            school_id=school_id,
            child_id=body.child_id,
            guardian_id=guardian_id,
            authorized=body.authorized,
            notes=body.notes,
        )
        db.add(response)

    await db.commit()
    return {"message": "Response recorded"}


@router.delete("/{auth_id}", status_code=status.HTTP_200_OK)
async def delete_trip_authorization(
    auth_id: uuid.UUID,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    _=Depends(require_school_admin),
):
    result = await db.execute(
        select(TripAuthorization).where(
            TripAuthorization.id == auth_id,
            TripAuthorization.school_id == school_id,
        )
    )
    auth = result.scalar_one_or_none()
    if auth is None:
        raise HTTPException(status_code=404, detail="Trip authorization not found")

    await db.delete(auth)
    await db.commit()
    return {"message": "Trip authorization deleted"}
