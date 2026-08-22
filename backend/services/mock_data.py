"""The beach roster served by /beaches.

Coordinates and names come from LOCATION_MAP so there is one source of truth.
They used to be duplicated here, and had drifted: Juhu's roster position was
968 m from where its weather was actually sampled, and Radhanagar's name
differed between the two.

The remaining fields are placeholders. The live figures for a beach come from
/beaches/{location_id}/weather; these exist so the roster stays renderable
before a reading arrives.
"""
from typing import Any, Dict, List

from core.config import LOCATION_MAP, LocationEnum

# Static per-beach placeholders, keyed by slug.
_PLACEHOLDERS: Dict[LocationEnum, Dict[str, Any]] = {
    LocationEnum.JUHU: {
        "wave_height_meters": 2.8,
        "current_speed_knots": 4.5,
        "water_quality": "Poor",
        "safety_status": "Red",
    },
    LocationEnum.MARINA: {
        "wave_height_meters": 1.4,
        "current_speed_knots": 2.1,
        "water_quality": "Moderate",
        "safety_status": "Amber",
    },
    LocationEnum.RADHANAGAR: {
        "wave_height_meters": 0.6,
        "current_speed_knots": 0.8,
        "water_quality": "Excellent",
        "safety_status": "Green",
    },
}

MOCK_BEACHES: List[Dict[str, Any]] = [
    {
        "id": index,
        "location_id": location.value,
        "name": LOCATION_MAP[location].name,
        "latitude": LOCATION_MAP[location].lat,
        "longitude": LOCATION_MAP[location].lon,
        **_PLACEHOLDERS[location],
    }
    for index, location in enumerate(LocationEnum, start=1)
]
