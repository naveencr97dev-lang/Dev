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

# Spin bowlers in the pool (everyone else who bowls is treated as pace).
SPINNERS = set("""Axar Patel; Kuldeep Yadav; Noor Ahmad; Rashid Khan; Ravindra Jadeja; Sunil Narine;
Varun Chakaravarthy; Yuzvendra Chahal; Will Jacks; Liam Livingstone; Wanindu Hasaranga; Abhishek Sharma;
Riyan Parag; Ravi Bishnoi; Krunal Pandya; Mitch Santner; Washington Sundar; Akeal Hosein; Maheesh Theekshana;
Rahul Chahar; Jacob Bethell; Rahul Tewatia; Digvesh Singh Rathi; Shahbaz Ahmed; Rachin Ravindra; Sai Kishore;
Harpreet Brar; Mayank Markande; Suyash Sharma; Swapnil Singh; AM Ghazanfar; Kamindu Mendis; Jayant Yadav;
Anukul Roy; Manimaran Siddharth; Harsh Dubey; Shreyas Gopal; Zeeshan Ansari; Vipraj Nigam; Karn Sharma;
Kumar Kartikeya Singh; Prashant Solanki; Vignesh Puthur; Keshav Maharaj; George Linde; Praveen Dubey;
Mahipal Lomror; Cooper Connolly; Rehan Ahmed; Raghu Sharma; Manav Suthar; Kanishk Chouhan; Vicky Ostwal;
Musheer Khan; Prashant Veer; Glenn Phillips; Aiden Markram""".replace("\n", " ").split("; "))

# Legend traits: how a star plays, used by the match engine for matchups.
TRAITS = {
    "Virat Kohli": ["anchor", "chaseMaster"],
    "Rohit Sharma": ["powerplayBlitz", "powerHitter"],
    "Suryakumar Yadav": ["threeSixty"],
    "Heinrich Klaasen": ["spinBasher", "powerHitter"],
    "Jos Buttler": ["powerplayBlitz", "chaseMaster"],
    "Travis Head": ["powerplayBlitz", "paceBasher"],
    "Abhishek Sharma": ["powerplayBlitz"],
    "KL Rahul": ["anchor"],
    "Shubman Gill": ["anchor"],
    "Sai Sudharsan": ["anchor"],
    "Yashasvi Jaiswal": ["powerplayBlitz"],
    "Phil Salt": ["powerplayBlitz"],
    "Nicholas Pooran": ["powerHitter", "spinBasher"],
    "Rishabh Pant": ["spinBasher"],
    "Mahendra Singh Dhoni": ["finisher", "chaseMaster"],
    "Hardik Pandya": ["finisher"],
    "Tim David": ["finisher", "powerHitter"],
    "David Miller": ["finisher", "chaseMaster"],
    "Rinku Singh": ["finisher"],
    "Shimron Hetmyer": ["finisher"],
    "Shivam Dube": ["spinBasher"],
    "Tristan Stubbs": ["finisher"],
    "Vaibhav Sooryavanshi": ["powerplayBlitz"],
    "Priyansh Arya": ["powerplayBlitz"],
    "Sanju Samson": ["spinBasher"],
    "Shreyas Iyer": ["spinBasher", "anchor"],
    "Ruturaj Gaikwad": ["anchor"],
    "Tilak Varma": ["chaseMaster"],
    "Quinton De Kock": ["powerplayBlitz"],
    "Liam Livingstone": ["powerHitter"],
    "Sunil Narine": ["powerplayBlitz", "mysterySpin", "economical"],
    "Ashutosh Sharma": ["finisher"],
    "Shashank Singh": ["finisher"],
    "Rajat Patidar": ["spinBasher"],
    "Mitch Marsh": ["paceBasher"],
    "Prabhsimran Singh": ["powerplayBlitz"],
    "Jasprit Bumrah": ["deathSpecialist", "economical"],
    "Rashid Khan": ["mysterySpin", "economical"],
    "Varun Chakaravarthy": ["mysterySpin"],
    "Yuzvendra Chahal": ["wicketTaker"],
    "Kuldeep Yadav": ["wicketTaker"],
    "Mitchell Starc": ["newBallSwing", "deathSpecialist"],
    "Trent Boult": ["newBallSwing"],
    "Bhuvneshwar Kumar": ["newBallSwing", "economical"],
    "Deepak Chahar": ["newBallSwing"],
    "Arshdeep Singh": ["deathSpecialist", "newBallSwing"],
    "Matheesha Pathirana": ["deathSpecialist"],
    "Josh Hazlewood": ["economical", "newBallSwing"],
    "Pat Cummins": ["economical"],
    "Mohammed Shami": ["newBallSwing"],
    "Mohammed Siraj": ["newBallSwing"],
    "Kagiso Rabada": ["wicketTaker"],
    "Jofra Archer": ["expressPace", "deathSpecialist"],
    "Harshal Patel": ["deathSpecialist"],
    "Thangarasu Natarajan": ["deathSpecialist"],
    "Ravindra Jadeja": ["economical"],
    "Axar Patel": ["economical"],
    "Wanindu Hasaranga": ["wicketTaker"],
    "Noor Ahmad": ["mysterySpin"],
    "Ravi Bishnoi": ["wicketTaker"],
    "Sam Curran": ["newBallSwing"],
    "Lockie Ferguson": ["expressPace"],
    "Mayank Yadav": ["expressPace"],
    "Umran Malik": ["expressPace"],
    "Anrich Nortje": ["expressPace"],
    "Mustafizur Rahman": ["deathSpecialist"],
    "Sandeep Sharma": ["deathSpecialist"],
}

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
            "bowlType": "spin" if p["name"] in SPINNERS else "pace",
            "traits": TRAITS.get(p["name"], []),
        })
    missing = (set(TRAITS) | SPINNERS) - {o["name"] for o in out}
    if missing:
        print("not in pool (ignored):", sorted(missing))
    json.dump(out, open("ios/Resources/players.json", "w"), indent=1, ensure_ascii=False)
    print(len(out), "players written")

if __name__ == "__main__":
    main(sys.argv[1])
