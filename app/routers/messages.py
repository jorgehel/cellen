import uuid
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.dependencies import get_current_user, get_school_id, require_school_admin
from app.models.modern import Message, MessageThread, ThreadParticipant, Notification
from app.models.user import User

router = APIRouter(prefix="/messages", tags=["messages"])


# ─── Schemas ──────────────────────────────────────────────────────────────────

class ThreadCreate(BaseModel):
    subject: str
    participant_ids: List[uuid.UUID]  # can be user_id, employee_id, or guardian_id
    message: Optional[str] = None
    thread_type: Optional[str] = "direct"


class MessagePost(BaseModel):
    body: str


class BroadcastCreate(BaseModel):
    body: str
    subject: Optional[str] = None
    target: str = "all"  # all, parents, teachers, staff


class ThreadResponse(BaseModel):
    id: uuid.UUID
    school_id: uuid.UUID
    subject: str
    thread_type: str
    created_by: uuid.UUID
    created_at: Optional[datetime] = None
    last_message_body: Optional[str] = None
    last_message_at: Optional[datetime] = None
    unread_count: int = 0

    model_config = {"from_attributes": True}


class MessageResponse(BaseModel):
    id: uuid.UUID
    thread_id: uuid.UUID
    sender_id: uuid.UUID
    body: str
    created_at: Optional[datetime] = None
    read_count: int = 0

    model_config = {"from_attributes": True}


# ─── Helper: resolve a participant ID to a user_id ───────────────────────────

async def _resolve_user_id(db: AsyncSession, pid: uuid.UUID, school_id: uuid.UUID) -> Optional[uuid.UUID]:
    """Try to find a User for the given ID — it might be a user_id, employee_id, or guardian_id."""
    # Direct user_id
    r = await db.execute(
        select(User.id).where(User.id == pid, User.school_id == school_id)
    )
    if r.scalar_one_or_none():
        return pid

    # Employee ID
    r2 = await db.execute(
        select(User.id).where(User.employee_id == pid, User.school_id == school_id)
    )
    uid = r2.scalar_one_or_none()
    if uid:
        return uid

    # Guardian ID
    r3 = await db.execute(
        select(User.id).where(User.guardian_id == pid, User.school_id == school_id)
    )
    uid = r3.scalar_one_or_none()
    if uid:
        return uid

    return None


# ─── Endpoints ────────────────────────────────────────────────────────────────

@router.get("/threads", response_model=List[ThreadResponse])
async def list_threads(
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    thread_ids_result = await db.execute(
        select(ThreadParticipant.thread_id).where(
            ThreadParticipant.user_id == current_user.id,
            ThreadParticipant.school_id == school_id,
        )
    )
    thread_ids = [row[0] for row in thread_ids_result.all()]

    if not thread_ids:
        return []

    result = await db.execute(
        select(MessageThread)
        .where(MessageThread.id.in_(thread_ids), MessageThread.school_id == school_id)
        .order_by(MessageThread.created_at.desc())
    )
    threads = result.scalars().all()

    messages_result = await db.execute(
        select(Message)
        .where(Message.thread_id.in_(thread_ids), Message.school_id == school_id)
        .order_by(Message.created_at.asc())
    )
    all_messages = messages_result.scalars().all()

    latest_msg: dict[uuid.UUID, Message] = {}
    thread_messages: dict[uuid.UUID, list] = {tid: [] for tid in thread_ids}
    for msg in all_messages:
        latest_msg[msg.thread_id] = msg
        thread_messages[msg.thread_id].append(msg)

    participants_result = await db.execute(
        select(ThreadParticipant).where(
            ThreadParticipant.thread_id.in_(thread_ids),
            ThreadParticipant.user_id == current_user.id,
        )
    )
    user_participants: dict[uuid.UUID, ThreadParticipant] = {
        p.thread_id: p for p in participants_result.scalars().all()
    }

    enriched = []
    for thread in threads:
        last = latest_msg.get(thread.id)
        participant = user_participants.get(thread.id)
        last_read_at = participant.last_read_at if participant else None

        from datetime import timezone
        msgs_in_thread = thread_messages.get(thread.id, [])
        if last_read_at is None:
            unread_count = len(msgs_in_thread)
        else:
            # Normalize last_read_at to UTC-aware for comparison
            if last_read_at.tzinfo is None:
                last_read_at = last_read_at.replace(tzinfo=timezone.utc)
            unread_count = sum(
                1 for m in msgs_in_thread
                if m.created_at and (
                    m.created_at.replace(tzinfo=timezone.utc) if m.created_at.tzinfo is None else m.created_at
                ) > last_read_at
            )

        enriched.append({
            **thread.__dict__,
            "last_message_body": last.body if last else None,
            "last_message_at": last.created_at if last else None,
            "unread_count": unread_count,
        })

    return enriched


@router.post("/threads", response_model=ThreadResponse, status_code=status.HTTP_201_CREATED)
async def create_thread(
    body: ThreadCreate,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    thread = MessageThread(
        school_id=school_id,
        subject=body.subject,
        thread_type=body.thread_type or "direct",
        created_by=current_user.id,
    )
    db.add(thread)
    await db.flush()

    # Resolve participant IDs (may be user_id, employee_id, or guardian_id)
    participant_user_ids: set[uuid.UUID] = {current_user.id}
    for pid in body.participant_ids:
        resolved = await _resolve_user_id(db, pid, school_id)
        if resolved:
            participant_user_ids.add(resolved)

    for uid in participant_user_ids:
        db.add(ThreadParticipant(
            thread_id=thread.id,
            user_id=uid,
            school_id=school_id,
        ))

    # Create first message if provided
    if body.message:
        db.add(Message(
            school_id=school_id,
            thread_id=thread.id,
            sender_id=current_user.id,
            body=body.message,
        ))

    await db.commit()
    await db.refresh(thread)

    # Return with unread_count=0 (just created)
    return {
        **thread.__dict__,
        "last_message_body": body.message,
        "last_message_at": None,
        "unread_count": 0,
    }


@router.get("/threads/{thread_id}/messages", response_model=List[MessageResponse])
async def list_thread_messages(
    thread_id: uuid.UUID,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    thread_result = await db.execute(
        select(MessageThread).where(
            MessageThread.id == thread_id,
            MessageThread.school_id == school_id,
        )
    )
    if thread_result.scalar_one_or_none() is None:
        raise HTTPException(status_code=404, detail="Thread not found")

    participant_result = await db.execute(
        select(ThreadParticipant).where(
            ThreadParticipant.thread_id == thread_id,
            ThreadParticipant.user_id == current_user.id,
        )
    )
    if participant_result.scalar_one_or_none() is None:
        raise HTTPException(status_code=403, detail="Access denied: not a participant in this thread")

    result = await db.execute(
        select(Message)
        .where(Message.thread_id == thread_id, Message.school_id == school_id)
        .order_by(Message.created_at.asc())
    )
    messages = result.scalars().all()

    participants_result = await db.execute(
        select(ThreadParticipant).where(ThreadParticipant.thread_id == thread_id)
    )
    participants = participants_result.scalars().all()

    enriched = []
    for msg in messages:
        read_count = sum(
            1
            for p in participants
            if p.user_id != msg.sender_id
            and p.last_read_at is not None
            and msg.created_at is not None
            and p.last_read_at >= msg.created_at
        )
        enriched.append({**msg.__dict__, "read_count": read_count})

    return enriched


@router.post("/threads/{thread_id}/messages", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
async def post_message(
    thread_id: uuid.UUID,
    body: MessagePost,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    thread_result = await db.execute(
        select(MessageThread).where(
            MessageThread.id == thread_id,
            MessageThread.school_id == school_id,
        )
    )
    if thread_result.scalar_one_or_none() is None:
        raise HTTPException(status_code=404, detail="Thread not found")

    participant_result = await db.execute(
        select(ThreadParticipant).where(
            ThreadParticipant.thread_id == thread_id,
            ThreadParticipant.user_id == current_user.id,
        )
    )
    if participant_result.scalar_one_or_none() is None:
        raise HTTPException(status_code=403, detail="Access denied: not a participant in this thread")

    message = Message(
        school_id=school_id,
        thread_id=thread_id,
        sender_id=current_user.id,
        body=body.body,
    )
    db.add(message)
    await db.commit()
    await db.refresh(message)
    return {**message.__dict__, "read_count": 0}


@router.put("/threads/{thread_id}/read", status_code=status.HTTP_200_OK)
async def mark_thread_read(
    thread_id: uuid.UUID,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    current_user=Depends(get_current_user),
):
    participant_result = await db.execute(
        select(ThreadParticipant).where(
            ThreadParticipant.thread_id == thread_id,
            ThreadParticipant.user_id == current_user.id,
        )
    )
    participant = participant_result.scalar_one_or_none()
    if participant is None:
        raise HTTPException(status_code=403, detail="Access denied: not a participant in this thread")

    from datetime import timezone
    participant.last_read_at = datetime.now(timezone.utc)
    await db.commit()
    return {"message": "Thread marked as read"}


@router.post("/broadcast", status_code=status.HTTP_201_CREATED)
async def broadcast_message(
    body: BroadcastCreate,
    school_id: uuid.UUID = Depends(get_school_id),
    db: AsyncSession = Depends(get_db),
    current_user=Depends(require_school_admin),
):
    """Admin-only: send a broadcast notification to all users matching the target role."""

    target = body.target.lower()
    if target not in ("all", "parents", "teachers", "staff"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="target must be one of: all, parents, teachers, staff",
        )

    role_filters: List[str] = []
    if target in ("all", "parents"):
        role_filters.append("parent")
    if target in ("all", "teachers"):
        role_filters.append("teacher")
    if target in ("all", "staff"):
        role_filters.append("staff")

    recipients_result = await db.execute(
        select(User).where(
            User.school_id == school_id,
            User.is_active,
            User.role.in_(role_filters),
        )
    )
    recipient_users = recipients_result.scalars().all()

    subject = body.subject or "Comunicado"
    thread = MessageThread(
        school_id=school_id,
        subject=subject,
        thread_type="broadcast",
        created_by=current_user.id,
    )
    db.add(thread)
    await db.flush()

    participant_ids: set = {current_user.id}
    for user in recipient_users:
        participant_ids.add(user.id)

    for uid in participant_ids:
        db.add(ThreadParticipant(
            thread_id=thread.id,
            user_id=uid,
            school_id=school_id,
        ))

    db.add(Message(
        school_id=school_id,
        thread_id=thread.id,
        sender_id=current_user.id,
        body=body.body,
    ))

    # Create notifications for all recipients
    for user in recipient_users:
        db.add(Notification(
            school_id=school_id,
            user_id=user.id,
            type="broadcast",
            title=subject,
            body=body.body[:255],
            related_id=thread.id,
            related_type="message_thread",
        ))

    await db.commit()
    await db.refresh(thread)
    return {
        **thread.__dict__,
        "last_message_body": body.body,
        "last_message_at": None,
        "unread_count": 0,
    }
