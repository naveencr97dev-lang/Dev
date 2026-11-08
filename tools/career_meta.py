"""Career-mode metadata for the curated players: approximate birth year.

These are this game's own approximate figures for career-mode ageing, not official data.
Legends get a fictional "prime" age, since they only appear in the optional Legends-era start.

Run from the repo root:  python3 tools/career_meta.py
Writes ios/Resources/career_meta.json  ({ player id: { "born": year } }).
"""
import json

BORN = {
    "virat-kohli": 1988, "rohit-sharma": 1987, "suryakumar-yadav": 1990, "shubman-gill": 1999,
    "yashasvi-jaiswal": 2001, "travis-head": 1993, "abhishek-sharma": 2000, "ruturaj-gaikwad": 1997,
    "sai-sudharsan": 2001, "shreyas-iyer": 1994, "tilak-varma": 2002, "rinku-singh": 1997,
    "shivam-dube": 1993, "david-miller": 1989, "tim-david": 1996, "shimron-hetmyer": 1996,
    "rajat-patidar": 1993, "priyansh-arya": 2001, "vaibhav-sooryavanshi": 2011, "tristan-stubbs": 2000,
    "harry-brook": 1999, "jake-fraser-mcgurk": 2002, "devdutt-padikkal": 2000, "ajinkya-rahane": 1988,
    "dewald-brevis": 2003, "ayush-badoni": 1999, "shashank-singh": 1991, "ashutosh-sharma": 1998,
    "nehal-wadhera": 2000, "aiden-markram": 1994, "rovman-powell": 1993, "finn-allen": 1999,
    "daryl-mitchell": 1991, "angkrish-raghuvanshi": 2005, "nitish-rana": 1993, "jos-buttler": 1990,
    "kl-rahul": 1992, "rishabh-pant": 1997, "sanju-samson": 1994, "heinrich-klaasen": 1991,
    "nicholas-pooran": 1995, "quinton-de-kock": 1992, "ishan-kishan": 1998, "phil-salt": 1996,
    "prabhsimran-singh": 2000, "jitesh-sharma": 1993, "dhruv-jurel": 2001, "ryan-rickelton": 1996,
    "devon-conway": 1991, "josh-inglis": 1995, "sunil-narine": 1988, "ravindra-jadeja": 1988,
    "hardik-pandya": 1993, "axar-patel": 1994, "krunal-pandya": 1991, "washington-sundar": 1999,
    "marcus-stoinis": 1989, "sam-curran": 1998, "liam-livingstone": 1993, "mitchell-marsh": 1991,
    "cameron-green": 1999, "rachin-ravindra": 1999, "will-jacks": 1998, "nitish-kumar-reddy": 2003,
    "marco-jansen": 2000, "azmatullah-omarzai": 2000, "mitchell-santner": 1992, "wanindu-hasaranga": 1997,
    "romario-shepherd": 1994, "shardul-thakur": 1991, "venkatesh-iyer": 1994, "riyan-parag": 2001,
    "rahul-tewatia": 1993, "jasprit-bumrah": 1993, "rashid-khan": 1998, "yuzvendra-chahal": 1990,
    "kuldeep-yadav": 1994, "varun-chakaravarthy": 1991, "mitchell-starc": 1990, "trent-boult": 1989,
    "bhuvneshwar-kumar": 1990, "arshdeep-singh": 1999, "mohammed-shami": 1990, "mohammed-siraj": 1994,
    "josh-hazlewood": 1991, "pat-cummins": 1993, "kagiso-rabada": 1995, "jofra-archer": 1995,
    "matheesha-pathirana": 2002, "harshal-patel": 1990, "lockie-ferguson": 1991, "anrich-nortje": 1993,
    "mayank-yadav": 2002, "noor-ahmad": 2005, "ravi-bishnoi": 2000, "prasidh-krishna": 1996,
    "deepak-chahar": 1992, "thangarasu-natarajan": 1991, "mustafizur-rahman": 1995, "sandeep-sharma": 1993,
    "avesh-khan": 1996, "khaleel-ahmed": 1997, "harshit-rana": 2001, "maheesh-theekshana": 2000,
    "adam-zampa": 1992, "rahul-chahar": 1999, "tushar-deshpande": 1995, "akash-deep": 1996,
    "mukesh-kumar": 1993, "yash-dayal": 1997, "sai-kishore": 1996, "digvesh-rathi": 1999,
    "gerald-coetzee": 2000, "nathan-ellis": 1994, "spencer-johnson": 1995, "lungi-ngidi": 1996,
    "kyle-jamieson": 1994,
}

def main():
    players = json.load(open("ios/Resources/players.json"))
    out = {}
    for i, p in enumerate(players):
        if p["legend"]:
            # Legends era: everyone in a playing prime, 26-33.
            out[p["id"]] = {"born": 2027 - (26 + i % 8)}
        else:
            if p["id"] not in BORN:
                raise SystemExit(f"missing birth year: {p['id']}")
            out[p["id"]] = {"born": BORN[p["id"]]}
    with open("ios/Resources/career_meta.json", "w") as f:
        json.dump(out, f, indent=0, sort_keys=True)
    print(f"wrote {len(out)} entries")

if __name__ == "__main__":
    main()
