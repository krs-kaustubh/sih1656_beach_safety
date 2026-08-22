"""Tests for the risk engine and, critically, its rejection of bad AI answers.

    .venv/bin/python -m pytest test_risk_engine.py -q
"""
import json

import pytest

from schemas.risk import AlertItem, RiskAssessmentResponse, SeverityMode
from services.risk_engine import (
    fallback_rules_risk_assessment,
    validate_ai_assessment,
)

CALM = dict(wave_height=0.4, wind_speed=8.0, swell=0.3, uv_index=2.0,
            water_quality="Unknown")
DANGEROUS = dict(wave_height=4.2, wind_speed=70.0, swell=3.4, uv_index=11.0,
                 water_quality="Unknown")


def ai(severity, *, title="Looks fine", reasoning="Some reasoning here.",
       triggered=None, alerts=None):
    return RiskAssessmentResponse(
        severity_mode=severity,
        source="ai",
        risk_title=title,
        reasoning_summary=reasoning,
        triggered_parameters=triggered if triggered is not None else [],
        active_alerts=alerts or [],
    )


class TestRules:
    def test_calm_water_is_normal(self):
        assert fallback_rules_risk_assessment(**CALM).severity_mode == SeverityMode.NORMAL

    def test_dangerous_water_is_severe(self):
        assert fallback_rules_risk_assessment(**DANGEROUS).severity_mode == SeverityMode.SEVERE

    def test_marks_itself_as_the_rules_engine(self):
        assert fallback_rules_risk_assessment(**CALM).source == "rules"

    def test_any_caution_explains_itself(self):
        # A rating above Normal with nothing listed leaves the app showing a
        # caution it cannot explain.
        for wave in (1.0, 1.5, 1.9, 2.4, 3.6):
            r = fallback_rules_risk_assessment(**{**CALM, "wave_height": wave})
            if r.severity_mode != SeverityMode.NORMAL:
                assert r.triggered_parameters, f"no explanation at wave {wave}m"

    def test_names_only_real_parameters(self):
        from services.risk_engine import KNOWN_PARAMETERS
        r = fallback_rules_risk_assessment(**DANGEROUS)
        assert set(r.triggered_parameters) <= KNOWN_PARAMETERS


class TestAiValidation:
    """The model may be more cautious than the thresholds, never less."""

    def test_accepts_an_agreeing_answer(self):
        rules = fallback_rules_risk_assessment(**DANGEROUS)
        good = ai(SeverityMode.SEVERE, title="Severe",
                  triggered=rules.triggered_parameters)
        assert validate_ai_assessment(good, rules) is None

    def test_accepts_the_model_escalating(self):
        # Noticing a combination the thresholds miss is the whole point.
        rules = fallback_rules_risk_assessment(**CALM)
        assert validate_ai_assessment(ai(SeverityMode.INTERMEDIATE_HIGH), rules) is None

    def test_rejects_the_model_talking_the_risk_down(self):
        # The failure this exists to stop: a model calling 4m surf "Normal".
        rules = fallback_rules_risk_assessment(**DANGEROUS)
        reason = validate_ai_assessment(ai(SeverityMode.NORMAL), rules)
        assert reason is not None and "less cautious" in reason

    def test_rejects_a_single_step_downgrade_too(self):
        rules = fallback_rules_risk_assessment(**DANGEROUS)
        assert validate_ai_assessment(ai(SeverityMode.INTERMEDIATE_HIGH), rules) is not None

    def test_rejects_dropping_a_hazard_the_thresholds_flagged(self):
        # Silently losing a triggered hazard is how a real warning disappears.
        rules = fallback_rules_risk_assessment(**DANGEROUS)
        assert rules.triggered_parameters
        reason = validate_ai_assessment(
            ai(SeverityMode.SEVERE, triggered=[]), rules
        )
        assert reason is not None and "dropped" in reason

    def test_rejects_invented_parameters(self):
        rules = fallback_rules_risk_assessment(**CALM)
        reason = validate_ai_assessment(
            ai(SeverityMode.SEVERE, triggered=["moon_phase"]), rules
        )
        assert reason is not None and "invented" in reason

    def test_rejects_empty_or_bloated_text(self):
        rules = fallback_rules_risk_assessment(**CALM)
        assert validate_ai_assessment(ai(SeverityMode.SEVERE, reasoning="  "), rules)
        assert validate_ai_assessment(ai(SeverityMode.SEVERE, title=""), rules)
        assert validate_ai_assessment(
            ai(SeverityMode.SEVERE, reasoning="x" * 401), rules
        )

    def test_rejects_a_titleless_alert(self):
        rules = fallback_rules_risk_assessment(**CALM)
        bad = ai(SeverityMode.SEVERE, alerts=[
            AlertItem(title="  ", issued_time="now", location_scope="Juhu")
        ])
        assert validate_ai_assessment(bad, rules) is not None


class TestEvaluateRisk:
    """End to end, with the model call stubbed."""

    @pytest.fixture(autouse=True)
    def _no_real_key(self, monkeypatch):
        monkeypatch.setenv("GROQ_API_KEY", "test-key")

    def _stub_llm(self, monkeypatch, payload):
        import services.risk_engine as engine

        class _Response:
            def raise_for_status(self): pass
            def json(self):
                return {"choices": [{"message": {"content": json.dumps(payload)}}]}

        class _Client:
            def __init__(self, *a, **kw): pass
            async def __aenter__(self): return self
            async def __aexit__(self, *a): return False
            async def post(self, *a, **kw): return _Response()

        monkeypatch.setattr(engine.httpx, "AsyncClient", _Client)

    def test_uses_a_valid_model_answer(self, monkeypatch):
        import asyncio
        from services.risk_engine import evaluate_risk
        self._stub_llm(monkeypatch, {
            "severity_mode": "SEVERE",
            "risk_title": "Model says severe",
            "reasoning_summary": "Heavy surf and gale winds make entry unsafe.",
            "triggered_parameters": ["wave_height", "wind_speed", "swell", "uv_index"],
            "active_alerts": [],
        })
        r = asyncio.run(evaluate_risk(**DANGEROUS, location_name="Juhu"))
        assert r.source == "ai"
        assert r.risk_title == "Model says severe"

    def test_falls_back_when_the_model_understates_the_risk(self, monkeypatch):
        import asyncio
        from services.risk_engine import evaluate_risk
        self._stub_llm(monkeypatch, {
            "severity_mode": "NORMAL",
            "risk_title": "All clear",
            "reasoning_summary": "Conditions look pleasant for swimming.",
            "triggered_parameters": [],
            "active_alerts": [],
        })
        r = asyncio.run(evaluate_risk(**DANGEROUS, location_name="Juhu"))
        assert r.source == "rules"
        assert r.severity_mode == SeverityMode.SEVERE
        assert "All clear" not in r.risk_title

    def test_falls_back_on_malformed_json(self, monkeypatch):
        import asyncio
        import services.risk_engine as engine
        from services.risk_engine import evaluate_risk

        class _Response:
            def raise_for_status(self): pass
            def json(self): return {"choices": [{"message": {"content": "not json"}}]}

        class _Client:
            def __init__(self, *a, **kw): pass
            async def __aenter__(self): return self
            async def __aexit__(self, *a): return False
            async def post(self, *a, **kw): return _Response()

        monkeypatch.setattr(engine.httpx, "AsyncClient", _Client)
        r = asyncio.run(evaluate_risk(**DANGEROUS, location_name="Juhu"))
        assert r.source == "rules"

    def test_falls_back_when_the_call_times_out(self, monkeypatch):
        import asyncio
        import httpx
        import services.risk_engine as engine
        from services.risk_engine import evaluate_risk

        class _Client:
            def __init__(self, *a, **kw): pass
            async def __aenter__(self): return self
            async def __aexit__(self, *a): return False
            async def post(self, *a, **kw):
                raise httpx.TimeoutException("too slow")

        monkeypatch.setattr(engine.httpx, "AsyncClient", _Client)
        r = asyncio.run(evaluate_risk(**DANGEROUS, location_name="Juhu"))
        assert r.source == "rules"
        assert r.severity_mode == SeverityMode.SEVERE

    def test_uses_rules_when_no_key_is_configured(self, monkeypatch):
        import asyncio
        from services.risk_engine import evaluate_risk
        monkeypatch.delenv("GROQ_API_KEY", raising=False)
        monkeypatch.delenv("OPENAI_API_KEY", raising=False)
        r = asyncio.run(evaluate_risk(**CALM, location_name="Juhu"))
        assert r.source == "rules"


class TestKeyResolution:
    """The key has to be readable from .env, not just the shell.

    Putting GROQ_API_KEY in .env used to do nothing: ProviderAPISettings had no
    field to bind it to and extra="ignore" discarded it, so the engine fell
    back to rules — which looks exactly like having no key at all.
    """

    def test_reads_the_key_from_settings(self, monkeypatch):
        from core.config import ProviderAPISettings
        providers = ProviderAPISettings(GROQ_API_KEY="gsk_from_env_file")
        assert providers.get_llm_key() == "gsk_from_env_file"

    def test_falls_back_to_the_process_environment(self, monkeypatch):
        from core.config import ProviderAPISettings
        monkeypatch.setenv("GROQ_API_KEY", "gsk_from_shell")
        providers = ProviderAPISettings(_env_file=None)
        assert providers.get_llm_key() == "gsk_from_shell"

    def test_accepts_an_openai_key_too(self):
        from core.config import ProviderAPISettings
        providers = ProviderAPISettings(OPENAI_API_KEY="sk_openai")
        assert providers.get_llm_key() == "sk_openai"

    def test_reports_no_key_when_none_is_set(self, monkeypatch):
        from core.config import ProviderAPISettings
        monkeypatch.delenv("GROQ_API_KEY", raising=False)
        monkeypatch.delenv("OPENAI_API_KEY", raising=False)
        providers = ProviderAPISettings(_env_file=None)
        assert providers.get_llm_key() is None

    def test_model_and_endpoint_are_overridable(self):
        from core.config import ProviderAPISettings
        providers = ProviderAPISettings(
            GROQ_MODEL="llama-3.1-8b-instant",
            GROQ_API_BASE_URL="https://example.test/v1/chat",
        )
        assert providers.GROQ_MODEL == "llama-3.1-8b-instant"
        assert providers.GROQ_API_BASE_URL == "https://example.test/v1/chat"
