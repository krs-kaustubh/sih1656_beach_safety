from fastapi import FastAPI

from core.config import settings
from api.beach_routes import router as beach_router

app = FastAPI(
    title="Beach Safety API",
    version="0.1.0",
)

app.include_router(beach_router)


@app.get("/health")
def health_check():
    """Readiness, and which sources are actually configured.

    Worth checking before a demo: a missing model key or a mock-data flag
    looks identical to a working system from the outside, and this is the
    quickest way to tell them apart.
    """
    providers = settings.providers
    return {
        "status": "ok",
        "live_weather": not settings.demo.USE_MOCK_DATA,
        "risk_engine": "ai" if providers.get_llm_key() else "rules",
        "providers": {
            "tomorrow_io": bool(providers.get_tomorrow_key()),
            "openweather": bool(providers.get_openweather_key()),
            "risk_model": bool(providers.get_llm_key()),
        },
    }

