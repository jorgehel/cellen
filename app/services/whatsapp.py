"""WhatsApp Cloud API (Meta Business) integration.

To enable WhatsApp notifications:
  1. Create a Meta Business account at business.facebook.com
  2. Add a WhatsApp Business app and get a phone number
  3. Set WHATSAPP_PHONE_NUMBER_ID and WHATSAPP_ACCESS_TOKEN in .env
     OR store them per-school in School.wa_phone_number_id / wa_access_token
  4. Set wa_enabled=True on the school record (via admin settings)

Template messages require Meta approval. For utility/service messages within
a 24h window (user messaged first), plain text messages work without templates.
For proactive school notifications, a pre-approved template is needed.
"""

import logging
from typing import Optional

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)

_GRAPH_URL = "https://graph.facebook.com/v20.0"


def _normalize_angola_phone(phone: str) -> Optional[str]:
    """Convert a phone number to international format without leading +.
    Handles Angolan numbers (9-digit mobile starting with 9).
    Returns None if the number is unrecognizable.
    """
    digits = "".join(c for c in phone if c.isdigit())
    if not digits:
        return None
    # Already has country code 244
    if digits.startswith("244") and len(digits) >= 12:
        return digits
    # 9-digit Angolan mobile
    if digits.startswith("9") and len(digits) == 9:
        return f"244{digits}"
    # 12-digit starting with 244
    if len(digits) == 12 and digits.startswith("244"):
        return digits
    # Unknown format — return as-is with 244 prefix if short
    if len(digits) >= 9:
        return f"244{digits[-9:]}"
    return None


async def send_whatsapp(
    phone: str,
    message: str,
    *,
    phone_number_id: Optional[str] = None,
    access_token: Optional[str] = None,
) -> bool:
    """Send a plain WhatsApp text message via Meta Cloud API.

    Uses school-level credentials if provided, falls back to platform env vars.
    Returns True on success, False on failure (errors are logged, not raised).
    """
    pid = phone_number_id or settings.WHATSAPP_PHONE_NUMBER_ID
    token = access_token or settings.WHATSAPP_ACCESS_TOKEN

    if not pid or not token:
        logger.debug("WhatsApp not configured — skipping message to %s", phone)
        return False

    to = _normalize_angola_phone(phone)
    if not to:
        logger.warning("Cannot normalize phone number for WhatsApp: %s", phone)
        return False

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                f"{_GRAPH_URL}/{pid}/messages",
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json",
                },
                json={
                    "messaging_product": "whatsapp",
                    "to": to,
                    "type": "text",
                    "text": {"body": message, "preview_url": False},
                },
            )
            if resp.status_code == 200:
                return True
            logger.warning(
                "WhatsApp API error %s: %s", resp.status_code, resp.text[:200]
            )
            return False
    except Exception as exc:  # network timeout etc.
        logger.error("WhatsApp send failed: %s", exc)
        return False


async def send_whatsapp_to_guardians(
    phones: list[str],
    message: str,
    *,
    phone_number_id: Optional[str] = None,
    access_token: Optional[str] = None,
) -> int:
    """Send WhatsApp message to multiple guardian phone numbers.
    Returns count of successful sends."""
    sent = 0
    for phone in phones:
        if phone and await send_whatsapp(
            phone, message,
            phone_number_id=phone_number_id,
            access_token=access_token,
        ):
            sent += 1
    return sent
