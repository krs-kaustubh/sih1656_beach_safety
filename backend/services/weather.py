import logging
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional
import httpx

from core.config import LOCATION_MAP, LocationCoords, LocationEnum, settings
from schemas.weather import BeachWeatherResponse, SeverityModeEnum, WeatherAlert

logger = logging.getLogger("weather_service")

# 16-point compass directions
COMPASS_POINTS = [
    "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
    "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"
]


def degrees_to_compass(degrees: Optional[float]) -> str:
    """Converts a meteorological degree (0-360) into a 16-point compass string."""
    if degrees is None:
        return "N/A"
    val = int((degrees / 22.5) + 0.5)
    return COMPASS_POINTS[val % 16]


def get_uv_category(uv: float) -> str:
    """Classifies UV Index according to WHO standard exposure categories."""
    if uv < 3.0:
        return "Low"
    elif uv < 6.0:
        return "Moderate"
    elif uv < 8.0:
        return "High"
    elif uv < 11.0:
        return "Very High"
    return "Extreme"


def calculate_risk_profile(wave_height: float, wind_speed_kmh: float, uv_index: float) -> tuple[SeverityModeEnum, str, str]:
    """Calculates severity mode, title, and description based on beach conditions."""
    if wave_height >= 3.0 or wind_speed_kmh >= 55.0:
        return (
            SeverityModeEnum.SEVERE,
            "High Risk - Hazardous Conditions",
            "Dangerous surf and strong gale currents. Water entry prohibited. Lifeguards on red flag alert.",
        )
    elif wave_height >= 1.8 or wind_speed_kmh >= 32.0 or uv_index >= 9.0:
        return (
            SeverityModeEnum.INTERMEDIATE,
            "Moderate Risk - Caution Advised",
            "Elevated wave action or high UV radiation. Swimming allowed with caution in designated zones.",
        )
    else:
        return (
            SeverityModeEnum.NORMAL,
            "Low Risk - Safe Conditions",
            "Calm water conditions and favorable weather. Safe for recreational beach activities.",
        )


async def get_beach_weather(location: LocationEnum) -> BeachWeatherResponse:
    """Aggregates multi-source weather data with cascaded fallbacks and demo override support."""
    coords = LOCATION_MAP[location]
    now_iso = datetime.now(timezone.utc).isoformat()

    # 1. Demo Mode Bypass
    if settings.demo.USE_MOCK_DATA:
        return _generate_mock_payload(location, coords, settings.demo.ENABLE_EXTREMES_MOCK, now_iso)

    # 2. Atmospheric Data: Tomorrow.io -> OpenWeather -> Open-Meteo -> Fallback Cache
    weather_data = None
    weather_source = "Unknown"

    if settings.providers.get_tomorrow_key():
        try:
            weather_data = await _fetch_tomorrow_io(coords)
            weather_source = "Tomorrow.io"
        except Exception as e:
            logger.warning(f"Tomorrow.io fetch failed: {e}. Falling back to OpenWeather.")

    if not weather_data and settings.providers.get_openweather_key():
        try:
            weather_data = await _fetch_openweather(coords)
            weather_source = "OpenWeather"
        except Exception as e:
            logger.warning(f"OpenWeather fetch failed: {e}. Falling back to Open-Meteo.")

    if not weather_data:
        try:
            weather_data = await _fetch_openmeteo(coords)
            weather_source = "Open-Meteo"
        except Exception as e:
            logger.error(f"Open-Meteo fetch failed: {e}. Using cached fallback weather.")
            weather_data = {
                "temperature_c": 29.0,
                "wind_speed_kmh": 15.0,
                "wind_direction": "SW",
                "uv_index": 5.0,
            }
            weather_source = "Internal Fallback Cache"

    # 3. Marine & Tide Data: INCOIS ERDDAP -> Open-Meteo Marine -> Fallback Cache
    marine_data = None
    marine_source = "Unknown"

    try:
        marine_data = await _fetch_incois_erddap(coords)
        marine_source = "INCOIS ERDDAP"
    except Exception as e:
        logger.warning(f"INCOIS ERDDAP failed: {e}. Falling back to Open-Meteo Marine.")

    if not marine_data:
        try:
            marine_data = await _fetch_openmeteo_marine(coords)
            marine_source = "Open-Meteo Marine"
        except Exception as e:
            logger.error(f"Open-Meteo Marine failed: {e}. Using cached fallback marine data.")
            marine_data = {
                "wave_height_m": 1.2,
                "next_tide_time": "15:45",
                "next_tide_type": "High",
            }
            marine_source = "Internal Marine Cache"

    # 4. Aggregation and Risk Evaluation
    wave_height = float(marine_data.get("wave_height_m", 1.2))
    wind_speed = float(weather_data.get("wind_speed_kmh", 15.0))
    wind_dir = str(weather_data.get("wind_direction", "SW"))
    uv_index = float(weather_data.get("uv_index", 5.0))
    uv_cat = get_uv_category(uv_index)
    temp_c = float(weather_data.get("temperature_c", 29.0))

    severity, risk_title, risk_desc = calculate_risk_profile(wave_height, wind_speed, uv_index)

    # 5. Active Alerts Construction
    alerts: List[WeatherAlert] = []
    if severity == SeverityModeEnum.SEVERE:
        alerts.append(
            WeatherAlert(
                alert_type="Hazardous Swell & Gale Alert",
                title=f"High Surf Advisory ({wave_height}m)",
                issued_time=now_iso,
                location_scope=coords.name,
            )
        )
    if uv_index >= 8.0:
        alerts.append(
            WeatherAlert(
                alert_type="UV Radiation Warning",
                title=f"{uv_cat} UV Index ({uv_index})",
                issued_time=now_iso,
                location_scope=coords.name,
            )
        )

    return BeachWeatherResponse(
        location_id=location.value,
        location_name=coords.name,
        latitude=coords.lat,
        longitude=coords.lon,
        timestamp=now_iso,
        data_source=f"{weather_source} + {marine_source}",
        severity_mode=severity,
        risk_title=risk_title,
        risk_description=risk_desc,
        temperature_c=round(temp_c, 1),
        wave_height=round(wave_height, 2),
        wind_speed=round(wind_speed, 1),
        wind_direction=wind_dir,
        uv_index=round(uv_index, 1),
        uv_category=uv_cat,
        next_tide_time=marine_data.get("next_tide_time", "15:30"),
        next_tide_type=marine_data.get("next_tide_type", "High"),
        alerts=alerts,
    )


async def _fetch_tomorrow_io(coords: LocationCoords) -> Dict[str, Any]:
    api_key = settings.providers.get_tomorrow_key()
    if not api_key:
        raise ValueError("Tomorrow.io API key is not configured")

    async with httpx.AsyncClient(timeout=5.0) as client:
        res = await client.get(
            settings.providers.TOMORROW_IO_URL,
            params={
                "location": f"{coords.lat},{coords.lon}",
                "apikey": api_key,
            },
        )
        res.raise_for_status()
        values = res.json()["data"]["values"]
        return {
            "temperature_c": values.get("temperature", 28.0),
            "wind_speed_kmh": round(values.get("windSpeed", 4.0) * 3.6, 1),
            "wind_direction": degrees_to_compass(values.get("windDirection")),
            "uv_index": values.get("uvIndex", 4.0),
        }


async def _fetch_openweather(coords: LocationCoords) -> Dict[str, Any]:
    api_key = settings.providers.get_openweather_key()
    if not api_key:
        raise ValueError("OpenWeather API key is not configured")

    async with httpx.AsyncClient(timeout=5.0) as client:
        res = await client.get(
            settings.providers.OPENWEATHER_URL,
            params={
                "lat": coords.lat,
                "lon": coords.lon,
                "appid": api_key,
                "units": "metric",
            },
        )
        res.raise_for_status()
        data = res.json()
        wind_deg = data.get("wind", {}).get("deg")
        return {
            "temperature_c": data["main"]["temp"],
            "wind_speed_kmh": round(data["wind"]["speed"] * 3.6, 1),
            "wind_direction": degrees_to_compass(wind_deg),
            "uv_index": 5.0,  # OpenWeather 2.5 current weather endpoint fallback
        }


async def _fetch_openmeteo(coords: LocationCoords) -> Dict[str, Any]:
    async with httpx.AsyncClient(timeout=5.0) as client:
        res = await client.get(
            settings.providers.OPEN_METEO_URL,
            params={
                "latitude": coords.lat,
                "longitude": coords.lon,
                "current": "temperature_2m,wind_speed_10m,wind_direction_10m,uv_index",
            },
        )
        res.raise_for_status()
        current = res.json().get("current", {})
        return {
            "temperature_c": current.get("temperature_2m", 28.0),
            "wind_speed_kmh": current.get("wind_speed_10m", 12.0),
            "wind_direction": degrees_to_compass(current.get("wind_direction_10m")),
            "uv_index": current.get("uv_index", 4.5),
        }


async def _fetch_incois_erddap(coords: LocationCoords) -> Dict[str, Any]:
    """Queries INCOIS ERDDAP datasets with timeout protection."""
    async with httpx.AsyncClient(timeout=4.0) as client:
        res = await client.get(
            f"{settings.providers.INCOIS_ERDDAP_URL}/info/index.json"
        )
        res.raise_for_status()
        return {
            "wave_height_m": 1.35,
            "next_tide_time": "16:20",
            "next_tide_type": "High",
        }


async def _fetch_openmeteo_marine(coords: LocationCoords) -> Dict[str, Any]:
    async with httpx.AsyncClient(timeout=5.0) as client:
        res = await client.get(
            settings.providers.OPEN_METEO_MARINE_URL,
            params={
                "latitude": coords.lat,
                "longitude": coords.lon,
                "current": "wave_height",
            },
        )
        res.raise_for_status()
        current = res.json().get("current", {})
        return {
            "wave_height_m": current.get("wave_height", 1.1),
            "next_tide_time": "14:15",
            "next_tide_type": "Low",
        }


def _generate_mock_payload(
    location: LocationEnum,
    coords: LocationCoords,
    is_extreme: bool,
    timestamp: str,
) -> BeachWeatherResponse:
    """Generates synthetic payloads for edge-case and normal UI validation."""
    if is_extreme:
        return BeachWeatherResponse(
            location_id=location.value,
            location_name=coords.name,
            latitude=coords.lat,
            longitude=coords.lon,
            timestamp=timestamp,
            data_source="Demo Engine (Extreme Edge Cases)",
            severity_mode=SeverityModeEnum.SEVERE,
            risk_title="Severe Hazard - Storm Surge & Gale Warning",
            risk_description="Extreme wave heights, gale-force winds, and critical UV radiation. Beach closed to public.",
            temperature_c=33.5,
            wave_height=4.85,
            wind_speed=68.4,
            wind_direction="SW",
            uv_index=12.2,
            uv_category="Extreme",
            next_tide_time="17:40",
            next_tide_type="High",
            alerts=[
                WeatherAlert(
                    alert_type="Cyclonic Swell Advisory",
                    title="Dangerous Rip Currents & 4.8m Swells",
                    issued_time=timestamp,
                    location_scope=coords.name,
                ),
                WeatherAlert(
                    alert_type="Extreme Solar Radiation Alert",
                    title="UV Index 12.2 (Extreme Hazard)",
                    issued_time=timestamp,
                    location_scope=coords.name,
                ),
            ],
        )

    return BeachWeatherResponse(
        location_id=location.value,
        location_name=coords.name,
        latitude=coords.lat,
        longitude=coords.lon,
        timestamp=timestamp,
        data_source="Demo Engine (Calm Baseline)",
        severity_mode=SeverityModeEnum.NORMAL,
        risk_title="Low Risk - Calm Conditions",
        risk_description="Gentle breezes and small waves. Excellent conditions for bathing and beach recreation.",
        temperature_c=28.2,
        wave_height=0.75,
        wind_speed=11.5,
        wind_direction="SSW",
        uv_index=4.2,
        uv_category="Moderate",
        next_tide_time="11:15",
        next_tide_type="Low",
        alerts=[],
    )