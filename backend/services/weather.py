import logging
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional
import httpx

from core.config import LOCATION_MAP, LocationCoords, LocationEnum, settings
from schemas.risk import SeverityMode
from schemas.weather import BeachWeatherResponse, SeverityModeEnum, WeatherAlert
from services.risk_engine import evaluate_risk

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


def _to_response_severity(mode: SeverityMode) -> SeverityModeEnum:
    """Collapses the engine five bands onto the response three.

    Anything above Normal is a caution and only the engine top band is
    Severe, so a rating is never softened on the way out.
    """
    if mode == SeverityMode.NORMAL:
        return SeverityModeEnum.NORMAL
    if mode == SeverityMode.SEVERE:
        return SeverityModeEnum.SEVERE
    return SeverityModeEnum.INTERMEDIATE


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
            # No tide or sea temperature here: an unreachable provider means
            # we do not know them, and a plausible-looking guess in a safety
            # app is worse than an honest gap.
            marine_data = {"wave_height_m": 1.2}
            marine_source = "Internal Marine Cache"

    # 4. Aggregation and Risk Evaluation
    wave_height = float(marine_data.get("wave_height_m", 1.2))
    wind_speed = float(weather_data.get("wind_speed_kmh", 15.0))
    wind_dir = str(weather_data.get("wind_direction", "SW"))
    # UV always comes from Open-Meteo, whichever provider supplied the rest.
    #
    # Tomorrow.io reports a clear-sky UV index: at Havelock under 100% cloud it
    # returned 5.0, matching Open-Meteo's clear-sky figure of 5.05, while the
    # actual cloud-attenuated exposure was 2.45 — enough to move the category
    # from Low to Moderate. What a beachgoer needs is the UV reaching the
    # ground, so the cloud-adjusted value wins and the provider's own number is
    # only a fallback.
    raw_uv = None
    try:
        raw_uv = (await _fetch_openmeteo(coords)).get("uv_index")
    except Exception as e:
        logger.warning(f"Cloud-adjusted UV from Open-Meteo failed: {e}")
    if raw_uv is None:
        raw_uv = weather_data.get("uv_index")
    uv_index = float(raw_uv) if raw_uv is not None else 0.0
    uv_cat = get_uv_category(uv_index)
    temp_c = float(weather_data.get("temperature_c", 29.0))
    sea_temp = marine_data.get("sea_temperature_c")

    # A source falling all the way through to its internal cache means we have
    # no observation at all — those values are placeholders, not measurements.
    # Grading them produced "Low Risk - Safe Conditions" with every provider
    # down, which is the one thing a safety app must never say. Report the gap
    # instead, and fail cautious rather than safe.
    degraded = weather_source.startswith("Internal") or marine_source.startswith("Internal")
    if degraded:
        no_weather = weather_source.startswith("Internal")
        no_marine = marine_source.startswith("Internal")
        if no_weather and no_marine:
            what = "Live readings"
        elif no_weather:
            what = "Live wind and UV readings"
        else:
            what = "Live wave and tide readings"

        severity = SeverityModeEnum.INTERMEDIATE
        triggered = []
        engine = "unavailable"
        risk_title = "Conditions Unavailable"
        risk_desc = (
            f"{what} could not be retrieved, so conditions cannot be assessed. "
            "Treat the water as unknown and check with lifeguards on site "
            "before entering."
        )
    else:
        # The risk engine tries a model first and falls back to the same
        # thresholds when there is no key, the call is slow, or the answer
        # fails validation against those thresholds. Either way it returns
        # an explanation of what drove the rating.
        assessment = await evaluate_risk(
            wave_height=wave_height,
            wind_speed=wind_speed,
            # Real swell, which is a different measurement from wave height.
            # Passing wave height here double-counted one reading against two
            # rules and inflated the rating. Unknown swell contributes zero
            # rather than inflating.
            swell=float(marine_data.get("swell_height_m") or 0.0),
            uv_index=uv_index,
            # No provider supplies live water quality. The roster carries a
            # value, but it is a static fixture, and letting a fixture drive
            # a live rating is the same defect as grading placeholder
            # weather. "Unknown" matches no hazard rule, so it contributes
            # nothing rather than contributing something invented.
            water_quality="Unknown",
            location_name=coords.name,
        )
        severity = _to_response_severity(assessment.severity_mode)
        risk_title = assessment.risk_title
        risk_desc = assessment.reasoning_summary
        triggered = list(assessment.triggered_parameters)
        engine = assessment.source

    # 5. Active Alerts Construction
    alerts: List[WeatherAlert] = []
    if degraded:
        alerts.append(
            WeatherAlert(
                alert_type="Data Unavailable",
                title="Live conditions could not be retrieved",
                issued_time=now_iso,
                location_scope=coords.name,
            )
        )
    if not degraded and severity == SeverityModeEnum.SEVERE:
        alerts.append(
            WeatherAlert(
                alert_type="Hazardous Swell & Gale Alert",
                title=f"High Surf Advisory ({wave_height}m)",
                issued_time=now_iso,
                location_scope=coords.name,
            )
        )
    if not degraded and uv_index >= 8.0:
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
        # UV is sourced separately from the rest of the atmospheric data.
        data_source=f"{weather_source} + {marine_source} + Open-Meteo (UV)",
        severity_mode=severity,
        risk_title=risk_title,
        risk_description=risk_desc,
        triggered_parameters=triggered,
        risk_engine=engine,
        temperature_c=round(temp_c, 1),
        sea_temperature_c=round(float(sea_temp), 1) if sea_temp is not None else None,
        wave_height=round(wave_height, 2),
        wind_speed=round(wind_speed, 1),
        wind_direction=wind_dir,
        uv_index=round(uv_index, 1),
        uv_category=uv_cat,
        next_tide_time=marine_data.get("next_tide_time"),
        next_tide_type=marine_data.get("next_tide_type"),
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
            # The 2.5 current-weather endpoint carries no UV index. Returning
            # a constant here reported "Moderate" sun at 5am; None lets the
            # caller fall back to a provider that actually measures it.
            "uv_index": None,
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
    """INCOIS ERDDAP marine data.

    Not implemented yet. This previously reached the ERDDAP index and then
    returned fixed numbers, so a successful call advertised "INCOIS ERDDAP" as
    the data source for values INCOIS never supplied. Raising instead lets the
    Open-Meteo Marine fallback run and keeps data_source truthful.
    """
    raise NotImplementedError(
        "INCOIS ERDDAP dataset query is not implemented; using marine fallback"
    )


def _next_tide_from_sea_level(
    times: List[str],
    levels: List[Any],
    now: Optional[datetime] = None,
) -> Dict[str, Any]:
    """Finds the next tide turn in an hourly sea-level series.

    A tide turn is a local extremum of sea level: the water rises to a high,
    then falls to a low. Walking forward until the trend reverses gives the
    next turn and tells us which kind it is.

    The series starts at midnight, so it is trimmed to the present first —
    otherwise the "next" tide is whichever turn happened earliest today, which
    may be hours in the past. One hour of lead-in is kept so the current
    direction of travel can still be established.

    Resolution is hourly, so the time is accurate to roughly half an hour.
    Returns an empty dict when the series is unusable, so the caller reports
    no tide rather than inventing one.
    """
    series = [(t, l) for t, l in zip(times, levels) if l is not None]
    if len(series) < 3:
        return {}

    if now is not None:
        cutoff = now - timedelta(hours=1)
        trimmed = [
            (t, l) for t, l in series
            if datetime.fromisoformat(t) >= cutoff
        ]
        # Keep the untrimmed series if trimming leaves too little to work with.
        if len(trimmed) >= 3:
            series = trimmed

    # Establish the current direction, skipping any flat stretch at the start.
    trend = 0
    start = 0
    for i in range(len(series) - 1):
        delta = series[i + 1][1] - series[i][1]
        if abs(delta) > 1e-4:
            trend = 1 if delta > 0 else -1
            start = i
            break
    if trend == 0:
        return {}

    for i in range(start + 1, len(series) - 1):
        delta = series[i + 1][1] - series[i][1]
        if abs(delta) <= 1e-4:
            continue
        if (1 if delta > 0 else -1) != trend:
            # The turn is at i: the last point before the direction reversed.
            # Hourly samples rarely land on the turn itself, so fit a parabola
            # through the three points around it and take its vertex. Juhu's
            # low sat flat across 14:00 and 15:00; reporting the sample gave
            # 15:00 where the actual turn is 14:30.
            turn_at = datetime.fromisoformat(series[i][0])
            y1, y2, y3 = series[i - 1][1], series[i][1], series[i + 1][1]
            denominator = y1 - 2 * y2 + y3
            if abs(denominator) > 1e-9:
                offset_hours = 0.5 * (y1 - y3) / denominator
                # A vertex more than one sample away means the fit is not
                # describing this turn; trust the sample instead.
                if -1.0 <= offset_hours <= 1.0:
                    turn_at += timedelta(hours=offset_hours)

            # Round to the nearest five minutes: the source is hourly, so
            # minute-level precision would overstate what is known.
            minutes = round(turn_at.minute / 5) * 5
            if minutes == 60:
                turn_at += timedelta(hours=1)
                minutes = 0
            turn_at = turn_at.replace(minute=minutes, second=0, microsecond=0)

            return {
                "next_tide_time": turn_at.strftime("%H:%M"),
                "next_tide_type": "High" if trend > 0 else "Low",
            }
    return {}


async def _fetch_openmeteo_marine(coords: LocationCoords) -> Dict[str, Any]:
    """Marine conditions from Open-Meteo: waves, sea temperature and tides.

    Tides are derived from the hourly sea-level series rather than hardcoded.
    Sea surface temperature is fetched here because the atmospheric providers
    only report air temperature, which is not what a swimmer needs to know.
    """
    async with httpx.AsyncClient(timeout=8.0) as client:
        res = await client.get(
            settings.providers.OPEN_METEO_MARINE_URL,
            params={
                "latitude": coords.lat,
                "longitude": coords.lon,
                "current": "wave_height,swell_wave_height,sea_surface_temperature",
                "hourly": "sea_level_height_msl",
                "timezone": "Asia/Kolkata",
                "forecast_days": 2,
            },
        )
        res.raise_for_status()
        payload = res.json()
        current = payload.get("current", {})
        hourly = payload.get("hourly", {})

        result: Dict[str, Any] = {
            "wave_height_m": current.get("wave_height", 1.1),
            "swell_height_m": current.get("swell_wave_height"),
            "sea_temperature_c": current.get("sea_surface_temperature"),
        }
        # The series is in Asia/Kolkata, so compare against local wall time.
        local_now = datetime.now(timezone.utc) + timedelta(hours=5, minutes=30)
        result.update(
            _next_tide_from_sea_level(
                hourly.get("time", []),
                hourly.get("sea_level_height_msl", []),
                now=local_now.replace(tzinfo=None),
            )
        )
        return result


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