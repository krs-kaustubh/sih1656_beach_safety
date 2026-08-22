from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from api.beach_routes import router as beach_router

app = FastAPI(
    title="Beach Safety API",
    version="0.1.0",
)

# Chrome/web blocks cross-origin fetches by default; the Flutter web build
# runs on its own dev-server origin (not 127.0.0.1:8000), so without this
# every request from `flutter run -d chrome` fails as "Failed to fetch"
# even though the backend itself is healthy. Wide open for local dev —
# tighten allow_origins before any real deployment.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(beach_router)


@app.get("/health")
def health_check():
    return {"status": "ok"}