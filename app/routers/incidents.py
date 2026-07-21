import uuid
from datetime import date, datetime, time
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user, get_school_id, require_teacher
from app.models.modern import Incident
from app.models.person import Child, ChildGuardian

router = APIRouter(prefix="/incidents", tags=["incidents"])


# ─── Schemas ──────────────────────────────────────────────────────────────────

class IncidentCreate(BaseModel):
    child_id: uuid.UUID
    description: str
    severity: str = "minor"  # minor / moderate / serious
    incident_time: Optional[time] = None
    action_taken: Optional[str] = None
    incident_date: Optional[date] = None


class IncidentUpdate(BaseModel):
    action_taken: Optional[str] = None
    parent_notified: Optional[bool] = None
    severity: Optional[str] = None
    description: Optional[str] = None


class IncidentResponse(BaseModel):
    id: uuid.UUID
    school_id: uuid.UUID
    child_id: uuid.UUID
    reported_by: uuid.UUID
    incident_date: date
    incident_time: Optional[time] = None
    severity: str
    description: str
    action_taken: Optional[str] = None
    parent_notified: bool
    parent_notified_at: Optional[datetime] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# ─── Endpoints ────────────────────────────────────────────────────────────────

@router.get("/mine", response_model=List[IncidentResponse])
async def list_parent_incidents(
    skip: int = 0,
    limit: int = 50,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Return incidents for children linked to the authenticated parent."""
    guardian_id = getattr(current_user, "guardian_id", None)
    if guardian_id is None:
        raise HTTPException(status_code=403, detail="No guardian record linked")

    child_ids_result = await db.execute(
        select(ChildGuardian.child_id).where(ChildGuardian.guardian_id == guardian_id)
    )
    child_ids = [r[0] for r in child_ids_result.all()]
    if not child_ids:
        return []

    query = (
        select(Incident)
        .where(Incident.school_id == school_id, Incident.child_id.in_(child_ids))
        .order_by(Incident.incident_date.desc())
        .offset(skip)
        .limit(limit)
    )
    result = await db.execute(query)
    return result.scalars().all()


@router.get("", response_model=List[IncidentResponse])
async def list_incidents(
    child_id: Optional[uuid.UUID] = None,
    skip: int = 0,
    limit: int = 50,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    _=Depends(require_teacher),
):
    query = select(Incident).where(Incident.school_id == school_id)
    if child_id:
        query = query.where(Incident.child_id == child_id)

    result = await db.execute(
        query.order_by(Incident.incident_date.desc()).offset(skip).limit(limit)
    )
    return result.scalars().all()


@router.post("/", response_model=IncidentResponse, status_code=status.HTTP_201_CREATED)
async def create_incident(
    body: IncidentCreate,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_teacher),
):
    # Verify child belongs to school
    child_result = await db.execute(
        select(Child).where(Child.id == body.child_id, Child.school_id == school_id)
    )
    if child_result.scalar_one_or_none() is None:
        raise HTTPException(status_code=404, detail="Child not found")

    employee_id = getattr(current_user, "employee_id", None)
    if employee_id is None:
        raise HTTPException(status_code=400, detail="Current user has no associated employee record")

    incident = Incident(
        school_id=school_id,
        child_id=body.child_id,
        reported_by=employee_id,
        incident_date=body.incident_date or date.today(),
        incident_time=body.incident_time,
        severity=body.severity,
        description=body.description,
        action_taken=body.action_taken,
    )
    db.add(incident)
    await db.flush()

    # Notify parents for serious incidents
    if body.severity == "serious":
        from app.services.notifications import notify_parents_of_child
        await notify_parents_of_child(
            db, school_id, body.child_id,
            notif_type="incident",
            title="Ocorrência Grave",
            body=f"Foi registada uma ocorrência grave relativa ao seu filho: {body.description[:100]}",
            related_id=incident.id,
            related_type="incident",
        )

    await db.commit()
    await db.refresh(incident)
    return incident


@router.get("/{incident_id}", response_model=IncidentResponse)
async def get_incident(
    incident_id: uuid.UUID,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    _=Depends(require_teacher),
):
    result = await db.execute(
        select(Incident).where(Incident.id == incident_id, Incident.school_id == school_id)
    )
    incident = result.scalar_one_or_none()
    if incident is None:
        raise HTTPException(status_code=404, detail="Incident not found")
    return incident


@router.put("/{incident_id}", response_model=IncidentResponse)
async def update_incident(
    incident_id: uuid.UUID,
    body: IncidentUpdate,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    _=Depends(require_teacher),
):
    result = await db.execute(
        select(Incident).where(Incident.id == incident_id, Incident.school_id == school_id)
    )
    incident = result.scalar_one_or_none()
    if incident is None:
        raise HTTPException(status_code=404, detail="Incident not found")

    update_data = body.model_dump(exclude_unset=True)

    # If parent_notified is being set to True and wasn't before, record timestamp
    if update_data.get("parent_notified") is True and not incident.parent_notified:
        incident.parent_notified_at = datetime.utcnow()

    for field, value in update_data.items():
        setattr(incident, field, value)

    await db.commit()
    await db.refresh(incident)
    return incident
