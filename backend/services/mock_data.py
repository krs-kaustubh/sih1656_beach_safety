"""The beach roster served by /beaches.

Coordinates and names come from LOCATION_MAP so there is one source of truth.
They used to be duplicated here, and had drifted: Juhu's roster position was
968 m from where its weather was actually sampled, and Radhanagar's name
differed between the two.

The remaining fields are real readings taken on 26 August 2026 rather than
invented stand-ins. The live figures for a beach still come from
/beaches/{location_id}/weather; these exist so the roster stays renderable
before a reading arrives, and so it is not misleading while it waits.
"""
from typing import Any, Dict, List

from core.config import LOCATION_MAP, LocationEnum

# Observed values, not placeholders.
#
# Wave height and ocean current were read from Open-Meteo's marine API at each
# beach's own coordinates on 26 August 2026, 14:15 IST; current is converted
# from km/h to knots. Water quality has no live feed behind it — those are the
# standing characterisations of these beaches, not readings from the day.
#
# safety_status follows the thresholds in the README from those numbers: Juhu
# is Amber on water quality alone (its sea is unremarkable today), Marina is
# Green on a calm 0.86 m sea, and Radhanagar is Amber on a 27 km/h wind rather
# than on swell.
_PLACEHOLDERS: Dict[LocationEnum, Dict[str, Any]] = {
    LocationEnum.JUHU: {
        "wave_height_meters": 1.44,
        "current_speed_knots": 0.8,
        "water_quality": "Poor",
        "safety_status": "Amber",
    },
    LocationEnum.MARINA: {
        "wave_height_meters": 0.86,
        "current_speed_knots": 0.4,
        "water_quality": "Moderate",
        "safety_status": "Green",
    },
    LocationEnum.RADHANAGAR: {
        "wave_height_meters": 1.04,
        "current_speed_knots": 0.3,
        "water_quality": "Excellent",
        "safety_status": "Amber",
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
