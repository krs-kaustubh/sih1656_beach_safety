import logging
import httpx
from core.config import settings

logger = logging.getLogger("whatsapp_gateway")

async def send_alert(chat_id: str, text: str) -> None:
    """Fire-and-forget WA send via WAHA. Runs inside BackgroundTasks — no return value blocks the caller."""
    url = f"{settings.waha.BASE_URL}/api/sendText"
    headers = {"X-Api-Key": settings.waha.API_KEY, "Content-Type": "application/json"}
    payload = {"chatId": chat_id, "text": text, "session": settings.waha.SESSION}
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            res = await client.post(url, headers=headers, json=payload)
            res.raise_for_status()
            logger.info(f"WA alert sent to {chat_id}")
    except Exception as e:
        logger.error(f"WA send failed for {chat_id}: {e}")