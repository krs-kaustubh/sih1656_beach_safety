from typing import Any, Dict

from fastapi import APIRouter, BackgroundTasks, HTTPException, status
from core.config import LocationEnum
from schemas.beach import BeachListResponse, BeachResponse
from schemas.weather import BeachWeatherResponse
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