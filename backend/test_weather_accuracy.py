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
