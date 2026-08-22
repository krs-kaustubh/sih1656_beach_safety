import json
import logging
from typing import Any, Dict, List, Optional
import httpx

from core.config import settings
from schemas.risk import AlertItem, RiskAssessmentResponse, SeverityMode

logger = logging.getLogger("risk_engine")

SYSTEM_PROMPT = """Role: Ocean Safety AI Expert for Indian Coastal Tourism.
Task: Analyze ocean/meteorological parameters and categorize the risk level into one of: NORMAL, INTERMEDIATE_LOW, INTERMEDIATE_MED, INTERMEDIATE_HIGH, SEVERE.
Output Format: Must strictly adhere to the requested JSON schema."""

DEFAULT_MODEL = "llama-3.3-70b-versatile"
TIMEOUT_SECONDS = 0.8  # 800ms timeout

# Ordered least to most hazardous, so two assessments can be compared.
SEVERITY_ORDER: List[SeverityMode] = [
    SeverityMode.NORMAL,
    SeverityMode.INTERMEDIATE_LOW,
    SeverityMode.INTERMEDIATE_MED,
    SeverityMode.INTERMEDIATE_HIGH,
    SeverityMode.SEVERE,
]

KNOWN_PARAMETERS = {
    "wave_height",
    "wind_speed",
    "swell",
    "uv_index",
    "water_quality",
}


def validate_ai_assessment(
    ai: RiskAssessmentResponse,
    rules: RiskAssessmentResponse,
) -> Optional[str]:
    """Checks an LLM assessment against the deterministic one.

    Returns None if the assessment is usable, or a short reason to reject it.

    The rule that matters is asymmetric: the model may be *more* cautious than
    the thresholds, never less. A model is free to notice a combination the
    thresholds miss and escalate, but it must not talk the risk down — an LLM
    calling 4 m surf "Normal" is exactly the failure this guards, and the
    deterministic answer is the floor.
    """
    try:
        ai_rank = SEVERITY_ORDER.index(ai.severity_mode)
        rules_rank = SEVERITY_ORDER.index(rules.severity_mode)
    except ValueError:
        return f"unknown severity {ai.severity_mode!r}"

    if ai_rank < rules_rank:
        return (
            f"less cautious than the thresholds "
            f"({ai.severity_mode.value} < {rules.severity_mode.value})"
        )

    summary = (ai.reasoning_summary or "").strip()
    if not summary:
        return "empty reasoning"
    if len(summary) > 400:
        return f"reasoning too long ({len(summary)} chars)"

    title = (ai.risk_title or "").strip()
    if not title:
        return "empty risk title"
    if len(title) > 80:
        return f"risk title too long ({len(title)} chars)"

    unknown = set(ai.triggered_parameters) - KNOWN_PARAMETERS
    if unknown:
        return f"invented parameters {sorted(unknown)}"

    # Anything the thresholds flagged must still be acknowledged; silently
    # dropping a triggered hazard is how a real warning goes missing.
    dropped = set(rules.triggered_parameters) - set(ai.triggered_parameters)
    if dropped:
        return f"dropped triggered parameters {sorted(dropped)}"

    if any(not (a.title or "").strip() for a in ai.active_alerts):
        return "alert with no title"

    return None


def fallback_rules_risk_assessment(
    wave_height: float,
    wind_speed: float,
    swell: float,
    uv_index: float,
    water_quality: str,
    location_name: Optional[str] = None,
) -> RiskAssessmentResponse:
    """Deterministic, rules-based fallback to evaluate ocean & weather risk."""
    location_scope = location_name or "Coastal Zone"
    triggered: List[str] = []
    alerts: List[AlertItem] = []
    
    # Check individual hazard triggers
    # Wave height checks (in meters)
    if wave_height >= 3.0:
        triggered.append("wave_height")
        alerts.append(
            AlertItem(
                title="Extreme Surf & Rip Current Warning",
                issued_time="Real-time",
                location_scope=location_scope,
            )
        )
    elif wave_height >= 1.8:
        triggered.append("wave_height")
        alerts.append(
            AlertItem(
                title="Rough Sea Advisory",
                issued_time="Real-time",
                location_scope=location_scope,
            )
        )

    # Wind speed checks (in km/h)
    if wind_speed >= 55.0:
        triggered.append("wind_speed")
        alerts.append(
            AlertItem(
                title="Gale-Force Wind Alert",
                issued_time="Real-time",
                location_scope=location_scope,
            )
        )
    elif wind_speed >= 35.0:
        triggered.append("wind_speed")
        alerts.append(
            AlertItem(
                title="High Wind Caution",
                issued_time="Real-time",
                location_scope=location_scope,
            )
        )

    # Swell checks (in meters)
    if swell >= 2.5:
        triggered.append("swell")
        alerts.append(
            AlertItem(
                title="High Swell Surge Warning",
                issued_time="Real-time",
                location_scope=location_scope,
            )
        )
    elif swell >= 1.5:
        triggered.append("swell")

    # UV Index checks
    if uv_index >= 11.0:
        triggered.append("uv_index")
        alerts.append(
            AlertItem(
                title="Extreme Solar UV Alert",
                issued_time="Real-time",
                location_scope=location_scope,
            )
        )
    elif uv_index >= 8.0:
        triggered.append("uv_index")
        alerts.append(
            AlertItem(
                title="Very High UV Caution",
                issued_time="Real-time",
                location_scope=location_scope,
            )
        )

    # Water quality checks
    wq_lower = (water_quality or "").strip().lower()
    if wq_lower in ["poor", "hazardous", "contaminated", "bad"]:
        triggered.append("water_quality")
        alerts.append(
            AlertItem(
                title="Poor Water Quality Alert",
                issued_time="Real-time",
                location_scope=location_scope,
            )
        )

    # Risk classification logic
    # SEVERE: life-threatening waves, gale wind, or combination of critical hazards
    if wave_height >= 3.5 or wind_speed >= 60.0 or swell >= 3.0 or (wave_height >= 2.5 and wind_speed >= 45.0):
        severity = SeverityMode.SEVERE
        risk_title = "Severe Hazard - High Risk"
        reasoning = (
            f"Dangerous ocean conditions observed with wave heights of {wave_height:.1f}m and winds of {wind_speed:.1f} km/h. "
            "Entering the water is strictly prohibited due to strong rip currents and hazardous surf."
        )
    # INTERMEDIATE_HIGH: significant rough seas, strong winds, or hazardous swell
    elif wave_height >= 2.2 or wind_speed >= 45.0 or swell >= 2.0 or (wave_height >= 1.8 and wind_speed >= 35.0):
        severity = SeverityMode.INTERMEDIATE_HIGH
        risk_title = "High Caution - Rough Conditions"
        reasoning = (
            f"Elevated marine turbulence with waves at {wave_height:.1f}m and winds reaching {wind_speed:.1f} km/h. "
            "Swimming and water sports are discouraged; heed lifeguard instructions."
        )
    # INTERMEDIATE_MED: moderate waves/winds or very high UV/poor water quality
    elif wave_height >= 1.5 or wind_speed >= 30.0 or uv_index >= 8.0 or "water_quality" in triggered:
        severity = SeverityMode.INTERMEDIATE_MED
        risk_title = "Moderate Caution - Variable Conditions"
        reasoning = (
            f"Moderate sea conditions present with wave heights around {wave_height:.1f}m and UV index of {uv_index:.1f}. "
            "Bathing is permitted in designated safe zones with standard precautions."
        )
    # INTERMEDIATE_LOW: mild waves or slight breeze
    elif wave_height >= 1.0 or wind_speed >= 20.0 or uv_index >= 6.0:
        severity = SeverityMode.INTERMEDIATE_LOW
        risk_title = "Low Moderate Risk - Generally Favorable"
        reasoning = (
            f"Mild ocean action with wave heights of {wave_height:.1f}m and moderate breeze of {wind_speed:.1f} km/h. "
            "Conditions are generally safe for beach activities with normal vigilance."
        )
    # NORMAL: calm conditions
    else:
        severity = SeverityMode.NORMAL
        risk_title = "Low Risk - Safe Conditions"
        reasoning = (
            f"Calm sea state with waves at {wave_height:.1f}m and light winds of {wind_speed:.1f} km/h. "
            "Excellent and safe environment for all recreational beach activities."
        )

    # The alert thresholds above are stricter than the classification bands, so
    # a rating could come back above Normal with nothing listed as driving it —
    # leaving the app to show a caution it could not explain. Fill in whatever
    # actually crossed a band threshold.
    if severity != SeverityMode.NORMAL and not triggered:
        contributing = {
            "wave_height": wave_height >= 1.0,
            "wind_speed": wind_speed >= 20.0,
            "swell": swell >= 1.5,
            "uv_index": uv_index >= 6.0,
        }
        triggered = [name for name, crossed in contributing.items() if crossed]

    return RiskAssessmentResponse(
        severity_mode=severity,
        source="rules",
        risk_title=risk_title,
        reasoning_summary=reasoning,
        triggered_parameters=sorted(set(triggered)),
        active_alerts=alerts,
    )


async def evaluate_risk(
    wave_height: float,
    wind_speed: float,
    swell: float,
    uv_index: float,
    water_quality: str,
    location_name: Optional[str] = None,
    api_key: Optional[str] = None,
) -> RiskAssessmentResponse:
    """
    Evaluates beach safety and risk profile using Groq/OpenAI compatible LLM with structured JSON output.
    Enforces an 800ms timeout and falls back to a deterministic rules engine if unavailable or timed out.
    """
    # Resolve API Key
    resolved_api_key = api_key or settings.providers.get_llm_key()

    # Check environment variable directly if not found in settings
    import os
    if not resolved_api_key:
        resolved_api_key = os.getenv("GROQ_API_KEY") or os.getenv("OPENAI_API_KEY")

    if not resolved_api_key:
        logger.info("No LLM API key detected. Falling back to local rules-based risk assessment.")
        return fallback_rules_risk_assessment(
            wave_height=wave_height,
            wind_speed=wind_speed,
            swell=swell,
            uv_index=uv_index,
            water_quality=water_quality,
            location_name=location_name,
        )

    endpoint_url = (
        settings.providers.GROQ_API_BASE_URL
        or os.getenv("GROQ_API_BASE_URL")
        or "https://api.groq.com/openai/v1/chat/completions"
    )
    model_name = (
        settings.providers.GROQ_MODEL or os.getenv("GROQ_MODEL") or DEFAULT_MODEL
    )

    user_payload = {
        "location": location_name or "Coastal Beach",
        "wave_height_meters": wave_height,
        "wind_speed_kmh": wind_speed,
        "swell_meters": swell,
        "uv_index": uv_index,
        "water_quality": water_quality,
        "schema_instructions": {
            "severity_mode": "Must be one of NORMAL, INTERMEDIATE_LOW, INTERMEDIATE_MED, INTERMEDIATE_HIGH, SEVERE",
            "risk_title": "Short title describing overall risk level",
            "reasoning_summary": "2-sentence natural explanation of the risk for UI display.",
            "triggered_parameters": "List of strings indicating hazardous metrics (e.g. ['wave_height', 'wind_speed'])",
            "active_alerts": "List of objects with title, issued_time, location_scope",
        },
    }

    headers = {
        "Authorization": f"Bearer {resolved_api_key}",
        "Content-Type": "application/json",
    }

    body = {
        "model": model_name,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {
                "role": "user",
                "content": f"Assess beach risk for metrics: {json.dumps(user_payload)}",
            },
        ],
        "response_format": {"type": "json_object"},
        "temperature": 0.1,
    }

    # Computed up front: it is both the fallback and the yardstick the model's
    # answer is judged against.
    rules = fallback_rules_risk_assessment(
        wave_height=wave_height,
        wind_speed=wind_speed,
        swell=swell,
        uv_index=uv_index,
        water_quality=water_quality,
        location_name=location_name,
    )

    try:
        async with httpx.AsyncClient(timeout=TIMEOUT_SECONDS) as client:
            response = await client.post(endpoint_url, headers=headers, json=body)
            response.raise_for_status()
            data = response.json()
            raw_content = data["choices"][0]["message"]["content"]
            parsed_json = json.loads(raw_content)
            assessment = RiskAssessmentResponse.model_validate(parsed_json)
    except httpx.TimeoutException:
        logger.warning("LLM risk assessment timed out (>800ms). Using rules engine.")
        return rules
    except Exception as exc:
        logger.warning(
            f"LLM risk assessment failed ({type(exc).__name__}: {exc}). Using rules engine."
        )
        return rules

    rejection = validate_ai_assessment(assessment, rules)
    if rejection:
        logger.warning(f"Rejected LLM risk assessment: {rejection}. Using rules engine.")
        return rules

    logger.info("Using LLM risk assessment (passed validation against thresholds).")
    return assessment.model_copy(update={"source": "ai"})
