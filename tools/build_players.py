"""Build ios/Resources/players.json from the Crick Auction player list (Apache-2.0).

Usage: python3 -I tools/build_players.py <path-to-crick-auction>/src/data/players.js

Reads the file as plain JSON data (nothing is executed), drops image URLs, and
derives separate batting / bowling ratings (0-100) from career stats so the
match engine can tell a batter from a bowler.
"""
import json, sys

def clamp(v, lo, hi):
    return max(lo, min(hi, v))

ROLE = {"Batsman": "BAT", "Batter": "BAT", "Bowler": "BOWL",
        "All-Rounder": "AR", "Wicket-Keeper": "WK"}

def bat_rating(p, role):
    s = p.get("stats") or {}
    base = {"BAT": 45, "WK": 42, "AR": 38, "BOWL": 14}[role]
    if s.get("sr") and s.get("runs") is not None:
        avg = s.get("avg") or (s["runs"] / max(s.get("matches", 1), 1))
        raw = clamp(avg / 40, 0, 1.25) * 45 + clamp(s["sr"] / 150, 0, 1.2) * 45
        w = clamp(s.get("matches", 0) / 40, 0, 1)
        stat = w * raw + (1 - w) * base
    else:
        stat = base
    if role in ("BAT", "WK"):
        val = 0.5 * stat + 0.5 * p["rating"]
    elif role == "AR":
        val = 0.6 * stat + 0.4 * (p["rating"] - 6)
    else:
        val = stat
    return int(round(clamp(val, 8, 96)))

def bowl_rating(p, role):
    s = p.get("stats") or {}
    base = {"BOWL": 45, "AR": 40, "BAT": 10, "WK": 4}[role]
    if s.get("econ") and s.get("wickets") is not None:
        m = max(s.get("matches", 1), 1)
        raw = clamp(100 - (s["econ"] - 6) * 15, 20, 100) * 0.6 + clamp(s["wickets"] / m * 60, 0, 100) * 0.4
        w = clamp(m / 30, 0, 1)
        stat = w * raw + (1 - w) * base
    else:
        stat = base
    if role == "BOWL":
        val = 0.5 * stat + 0.5 * p["rating"]
    elif role == "AR":
        val = 0.6 * stat + 0.4 * (p["rating"] - 6)
    else:
        val = stat
    return int(round(clamp(val, 3, 96)))

def pool(p, role):
    st = p["set"]
    if st == "Marquee Set 1":
        return "Marquee"
    if st.startswith("U") or st.startswith("Uncapped"):
        return "Uncapped"
    return {"BAT": "Batters", "AR": "All-rounders", "WK": "Wicket-keepers", "BOWL": "Bowlers"}[role]

def line(s):
    parts = [f"{s.get('matches', 0)} M"]
    if s.get("runs") is not None:
        parts.append(f"{s['runs']} runs")
        if s.get("sr"):
            parts.append(f"SR {s['sr']:.0f}")
    if s.get("wickets") is not None:
        parts.append(f"{s['wickets']} wkts")
        if s.get("econ"):
            parts.append(f"Econ {s['econ']:.2f}")
    return " · ".join(parts)

def main(path):
    src = open(path, encoding="utf-8").read()
    data = json.loads(src[src.index("["): src.rindex("]") + 1])
    out, seen = [], set()
    for p in data:
        if p["name"] in seen:
            continue
        seen.add(p["name"])
        role = ROLE[p["role"]]
        out.append({
            "id": p["id"],
            "name": p["name"],
            "role": role,
            "overseas": p["type"] == "Overseas",
            "country": p["country"] if p["country"] != "OS" else "",
            "base": int(round(p["basePrice"] * 100)),  # lakhs
            "pool": pool(p, role),
            "rating": int(clamp(p["rating"], 20, 99)),
            "bat": bat_rating(p, role),
            "bowl": bowl_rating(p, role),
            "line": line(p.get("stats") or {}),
        })
    json.dump(out, open("ios/Resources/players.json", "w"), indent=1, ensure_ascii=False)
    print(len(out), "players written")

if __name__ == "__main__":
    main(sys.argv[1])
