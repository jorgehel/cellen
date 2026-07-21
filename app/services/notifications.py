"""Notification emission helpers.

Usage in any router:
    from app.services.notifications import notify_parents_of_child

    await notify_parents_of_child(
        db, school_id, child_id,
        notif_type="caderneta",
        title="Nova Caderneta",
        body="O educador registou o relatório diário do seu filho.",
        related_id=caderneta.id,
        related_type="caderneta",
    )
"""
import uuid
from typing import Optional

from sqlalchemy import select  # noqa: F401 (also used in new helpers)
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.modern import Notification
from app.models.person import ChildGuardian, Guardian


async def _get_parent_user_ids_for_child(
    db: AsyncSession, school_id: uuid.UUID, child_id: uuid.UUID
) -> list[uuid.UUID]:
    """Return user IDs of all guardians (parents) linked to a child."""
    from app.models.user import User

    result = await db.execute(
        select(User.id)
        .join(Guardian, Guardian.id == User.guardian_id)
        .join(ChildGuardian, ChildGuardian.guardian_id == Guardian.id)
        .where(
            ChildGuardian.child_id == child_id,
            ChildGuardian.school_id == school_id,
            User.is_active.is_(True),
        )
    )
    return [row[0] for row in result.all()]


async def _get_guardian_phones_for_child(
    db: AsyncSession, school_id: uuid.UUID, child_id: uuid.UUID
) -> list[str]:
    """Return non-empty mobile numbers of all guardians linked to a child."""
    result = await db.execute(
        select(Guardian.mobile_first, Guardian.mobile_second)
        .join(ChildGuardian, ChildGuardian.guardian_id == Guardian.id)
        .where(
            ChildGuardian.child_id == child_id,
            ChildGuardian.school_id == school_id,
        )
    )
    phones: list[str] = []
    for row in result.all():
        if row[0]:
            phones.append(row[0])
        if row[1]:
            phones.append(row[1])
    return phones


async def notify_parents_of_child(
    db: AsyncSession,
    school_id: uuid.UUID,
    child_id: uuid.UUID,
    *,
    notif_type: str,
    title: str,
    body: str,
    related_id: Optional[uuid.UUID] = None,
    related_type: Optional[str] = None,
) -> int:
    """Create an in-app notification for every parent linked to a child,
    and send a WhatsApp message if the school has it enabled.
    Returns the number of in-app notifications created."""
    user_ids = await _get_parent_user_ids_for_child(db, school_id, child_id)
    for uid in user_ids:
        db.add(Notification(
            school_id=school_id,
            user_id=uid,
            type=notif_type,
            title=title,
            body=body,
            related_id=related_id,
            related_type=related_type,
        ))

    # WhatsApp — fire-and-forget, best effort
    try:
        from app.models.school import School
        from app.services.whatsapp import send_whatsapp_to_guardians

        school_r = await db.execute(select(School).where(School.id == school_id))
        school = school_r.scalar_one_or_none()
        if school and school.wa_enabled:
            phones = await _get_guardian_phones_for_child(db, school_id, child_id)
            if phones:
                wa_message = f"*{title}*\n{body}"
                import asyncio
                asyncio.create_task(
                    send_whatsapp_to_guardians(
                        phones,
                        wa_message,
                        phone_number_id=school.wa_phone_number_id or None,
                        access_token=school.wa_access_token or None,
                    )
                )
    except Exception:
        pass  # WhatsApp is best-effort, never blocks the main flow

    return len(user_ids)


async def notify_user(
    db: AsyncSession,
    school_id: uuid.UUID,
    user_id: uuid.UUID,
    *,
    notif_type: str,
    title: str,
    body: str,
    related_id: Optional[uuid.UUID] = None,
    related_type: Optional[str] = None,
) -> None:
    """Create a notification for a single user."""
    db.add(Notification(
        school_id=school_id,
        user_id=user_id,
        type=notif_type,
        title=title,
        body=body,
        related_id=related_id,
        related_type=related_type,
    ))


async def notify_users_by_role(
    db: AsyncSession,
    school_id: uuid.UUID,
    role: str,
    *,
    notif_type: str,
    title: str,
    body: str,
    related_id: Optional[uuid.UUID] = None,
    related_type: Optional[str] = None,
) -> int:
    """Create notifications for all active users with a given role in a school."""
    from app.models.user import User

    result = await db.execute(
        select(User.id).where(
            User.school_id == school_id,
            User.role == role,
            User.is_active.is_(True),
        )
    )
    user_ids = [row[0] for row in result.all()]
    for uid in user_ids:
        db.add(Notification(
            school_id=school_id,
            user_id=uid,
            type=notif_type,
            title=title,
            body=body,
            related_id=related_id,
            related_type=related_type,
        ))
    return len(user_ids)
