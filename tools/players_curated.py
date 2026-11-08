"""Curated Auction XI player pool: today's best T20 players plus retired IPL legends.

Ratings (0-100) and traits are this game's own judgement of each player's T20/IPL
career and style — not official figures. Career notes are approximate.

Run from the repo root:  python3 tools/players_curated.py
Writes ios/Resources/players.json.

Row format:
  name | role | country | bowl type | bat | bowl | preferred batting slot | traits | era | note
  role: BAT WK AR BOWL · bowl type: pace / spin · slot: open top middle finish lower
  era: L = retired IPL legend, C = current
"""
import json, re

ROWS = r"""
# ---------------- Batters ----------------
Sachin Tendulkar|BAT|IND|spin|86|20|open|anchor,technician,bigMatch|L|Orange Cap 2010 · IPL title 2013
Chris Gayle|BAT|WI|spin|92|25|open|powerHitter,powerplayBlitz,flatTrackBully|L|~4,965 IPL runs at SR ~148 · 175* record
AB de Villiers|BAT|SA|pace|93|10|middle|threeSixty,finisher,shortBallKing|L|~5,160 IPL runs at SR ~152 · Mr 360
David Warner|BAT|AUS|pace|89|5|open|powerplayBlitz,paceBasher,chaseMaster|L|~6,560 IPL runs · 3× Orange Cap · 2016 title captain
Suresh Raina|BAT|IND|spin|85|35|top|spinBasher,bigMatch|L|~5,530 IPL runs · "Mr IPL" · 4 titles
Virender Sehwag|BAT|IND|spin|84|20|open|powerplayBlitz,flatTrackBully|L|IPL SR ~155 · 122 off 58 in 2014 Q2
Gautam Gambhir|BAT|IND|spin|80|5|open|anchor,bigMatch|L|~4,220 IPL runs · 2× title-winning captain
Shikhar Dhawan|BAT|IND|spin|82|10|open|anchor,technician|L|~6,770 IPL runs · Mr Consistent
Yuvraj Singh|BAT|IND|spin|80|45|middle|powerHitter,spinBasher|L|Two IPL hat-tricks · big-hitting left-hander
Faf du Plessis|BAT|SA|spin|83|5|open|anchor,technician,bigMatch|L|~4,770 IPL runs · 86 in the 2021 Final
Kevin Pietersen|BAT|ENG|spin|80|20|top|threeSixty,paceBasher|L|Switch-hit pioneer · IPL hundred 2012
Brendon McCullum|BAT|NZ|pace|82|5|open|powerplayBlitz,powerHitter|L|158* in the very first IPL match
Matthew Hayden|BAT|AUS|pace|82|5|open|powerplayBlitz,paceBasher|L|Orange Cap 2009 · Mongoose bat
Michael Hussey|BAT|AUS|pace|79|10|top|anchor,chaseMaster,technician|L|Orange Cap 2013 · Mr Cricket
Ambati Rayudu|BAT|IND|spin|77|10|middle|spinBasher,chaseMaster|L|6 IPL titles · 2018 comeback season
Robin Uthappa|BAT|IND|pace|78|5|open|powerplayBlitz,bigMatch|L|Orange Cap 2014 · 2 titles
Shaun Marsh|BAT|AUS|pace|80|5|open|anchor,technician|L|Orange Cap 2008 (616 runs)
Murali Vijay|BAT|IND|spin|75|10|open|anchor,technician|L|Two IPL hundreds · 95 in the 2011 Final
Lendl Simmons|BAT|WI|pace|78|20|open|anchor,flatTrackBully|L|Opened for 2 title-winning seasons
Kane Williamson|BAT|NZ|spin|80|20|top|anchor,technician,chaseMaster|L|Orange Cap 2018 (735 runs)
Steve Smith|BAT|AUS|spin|77|15|top|anchor,technician|L|IPL hundred 2016 · captained 2017 finalists
Virat Kohli|BAT|IND|pace|92|10|top|anchor,chaseMaster,bigMatch|C|~8,600 IPL runs · 973 in 2016 · 8 hundreds
Rohit Sharma|BAT|IND|spin|86|15|open|powerplayBlitz,powerHitter,bigMatch|C|~7,000 IPL runs · 6 titles
Suryakumar Yadav|BAT|IND|spin|88|10|top|threeSixty,shortBallKing|C|SKY · scoops and ramps all round
Shubman Gill|BAT|IND|spin|86|5|open|anchor,technician|C|890 runs in 2023 · Orange Cap
Yashasvi Jaiswal|BAT|IND|spin|84|10|open|powerplayBlitz,paceBasher|C|13-ball fifty — IPL record
Travis Head|BAT|AUS|spin|87|20|open|powerplayBlitz,paceBasher,bigMatch|C|Powerplay demolisher · SR ~190 in 2024
Abhishek Sharma|BAT|IND|spin|84|42|open|powerplayBlitz,powerHitter|C|141 off 55 in 2025 · 42 sixes in 2024
Ruturaj Gaikwad|BAT|IND|spin|82|5|open|anchor,technician|C|Orange Cap 2021 · CSK captain
Sai Sudharsan|BAT|IND|spin|84|5|top|anchor,technician|C|Orange Cap 2025
Shreyas Iyer|BAT|IND|spin|83|10|top|spinBasher,chaseMaster,bigMatch|C|2024 title captain · 2025 finalist
Tilak Varma|BAT|IND|spin|80|25|middle|chaseMaster,spinBasher|C|Calm left-hander in the middle
Rinku Singh|BAT|IND|spin|80|5|finish|finisher,chaseMaster|C|Five sixes in the last over vs GT
Shivam Dube|BAT|IND|pace|79|35|middle|spinBasher,powerHitter|C|Spin-wrecking six hitter
David Miller|BAT|SA|spin|82|5|finish|finisher,chaseMaster|C|Killer Miller · 2022 champion
Tim David|BAT|AUS|spin|80|15|finish|finisher,powerHitter|C|Death-overs six machine
Shimron Hetmyer|BAT|WI|spin|78|5|finish|finisher,powerHitter|C|Left-handed finisher
Rajat Patidar|BAT|IND|spin|79|5|top|spinBasher,bigMatch|C|2025 title-winning captain · hundred in an Eliminator
Priyansh Arya|BAT|IND|spin|77|5|open|powerplayBlitz|C|39-ball hundred in 2025
Vaibhav Sooryavanshi|BAT|IND|spin|76|5|open|powerplayBlitz,powerHitter|C|35-ball hundred at 14
Tristan Stubbs|BAT|SA|spin|78|15|finish|finisher,spinBasher|C|Death hitter with a reverse ramp
Harry Brook|BAT|ENG|spin|79|10|middle|paceBasher,spinBasher|C|IPL hundred 2023
Jake Fraser-McGurk|BAT|AUS|spin|78|5|open|powerplayBlitz,powerHitter,flatTrackBully|C|15-ball fifty in 2024
Devdutt Padikkal|BAT|IND|spin|74|5|top|anchor|C|Elegant left-handed opener
Ajinkya Rahane|BAT|IND|spin|75|5|top|technician,anchor|C|IPL hundreds in two eras
Dewald Brevis|BAT|SA|spin|76|20|middle|powerHitter,spinBasher|C|Baby AB
Ayush Badoni|BAT|IND|spin|72|20|finish|finisher|C|Unflappable lower-middle order
Shashank Singh|BAT|IND|pace|75|10|finish|finisher,chaseMaster|C|Chased 262 for PBKS
Ashutosh Sharma|BAT|IND|pace|74|5|finish|finisher,powerHitter|C|Last-over heists
Nehal Wadhera|BAT|IND|spin|72|10|middle|spinBasher|C|Left-handed spin hitter
Aiden Markram|BAT|SA|spin|78|42|top|anchor,technician|C|Captained SRH to the 2024 Final
Rovman Powell|BAT|WI|pace|75|20|finish|powerHitter,flatTrackBully|C|Huge Caribbean hitter
Finn Allen|BAT|NZ|spin|76|5|open|powerplayBlitz,powerHitter|C|Kiwi powerplay blitzer
Daryl Mitchell|BAT|NZ|pace|77|30|middle|spinBasher,anchor|C|Sweeps spinners to distraction
Angkrish Raghuvanshi|BAT|IND|spin|72|5|top|anchor|C|Young KKR top order
Nitish Rana|BAT|IND|spin|74|30|top|spinBasher|C|Left-handed spin hitter
# ---------------- Wicket-keepers ----------------
MS Dhoni|WK|IND|pace|86|5|finish|finisher,chaseMaster,bigMatch|L|5× IPL champion captain · helicopter shot
Adam Gilchrist|WK|AUS|pace|82|5|open|powerplayBlitz,paceBasher,bigMatch|L|2009 title captain · 42-ball hundred in 2008
Dinesh Karthik|WK|IND|pace|77|5|finish|finisher,threeSixty|L|DK the finisher · 17 IPL seasons
Kumar Sangakkara|WK|SL|pace|77|5|top|anchor,technician|L|Elegant left-hander
Parthiv Patel|WK|IND|pace|72|5|open|anchor|L|3 IPL titles
Wriddhiman Saha|WK|IND|pace|72|5|open|technician|L|Hundred in the 2014 Final
Jos Buttler|WK|ENG|pace|90|5|open|powerplayBlitz,chaseMaster,bigMatch|C|863 runs and 4 hundreds in 2022
KL Rahul|WK|IND|pace|87|5|open|anchor,technician|C|4 IPL seasons of 600+ runs
Rishabh Pant|WK|IND|pace|84|5|middle|spinBasher,powerHitter|C|Fearless left-hander · one-handed sixes
Sanju Samson|WK|IND|pace|83|5|top|spinBasher,powerHitter|C|Stylish six-hitter · RR captain
Heinrich Klaasen|WK|SA|pace|88|5|middle|spinBasher,powerHitter|C|Destroyer of spin · SR ~170
Nicholas Pooran|WK|WI|pace|86|5|finish|powerHitter,spinBasher,flatTrackBully|C|Most sixes in 2025
Quinton de Kock|WK|SA|pace|82|5|open|powerplayBlitz,paceBasher|C|140* in 2022 — record stand
Ishan Kishan|WK|IND|pace|80|5|open|powerplayBlitz|C|Left-handed opener · IPL hundred 2025
Phil Salt|WK|ENG|pace|84|5|open|powerplayBlitz,paceBasher|C|2025 champion opener
Prabhsimran Singh|WK|IND|pace|77|5|open|powerplayBlitz|C|Attacking PBKS opener
Jitesh Sharma|WK|IND|pace|74|5|finish|finisher|C|85* to seal a top-2 finish in 2025
Dhruv Jurel|WK|IND|pace|75|5|finish|finisher,technician|C|Calm lower-order hitter
Ryan Rickelton|WK|SA|pace|76|5|open|powerplayBlitz|C|Left-handed MI opener
Devon Conway|WK|NZ|pace|79|5|open|anchor,technician|C|CSK title-winning opener 2023
Josh Inglis|WK|AUS|pace|76|5|middle|spinBasher|C|Sweeps and reverse-sweeps
# ---------------- All-rounders ----------------
Andre Russell|AR|WI|pace|84|70|finish|finisher,powerHitter,wicketTaker|L|SR ~175 · 2× MVP
Kieron Pollard|AR|WI|pace|80|60|finish|finisher,powerHitter,bigMatch|L|5 IPL titles · death-overs giant
Shane Watson|AR|AUS|pace|84|70|open|powerplayBlitz,bigMatch|L|117* in the 2018 Final · 2008 MVP
Jacques Kallis|AR|SA|pace|80|66|top|anchor,technician,economical|L|2 titles with KKR
Dwayne Bravo|AR|WI|pace|66|80|finish|deathSpecialist,slowerBallMaster|L|2× Purple Cap · 32 wkts in 2013
Yusuf Pathan|AR|IND|spin|79|50|finish|powerHitter,finisher|L|37-ball hundred in 2010
Irfan Pathan|AR|IND|pace|62|70|middle|newBallSwing|L|Left-arm swing
Ben Stokes|AR|ENG|pace|78|68|middle|bigMatch,chaseMaster,bounceMerchant|L|2017 MVP · two IPL hundreds
Glenn Maxwell|AR|AUS|spin|80|58|middle|threeSixty,powerHitter|L|The Big Show · switch hits
Shakib Al Hasan|AR|BAN|spin|72|76|middle|economical,middleOversBoss|L|2 titles with KKR
Moeen Ali|AR|ENG|spin|72|68|top|spinBasher,turnerTerror|L|2021 champion
Sunil Narine|AR|WI|spin|76|88|open|powerplayBlitz,mysterySpin,economical|C|3× MVP · 180+ IPL wickets
Ravindra Jadeja|AR|IND|spin|74|80|finish|economical,finisher,turnerTerror|C|Won the 2023 Final off the last 2 balls
Hardik Pandya|AR|IND|pace|82|74|finish|finisher,bounceMerchant,bigMatch|C|2022 title captain
Axar Patel|AR|IND|spin|72|80|middle|economical,middleOversBoss|C|Left-arm spin, economy ~7.3
Krunal Pandya|AR|IND|spin|66|72|middle|economical,bigMatch|C|Player of the Match, 2025 Final
Washington Sundar|AR|IND|spin|64|74|middle|economical|C|Powerplay off-spin
Marcus Stoinis|AR|AUS|pace|78|58|finish|finisher,powerHitter|C|124* chasing 211
Sam Curran|AR|ENG|pace|70|74|middle|newBallSwing,bigMatch|C|Left-arm swing
Liam Livingstone|AR|ENG|spin|78|56|middle|powerHitter,spinBasher|C|117-metre six
Mitchell Marsh|AR|AUS|pace|80|60|top|paceBasher,powerHitter|C|Six-hitting top order
Cameron Green|AR|AUS|pace|77|66|top|paceBasher,bounceMerchant|C|Hundred for MI 2023
Rachin Ravindra|AR|NZ|spin|76|58|open|technician,powerplayBlitz|C|Left-handed opener, left-arm spin
Will Jacks|AR|ENG|spin|77|58|open|powerplayBlitz,powerHitter|C|41-ball hundred in 2024
Nitish Kumar Reddy|AR|IND|pace|72|58|middle|paceBasher|C|Emerging Player 2024
Marco Jansen|AR|SA|pace|60|76|lower|newBallSwing,bounceMerchant|C|Tall left-arm swing and bounce
Azmatullah Omarzai|AR|AFG|pace|64|72|middle|newBallSwing|C|Seam-bowling all-rounder
Mitchell Santner|AR|NZ|spin|58|78|lower|economical,middleOversBoss|C|Left-arm spin control
Wanindu Hasaranga|AR|SL|spin|58|82|lower|wicketTaker,turnerTerror|C|26 wickets in 2022
Romario Shepherd|AR|WI|pace|70|62|finish|powerHitter,finisher|C|14-ball fifty in 2025
Shardul Thakur|AR|IND|pace|62|70|lower|wicketTaker|C|Lord Shardul · golden arm
Venkatesh Iyer|AR|IND|pace|74|45|top|paceBasher|C|2021 breakout opener
Riyan Parag|AR|IND|spin|76|50|middle|spinBasher|C|573 runs in 2024
Rahul Tewatia|AR|IND|spin|70|55|finish|finisher,chaseMaster|C|Five sixes in an over vs Cottrell
# ---------------- Bowlers ----------------
Lasith Malinga|BOWL|SL|pace|20|90|lower|deathSpecialist,wicketTaker,bigMatch|L|170 IPL wickets · Purple Cap 2011
Harbhajan Singh|BOWL|IND|spin|30|80|lower|economical,turnerTerror|L|150 IPL wickets · 4 titles
Amit Mishra|BOWL|IND|spin|20|80|lower|wicketTaker,turnerTerror|L|3 IPL hat-tricks
Ravichandran Ashwin|BOWL|IND|spin|35|84|lower|economical,middleOversBoss,turnerTerror|L|180+ IPL wickets
Dale Steyn|BOWL|SA|pace|20|86|lower|newBallSwing,expressPace|L|Fastest, fiercest new-ball spells
Zaheer Khan|BOWL|IND|pace|20|82|lower|newBallSwing,slowerBallMaster|L|Left-arm swing master
Shane Warne|BOWL|AUS|spin|25|84|lower|wicketTaker,bigMatch|L|2008 title-winning captain
Anil Kumble|BOWL|IND|spin|20|80|lower|economical,wicketTaker|L|5/5 in 2009
Morne Morkel|BOWL|SA|pace|20|80|lower|bounceMerchant,economical|L|Purple Cap 2012
Imran Tahir|BOWL|SA|spin|10|82|lower|wicketTaker|L|Purple Cap 2019 · the sprint celebration
Piyush Chawla|BOWL|IND|spin|25|76|lower|wicketTaker|L|190+ IPL wickets
Praveen Kumar|BOWL|IND|pace|30|76|lower|newBallSwing,economical|L|Swing it both ways
Ashish Nehra|BOWL|IND|pace|10|78|lower|newBallSwing,deathSpecialist|L|Left-arm swing, title-winning coach
Mitchell Johnson|BOWL|AUS|pace|30|79|lower|expressPace,bounceMerchant|L|Bowled MI to the 2017 title
Pragyan Ojha|BOWL|IND|spin|10|74|lower|economical|L|Purple Cap 2010
Umesh Yadav|BOWL|IND|pace|20|75|lower|expressPace,newBallSwing|L|Powerplay wicket-taker
Mohit Sharma|BOWL|IND|pace|15|74|lower|slowerBallMaster,deathSpecialist|L|Purple Cap 2014
Jasprit Bumrah|BOWL|IND|pace|15|95|lower|deathSpecialist,economical,newBallSwing,bigMatch|C|Best death bowler in the world
Rashid Khan|BOWL|AFG|spin|50|92|lower|mysterySpin,economical,middleOversBoss|C|Leg-spin genius · 150+ IPL wickets
Yuzvendra Chahal|BOWL|IND|spin|10|86|lower|wicketTaker,turnerTerror|C|Most IPL wickets ever (200+)
Kuldeep Yadav|BOWL|IND|spin|15|84|lower|wicketTaker,mysterySpin|C|Left-arm wrist spin
Varun Chakaravarthy|BOWL|IND|spin|10|85|lower|mysterySpin,middleOversBoss|C|21 wickets in KKR's 2024 title run
Mitchell Starc|BOWL|AUS|pace|35|86|lower|newBallSwing,deathSpecialist,bigMatch|C|Player of the Match in Q1 and the 2024 Final
Trent Boult|BOWL|NZ|pace|20|85|lower|newBallSwing|C|First-over wicket specialist
Bhuvneshwar Kumar|BOWL|IND|pace|30|84|lower|newBallSwing,economical,slowerBallMaster|C|2× Purple Cap
Arshdeep Singh|BOWL|IND|pace|15|83|lower|deathSpecialist,newBallSwing|C|Left-arm yorkers
Mohammed Shami|BOWL|IND|pace|15|83|lower|newBallSwing,wicketTaker|C|Purple Cap 2023
Mohammed Siraj|BOWL|IND|pace|15|81|lower|newBallSwing|C|Swing and aggression
Josh Hazlewood|BOWL|AUS|pace|15|84|lower|economical,bounceMerchant,newBallSwing|C|Relentless line and length
Pat Cummins|BOWL|AUS|pace|45|82|lower|bounceMerchant,bigMatch|C|2024 finalist captain
Kagiso Rabada|BOWL|SA|pace|25|85|lower|wicketTaker,expressPace|C|Purple Cap 2020
Jofra Archer|BOWL|ENG|pace|40|84|lower|expressPace,deathSpecialist|C|2020 MVP · 150 km/h yorkers
Matheesha Pathirana|BOWL|SL|pace|5|80|lower|deathSpecialist|C|Slingy death yorkers
Harshal Patel|BOWL|IND|pace|35|78|lower|slowerBallMaster,deathSpecialist|C|32 wickets in 2021 · Purple Cap ×2
Lockie Ferguson|BOWL|NZ|pace|20|78|lower|expressPace,bounceMerchant|C|Raw pace
Anrich Nortje|BOWL|SA|pace|10|78|lower|expressPace|C|IPL's fastest balls
Mayank Yadav|BOWL|IND|pace|10|75|lower|expressPace|C|156 km/h on debut
Noor Ahmad|BOWL|AFG|spin|10|80|lower|mysterySpin,wicketTaker|C|Left-arm wrist spin · 24 wickets in 2025
Ravi Bishnoi|BOWL|IND|spin|10|78|lower|wicketTaker|C|Quick leg-spin
Prasidh Krishna|BOWL|IND|pace|10|80|lower|bounceMerchant,wicketTaker|C|Purple Cap 2025
Deepak Chahar|BOWL|IND|pace|35|77|lower|newBallSwing|C|Powerplay swing
Thangarasu Natarajan|BOWL|IND|pace|5|76|lower|deathSpecialist|C|Yorker king
Mustafizur Rahman|BOWL|BAN|pace|5|78|lower|slowerBallMaster,deathSpecialist|C|The cutter master
Sandeep Sharma|BOWL|IND|pace|10|76|lower|newBallSwing,slowerBallMaster|C|Swing and slower balls
Avesh Khan|BOWL|IND|pace|15|74|lower|bounceMerchant|C|Hit-the-deck pace
Khaleel Ahmed|BOWL|IND|pace|5|76|lower|newBallSwing|C|Left-arm new ball
Harshit Rana|BOWL|IND|pace|25|74|lower|wicketTaker|C|2024 title-winning seamer
Maheesh Theekshana|BOWL|SL|spin|10|77|lower|economical,mysterySpin|C|Carrom-ball off-spin
Adam Zampa|BOWL|AUS|spin|10|78|lower|wicketTaker|C|Wicket-taking leg-spin
Rahul Chahar|BOWL|IND|spin|10|72|lower|wicketTaker|C|Leg-spin
Tushar Deshpande|BOWL|IND|pace|10|72|lower|wicketTaker|C|Impact seamer
Akash Deep|BOWL|IND|pace|15|72|lower|newBallSwing|C|Seam and swing
Mukesh Kumar|BOWL|IND|pace|10|72|lower|deathSpecialist|C|Yorkers at the death
Yash Dayal|BOWL|IND|pace|10|72|lower|newBallSwing|C|Left-arm swing · 2025 champion
Sai Kishore|BOWL|IND|spin|20|74|lower|economical|C|Left-arm spin
Digvesh Rathi|BOWL|IND|spin|5|72|lower|mysterySpin|C|Mystery spinner
Gerald Coetzee|BOWL|SA|pace|20|74|lower|expressPace|C|Express pace
Nathan Ellis|BOWL|AUS|pace|15|74|lower|deathSpecialist,slowerBallMaster|C|Death-overs variations
Spencer Johnson|BOWL|AUS|pace|10|72|lower|expressPace,newBallSwing|C|Left-arm pace
Lungi Ngidi|BOWL|SA|pace|10|76|lower|wicketTaker,slowerBallMaster|C|Slower-ball wickets
Kyle Jamieson|BOWL|NZ|pace|30|72|lower|bounceMerchant|C|2-metre bounce
"""

TRAITS = {"powerHitter", "anchor", "finisher", "spinBasher", "paceBasher", "powerplayBlitz", "chaseMaster",
          "threeSixty", "bigMatch", "flatTrackBully", "technician", "shortBallKing",
          "deathSpecialist", "newBallSwing", "mysterySpin", "economical", "wicketTaker", "expressPace",
          "slowerBallMaster", "bounceMerchant", "turnerTerror", "middleOversBoss"}
ROLES = {"BAT", "WK", "AR", "BOWL"}
SLOTS = {"open", "top", "middle", "finish", "lower"}
COUNTRIES = {"IND", "AUS", "ENG", "SA", "NZ", "WI", "SL", "AFG", "BAN"}


def rating(role, bat, bowl):
    if role in ("BAT", "WK"):
        return bat
    if role == "BOWL":
        return bowl
    return min(97, round(max(bat, bowl) * 0.7 + min(bat, bowl) * 0.3 + 5))


def base_price(r):
    for floor, price in ((85, 200), (80, 150), (75, 100), (70, 75)):
        if r >= floor:
            return price
    return 50


def slug(name):
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def main():
    out, seen = [], set()
    for line in ROWS.strip().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        name, role, country, btype, bat, bowl, slot, traits, era, note = [x.strip() for x in line.split("|")]
        assert name not in seen, f"duplicate {name}"
        seen.add(name)
        assert role in ROLES and slot in SLOTS and country in COUNTRIES and btype in ("pace", "spin") and era in "LC", line
        tr = [t for t in traits.split(",") if t]
        assert all(t in TRAITS for t in tr), (name, tr)
        bat, bowl = int(bat), int(bowl)
        r = rating(role, bat, bowl)
        out.append({
            "id": slug(name),
            "name": name,
            "role": role,
            "overseas": country != "IND",
            "country": country,
            "base": base_price(r),
            "pool": "Legends" if era == "L" else "Stars",
            "rating": r,
            "bat": bat,
            "bowl": bowl,
            "line": note,
            "bowlType": btype,
            "traits": tr,
            "slot": slot,
            "legend": era == "L",
        })
    json.dump(out, open("ios/Resources/players.json", "w"), indent=1, ensure_ascii=False)
    by_role = {r: sum(1 for p in out if p["role"] == r) for r in ROLES}
    ind = {r: sum(1 for p in out if p["role"] == r and not p["overseas"]) for r in ROLES}
    print(len(out), "players", by_role, "indian", ind, "legends", sum(p["legend"] for p in out))


if __name__ == "__main__":
    main()
