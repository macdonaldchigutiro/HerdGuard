# HerdGuard - backend

Live simulated herd (12 animals), geofence, fever and low-battery alerts.

## Run (Windows)
    cd herdguard_backend
    python -m venv venv
    venv\Scripts\activate
    pip install -r requirements.txt
    python -m uvicorn main:app --reload --host 0.0.0.0

Check it: http://127.0.0.1:8000/api/state  (live JSON)
API docs:  http://127.0.0.1:8000/docs  (you can press the demo buttons there too)

## Demo buttons (the app has these in its menu)
- POST /api/demo/theft   one animal runs out of the fence fast
- POST /api/demo/fever   one animal's temperature climbs and activity drops
- POST /api/demo/reset

## Connecting real tags (later)
Your GPS tags or LoRa gateway send readings to POST /api/ingest with the header
X-API-Key (set HERDGUARD_API_KEY). Body:
    {"tag_id": "COW-17", "lat": -17.83, "lon": 31.05, "temp_c": 38.7,
     "battery": 81, "activity": 42}
Set FARM_ORIGIN_LAT and FARM_ORIGIN_LON to your farm's south-west corner and
edit FENCE in main.py to match your paddock (in metres from that corner).

Typical hardware: ESP32 + GPS module + temperature sensor + LoRa radio,
reporting to a LoRa gateway on the farm.

## Note
State is held in memory and resets when the server restarts. Add a database
(SQLite or PostgreSQL/TimescaleDB) when you want history.
