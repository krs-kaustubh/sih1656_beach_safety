from typing import Any, Dict

from fastapi import APIRouter, BackgroundTasks, HTTPException, status
from core.config import LocationEnum
from schemas.beach import BeachListResponse, BeachResponse
from schemas.weather import BeachWeatherResponse, SeverityModeEnum
from services.geofence import should_alert
from services.mock_data import MOCK_BEACHES
from services.risk_engine import evaluate_risk
from services.weather import get_beach_weather
from services.whatsapp import send_alert

router = APIRouter(prefix="/beaches", tags=["beaches"])


@router.get("", response_model=BeachListResponse)
def get_beaches() -> BeachListResponse:
    return BeachListResponse(beaches=[BeachResponse(**beach) for beach in MOCK_BEACHES])


@router.get("/{id}", response_model=BeachResponse)
def get_beach_by_id(id: int) -> BeachResponse:
    for beach in MOCK_BEACHES:
        if beach["id"] == id:
            return BeachResponse(**beach)
    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail=f"Beach with id {id} not found",
    )


@router.get("/{location}/weather", response_model=BeachWeatherResponse)
async def get_beach_weather_endpoint(location: LocationEnum) -> BeachWeatherResponse:
    """Fetches comprehensive weather, marine conditions, safety alerts, and risk metrics for a beach."""
    try:
        return await get_beach_weather(location)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to assemble beach weather profile: {str(exc)}",
        )


@router.post("/{location}/check-safety")
async def check_user_safety(
    location: LocationEnum,
    user_lat: float,
    user_lon: float,
    chat_id: str,
    background_tasks: BackgroundTasks,
) -> Dict[str, Any]:
    """
    Checks whether a user's current position + live risk level warrants a WhatsApp alert.
    Alert fires only if BOTH hold: user is inside the hazard zone AND severity is
    INTERMEDIATE_MED, INTERMEDIATE_HIGH, or SEVERE.

    WhatsApp dispatch runs via BackgroundTasks so this endpoint returns immediately
    regardless of WAHA latency or downtime.
    """
    try:
        weather = await get_beach_weather(location)
        risk = await evaluate_risk(
            wave_height=weather.wave_height,
            wind_speed=weather.wind_speed,
            swell=weather.wave_height,
            uv_index=weather.uv_index,
            water_quality="Moderate",
            location_name=weather.location_name,
        )

        alert_needed = await should_alert(
            user_lat=user_lat,
            user_lon=user_lon,
            beach_id=location.value,
            severity_mode=risk.severity_mode.value,
        )

        if alert_needed:
            background_tasks.add_task(
                send_alert,
                chat_id,
                f"⚠️ {risk.risk_title} — {weather.location_name}\n{risk.reasoning_summary}",
            )

        return {
            "in_hazard_zone_and_alerted": alert_needed,
            "severity_mode": risk.severity_mode.value,
            "risk_title": risk.risk_title,
        }
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to evaluate safety check: {str(exc)}",
        )

# What the app shows as "High Risk". The weather response speaks
# Normal/Intermediate/Severe, and RiskLevel.fromApi on the client maps Severe
# to high — so this is the one mode that warrants an escalation warning.
_HIGH_RISK_MODES = {SeverityModeEnum.SEVERE}


@router.post("/{location}/notify-escalation")
async def notify_escalation(
    location: LocationEnum,
    chat_id: str,
    background_tasks: BackgroundTasks,
    test: bool = False,
) -> Dict[str, Any]:
    """Sends a WhatsApp warning that this beach has risen to High Risk.

    The client detects the escalation (it is the only party that knows what
    rating the user was last shown), but it does not get to dictate the
    message. The severity is re-checked here and the text is composed here,
    so a client cannot use this endpoint to push arbitrary WhatsApp content
    or to warn about a beach that is currently calm.

    Dispatch runs in the background, so a slow or unreachable WAHA gateway
    cannot hold up the app.

    `test=true` sends a message that says plainly that it is a test and skips
    the severity check, so a user can confirm their number works without
    waiting for conditions to deteriorate. It cannot be mistaken for a real
    warning because the text differs.
    """
    if test:
        background_tasks.add_task(
            send_alert,
            chat_id,
            "\u2705 Lehar test message. Your WhatsApp alerts are set up "
            "correctly. This is not a safety warning.",
        )
        return {"sent": True, "test": True}

    try:
        weather = await get_beach_weather(location)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to read current conditions: {exc}",
        )

    severity = weather.severity_mode
    if severity not in _HIGH_RISK_MODES:
        # Not an error: the conditions genuinely eased between the client
        # noticing and this call landing. Saying so beats sending a warning
        # that the app itself would no longer show.
        return {
            "sent": False,
            "reason": "beach is no longer at high risk",
            "severity_mode": severity.value,
        }

    drivers = ", ".join(weather.triggered_parameters or []) or "overall conditions"
    background_tasks.add_task(
        send_alert,
        chat_id,
        f"\u26a0\ufe0f {weather.location_name} is now High Risk\n\n"
        f"{weather.risk_description}\n\nDriven by: {drivers}.",
    )
    return {"sent": True, "severity_mode": severity.value}
