#!/usr/bin/env python3
"""
Formula 1 Data Service for Omarchy Quickshell Plugin (mush.f1)
Fetches next race schedule, driver & constructor standings from Ergast/Jolpica F1 API,
formats local times and countdowns, manages desktop notifications, and caches data.
"""

import os
import sys
import json
import time
import urllib.request
import urllib.error
import datetime
import subprocess
from pathlib import Path

CACHE_DIR = Path.home() / ".cache" / "omarchy-f1"
SETTINGS_DIR = Path.home() / ".config" / "omarchy" / "settings"
CACHE_FILE = CACHE_DIR / "data.json"
RAW_CACHE_FILE = CACHE_DIR / "raw.json"
NOTIFIED_FILE = CACHE_DIR / "notified.json"
SETTINGS_FILE = SETTINGS_DIR / "f1.json"

COUNTRY_MAP = {
    "italy": {"code": "ITA", "flag": "🇮🇹"},
    "monaco": {"code": "MON", "flag": "🇲🇨"},
    "united kingdom": {"code": "GBR", "flag": "🇬🇧"},
    "great britain": {"code": "GBR", "flag": "🇬🇧"},
    "uk": {"code": "GBR", "flag": "🇬🇧"},
    "belgium": {"code": "BEL", "flag": "🇧🇪"},
    "netherlands": {"code": "NLD", "flag": "🇳🇱"},
    "spain": {"code": "ESP", "flag": "🇪🇸"},
    "austria": {"code": "AUT", "flag": "🇦🇹"},
    "hungary": {"code": "HUN", "flag": "🇭🇺"},
    "singapore": {"code": "SGP", "flag": "🇸🇬"},
    "japan": {"code": "JPN", "flag": "🇯🇵"},
    "united states": {"code": "USA", "flag": "🇺🇸"},
    "usa": {"code": "USA", "flag": "🇺🇸"},
    "mexico": {"code": "MEX", "flag": "🇲🇽"},
    "brazil": {"code": "BRA", "flag": "🇧🇷"},
    "australia": {"code": "AUS", "flag": "🇦🇺"},
    "bahrain": {"code": "BHR", "flag": "🇧🇭"},
    "saudi arabia": {"code": "SAU", "flag": "🇸🇦"},
    "azerbaijan": {"code": "AZE", "flag": "🇦🇿"},
    "canada": {"code": "CAN", "flag": "🇨🇦"},
    "china": {"code": "CHN", "flag": "🇨🇳"},
    "qatar": {"code": "QAT", "flag": "🇶🇦"},
    "uae": {"code": "UAE", "flag": "🇦🇪"},
    "united arab emirates": {"code": "UAE", "flag": "🇦🇪"},
}

TEAM_COLORS = {
    "mercedes": "#00D2BE",
    "ferrari": "#E8002D",
    "red_bull": "#3671C6",
    "mclaren": "#FF8000",
    "aston_martin": "#229971",
    "alpine": "#0093CC",
    "williams": "#64C4FF",
    "rb": "#6692FF",
    "racing_bulls": "#6692FF",
    "sauber": "#52E252",
    "kick_sauber": "#52E252",
    "haas": "#B6BABD",
}

SESSION_DURATIONS = {
    "fp1": 3600,
    "fp2": 3600,
    "fp3": 3600,
    "sprint_qualifying": 3600,
    "sprint": 2700,
    "qualifying": 3600,
    "race": 7200,
}

def ensure_dirs():
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    SETTINGS_DIR.mkdir(parents=True, exist_ok=True)

def load_settings():
    ensure_dirs()
    if SETTINGS_FILE.exists():
        try:
            with open(SETTINGS_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {"notifications_enabled": True, "notify_15m": True, "notify_live": True}

def save_settings(s):
    ensure_dirs()
    with open(SETTINGS_FILE, "w", encoding="utf-8") as f:
        json.dump(s, f, indent=2)

def load_notified():
    if NOTIFIED_FILE.exists():
        try:
            with open(NOTIFIED_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {}

def save_notified(n):
    with open(NOTIFIED_FILE, "w", encoding="utf-8") as f:
        json.dump(n, f, indent=2)

def send_notification(headline, body, glyph="🏎️", urgency="normal"):
    cmd = [
        "omarchy-notification-send",
        "--app-name", "Formula 1",
        "-g", glyph,
        "-u", urgency,
        headline,
        body
    ]
    try:
        subprocess.run(cmd, check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception as e:
        print(f"Error sending notification: {e}", file=sys.stderr)

def fetch_json(url, timeout=8):
    req = urllib.request.Request(
        url,
        headers={"User-Agent": "Omarchy-Quickshell-F1/1.0", "Accept": "application/json"}
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8"))

def parse_iso(date_str, time_str=""):
    time_clean = time_str.strip() if time_str else "12:00:00Z"
    if not time_clean.endswith("Z") and "+" not in time_clean and "-" not in time_clean[10:]:
        time_clean += "Z"
    iso_str = f"{date_str}T{time_clean}"
    try:
        return datetime.datetime.fromisoformat(iso_str)
    except Exception:
        dt = datetime.datetime.strptime(f"{date_str} {time_clean.rstrip('Z')}", "%Y-%m-%d %H:%M:%S")
        return dt.replace(tzinfo=datetime.timezone.utc)

def format_countdown(diff_seconds):
    if diff_seconds <= 0:
        return "LIVE NOW"
    days = int(diff_seconds // 86400)
    hours = int((diff_seconds % 86400) // 3600)
    mins = int((diff_seconds % 3600) // 60)
    if days > 0:
        return f"{days}d {hours}h"
    elif hours > 0:
        return f"{hours}h {mins}m"
    else:
        return f"{mins}m"

def process_f1_data(raw_data):
    now_utc = datetime.datetime.now(datetime.timezone.utc)
    now_ts = now_utc.timestamp()

    race_table = raw_data.get("next", {}).get("MRData", {}).get("RaceTable", {})
    races = race_table.get("Races", [])
    if not races:
        return None

    race = races[0]
    season = race.get("season", "2026")
    rnd = race.get("round", "1")
    race_name = race.get("raceName", "Grand Prix")
    circuit = race.get("Circuit", {})
    circuit_name = circuit.get("circuitName", "Circuit")
    location = circuit.get("Location", {})
    locality = location.get("locality", "")
    country = location.get("country", "")

    country_lower = country.lower()
    mapping = COUNTRY_MAP.get(country_lower, {})
    country_code = mapping.get("code", country[:3].upper() if country else "F1")
    country_flag = mapping.get("flag", "🏁")

    raw_sessions = [
        ("fp1", "Practice 1", "FP1", "practice", race.get("FirstPractice")),
        ("fp2", "Practice 2", "FP2", "practice", race.get("SecondPractice")),
        ("fp3", "Practice 3", "FP3", "practice", race.get("ThirdPractice")),
        ("sprint_qualifying", "Sprint Shootout", "Shootout", "qualifying", race.get("SprintQualifying")),
        ("sprint", "Sprint", "Sprint", "sprint", race.get("Sprint")),
        ("qualifying", "Qualifying", "Quali", "qualifying", race.get("Qualifying")),
        ("race", "Grand Prix", "Race", "race", {"date": race.get("date"), "time": race.get("time")}),
    ]

    sessions = []
    has_live = False
    active_session = None
    next_session = None

    for sid, sname, s_short, stype, sdata in raw_sessions:
        if not sdata or not sdata.get("date"):
            continue
        dt_utc = parse_iso(sdata.get("date"), sdata.get("time", ""))
        start_ts = dt_utc.timestamp()
        duration = SESSION_DURATIONS.get(sid, 3600)
        end_ts = start_ts + duration
        diff = start_ts - now_ts

        if now_ts > end_ts:
            status = "completed"
        elif start_ts <= now_ts <= end_ts:
            status = "live"
            has_live = True
        else:
            status = "upcoming"

        dt_local = dt_utc.astimezone()
        local_day = dt_local.strftime("%a")
        local_time_short = dt_local.strftime("%H:%M")
        local_time_full = dt_local.strftime("%a %b %d, %H:%M %Z")

        s_obj = {
            "id": sid,
            "name": sname,
            "shortName": s_short,
            "type": stype,
            "status": status,
            "startIso": dt_utc.isoformat(),
            "startTimestamp": start_ts,
            "endTimestamp": end_ts,
            "diffSeconds": int(diff),
            "countdownStr": format_countdown(diff) if status == "upcoming" else ("LIVE NOW" if status == "live" else "Done"),
            "localDay": local_day,
            "localTime": local_time_short,
            "localTimeFull": local_time_full,
        }
        sessions.append(s_obj)

        if status == "live" and not active_session:
            active_session = s_obj

    upcoming = [s for s in sessions if s["status"] == "upcoming"]
    upcoming.sort(key=lambda x: x["startTimestamp"])
    if upcoming:
        next_session = upcoming[0]

    if active_session:
        bar_text = f"🔴 LIVE · {active_session['shortName']}"
        pill_status = "live"
    elif next_session:
        if next_session["diffSeconds"] <= 86400:
            bar_text = f"🏎️ {country_code} · {next_session['shortName']} in {next_session['countdownStr']}"
        else:
            bar_text = f"🏎️ {country_code} · {next_session['shortName']} {next_session['localDay']} {next_session['localTime']}"
        pill_status = "upcoming"
    else:
        bar_text = f"🏎️ {race_name}"
        pill_status = "completed"

    driver_standings = []
    raw_drivers = raw_data.get("drivers", {}).get("MRData", {}).get("StandingsTable", {}).get("StandingsLists", [])
    if raw_drivers:
        d_list = raw_drivers[0].get("DriverStandings", [])
        for d in d_list[:15]:
            driver_info = d.get("Driver", {})
            constructors = d.get("Constructors", [])
            team_info = constructors[0] if constructors else {}
            team_id = team_info.get("constructorId", "").lower()
            team_name = team_info.get("name", "Unknown")
            driver_standings.append({
                "pos": d.get("position", ""),
                "code": driver_info.get("code", driver_info.get("familyName", "")[:3].upper()),
                "number": driver_info.get("permanentNumber", ""),
                "name": f"{driver_info.get('givenName', '')} {driver_info.get('familyName', '')}".strip(),
                "shortName": driver_info.get("familyName", ""),
                "team": team_name,
                "teamColor": TEAM_COLORS.get(team_id, "#cacccc"),
                "points": d.get("points", "0"),
                "wins": d.get("wins", "0"),
            })

    constructor_standings = []
    raw_constructors = raw_data.get("constructors", {}).get("MRData", {}).get("StandingsTable", {}).get("StandingsLists", [])
    if raw_constructors:
        c_list = raw_constructors[0].get("ConstructorStandings", [])
        for c in c_list[:10]:
            c_info = c.get("Constructor", {})
            c_id = c_info.get("constructorId", "").lower()
            constructor_standings.append({
                "pos": c.get("position", ""),
                "name": c_info.get("name", ""),
                "teamColor": TEAM_COLORS.get(c_id, "#cacccc"),
                "points": c.get("points", "0"),
                "wins": c.get("wins", "0"),
            })

    leader_text = ""
    if driver_standings:
        p1 = driver_standings[0]
        leader_text = f"\n🏆 P1: {p1['name']} ({p1['points']} pts)"

    next_info = ""
    if active_session:
        next_info = f"\n🔴 LIVE NOW: {active_session['name']}"
    elif next_session:
        next_info = f"\n⏰ Next: {next_session['name']} at {next_session['localTime']} ({next_session['countdownStr']})"

    tooltip = (
        f"🏎️ {race_name} (Round {rnd}/{season})\n"
        f"📍 {circuit_name} · {locality}, {country}"
        f"{next_info}"
        f"{leader_text}\n"
        f"💡 Click to open F1 Hub · Right-click for notification"
    )

    return {
        "season": season,
        "round": rnd,
        "raceName": race_name,
        "circuitName": circuit_name,
        "locality": locality,
        "country": country,
        "countryCode": country_code,
        "countryFlag": country_flag,
        "sessions": sessions,
        "isLive": has_live,
        "activeSession": active_session,
        "nextSession": next_session,
        "barText": bar_text,
        "pillStatus": pill_status,
        "tooltip": tooltip,
        "drivers": driver_standings,
        "constructors": constructor_standings,
        "lastUpdated": datetime.datetime.now().strftime("%H:%M:%S"),
        "lastUpdatedTs": int(now_ts),
    }

def check_notifications(data):
    settings = load_settings()
    if not settings.get("notifications_enabled", True):
        return

    notified = load_notified()
    changed = False
    season = data.get("season", "2026")
    rnd = data.get("round", "1")
    race_name = data.get("raceName", "Grand Prix")
    sessions = data.get("sessions", [])

    for s in sessions:
        sid = s["id"]
        sname = s["name"]
        diff = s["diffSeconds"]

        key_15m = f"{season}_{rnd}_{sid}_15m"
        if settings.get("notify_15m", True) and 0 <= diff <= 900:
            if key_15m not in notified:
                mins = max(1, int(diff // 60))
                send_notification(
                    f"F1 · {race_name}",
                    f"{sname} starts in {mins} minutes ({s['localTime']})!",
                    glyph="🏎️",
                    urgency="normal"
                )
                notified[key_15m] = time.time()
                changed = True

        key_live = f"{season}_{rnd}_{sid}_live"
        if settings.get("notify_live", True) and -180 <= diff <= 60:
            if key_live not in notified:
                title = "🟢 LIGHTS OUT!" if s["type"] == "race" else "🟢 Session Started"
                send_notification(
                    f"F1 · {race_name}",
                    f"{title} — {sname} is LIVE NOW!",
                    glyph="🏁",
                    urgency="critical"
                )
                notified[key_live] = time.time()
                changed = True

    if changed:
        save_notified(notified)

def run_fetch():
    ensure_dirs()
    raw_data = {}

    try:
        raw_next = fetch_json("https://api.jolpi.ca/ergast/f1/current/next.json", timeout=6)
        raw_drivers = fetch_json("https://api.jolpi.ca/ergast/f1/current/driverStandings.json", timeout=6)
        raw_constructors = fetch_json("https://api.jolpi.ca/ergast/f1/current/constructorStandings.json", timeout=6)
        raw_data = {
            "next": raw_next,
            "drivers": raw_drivers,
            "constructors": raw_constructors
        }
        with open(RAW_CACHE_FILE, "w", encoding="utf-8") as f:
            json.dump(raw_data, f)
    except Exception as e:
        print(f"Network fetch warning: {e}. Falling back to cached data.", file=sys.stderr)
        if RAW_CACHE_FILE.exists():
            try:
                with open(RAW_CACHE_FILE, "r", encoding="utf-8") as f:
                    raw_data = json.load(f)
            except Exception as read_err:
                print(f"Error reading raw cache: {read_err}", file=sys.stderr)

    if not raw_data:
        print("No F1 data available (offline and no cache)", file=sys.stderr)
        return False

    processed = process_f1_data(raw_data)
    if not processed:
        return False

    check_notifications(processed)

    temp_file = CACHE_DIR / "data.json.tmp"
    with open(temp_file, "w", encoding="utf-8") as f:
        json.dump(processed, f, indent=2)
    temp_file.replace(CACHE_FILE)

    print(f"F1 data updated: {processed['barText']}")
    return True

def run_test_notify():
    send_notification(
        "Formula 1 Alert Active",
        "Omarchy F1 Hub is active! You will be notified before race sessions.",
        glyph="🏎️",
        urgency="normal"
    )
    print("Test notification sent.")

def run_quick_notify():
    if not CACHE_FILE.exists():
        run_fetch()
    if CACHE_FILE.exists():
        try:
            with open(CACHE_FILE, "r", encoding="utf-8") as f:
                d = json.load(f)
            if d.get("isLive") and d.get("activeSession"):
                send_notification(
                    f"F1 · {d['raceName']}",
                    f"🔴 LIVE NOW: {d['activeSession']['name']} at {d['circuitName']}",
                    glyph="🏁",
                    urgency="critical"
                )
            elif d.get("nextSession"):
                ns = d["nextSession"]
                send_notification(
                    f"F1 · {d['raceName']}",
                    f"Next: {ns['name']} at {ns['localTime']} ({ns['countdownStr']})",
                    glyph="🏎️",
                    urgency="normal"
                )
            else:
                send_notification(
                    f"F1 · {d['raceName']}",
                    f"Round {d['round']} at {d['circuitName']}",
                    glyph="🏎️",
                    urgency="normal"
                )
        except Exception as e:
            print(f"Error in quick-notify: {e}", file=sys.stderr)

def run_toggle_notify():
    s = load_settings()
    s["notifications_enabled"] = not s.get("notifications_enabled", True)
    save_settings(s)
    state = "ENABLED" if s["notifications_enabled"] else "DISABLED"
    send_notification(
        "F1 Notification Settings",
        f"Formula 1 race alerts are now {state}.",
        glyph="🔔",
        urgency="low"
    )
    print(f"Notifications are now {state}.")

if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else "fetch"
    if action == "fetch":
        run_fetch()
    elif action == "notify-test" or action == "test-notify":
        run_test_notify()
    elif action == "quick-notify":
        run_quick_notify()
    elif action == "toggle-notify":
        run_toggle_notify()
    else:
        print(f"Unknown action: {action}. Available: fetch, notify-test, quick-notify, toggle-notify")
