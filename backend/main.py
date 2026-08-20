from fastapi import FastAPI
from api.beach_routes import router as beach_router

app = FastAPI(
    title="Beach Safety API",
    version="0.1.0",
)

app.include_router(beach_router)


@app.get("/health")
def health_check():
    return {"status": "ok"}

