from typing import List, Literal
from pydantic import BaseModel, ConfigDict


class BeachResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    latitude: float
    longitude: float
    wave_height_meters: float
    current_speed_knots: float
    water_quality: str
    safety_status: Literal["Green", "Amber", "Red"]


class BeachListResponse(BaseModel):
    beaches: List[BeachResponse]
