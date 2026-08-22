from enum import Enum
from typing import Dict, Optional
from pydantic import BaseModel, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class LocationEnum(str, Enum):
    JUHU = "juhu"
    MARINA = "marina"
    RADHANAGAR = "radhanagar"


class LocationCoords(BaseModel):
    name: str
    lat: float
    lon: float


LOCATION_MAP: Dict[LocationEnum, LocationCoords] = {
    LocationEnum.JUHU: LocationCoords(name="Juhu Beach, Mumbai", lat=19.1075, lon=72.8263),
    LocationEnum.MARINA: LocationCoords(name="Marina Beach, Chennai", lat=13.0500, lon=80.2824),
    LocationEnum.RADHANAGAR: LocationCoords(name="Radhanagar Beach, Havelock", lat=11.9841, lon=92.9515),
}


class DemoSettings(BaseSettings):
    """Demo operational flags."""
    USE_MOCK_DATA: bool = False
    ENABLE_EXTREMES_MOCK: bool = False

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


class ProviderAPISettings(BaseSettings):
    """API Keys and Base URLs for all weather/marine providers."""
    # Free Public APIs (No key required)
    INCOIS_ERDDAP_URL: str = "https://erddap.incois.gov.in/erddap"
    OPEN_METEO_URL: str = "https://api.open-meteo.com/v1/forecast"
    OPEN_METEO_MARINE_URL: str = "https://marine-api.open-meteo.com/v1/marine"

    # Commercial APIs with fallback alias support for .env naming
    TOMORROW_IO_KEY: SecretStr = SecretStr("")
    TOMORROWIO_API_KEY: Optional[str] = None
    TOMORROW_IO_URL: str = "https://api.tomorrow.io/v4/weather/realtime"

    OPENWEATHER_KEY: SecretStr = SecretStr("")
    OPENWEATHER_API_KEY: Optional[str] = None
    OPENWEATHER_URL: str = "https://api.openweathermap.org/data/2.5/weather"

    # Risk-assessment model. Declared here so the key can live in .env like
    # every other credential — without a field to bind to, pydantic-settings
    # discards it (extra="ignore") and the engine silently falls back to
    # rules, which looks identical to having no key at all.
    GROQ_API_KEY: Optional[str] = None
    OPENAI_API_KEY: Optional[str] = None
    GROQ_MODEL: Optional[str] = None
    GROQ_API_BASE_URL: Optional[str] = None

    # Budget for the model call. Measured round trips on Groq are around 1.3s
    # for the 20b model and 2.3s for the 120b, so the old 800ms ceiling meant
    # every call timed out and the rules engine always won — the model was
    # wired in but could never actually answer.
    RISK_MODEL_TIMEOUT_SECONDS: float = 2.5

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    def get_tomorrow_key(self) -> str:
        if self.TOMORROWIO_API_KEY:
            return self.TOMORROWIO_API_KEY
        return self.TOMORROW_IO_KEY.get_secret_value()

    def get_openweather_key(self) -> str:
        if self.OPENWEATHER_API_KEY:
            return self.OPENWEATHER_API_KEY
        return self.OPENWEATHER_KEY.get_secret_value()

    def get_llm_key(self) -> Optional[str]:
        """Key for the risk model, from .env or the process environment."""
        import os

        return (
            self.GROQ_API_KEY
            or self.OPENAI_API_KEY
            or os.getenv("GROQ_API_KEY")
            or os.getenv("OPENAI_API_KEY")
        )


class Settings(BaseSettings):
    demo: DemoSettings = DemoSettings()
    providers: ProviderAPISettings = ProviderAPISettings()

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()