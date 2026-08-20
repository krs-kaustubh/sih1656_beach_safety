# Beach Safety FastAPI Backend

FastAPI backend service for beach safety monitoring and data processing.

## Folder Structure

- `api/`: API route handlers and endpoints.
- `services/`: Business logic, domain services, and external integrations.
- `schemas/`: Pydantic schemas for request validation and response serialization.
- `data_pipeline/`: Data ingestion scripts, transformations, and processing pipelines.
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

## Running the Server

Start the local development server with Uvicorn:

```bash
uvicorn main:app --reload
```

The server will start at `http://127.0.0.1:8000`.

- Health Check Endpoint: `http://127.0.0.1:8000/health`
- Interactive API Docs (Swagger UI): `http://127.0.0.1:8000/docs`
- Alternative API Docs (ReDoc): `http://127.0.0.1:8000/redoc`
