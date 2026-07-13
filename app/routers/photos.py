import uuid
from datetime import date, datetime
from typing import Any, List, Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user, get_school_id, require_teacher
from app.models.modern import Photo
from app.services.storage import save_upload

router = APIRouter(prefix="/photos", tags=["photos"])

ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}


# ─── Schemas ──────────────────────────────────────────────────────────────────

class PhotoResponse(BaseModel):
    id: uuid.UUID
    school_id: uuid.UUID
    uploaded_by: uuid.UUID
    turma_id: Optional[uuid.UUID] = None
    child_ids: Optional[Any] = None
    child_id: Optional[uuid.UUID] = None
    url: str
    caption: Optional[str] = None
    photo_date: Optional[date] = None
    created_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# ─── Endpoints ────────────────────────────────────────────────────────────────

@router.get("", response_model=List[PhotoResponse])
async def list_photos(
    turma_id: Optional[uuid.UUID] = None,
    child_id: Optional[uuid.UUID] = None,
    from_date: Optional[date] = None,
    to_date: Optional[date] = None,
    skip: int = 0,
    limit: int = 50,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    from app.models.person import ChildGuardian

    role = getattr(current_user, "_role", "parent")
    query = select(Photo).where(Photo.school_id == school_id)

    # Parents only see photos linked to their children
    if role not in ("school_admin", "platform_admin", "teacher", "staff"):
        guardian_id = getattr(current_user, "guardian_id", None)
        if not guardian_id:
            return []
        child_ids_result = await db.execute(
            select(ChildGuardian.child_id).where(ChildGuardian.guardian_id == guardian_id)
        )
        allowed_child_ids = [str(r[0]) for r in child_ids_result.all()]
        if not allowed_child_ids:
            return []
        # Filter photos whose child_ids JSONB array contains any of the guardian's children
        from sqlalchemy import or_
        conditions = [Photo.child_ids.contains([cid]) for cid in allowed_child_ids]
        query = query.where(or_(*conditions))

    if turma_id:
        query = query.where(Photo.turma_id == turma_id)
    if child_id:
        query = query.where(Photo.child_ids.contains([str(child_id)]))
    if from_date:
        query = query.where(Photo.photo_date >= from_date)
    if to_date:
        query = query.where(Photo.photo_date <= to_date)

    result = await db.execute(
        query.order_by(Photo.photo_date.desc()).offset(skip).limit(limit)
    )
    photos = result.scalars().all()

    return [{
        **p.__dict__,
        "child_id": (p.child_ids[0] if isinstance(p.child_ids, list) and p.child_ids else None),
    } for p in photos]


@router.post("", response_model=PhotoResponse, status_code=status.HTTP_201_CREATED)
async def create_photo(
    file: UploadFile = File(...),
    child_id: Optional[uuid.UUID] = Form(None),
    turma_id: Optional[uuid.UUID] = Form(None),
    caption: Optional[str] = Form(None),
    photo_date: Optional[date] = Form(None),
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_teacher),
):
    content_type = file.content_type or ""
    if content_type not in ALLOWED_IMAGE_TYPES:
        raise HTTPException(
            status_code=415,
            detail=f"File type '{content_type}' not allowed for photos. Use JPEG, PNG, or WebP.",
        )

    file_url = await save_upload(file, "photos", school_id)

    child_ids_serialized = [str(child_id)] if child_id else None

    photo = Photo(
        school_id=school_id,
        uploaded_by=current_user.id,
        url=file_url,
        caption=caption,
        photo_date=photo_date or date.today(),
        turma_id=turma_id,
        child_ids=child_ids_serialized,
    )
    db.add(photo)
    await db.commit()
    await db.refresh(photo)
    return {
        **photo.__dict__,
        "child_id": child_id,
    }


@router.delete("/{photo_id}", status_code=status.HTTP_200_OK)
async def delete_photo(
    photo_id: uuid.UUID,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_teacher),
):
    result = await db.execute(
        select(Photo).where(Photo.id == photo_id, Photo.school_id == school_id)
    )
    photo = result.scalar_one_or_none()
    if photo is None:
        raise HTTPException(status_code=404, detail="Photo not found")

    await db.delete(photo)
    await db.commit()
    return {"message": "Photo deleted"}
