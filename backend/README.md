# Beach Safety & Early Warning System - FastAPI Backend

A resilient, real-time coastal monitoring and ocean safety backend service built with FastAPI. The platform aggregates multi-source meteorological, oceanographic, and marine radar data to compute deterministic hazard thresholds and deliver AI-synthesized safety advisories for Indian coastal tourism hubs.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
   - [Directory Structure](#directory-structure)
   - [Cascading Data Fallback Strategy](#cascading-data-fallback-strategy)
   - [Geofence & Hazard Zone Spatial Engine](#geofence--hazard-zone-spatial-engine)
2. [Environment Variables](#environment-variables)
3. [Core API Endpoints](#core-api-endpoints)
   - [`GET /health`](#get-health)
   - [`GET /beaches`](#get-beaches)
   - [`GET /beaches/{id}`](#get-beachesid)
   - [`GET /beaches/{location}/weather`](#get-beacheslocationweather)
4. [Risk Engine Logic](#risk-engine-logic)
   - [Hybrid Architecture (Deterministic Rules + AI Synthesis)](#hybrid-architecture)
   - [Severity Classification Matrix](#severity-classification-matrix)
   - [Resilience & Failover Workflow](#resilience--failover-workflow)
5. [Local Setup Instructions](#local-setup-instructions)
   - [Prerequisites & Installation](#prerequisites--installation)
   - [Running the Server](#running-the-server)
   - [Triggering Demo & Edge-Case Configurations](#triggering-demo--edge-case-configurations)
   - [Testing Endpoints via cURL](#testing-endpoints-via-curl)

---

## Architecture Overview

The backend is organized into modular decoupled layers separating API routing, data aggregation, spatial computations, risk modeling, and configuration management.

### Directory Structure

```
backend/
├── api/
│   └── beach_routes.py       # FastAPI routing endpoints for beaches & weather
├── core/
│   └── config.py             # Settings, environment parser, location coordinates
├── data_pipeline/            # Data ingestion, transformation, and batch pipelines
├── schemas/
│   ├── beach.py              # Pydantic schemas for beach discovery
│   ├── risk.py               # Pydantic models for risk assessment & alert items
│   └── weather.py            # Response schemas for weather and safety profiles
├── services/
│   ├── geofence.py           # Shapely spatial point-in-polygon hazard zone detector
│   ├── mock_data.py          # Seed data for coastal stations
│   ├── risk_engine.py        # Hybrid LLM (Groq) + deterministic rules engine
│   └── weather.py            # Cascaded weather/marine multi-provider aggregator
├── main.py                   # FastAPI initialization & health routing
└── requirements.txt          # Production dependencies
```

### Cascading Data Fallback Strategy

Coastal telemetry demands high availability. If a primary third-party provider or national ocean data portal experiences downtime or rate limits, the system cascades down to alternate providers and ultimately to an internal validated cache to ensure zero service disruption.

```
                  ┌─────────────────────────────────┐
                  │   Incoming Weather Request      │
                  └────────────────┬────────────────┘
                                   │
                     Is USE_MOCK_DATA enabled?
                     ├── YES ──► Return Synthetic Mock Data (Calm / Extreme)
                     │
                     └── NO ───► Proceed to Cascaded Providers:
                                   │
       ┌───────────────────────────┴───────────────────────────┐
       ▼                                                       ▼
[Atmospheric Pipeline]                                  [Marine & Tide Pipeline]
1. Tomorrow.io Real-time API                            1. INCOIS ERDDAP Dataset API
   │ (fail / missing key)                                  │ (fail / timeout)
   ▼                                                       ▼
2. OpenWeather API (v2.5)                               2. Open-Meteo Marine API
   │ (fail / missing key)                                  │ (fail / timeout)
   ▼                                                       ▼
3. Open-Meteo Weather Forecast API                      3. Internal Marine Cache
   │ (fail / timeout)
   ▼
4. Internal Atmospheric Cache
       │                                                       │
       └───────────────────────────┬───────────────────────────┘
                                   ▼
              Aggregated Ocean/Weather Parameters
                                   │
                                   ▼
                       [Risk Assessment Engine]
```

### Geofence & Hazard Zone Spatial Engine

The spatial subsystem (`services/geofence.py`) implements standard 2D Cartesian spatial point-in-polygon evaluations using Shapely (`Point(lon, lat)` and `Polygon([(lon, lat), ...])`).
- Supports predefined hazard polygon vertices for beaches such as **Juhu Beach (Mumbai)**, **Marina Beach (Chennai)**, and **Radhanagar Beach (Havelock Island)**.
- Implements an extensible `HazardZoneDataProvider` Protocol, allowing runtime swapping from in-memory polygons to PostgreSQL/PostGIS spatial tables or Redis spatial indexes.
- Validates latitude/longitude ranges ($-90 \le \text{lat} \le 90$, $-180 \le \text{lon} \le 180$) and protects against `NaN`/`Inf` inputs.

---

## Environment Variables

All settings can be configured via a `.env` file in the project root or passed as system environment variables.

| Variable | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `ENVIRONMENT` | `string` | `development` | Runtime environment (`development`, `staging`, `production`). |
| `USE_MOCK_DATA` | `boolean` | `false` | When `true`, bypasses all external network requests with synthetic datasets. |
| `ENABLE_EXTREMES_MOCK` | `boolean` | `false` | When `true` (and `USE_MOCK_DATA=true`), simulates extreme surge, gale wind, and UV hazards. |
| `OPENWEATHER_API_KEY` | `string` | `""` | API Key for OpenWeather Current Weather endpoint. (Alias: `OPENWEATHER_KEY`). |
| `TOMORROWIO_API_KEY` | `string` | `""` | API Key for Tomorrow.io Real-time API. (Alias: `TOMORROW_IO_KEY`). |
| `GROQ_API_KEY` | `string` | `""` | API Key for Groq Cloud (or OpenAI compatible provider) for LLM risk synthesis. |
| `GROQ_MODEL` | `string` | `llama-3.3-70b-versatile` | LLM model identifier used for risk synthesis. |
| `GROQ_API_BASE_URL` | `string` | `https://api.groq.com/openai/v1/chat/completions` | API endpoint for the AI synthesis layer. |
| `INCOIS_ERDDAP_URL` | `string` | `https://erddap.incois.gov.in/erddap` | Base URL for INCOIS ERDDAP oceanographic data services. |
| `OPEN_METEO_URL` | `string` | `https://api.open-meteo.com/v1/forecast` | Base URL for Open-Meteo atmospheric forecast API. |
| `OPEN_METEO_MARINE_URL` | `string` | `https://marine-api.open-meteo.com/v1/marine` | Base URL for Open-Meteo marine wave and swell API. |
| `TOMORROW_IO_URL` | `string` | `https://api.tomorrow.io/v4/weather/realtime` | Base URL for Tomorrow.io endpoint. |
| `OPENWEATHER_URL` | `string` | `https://api.openweathermap.org/data/2.5/weather` | Base URL for OpenWeather endpoint. |
| `IMD_API_KEY` | `string` | `""` | Optional API key reserved for future IMD / Doppler Radar pipeline integrations. |

---

## Core API Endpoints

### 1. Health Check

| Property | Description |
| :--- | :--- |
| **Route** | `GET /health` |
| **Description** | Returns health status of the service. |
| **Auth** | None |

#### Response (`200 OK`)
```json
{
  "status": "ok"
}
```

---

### 2. Discover Beaches

| Property | Description |
| :--- | :--- |
| **Route** | `GET /beaches` |
| **Description** | Returns the list of coastal beach stations with baseline safety flags and live ocean parameters. |
| **Query Parameters** | None |
| **Auth** | None |

#### Response (`200 OK`)
```json
{
  "beaches": [
    {
      "id": 1,
      "name": "Juhu Beach, Mumbai",
      "latitude": 19.0988,
      "longitude": 72.8267,
      "wave_height_meters": 2.8,
      "current_speed_knots": 4.5,
      "water_quality": "Poor",
      "safety_status": "Red"
    },
    {
      "id": 2,
      "name": "Marina Beach, Chennai",
      "latitude": 13.0499,
      "longitude": 80.2824,
      "wave_height_meters": 1.4,
      "current_speed_knots": 2.1,
      "water_quality": "Moderate",
      "safety_status": "Amber"
    },
    {
      "id": 3,
      "name": "Radhanagar Beach, Havelock Island",
      "latitude": 11.9841,
      "longitude": 92.9548,
      "wave_height_meters": 0.6,
      "current_speed_knots": 0.8,
      "water_quality": "Excellent",
      "safety_status": "Green"
    }
  ]
}
```

---

### 3. Get Beach Details by ID

| Property | Description |
| :--- | :--- |
| **Route** | `GET /beaches/{id}` |
| **Description** | Retrieve metadata and status for a single beach by numerical ID. |
| **Path Parameters** | `id` (`integer`, required): Numerical ID of the beach (e.g. `1`, `2`, `3`). |
| **Errors** | `404 Not Found` if beach ID is not registered. |

#### Response (`200 OK`)
```json
{
  "id": 1,
  "name": "Juhu Beach, Mumbai",
  "latitude": 19.0988,
  "longitude": 72.8267,
  "wave_height_meters": 2.8,
  "current_speed_knots": 4.5,
  "water_quality": "Poor",
  "safety_status": "Red"
}
```

---

### 4. Real-Time Beach Weather & Safety Grid

| Property | Description |
| :--- | :--- |
| **Route** | `GET /beaches/{location}/weather` |
| **Description** | Assembles full meteorological grid, marine conditions, calculated risk profile, and active safety alerts for a beach. |
| **Path Parameters** | `location` (`string`, required): One of `juhu`, `marina`, `radhanagar`. |
| **Auth** | None |
| **Errors** | `422 Validation Error` for invalid location enum; `500 Internal Server Error` on data assembly failure. |

#### Response (`200 OK`)
```json
{
  "location_id": "juhu",
  "location_name": "Juhu Beach, Mumbai",
  "latitude": 19.1075,
  "longitude": 72.8263,
  "timestamp": "2026-08-21T17:30:00.000000+00:00",
  "data_source": "Tomorrow.io + INCOIS ERDDAP",
  "severity_mode": "Normal",
  "risk_title": "Low Risk - Safe Conditions",
  "risk_description": "Calm water conditions and favorable weather. Safe for recreational beach activities.",
  "temperature_c": 28.5,
  "wave_height": 1.1,
  "wind_speed": 14.2,
  "wind_direction": "SW",
  "uv_index": 5.4,
  "uv_category": "Moderate",
  "next_tide_time": "15:45",
  "next_tide_type": "High",
  "alerts": []
}
```

#### Extreme / High-Risk Response Example (`200 OK`)
```json
{
  "location_id": "juhu",
  "location_name": "Juhu Beach, Mumbai",
  "latitude": 19.1075,
  "longitude": 72.8263,
  "timestamp": "2026-08-21T17:30:00.000000+00:00",
  "data_source": "Demo Engine (Extreme Edge Cases)",
  "severity_mode": "Severe",
  "risk_title": "Severe Hazard - Storm Surge & Gale Warning",
  "risk_description": "Extreme wave heights, gale-force winds, and critical UV radiation. Beach closed to public.",
  "temperature_c": 33.5,
  "wave_height": 4.85,
  "wind_speed": 68.4,
  "wind_direction": "SW",
  "uv_index": 12.2,
  "uv_category": "Extreme",
  "next_tide_time": "17:40",
  "next_tide_type": "High",
  "alerts": [
    {
      "alert_type": "Cyclonic Swell Advisory",
      "title": "Dangerous Rip Currents & 4.8m Swells",
      "issued_time": "2026-08-21T17:30:00.000000+00:00",
      "location_scope": "Juhu Beach, Mumbai"
    },
    {
      "alert_type": "Extreme Solar Radiation Alert",
      "title": "UV Index 12.2 (Extreme Hazard)",
      "issued_time": "2026-08-21T17:30:00.000000+00:00",
      "location_scope": "Juhu Beach, Mumbai"
    }
  ]
}
```

---

## Risk Engine Logic

The safety assessment pipeline combines an **AI Synthesis Layer** (Groq / LLaMA 3.3) with a **Deterministic Rules-Based Fallback Engine** (`services/risk_engine.py`).

```
                    ┌───────────────────────────────┐
                    │  Marine & Weather Telemetry   │
                    │  (Waves, Wind, Swell, UV, WQ) │
                    └───────────────┬───────────────┘
                                    │
                                    ▼
                     Is GROQ / LLM API Key present?
                     ├── NO ──► Fallback to Deterministic Rules Engine
                     │
                     └── YES ─► Call Groq API with 800ms Strict Timeout
                                    │
                       ┌────────────┴────────────┐
                       ▼                         ▼
                  [Success]             [Timeout / Failure]
               Return Validated                  │
               AI Risk Response                  ▼
                                     Fallback to Deterministic
                                           Rules Engine
```

### 1. AI Synthesis Layer (Groq / LLaMA 3.3)
- **Role**: Expert Ocean Safety Advisor for Indian Coastal Tourism.
- **Latency Control**: Protected by a strict **800ms asynchronous timeout** (`httpx.AsyncClient(timeout=0.8)`).
- **Format Enforcement**: Utilizes `response_format={"type": "json_object"}` and schema instructions to guarantee that outputs strictly validate against `schemas.risk.RiskAssessmentResponse`.

### 2. Deterministic Rules-Based Engine
When the LLM is unconfigured, times out, or encounters errors, the deterministic rules engine executes instantly with zero external dependencies.

#### Threshold & Hazard Trigger Matrix

| Metric | Normal Range | Intermediate Caution | Severe Trigger |
| :--- | :--- | :--- | :--- |
| **Wave Height ($H_s$)** | $< 1.0\text{ m}$ | $1.0\text{ m} \le H_s < 3.0\text{ m}$ | $\ge 3.0\text{ m}$ (or $\ge 3.5\text{ m}$ for severe) |
| **Wind Speed ($V$)** | $< 20\text{ km/h}$ | $20\text{ km/h} \le V < 55\text{ km/h}$ | $\ge 55\text{ km/h}$ (or $\ge 60\text{ km/h}$ for severe) |
| **Swell Surge ($S$)** | $< 1.5\text{ m}$ | $1.5\text{ m} \le S < 2.5\text{ m}$ | $\ge 2.5\text{ m}$ (or $\ge 3.0\text{ m}$ for severe) |
| **UV Radiation Index** | $< 6.0$ (Low/Moderate) | $6.0 \le \text{UV} < 11.0$ (High/Very High) | $\ge 11.0$ (Extreme) |
| **Water Quality** | `Good`, `Excellent` | `Moderate` | `Poor`, `Hazardous`, `Contaminated`, `Bad` |

#### Output State Classifications

| State | Severity Level | Conditions & Operational Directive |
| :--- | :--- | :--- |
| `NORMAL` | Low Risk (Green) | Calm seas ($H_s < 1.0\text{ m}$), gentle breezes. Water activities fully permitted. |
| `INTERMEDIATE_LOW` | Low-Moderate Caution (Green/Amber) | Mild surf ($H_s \ge 1.0\text{ m}$), wind $\ge 20\text{ km/h}$, or UV $\ge 6.0$. Normal vigilance recommended. |
| `INTERMEDIATE_MED` | Moderate Caution (Amber) | Waves $\ge 1.5\text{ m}$, wind $\ge 30\text{ km/h}$, UV $\ge 8.0$, or degraded water quality. Bathing permitted only in designated safe zones. |
| `INTERMEDIATE_HIGH` | High Caution (Amber/Red) | Waves $\ge 2.2\text{ m}$, wind $\ge 45\text{ km/h}$, or swell $\ge 2.0\text{ m}$. Swimming strongly discouraged; heed lifeguard flags. |
| `SEVERE` | High Risk / Hazard (Red) | Life-threatening surf ($H_s \ge 3.5\text{ m}$), gale winds ($\ge 60\text{ km/h}$), or compounded storm hazards. Beach closed to public. |

---

## Local Setup Instructions

### Prerequisites
- **Python**: Version 3.10+ (Recommended: Python 3.11 or 3.12)
- **C/C++ Build Tools**: Required for Shapely GEOS binaries (pre-built on standard wheels).

### Step-by-Step Installation

1. **Clone the repository and enter the backend directory**:
   ```bash
   git clone https://github.com/your-org/sih1656_beach_safety.git
   cd sih1656_beach_safety/backend
   ```

2. **Create and activate a virtual environment**:
   ```bash
   # Linux / macOS
   python3 -m venv venv
   source venv/bin/activate

   # Windows (Command Prompt / PowerShell)
   python -m venv venv
   .\venv\Scripts\activate
   ```

3. **Install dependencies**:
   ```bash
   pip install --upgrade pip
   pip install -r requirements.txt
   ```

4. **Set up your environment variables**:
   Create a `.env` file in the project root (`../.env`) or within the `backend/` directory:
   ```bash
   cp .env.example .env  # or edit .env directly
   ```

---

### Running the Server

Start the local development server with auto-reload:

```bash
uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

Once started, access:
- **Interactive OpenAPI Documentation (Swagger UI)**: [http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)
- **Alternative Documentation (ReDoc)**: [http://127.0.0.1:8000/redoc](http://127.0.0.1:8000/redoc)
- **Health Check**: [http://127.0.0.1:8000/health](http://127.0.0.1:8000/health)

---

### Triggering Demo & Edge-Case Configurations

You can switch operational modes without external API keys using `.env` toggles or by passing environment variables directly into the run command:

#### Configuration A: Live Provider Mode (Default)
Queries live third-party APIs (Tomorrow.io, OpenWeather, Open-Meteo, INCOIS) with cascaded fallbacks:
```env
USE_MOCK_DATA=false
ENABLE_EXTREMES_MOCK=false
```
```bash
uvicorn main:app --reload
```

#### Configuration B: Calm Baseline Demo Mode
Returns synthetic, low-risk conditions (Green status, safe surf, moderate UV) for offline demonstrations:
```env
USE_MOCK_DATA=true
ENABLE_EXTREMES_MOCK=false
```
```bash
USE_MOCK_DATA=true ENABLE_EXTREMES_MOCK=false uvicorn main:app --reload
```

#### Configuration C: Extreme Hazard & Gale Storm Surge Demo Mode
Simulates cyclonic swells ($4.85\text{ m}$), gale-force winds ($68.4\text{ km/h}$), extreme UV index ($12.2$), and active red-flag warnings:
```env
USE_MOCK_DATA=true
ENABLE_EXTREMES_MOCK=true
```
```bash
USE_MOCK_DATA=true ENABLE_EXTREMES_MOCK=true uvicorn main:app --reload
```

---

### Testing Endpoints via cURL

#### 1. Check Server Health
```bash
curl -X GET http://127.0.0.1:8000/health
```

#### 2. Get All Beaches
```bash
curl -X GET http://127.0.0.1:8000/beaches
```

#### 3. Get Real-Time Weather & Risk Profile for Juhu Beach
```bash
curl -X GET http://127.0.0.1:8000/beaches/juhu/weather
```

#### 4. Get Weather for Marina Beach or Radhanagar Beach
```bash
curl -X GET http://127.0.0.1:8000/beaches/marina/weather
curl -X GET http://127.0.0.1:8000/beaches/radhanagar/weather
```
