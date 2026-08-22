from pydantic import BaseModel, Field
from typing import List, Literal
from enum import Enum

class SeverityMode(str, Enum):
    NORMAL = "NORMAL"
    INTERMEDIATE_LOW = "INTERMEDIATE_LOW"
    INTERMEDIATE_MED = "INTERMEDIATE_MED"
    INTERMEDIATE_HIGH = "INTERMEDIATE_HIGH"
    SEVERE = "SEVERE"

class AlertItem(BaseModel):
    title: str = Field(..., description="e.g. Rip Current Warning")
    issued_time: str = Field(..., description="e.g. Issued 6:15 AM")
    location_scope: str = Field(..., description="e.g. South Shore")

class RiskAssessmentResponse(BaseModel):
    severity_mode: SeverityMode

    # "ai" when a model's assessment passed validation against the
    # deterministic thresholds; "rules" when the thresholds decided.
    source: Literal["ai", "rules"] = "rules"

    risk_title: str = Field(..., description="e.g. High Risk")
    reasoning_summary: str = Field(..., description="2-sentence natural explanation of the risk for UI display.")
    triggered_parameters: List[str] = Field(..., description="e.g. ['wave_height', 'wind_speed']")
    active_alerts: List[AlertItem]