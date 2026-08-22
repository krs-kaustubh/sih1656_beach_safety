from typing import List, Literal
from pydantic import BaseModel, ConfigDict


class BeachResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int

    # The key the weather endpoint uses (`juhu`, `marina`, ...). Without it a
    # client has to guess the slug from the name, which breaks on the first
    # beach whose slug is not its first word.
    location_id: str

    name: str
    latitude: float
    longitude: float
    wave_height_meters: float
    current_speed_knots: float
    water_quality: str
    safety_status: Literal["Green", "Amber", "Red"]


class BeachListResponse(BaseModel):
    beaches: List[BeachResponse]
