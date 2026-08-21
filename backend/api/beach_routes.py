from fastapi import APIRouter, HTTPException, status
from core.config import LocationEnum
from schemas.beach import BeachListResponse, BeachResponse
from schemas.weather import BeachWeatherResponse
from services.mock_data import MOCK_BEACHES
from services.weather import get_beach_weather

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
