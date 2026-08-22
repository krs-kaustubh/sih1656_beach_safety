"""Published tide predictions for the monitored beaches.

Why this exists
---------------
Open-Meteo's `sea_level_height_msl` is a global model and does not resolve
coastal tides well enough to use. Checked against published tables for
22 August 2026 it was wrong on both time and type at Mumbai — it put the next
turn at 14:30 Low when the real one is 12:59 High — and its tidal range is well
short of the real one at all three sites.

These figures are harmonic predictions from published tide tables, not
measurements and not guesses. That distinction matters: the constants removed
from this codebase earlier were invented numbers presented as observations,
whereas these are the authoritative predictions for these ports.

Limits, plainly
---------------
* Only the dates listed below are covered. Outside them the caller falls back
  to the model, which is worse but honest about being a model.
* Havelock has no published table of its own; Port Blair is the standard
  reference port, roughly 40 km south, so Radhanagar's real turns differ by a
  few minutes.
* Predictions ignore weather. A storm surge shifts real water levels away from
  any table.

Replacing this with a proper tide service (WorldTides, or INCOIS once its
ERDDAP query is implemented) is the right long-term fix.

Source: tidetime.org harmonic predictions, retrieved 22 August 2026.
"""
from datetime import date, datetime, time
from typing import Dict, List, Optional, Tuple

from core.config import LocationEnum

# (hour, minute, "High" | "Low") in India Standard Time.
_TideDay = List[Tuple[int, int, str]]

PUBLISHED_TIDES: Dict[LocationEnum, Dict[date, _TideDay]] = {
    # Mumbai (reference port for Juhu Beach).
    LocationEnum.JUHU: {
        date(2026, 8, 22): [
            (2, 40, "High"),
            (8, 41, "Low"),
            (12, 59, "High"),
            (20, 24, "Low"),
        ],
    },
    # Chennai (reference port for Marina Beach).
    LocationEnum.MARINA: {
        date(2026, 8, 22): [
            (5, 14, "Low"),
            (10, 1, "High"),
            (16, 32, "Low"),
        ],
    },
    # Port Blair (nearest reference port to Radhanagar Beach, Havelock).
    LocationEnum.RADHANAGAR: {
        date(2026, 8, 22): [
            (5, 11, "Low"),
            (11, 6, "High"),
            (16, 38, "Low"),
        ],
    },
}


def next_published_tide(
    location: LocationEnum,
    now: datetime,
) -> Optional[Dict[str, str]]:
    """The next published tide turn after `now`, if this date is covered.

    Returns None when the date is not in the table or every turn for the day
    has passed, so the caller can fall back to the model rather than showing a
    time from the wrong day.
    """
    for_location = PUBLISHED_TIDES.get(location)
    if not for_location:
        return None

    day = for_location.get(now.date())
    if not day:
        return None

    for hour, minute, kind in day:
        turn = datetime.combine(now.date(), time(hour, minute))
        if turn > now:
            return {
                "next_tide_time": turn.strftime("%H:%M"),
                "next_tide_type": kind,
                "tide_source": "Published tide table",
            }
    return None
