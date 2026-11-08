import Foundation

/// Generates fictional players (depth players, youth intakes) from per-nation name pools.
enum PlayerGen {
    struct NamePool {
        let first: [String]
        let last: [String]
    }

    static let pools: [String: NamePool] = [
        "IND": NamePool(
            first: ["Aarav", "Vihaan", "Arjun", "Kabir", "Rohan", "Aditya", "Karan", "Siddharth", "Varun", "Pranav",
                    "Nikhil", "Rahul", "Akash", "Harsh", "Yash", "Manav", "Dhruv", "Ishaan", "Kunal", "Sameer",
                    "Ankit", "Tanmay", "Ritesh", "Gaurav", "Mayank", "Abhinav", "Shaurya", "Atharva", "Parth", "Vivek",
                    "Raghav", "Sahil", "Aniket", "Omkar", "Tejas", "Kartik", "Aman", "Deepak", "Lakshay", "Hemant"],
            last: ["Sharma", "Verma", "Patil", "Nair", "Iyer", "Reddy", "Rao", "Singh", "Yadav", "Chauhan",
                   "Kulkarni", "Deshmukh", "Menon", "Pillai", "Joshi", "Mishra", "Pandey", "Tiwari", "Saxena", "Bhatt",
                   "Gill", "Sandhu", "Dhillon", "Rathore", "Thakur", "Naidu", "Shetty", "Kamath", "Bose", "Ghosh",
                   "Mukherjee", "Chopra", "Malhotra", "Kapoor", "Mehta", "Desai", "Jadhav", "Pawar", "Rawat", "Negi"]),
        "AUS": NamePool(
            first: ["Lachlan", "Cooper", "Mitchell", "Riley", "Jake", "Harrison", "Tom", "Callum", "Liam", "Fergus",
                    "Hamish", "Bailey", "Jordan", "Brody", "Nathan", "Zac", "Oliver", "Max", "Corey", "Declan"],
            last: ["Thompson", "Walsh", "McKenzie", "Fraser", "Doyle", "Henderson", "Clarke", "Bennett", "Kerr", "Lyons",
                   "Murray", "Pearce", "Sutherland", "Turner", "Wallace", "Hughes", "Dawson", "Gibbs", "Rowe", "Sinclair"]),
        "ENG": NamePool(
            first: ["George", "Harry", "Oliver", "Jack", "Charlie", "Alfie", "Freddie", "Ollie", "Ben", "Joe",
                    "Sam", "Will", "Tom", "Archie", "Luke", "Rory", "Dan", "Matt", "Josh", "Henry"],
            last: ["Hartley", "Pemberton", "Ashworth", "Whitfield", "Barnes", "Collins", "Fletcher", "Holloway", "Moss", "Sutton",
                   "Wakefield", "Banks", "Crawley", "Dunstan", "Fenwick", "Hargreaves", "Lowe", "Marsden", "Prior", "Rudd"]),
        "SA": NamePool(
            first: ["Pieter", "Johan", "Kyle", "Siya", "Thando", "Ruan", "Wiaan", "Lutho", "Bjorn", "Keegan",
                    "Sipho", "Dian", "Morné", "Andile", "Tiaan", "Jason", "Wihan", "Kagiso", "Corbin", "Neo"],
            last: ["van Wyk", "Botha", "Pretorius", "Nkosi", "Dlamini", "le Roux", "Steyn", "Venter", "Mokoena", "du Toit",
                   "Erasmus", "Ntini", "Fourie", "Mabaso", "Coetzer", "Hendricks", "Jacobs", "Mthembu", "Swart", "Visser"]),
        "NZ": NamePool(
            first: ["Finn", "Blair", "Hamish", "Kieran", "Tane", "Logan", "Mason", "Ryder", "Quinn", "Ash"],
            last: ["Ngata", "McIntosh", "Rowling", "Tipene", "Henare", "Bracewell", "Sowerby", "Kingi", "Waaka", "Lister"]),
        "WI": NamePool(
            first: ["Jermaine", "Kemar", "Akeem", "Shamar", "Keacy", "Alzarri", "Tevin", "Brandon", "Kirk", "Odean"],
            last: ["Joseph", "Charles", "Greaves", "Mayers", "Hosein", "Lewis", "Bramble", "Forde", "Seales", "Athanaze"]),
        "SL": NamePool(
            first: ["Kasun", "Dilshan", "Pathum", "Charith", "Dunith", "Kamindu", "Nuwan", "Lahiru", "Sadeera", "Chamika"],
            last: ["Perera", "Fernando", "Silva", "Jayasuriya", "Rajapaksa", "Bandara", "Wickramasinghe", "Dissanayake", "Herath", "Kumara"]),
        "AFG": NamePool(
            first: ["Hashmat", "Ibrahim", "Fazal", "Qais", "Rahmat", "Naveed", "Zia", "Farid", "Sharaf", "Bilal"],
            last: ["Zadran", "Shinwari", "Safi", "Ahmadzai", "Stanikzai", "Mangal", "Zazai", "Malik", "Arab", "Sadat"]),
        "BAN": NamePool(
            first: ["Tanzid", "Towhid", "Rishad", "Shoriful", "Jaker", "Tanvir", "Mahidul", "Parvez"],
            last: ["Hasan", "Hridoy", "Hossain", "Islam", "Ali", "Rahman", "Ankon", "Emon"]),
    ]

    /// Nationality mix for generated IPL-pool players (most are Indian, as squads need them).
    static let nationWeights: [(String, Double)] = [
        ("IND", 62), ("AUS", 7), ("ENG", 7), ("SA", 7), ("NZ", 5), ("WI", 5), ("SL", 3), ("AFG", 3), ("BAN", 1),
    ]

    static func pickNation(_ rng: inout SeededRNG) -> String {
        nationWeights[rng.weighted(nationWeights.map(\.1))].0
    }

    static func name(nation: String, rng: inout SeededRNG, taken: Set<String>) -> String {
        let pool = pools[nation] ?? pools["IND"]!
        for _ in 0..<40 {
            let n = "\(pool.first.randomElement(using: &rng)!) \(pool.last.randomElement(using: &rng)!)"
            if !taken.contains(n) { return n }
        }
        // Pools exhausted: add an initial.
        let initial = String("ABCDEFGHJKLMNPRSTV".randomElement(using: &rng)!)
        return "\(pool.first.randomElement(using: &rng)!) \(initial). \(pool.last.randomElement(using: &rng)!)"
    }

    static let batTraits: [Trait] = [.powerHitter, .anchor, .finisher, .spinBasher, .paceBasher, .powerplayBlitz,
                                     .chaseMaster, .technician, .shortBallKing, .flatTrackBully]
    static let paceTraits: [Trait] = [.deathSpecialist, .newBallSwing, .economical, .wicketTaker, .expressPace,
                                      .slowerBallMaster, .bounceMerchant]
    static let spinTraits: [Trait] = [.mysterySpin, .economical, .wicketTaker, .turnerTerror, .middleOversBoss]

    /// One fictional player.
    /// - rating: main-skill rating now; potential: ceiling.
    static func make(id: String, role: Role, nation: String, born: Int, rating: Int, potential: Int,
                     taken: Set<String>, tuning: CareerTuning = .standard, rng: inout SeededRNG) -> CareerPlayer {
        let spinChance = role == .BOWL || role == .AR ? 0.4 : 0.6
        let bowlType: BowlType = rng.unit() < spinChance ? .spin : .pace
        var bat: Int, bowl: Int
        switch role {
        case .BAT: bat = rating; bowl = Int.random(in: 5...38, using: &rng)
        case .WK: bat = rating; bowl = Int.random(in: 3...12, using: &rng)
        case .BOWL: bowl = rating; bat = Int.random(in: 12...38, using: &rng)
        case .AR:
            if rng.unit() < 0.5 { bat = rating; bowl = rating - Int.random(in: 2...14, using: &rng) }
            else { bowl = rating; bat = rating - Int.random(in: 2...14, using: &rng) }
        }
        let slot: BatSlot
        switch role {
        case .BAT, .WK: slot = [.open, .open, .top, .top, .middle, .finish].randomElement(using: &rng)!
        case .AR: slot = [.middle, .finish, .finish].randomElement(using: &rng)!
        case .BOWL: slot = .lower
        }
        var traits: [Trait] = []
        let options: [Trait]
        switch role {
        case .BAT, .WK: options = batTraits
        case .BOWL: options = bowlType == .spin ? spinTraits : paceTraits
        case .AR: options = batTraits + (bowlType == .spin ? spinTraits : paceTraits)
        }
        if rng.unit() < tuning.traitChance {
            traits.append(options.randomElement(using: &rng)!)
            if rng.unit() < tuning.secondTraitChance, let t = options.filter({ !traits.contains($0) }).randomElement(using: &rng) {
                traits.append(t)
            }
        }
        let attr = Attributes.seeded(bat: bat, bowl: bowl, keeper: role == .WK, traits: traits, rng: &rng)
        return CareerPlayer(id: id, name: name(nation: nation, rng: &rng, taken: taken), country: nation, role: role,
                            bowlType: bowlType, slot: slot, traits: traits, born: born, attr: attr,
                            potential: max(potential, rating), legend: false, generated: true,
                            line: "", clubId: nil)
    }

    static func randomRole(_ rng: inout SeededRNG) -> Role {
        [Role.WK, .BAT, .AR, .BOWL][rng.weighted([12, 28, 20, 40])]
    }

    /// Depth players for a new career: mostly solid pros (50-72) with a few prospects.
    static func depth(count: Int, year: Int, startId: Int, taken: Set<String>, tuning: CareerTuning,
                      rng: inout SeededRNG) -> [CareerPlayer] {
        var names = taken
        var out: [CareerPlayer] = []
        for i in 0..<count {
            let role = randomRole(&rng)
            let nation = pickNation(&rng)
            let age = Int.random(in: 19...34, using: &rng)
            let band: [Int]
            switch role {
            case .BAT, .WK: band = tuning.depthBat
            case .BOWL: band = tuning.depthBowl
            case .AR: band = [(tuning.depthBat[0] + tuning.depthBowl[0]) / 2, (tuning.depthBat[1] + tuning.depthBowl[1]) / 2]
            }
            let rating = Int.random(in: band[0]...band[1], using: &rng)
            let headroom = age <= 22 ? Int.random(in: 4...20, using: &rng) : (age <= 26 ? Int.random(in: 0...8, using: &rng) : 0)
            let p = make(id: "g\(startId + i)", role: role, nation: nation, born: year - age, rating: rating,
                         potential: min(95, rating + headroom), taken: names, tuning: tuning, rng: &rng)
            names.insert(p.name)
            out.append(p)
        }
        return out
    }

    /// A youth intake: 17-20 year olds, raw but with potential (a few gems).
    static func youth(count: Int, year: Int, startId: Int, taken: Set<String>, tuning: CareerTuning,
                      rng: inout SeededRNG) -> [CareerPlayer] {
        var names = taken
        var out: [CareerPlayer] = []
        for i in 0..<count {
            let role = randomRole(&rng)
            let nation = pickNation(&rng)
            let age = Int.random(in: 17...20, using: &rng)
            let rating = Int.random(in: 42...62, using: &rng)
            let gem = rng.unit() < tuning.youthGemChance
            let potential = gem ? Int.random(in: 82...94, using: &rng) : Int.random(in: rating + 4...min(88, rating + 24), using: &rng)
            let p = make(id: "g\(startId + i)", role: role, nation: nation, born: year - age, rating: rating,
                         potential: potential, taken: names, tuning: tuning, rng: &rng)
            names.insert(p.name)
            out.append(p)
        }
        return out
    }
}
