"""
HerdGuard backend.

Runs a live SIMULATED herd so you can build and demo the app with no hardware.
Real GPS tags can send readings to POST /api/ingest (see README).
"""
import asyncio
import math
import os
import random
import time
import uuid
from collections import deque
from contextlib import asynccontextmanager
from typing import Optional

from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

API_KEY = os.getenv("HERDGUARD_API_KEY", "dev-key")
# Real GPS: set these to the south-west corner of your farm (used by /api/ingest).
ORIGIN_LAT = float(os.getenv("FARM_ORIGIN_LAT", "0.0"))
ORIGIN_LON = float(os.getenv("FARM_ORIGIN_LON", "0.0"))

# The farm is drawn in metres. Fence = paddock boundary.
FENCE = [(90, 70), (700, 50), (790, 420), (140, 470)]
BOUNDS = (-60, -20, 960, 540)  # min x, min y, max x, max y shown on the radar
THEFT_TARGET = (930, 250)

NAMES = ["Bella", "Daisy", "Nala", "Sipho", "Zuri", "Thandi", "Mabel",
         "Rosie", "Ruby", "Duke", "Bruno", "Chief"]

HERD = {}
ALERTS = []
ALERT_INDEX = {}  # (animal_id, kind) -> active alert


def inside(x, y, poly=FENCE):
    """Point-in-polygon test (ray casting)."""
    c = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            c = not c
        j = i
    return c


def random_point_inside():
    while True:
        x, y = random.uniform(100, 780), random.uniform(60, 460)
        if inside(x, y):
            return x, y


def new_animal(i, name):
    x, y = random_point_inside()
    return {
        "id": f"a{i:02d}", "tag": f"T-{i:03d}", "name": name,
        "x": x, "y": y, "heading": random.uniform(0, math.tau),
        "speed": 0.0, "temp": 38.6 + random.uniform(-0.2, 0.2),
        "activity": 40.0, "battery": random.uniform(55, 98),
        "mode": "normal", "trail": deque(maxlen=24), "last_seen": time.time(),
    }


def reset():
    HERD.clear()
    ALERTS.clear()
    ALERT_INDEX.clear()
    for i, name in enumerate(NAMES, 1):
        a = new_animal(i, name)
        HERD[a["id"]] = a
    list(HERD.values())[3]["battery"] = 13.0  # one tag starts low on battery


def move(a):
    mode = a["mode"]
    if mode == "theft":
        tx, ty = THEFT_TARGET
        dx, dy = tx - a["x"], ty - a["y"]
        dist = math.hypot(dx, dy)
        step = min(9.0, dist)
        if dist > 0.5:
            a["x"] += dx / dist * step
            a["y"] += dy / dist * step
        a["speed"] = step
    else:
        speed = 0.4 if mode == "fever" else random.uniform(0.2, 1.6)
        a["heading"] += random.uniform(-0.6, 0.6)
        nx = a["x"] + math.cos(a["heading"]) * speed * 2
        ny = a["y"] + math.sin(a["heading"]) * speed * 2
        if inside(nx, ny):
            a["x"], a["y"] = nx, ny
        else:
            a["heading"] += math.pi * random.uniform(0.6, 1.4)
        a["speed"] = speed

    temp_target = {"fever": 40.8, "theft": 38.9}.get(mode, 38.6)
    a["temp"] += (temp_target - a["temp"]) * 0.08 + random.uniform(-0.03, 0.03)
    act_target = min(100.0, a["speed"] * 45)
    if mode == "fever":
        act_target *= 0.4
    a["activity"] += (act_target - a["activity"]) * 0.3
    a["battery"] = max(0.0, a["battery"] - 0.01)


def describe(a, kind):
    n = a["name"]
    if kind == "fence":
        if a["speed"] > 4:
            return "critical", f"Possible theft: {n} is moving fast outside the fence"
        return "critical", f"{n} has left the paddock"
    if kind == "fever":
        return "warning", f"{n} may have a fever ({a['temp']:.1f} °C)"
    if kind == "inactive":
        return "warning", f"{n} has not moved for a while"
    return "info", f"{n}'s tag battery is low ({a['battery']:.0f}%)"


def evaluate():
    for a in HERD.values():
        conds = {
            "fence": not inside(a["x"], a["y"]),
            "fever": a["temp"] >= 39.6,
            "inactive": a["mode"] == "live" and a["activity"] < 5,
            "battery": a["battery"] < 15,
        }
        for kind, on in conds.items():
            key = (a["id"], kind)
            current = ALERT_INDEX.get(key)
            if on and current is None:
                severity, message = describe(a, kind)
                alert = {
                    "id": uuid.uuid4().hex[:8], "animal_id": a["id"],
                    "kind": kind, "severity": severity, "message": message,
                    "ts": time.time(), "acknowledged": False, "active": True,
                }
                ALERTS.append(alert)
                ALERT_INDEX[key] = alert
                del ALERTS[:-60]
            elif not on and current is not None:
                current["active"] = False
                del ALERT_INDEX[key]


def status_of(animal_id):
    sev = [al["severity"] for (aid, _), al in ALERT_INDEX.items() if aid == animal_id]
    if "critical" in sev:
        return "critical"
    if "warning" in sev:
        return "warning"
    return "ok"


def alarm_of(animal_id):
    return any(
        aid == animal_id and al["severity"] == "critical" and not al["acknowledged"]
        for (aid, _), al in ALERT_INDEX.items()
    )


def tick():
    for a in HERD.values():
        if a["mode"] != "live":
            move(a)
            a["last_seen"] = time.time()
        a["trail"].append((round(a["x"], 1), round(a["y"], 1)))
    evaluate()


async def loop():
    while True:
        tick()
        await asyncio.sleep(1)


@asynccontextmanager
async def lifespan(app):
    reset()
    task = asyncio.create_task(loop())
    yield
    task.cancel()


app = FastAPI(title="HerdGuard API", lifespan=lifespan)
app.add_middleware(
    CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"]
)


@app.get("/api/state")
def state():
    animals = [{
        "id": a["id"], "tag": a["tag"], "name": a["name"],
        "x": round(a["x"], 1), "y": round(a["y"], 1),
        "temp": round(a["temp"], 1), "activity": round(a["activity"]),
        "battery": round(a["battery"]), "speed": round(a["speed"], 1),
        "status": status_of(a["id"]), "alarm": alarm_of(a["id"]),
        "last_seen": a["last_seen"], "trail": list(a["trail"]),
    } for a in HERD.values()]
    alerts = sorted(ALERTS, key=lambda al: al["ts"], reverse=True)[:30]
    return {
        "fence": [list(p) for p in FENCE], "bounds": list(BOUNDS),
        "animals": animals, "alerts": alerts, "server_time": time.time(),
    }


@app.post("/api/alerts/{alert_id}/ack")
def acknowledge(alert_id: str):
    for al in ALERTS:
        if al["id"] == alert_id:
            al["acknowledged"] = True
            return {"ok": True}
    raise HTTPException(404, "Alert not found")


@app.post("/api/animals/{animal_id}/safe")
def mark_safe(animal_id: str):
    for (aid, _), al in ALERT_INDEX.items():
        if aid == animal_id:
            al["acknowledged"] = True
    return {"ok": True}


def pick_normal():
    pool = [a for a in HERD.values() if a["mode"] == "normal"]
    if not pool:
        raise HTTPException(409, "No normal animals left. Reset the demo.")
    return random.choice(pool)


@app.post("/api/demo/theft")
def demo_theft():
    a = pick_normal()
    a["mode"] = "theft"
    return {"animal": a["name"]}


@app.post("/api/demo/fever")
def demo_fever():
    a = pick_normal()
    a["mode"] = "fever"
    return {"animal": a["name"]}


@app.post("/api/demo/reset")
def demo_reset():
    reset()
    return {"ok": True}


class Reading(BaseModel):
    tag_id: str
    lat: float
    lon: float
    temp_c: Optional[float] = None
    battery: Optional[float] = None
    activity: Optional[float] = None


def latlon_to_xy(lat, lon):
    x = (lon - ORIGIN_LON) * 111320 * math.cos(math.radians(ORIGIN_LAT))
    y = (lat - ORIGIN_LAT) * 110540
    return x, y


@app.post("/api/ingest")
def ingest(r: Reading, x_api_key: str = Header(default="")):
    """Real tags (via your gateway) post readings here."""
    if x_api_key != API_KEY:
        raise HTTPException(401, "Bad API key")
    aid = f"live-{r.tag_id}"
    x, y = latlon_to_xy(r.lat, r.lon)
    now = time.time()
    a = HERD.get(aid)
    if a is None:
        a = {
            "id": aid, "tag": r.tag_id, "name": r.tag_id, "x": x, "y": y,
            "heading": 0.0, "speed": 0.0, "temp": 38.6, "activity": 30.0,
            "battery": 100.0, "mode": "live", "trail": deque(maxlen=24),
            "last_seen": now,
        }
        HERD[aid] = a
    dt = max(now - a["last_seen"], 0.001)
    a["speed"] = math.hypot(x - a["x"], y - a["y"]) / dt
    a["x"], a["y"], a["last_seen"] = x, y, now
    if r.temp_c is not None:
        a["temp"] = r.temp_c
    if r.battery is not None:
        a["battery"] = r.battery
    if r.activity is not None:
        a["activity"] = r.activity
    return {"ok": True}
