from datetime import datetime
from enum import Enum
from typing import List, Literal, Optional
from pydantic import BaseModel, ConfigDict, Field


class SeverityModeEnum(str, Enum):
    NORMAL = "Normal"
    INTERMEDIATE = "Intermediate"
    SEVERE = "Severe"


class WeatherAlert(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    alert_type: str = Field(..., description="e.g. Swell Warning, High UV Alert, Rip Current Risk")
    title: str = Field(..., description="Short headline for the alert banner")
    issued_time: str = Field(..., description="ISO timestamp or formatted issue time")
    location_scope: str = Field(..., description="Scope/region e.g., 'Juhu Beach Coastal Zone'")


class BeachWeatherResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    # Beach & Metadata
    location_id: str
    location_name: str
    latitude: float
    longitude: float
    timestamp: str
    data_source: str

    # Primary Risk Level
    severity_mode: SeverityModeEnum
    risk_title: str
    risk_description: str

    # Core Weather Grid
    temperature_c: float = Field(..., description="Air temperature in Celsius")
    sea_temperature_c: Optional[float] = Field(
        None, description="Sea surface temperature in Celsius, when available"
    )
    wave_height: float = Field(..., description="Wave height in meters")
    wind_speed: float = Field(..., description="Wind speed in km/h")
    wind_direction: str = Field(..., description="Compass heading like 'SW', 'NNE'")
    uv_index: float
    uv_category: Literal["Low", "Moderate", "High", "Very High", "Extreme"]
    # Optional: derived from the hourly sea-level series, so an unreachable
    # marine provider means no tide rather than an invented one.
    next_tide_time: Optional[str] = Field(
        None, description="Time of next tide turn, e.g. '14:30'"
    )
    next_tide_type: Optional[Literal["High", "Low"]] = None

    # Active Alerts Array
    alerts: List[WeatherAlert] = Field(default_factory=list)
