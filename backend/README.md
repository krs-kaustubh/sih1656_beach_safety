# Beach Safety FastAPI Backend

FastAPI backend service for real-time beach safety monitoring, marine weather aggregation, risk assessment, and safety alert broadcasting.

## Folder Structure

- `api/`: API route handlers and endpoints (beach discovery, real-time weather, marine metrics).
- `services/`: Business logic, weather/marine API aggregators (Tomorrow.io, OpenWeather, Open-Meteo, INCOIS ERDDAP), and fallback engines.
- `schemas/`: Pydantic schemas for request validation, mobile weather grid responses, safety classifications, and alert payloads.
- `data_pipeline/`: Data ingestion scripts, transformations, and processing pipelines.
- `core/`: Core application configuration, provider settings, and demo/mock overrides.
- `main.py`: Application entry point initializing FastAPI and health check endpoint.

## Setup & Installation

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Create and activate a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. Install required dependencies:
   ```bash
   pip install -r requirements.txt
   ```

## Configuration & Environment Variables

Create a `.env` file in the root directory or configure environment variables:

```env
# Operational Mode
ENVIRONMENT=development
USE_MOCK_DATA=false          # Set to true to bypass API calls with synthetic data
ENABLE_EXTREMES_MOCK=false   # Set to true to simulate extreme weather edge cases (high surf, gale winds, high UV)

# Provider API Keys
OPENWEATHER_API_KEY=your_openweather_key
TOMORROWIO_API_KEY=your_tomorrow_io_key
```

## Running the Server

Start the local development server with Uvicorn:

```bash
uvicorn main:app --reload
```

The server will start at `http://127.0.0.1:8000`.

- Health Check Endpoint: `http://127.0.0.1:8000/health`
- Beach Discovery List: `http://127.0.0.1:8000/beaches`
- Real-Time Beach Weather & Safety Grid: `http://127.0.0.1:8000/beaches/{location}/weather` (e.g. `/beaches/juhu/weather`)
- Interactive API Docs (Swagger UI): `http://127.0.0.1:8000/docs`
- Alternative API Docs (ReDoc): `http://127.0.0.1:8000/redoc`
