import logging
import math
from typing import Dict, List, Optional, Protocol, Sequence, Tuple
from shapely.geometry import Point, Polygon  # type: ignore

logger = logging.getLogger("geofence_service")

# Default demo hazard polygons (latitude, longitude coordinate vertices)
# Note: shapely Point is created as Point(x, y) = Point(lon, lat) or Point(lat, lon) consistently.
# We standardize on: Point(lon, lat) with Polygon([(lon, lat), ...]) following standard GIS conventions (x=lon, y=lat).
DEMO_HAZARD_ZONES: Dict[str, List[Tuple[float, float]]] = {
    # Juhu Beach, Mumbai (Hazard Zone enclosing the dangerous rip current and deep surf sector along the shoreline)
    # Coordinates in (longitude, latitude)
    "juhu": [
        (72.8220, 19.1020),
        (72.8280, 19.1020),
        (72.8295, 19.1130),
        (72.8235, 19.1130),
    ],
    # Also support numeric / alias IDs if needed
    "1": [
        (72.8220, 19.1020),
        (72.8280, 19.1020),
        (72.8295, 19.1130),
        (72.8235, 19.1130),
    ],
    # Marina Beach, Chennai (Hazard Zone)
    "marina": [
        (80.2780, 13.0450),
        (80.2860, 13.0450),
        (80.2880, 13.0560),
        (80.2800, 13.0560),
    ],
    "2": [
        (80.2780, 13.0450),
        (80.2860, 13.0450),
        (80.2880, 13.0560),
        (80.2800, 13.0560),
    ],
    # Radhanagar Beach, Havelock (Hazard Zone)
    "radhanagar": [
        (92.9470, 11.9790),
        (92.9550, 11.9790),
        (92.9560, 11.9890),
        (92.9480, 11.9890),
    ],
    "3": [
        (92.9470, 11.9790),
        (92.9550, 11.9790),
        (92.9560, 11.9890),
        (92.9480, 11.9890),
    ],
}


class HazardZoneDataProvider(Protocol):
    """Protocol for fetching hazard zone polygon coordinates from any data source (in-memory, PostgreSQL/PostGIS, Redis, etc.)."""
    async def get_hazard_polygon(self, beach_id: str) -> Optional[Sequence[Tuple[float, float]]]:
        ...


class InMemoryHazardZoneProvider:
    """Default in-memory hazard zone provider with hardcoded mock polygons."""
    def __init__(self, zones: Optional[Dict[str, List[Tuple[float, float]]]] = None):
        self._zones = zones if zones is not None else DEMO_HAZARD_ZONES

    async def get_hazard_polygon(self, beach_id: str) -> Optional[Sequence[Tuple[float, float]]]:
        normalized_id = beach_id.strip().lower()
        return self._zones.get(normalized_id)


# Global active provider instance (can be swapped with DB provider via set_hazard_data_provider)
_active_provider: HazardZoneDataProvider = InMemoryHazardZoneProvider()


def set_hazard_data_provider(provider: HazardZoneDataProvider) -> None:
    """Allows swapping the hazard zone data source (e.g., to an async DB / PostGIS repository)."""
    global _active_provider
    _active_provider = provider
    logger.info(f"Swapped hazard data provider to {type(provider).__name__}")


def validate_coordinates(lat: float, lon: float) -> bool:
    """Validates that latitude and longitude are valid non-NaN numbers within geographic bounds."""
    if not isinstance(lat, (int, float)) or not isinstance(lon, (int, float)):
        return False
    if math.isnan(lat) or math.isinf(lat) or math.isnan(lon) or math.isinf(lon):
        return False
    if not (-90.0 <= lat <= 90.0):
        return False
    if not (-180.0 <= lon <= 180.0):
        return False
    return True


async def is_in_hazard_zone(
    user_lat: float,
    user_lon: float,
    beach_id: str,
    provider: Optional[HazardZoneDataProvider] = None,
) -> bool:
    """
    Evaluates whether a given (latitude, longitude) coordinate falls within the hazard zone polygon of a beach.

    Parameters:
        user_lat (float): User's latitude (-90 to +90)
        user_lon (float): User's longitude (-180 to +180)
        beach_id (str): Identifier of the beach (e.g., 'juhu', 'marina', '1')
        provider (HazardZoneDataProvider, optional): Custom provider to override the global provider.

    Returns:
        bool: True if the user is inside or touching the hazard zone polygon, False otherwise.
    """
    # 1. Validate coordinates
    if not validate_coordinates(user_lat, user_lon):
        logger.error(f"Invalid coordinate parameters received: lat={user_lat}, lon={user_lon}")
        return False

    if not beach_id or not isinstance(beach_id, str) or not beach_id.strip():
        logger.error(f"Invalid beach_id received: {beach_id}")
        return False

    try:
        # 2. Fetch polygon coordinates from active provider
        data_provider = provider or _active_provider
        coords = await data_provider.get_hazard_polygon(beach_id)

        if not coords or len(coords) < 3:
            logger.warning(f"No valid hazard zone polygon found for beach_id '{beach_id}' (points={len(coords) if coords else 0}).")
            return False

        # 3. Construct Shapely Geometry
        # Standard GIS: (x, y) = (longitude, latitude)
        polygon = Polygon(coords)
        point = Point(user_lon, user_lat)

        # 4. Spatial Evaluation (contains or touches the boundary)
        # Using polygon.covers(point) or polygon.contains(point) or polygon.intersects(point)
        # polygon.covers(point) evaluates to True if point is in interior or on the boundary
        return bool(polygon.covers(point))

    except Exception as exc:
        logger.error(f"Error evaluating hazard zone geofence for beach_id '{beach_id}' at ({user_lat}, {user_lon}): {exc}", exc_info=True)
        return False

NOTIFIABLE_SEVERITIES = {"INTERMEDIATE_MED", "INTERMEDIATE_HIGH", "SEVERE"}


async def should_alert(
    user_lat: float,
    user_lon: float,
    beach_id: str,
    severity_mode: str,
    provider: Optional[HazardZoneDataProvider] = None,
) -> bool:
    """
    Decides whether a WhatsApp alert should fire for this user.

    Both conditions must hold:
      1. severity_mode is one of NOTIFIABLE_SEVERITIES
      2. user's coordinates fall inside the beach's hazard zone polygon

    Severity is checked first (cheap) before the geometry check (relatively more work).
    """
    if severity_mode not in NOTIFIABLE_SEVERITIES:
        return False
    return await is_in_hazard_zone(user_lat, user_lon, beach_id, provider)