"""Accuracy checks for the weather pipeline.

    .venv/bin/python -m pytest test_weather_accuracy.py -q

These cover the parts that previously reported numbers nobody measured:
tide times, sea temperature and UV.
"""
from datetime import datetime

from services.weather import _next_tide_from_sea_level, degrees_to_compass, get_uv_category


def _series(start_hour, levels):
    times = [f"2026-08-22T{h:02d}:00" for h in range(start_hour, start_hour + len(levels))]
    return times, levels


class TestNextTide:
    def test_finds_a_rising_tide_turning_high(self):
        times, levels = _series(0, [0.1, 0.4, 0.7, 0.9, 0.8, 0.5])
        assert _next_tide_from_sea_level(times, levels) == {
            "next_tide_time": "03:00",
            "next_tide_type": "High",
        }

    def test_finds_a_falling_tide_turning_low(self):
        times, levels = _series(0, [0.9, 0.6, 0.2, -0.1, 0.2, 0.6])
        assert _next_tide_from_sea_level(times, levels) == {
            "next_tide_time": "03:00",
            "next_tide_type": "Low",
        }

    def test_skips_turns_that_already_happened(self):
        # The series always starts at midnight. Without trimming to now, the
        # "next" tide is whichever turn came first today — which may be hours
        # in the past. This is the bug that reported a 03:00 tide at 05:45.
        times, levels = _series(0, [0.1, 0.5, 0.9, 0.4, 0.0, 0.3, 0.8, 0.9, 0.4])
        result = _next_tide_from_sea_level(
            times, levels, now=datetime(2026, 8, 22, 5, 45)
        )
        assert result["next_tide_time"] > "05:00"

    def test_reports_nothing_rather_than_guessing_on_a_short_series(self):
        assert _next_tide_from_sea_level(["2026-08-22T00:00"], [0.5]) == {}
        assert _next_tide_from_sea_level([], []) == {}

    def test_reports_nothing_when_the_sea_is_flat(self):
        times, levels = _series(0, [0.5] * 6)
        assert _next_tide_from_sea_level(times, levels) == {}

    def test_tolerates_gaps_in_the_series(self):
        times, levels = _series(0, [0.1, None, 0.7, 0.9, 0.8, 0.5])
        assert _next_tide_from_sea_level(times, levels)["next_tide_type"] == "High"

    def test_ignores_a_flat_stretch_at_a_plateau(self):
        # Hourly sampling often lands two equal readings either side of a turn.
        times, levels = _series(0, [0.1, 0.5, 0.88, 0.88, 0.6, 0.2])
        assert _next_tide_from_sea_level(times, levels)["next_tide_type"] == "High"


class TestUvCategory:
    def test_uses_who_bands(self):
        assert get_uv_category(0) == "Low"
        assert get_uv_category(3) == "Moderate"
        assert get_uv_category(6) == "High"
        assert get_uv_category(8) == "Very High"
        assert get_uv_category(11) == "Extreme"


class TestCompass:
    def test_converts_degrees_to_a_heading(self):
        assert degrees_to_compass(0) == "N"
        assert degrees_to_compass(90) == "E"
        assert degrees_to_compass(180) == "S"
        assert degrees_to_compass(270) == "W"

    def test_240_degrees_is_wsw_not_sw(self):
        # Open-Meteo reported 240 deg for Marina while the app showed SW;
        # 240 is WSW, and the boundary matters for onshore/offshore calls.
        assert degrees_to_compass(240) == "WSW"


class TestRiskProfile:
    """calculate_risk_profile grades only real observations."""

    def test_calm_water_is_low_risk(self):
        from services.weather import calculate_risk_profile
        from schemas.weather import SeverityModeEnum
        severity, _, _ = calculate_risk_profile(0.5, 10.0, 2.0)
        assert severity == SeverityModeEnum.NORMAL

    def test_big_surf_is_severe(self):
        from services.weather import calculate_risk_profile
        from schemas.weather import SeverityModeEnum
        severity, _, _ = calculate_risk_profile(3.2, 10.0, 2.0)
        assert severity == SeverityModeEnum.SEVERE

    def test_gale_wind_is_severe_even_on_a_calm_sea(self):
        from services.weather import calculate_risk_profile
        from schemas.weather import SeverityModeEnum
        severity, _, _ = calculate_risk_profile(0.4, 60.0, 2.0)
        assert severity == SeverityModeEnum.SEVERE


class TestDegradedData:
    """With no observations the service must not claim the beach is safe."""

    def _all_providers_down(self, monkeypatch):
        import services.weather as w
        from core.config import settings

        # .env may set USE_MOCK_DATA, which short-circuits the whole provider
        # path before any of this is reached.
        monkeypatch.setattr(settings.demo, "USE_MOCK_DATA", False)

        async def boom(*_a, **_kw):
            raise RuntimeError("provider unreachable")

        for name in (
            "_fetch_tomorrow_io",
            "_fetch_openweather",
            "_fetch_openmeteo",
            "_fetch_incois_erddap",
            "_fetch_openmeteo_marine",
        ):
            monkeypatch.setattr(w, name, boom)

    def test_never_reports_safe_without_data(self, monkeypatch):
        import asyncio
        from core.config import LocationEnum
        from schemas.weather import SeverityModeEnum
        from services.weather import get_beach_weather

        self._all_providers_down(monkeypatch)
        r = asyncio.run(get_beach_weather(LocationEnum.JUHU))

        # The exact failure this guards: every provider down previously
        # produced "Low Risk - Safe Conditions. ... Safe for recreational
        # beach activities."
        assert r.severity_mode != SeverityModeEnum.NORMAL
        assert "Safe" not in r.risk_title
        assert "safe" not in r.risk_description.lower()
        assert r.risk_title == "Conditions Unavailable"

    def test_says_which_readings_are_missing(self, monkeypatch):
        import asyncio
        from core.config import LocationEnum
        from services.weather import get_beach_weather

        self._all_providers_down(monkeypatch)
        r = asyncio.run(get_beach_weather(LocationEnum.JUHU))
        assert "could not be retrieved" in r.risk_description
        assert "lifeguards" in r.risk_description

    def test_invents_no_tide_or_sea_temperature(self, monkeypatch):
        import asyncio
        from core.config import LocationEnum
        from services.weather import get_beach_weather

        self._all_providers_down(monkeypatch)
        r = asyncio.run(get_beach_weather(LocationEnum.JUHU))
        assert r.next_tide_time is None
        assert r.next_tide_type is None
        assert r.sea_temperature_c is None

    def test_raises_no_hazard_alerts_off_placeholder_numbers(self, monkeypatch):
        import asyncio
        from core.config import LocationEnum
        from services.weather import get_beach_weather

        self._all_providers_down(monkeypatch)
        r = asyncio.run(get_beach_weather(LocationEnum.JUHU))
        assert [a.alert_type for a in r.alerts] == ["Data Unavailable"]


class TestRoster:
    """The roster and the weather config must not drift apart."""

    def test_roster_positions_match_the_weather_sample_points(self):
        from core.config import LOCATION_MAP, LocationEnum
        from services.mock_data import MOCK_BEACHES

        by_slug = {b["location_id"]: b for b in MOCK_BEACHES}
        for loc in LocationEnum:
            entry = by_slug[loc.value]
            coords = LOCATION_MAP[loc]
            # Juhu's roster position was once 968 m from where its weather was
            # sampled, so the map pin and the reading disagreed.
            assert entry["latitude"] == coords.lat
            assert entry["longitude"] == coords.lon
            assert entry["name"] == coords.name

    def test_every_roster_entry_carries_its_weather_slug(self):
        from core.config import LocationEnum
        from services.mock_data import MOCK_BEACHES

        slugs = {b["location_id"] for b in MOCK_BEACHES}
        assert slugs == {loc.value for loc in LocationEnum}
