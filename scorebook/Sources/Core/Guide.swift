import Foundation

/// One robbable target type (store, bank, ATM...). Pure data, no UI.
public struct RobberyGuide: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let symbol: String          // SF Symbol name
    public let tier: Tier
    public let unlock: String
    public let take: String
    public let heat: String
    public let steps: [String]
    public let watchOut: [String]
    public let note: String?

    public enum Tier: Int, CaseIterable, Comparable {
        case small = 1, mid, big
        public var title: String {
            switch self {
            case .small: return "Small stores"
            case .mid: return "Smash 'n' Grabs"
            case .big: return "Big scores"
            }
        }
        public static func < (a: Tier, b: Tier) -> Bool { a.rawValue < b.rawValue }
    }
}

public struct MoneyMethod: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let symbol: String
    public let unlock: String
    public let pay: String
    public let how: [String]
}

public struct RuleGroup: Identifiable, Hashable {
    public let id: String
    public let title: String
    public let symbol: String
    public let rules: [String]
}

/// Static, spoiler-light guide content. No plot, no characters, no mission outcomes.
/// Sourced from post-launch guides (Nov 2026): GAMES.GG, GTABase, VGC.
/// Where guides disagree, the range or both claims are shown.
public enum Guide {

    // MARK: Robberies

    /// Shared opening every robbery uses; shown at the top of each step list.
    public static let prep: [String] = [
        "Drive past first: count entrances, people inside, and cameras.",
        "Put on a mask, hat or glasses before you walk in.",
        "Keep a full spare outfit in the trunk.",
        "Park the getaway car by the exit you'll use, facing out.",
    ]

    /// Targets where the walk-in prep doesn't apply.
    static let noPrep: Set<String> = ["safes", "atm"]

    public static func stepsWithPrep(_ g: RobberyGuide) -> [String] {
        noPrep.contains(g.id) ? g.steps : prep + g.steps
    }

    public static let robberies: [RobberyGuide] = [
        RobberyGuide(
            id: "convenience", name: "Convenience store", symbol: "cart",
            tier: .small,
            unlock: "From the start",
            take: "$200 – $2,000 (guides disagree)",
            heat: "1–2 stars, light police response",
            steps: [
                "Walk in with your weapon drawn. Aim (L2 / LT) without firing.",
                "Aim at the clerk to threaten them. Some empty the till on their own.",
                "If not, press Triangle / Y to open the register.",
                "Grab every stack, then check the counter for leftovers.",
                "Look for a back-room safe (see Safes).",
                "Leave by the exit next to your car.",
            ],
            watchOut: [
                "Clerks and customers can fight back. Use Focus (L3 + R3) to slow time and mark non-lethal takedowns.",
                "Shoot out the cameras inside, or keep your disguise on the whole time.",
                "You can't rob the same shop twice in a row. It may stay closed for a while.",
            ],
            note: "Best first target. Many unmarked shops can be robbed too."),
        RobberyGuide(
            id: "gas", name: "Gas station", symbol: "fuelpump",
            tier: .small,
            unlock: "From the start",
            take: "Small (same tier as convenience)",
            heat: "1–2 stars",
            steps: [
                "Check the forecourt for customers and patrol cars before you go in.",
                "Threaten the clerk with your weapon aimed (L2 / LT).",
                "Open the register (Triangle / Y) if they don't.",
                "Grab the cash and check for a safe.",
                "Leave on the side away from the main road.",
            ],
            watchOut: [
                "It's open on every side. Witnesses outside can call it in.",
                "Pumps and parked cars make bad cover in a gunfight.",
            ],
            note: "A good first target alongside convenience stores."),
        RobberyGuide(
            id: "liquor", name: "Liquor store", symbol: "wineglass",
            tier: .small,
            unlock: "From the start",
            take: "Small",
            heat: "1–2 stars",
            steps: [
                "Check whether there's a back door.",
                "Come in through the front. Forcing the back door alerts the owner.",
                "Threaten the clerk and empty the register.",
                "Check the back room for a safe.",
            ],
            watchOut: ["Forcing the back door alerts the owner before you're inside."],
            note: nil),
        RobberyGuide(
            id: "phone", name: "Grocery & phone repair", symbol: "iphone",
            tier: .small,
            unlock: "From the start",
            take: "Low",
            heat: "1–2 stars, light police response",
            steps: [
                "Threaten the clerk with your weapon aimed (L2 / LT).",
                "Open or empty the register.",
                "Grab everything and leave.",
            ],
            watchOut: ["The take is low. Only worth it if you're nearby and the area's quiet."],
            note: nil),
        RobberyGuide(
            id: "payday", name: "Payday loans", symbol: "banknote",
            tier: .mid,
            unlock: "Shown on the map",
            take: "Not confirmed",
            heat: "Likely higher than small stores",
            steps: [
                "Scout it the same way you would a small store.",
                "Threaten the staff, then take the till and any safe.",
            ],
            watchOut: ["No guide has confirmed the details yet. Update these notes once you've done one."],
            note: "This is a map robbery marker."),
        RobberyGuide(
            id: "pawn", name: "Pawn shop", symbol: "tag",
            tier: .mid,
            unlock: "Later in the story (reported mid Chapter 2)",
            take: "Hover the map marker for the estimated take. Reported $1,000 – $12,000.",
            heat: "Higher than small stores",
            steps: [
                "Hover the map marker to see the estimated take.",
                "Scout it. Many have a back entrance.",
                "Disable security or destroy the CCTV footage to delay the police.",
                "Smash the cases and grab the goods into your stash bag.",
                "Get the bag into your trunk, escape, then fence the goods.",
            ],
            watchOut: [
                "The goods aren't cash yet. You have to fence them.",
                "Cloud footage can't be destroyed, and the alarm goes off eventually.",
            ],
            note: "Shown on the map under Smash 'n' Grabs."),
        RobberyGuide(
            id: "jewelry", name: "Jewelry store", symbol: "diamond",
            tier: .mid,
            unlock: "Later in the story (reported Chapter 3)",
            take: "Hover the map marker for the estimated take",
            heat: "Higher than small stores",
            steps: [
                "Hover the map marker to see the estimated take.",
                "Scout it: more security than a shop. Look for the back way in.",
                "Disable security or wipe the CCTV footage first.",
                "Smash the cases fast. Every second gives the police more time.",
                "Stash bag into the trunk. Escape, lose the stars, then fence.",
            ],
            watchOut: [
                "Expect a bigger police response than at a shop.",
                "Lose the bag and you lose the score. Escape before you do anything else.",
            ],
            note: "Shown on the map under Smash 'n' Grabs."),
        RobberyGuide(
            id: "safes", name: "Safes", symbol: "lock.square",
            tier: .mid,
            unlock: "Inside many stores. Also shown on the map.",
            take: "Varies",
            heat: "Searching costs time, and the police close in meanwhile",
            steps: [
                "Look near the safe for a code on a sticky note.",
                "Use Focus (L3 + R3) to mark staff who know the code, then threaten them.",
                "Or search the area or talk to people around it.",
                "Kick in locked doors to reach it.",
                "As a last resort, use explosives. They open it but damage the cash.",
            ],
            watchOut: ["A fence can sometimes give you safe codes."],
            note: "Guides disagree on how codes are found, so try each method."),
        RobberyGuide(
            id: "atm", name: "Towable ATMs", symbol: "creditcard",
            tier: .mid,
            unlock: "Shown on the map",
            take: "Not confirmed",
            heat: "Not confirmed",
            steps: [
                "Bring a vehicle that can tow.",
                "Hook up the ATM and drag it somewhere quiet.",
            ],
            watchOut: ["No guide has confirmed the details yet. Update these notes once you've done one."],
            note: nil),
        RobberyGuide(
            id: "bank", name: "Bank", symbol: "building.columns",
            tier: .big,
            unlock: "After a story mission gives you the dye pack jammer",
            take: "Hover the map marker. It's the biggest tier.",
            heat: "Big police response once it's called in",
            steps: [
                "Plan the full escape route first: car, outfit change, hiding spot.",
                "Tellers: empty the cash drawers.",
                "Safes hold marked bills. The jammer handles the dye packs.",
                "The vault holds the most money. Go for it if the clock allows.",
                "Leave before the response builds. Switch cars, and change your outfit.",
            ],
            watchOut: [
                "Marked bills: keep the jammer on you.",
                "Don't go back into the area while the red heat zone is still up.",
            ],
            note: nil),
    ]

    // MARK: Rules

    public static let rules: [RuleGroup] = [
        RuleGroup(id: "escape", title: "Getting away", symbol: "car", rules: [
            "Store robberies usually give 1–2 stars.",
            "Flashing stars: the police lost sight of you. Stay hidden.",
            "Red star: you're still in the search area. Keep moving.",
            "The police know your outfit and car. Change from the trunk and swap vehicles.",
            "Pay 'n' Spray ($200) makes a known car unknown again.",
            "After the stars clear, a red heat zone remains. Leave it, and don't rob there again until it's gone.",
        ]),
        RuleGroup(id: "cash", title: "Keeping the money", symbol: "lock.shield", rules: [
            "You can carry at most $20,000. Anything over that is wasted.",
            "Deposit at an ATM after every score. You can't deposit from the phone.",
            "If you're wasted or busted, you lose pocket cash, unowned weapons and probably your stash bags.",
            "Banked money is always safe.",
            "Goods go in a stash bag. Put it in the trunk, but if you don't escape you can still lose it.",
            "Goods need a fence. Different loot needs different fences, and some unlock with the story.",
        ]),
        RuleGroup(id: "kit", title: "Buy first", symbol: "bag", rules: [
            "A mask or hat. Wear one you already own.",
            "A full spare outfit in the trunk.",
            "Ammo and a reliable gun from Ammu-Nation.",
            "An older, cheap getaway car. You can hotwire them; newer cars may need a key cloner.",
            "Keep $200 on you for Pay 'n' Spray.",
            "Then a garage. Garages are the property you can buy; safe houses can't be bought.",
        ]),
        RuleGroup(id: "clean", title: "Clean run checklist", symbol: "checkmark.seal", rules: [
            "Scouted the place.",
            "Disguise on.",
            "Car parked at the exit.",
            "Cameras out.",
            "Got in and out fast.",
            "Lost the stars.",
            "Changed outfit and car.",
            "Fenced the goods.",
            "Banked the cash.",
        ]),
    ]

    // MARK: Money

    public static let money: [MoneyMethod] = [
        MoneyMethod(id: "stores", name: "Store robberies", symbol: "cart",
                    unlock: "From the start", pay: "$200 – $2,000 each",
                    how: ["The fastest early cash. See the Rob tab.", "Rotate between areas so the heat zones can clear."]),
        MoneyMethod(id: "story", name: "Story & side missions", symbol: "flag",
                    unlock: "Story", pay: "Often a large payout",
                    how: ["Some story points wait until you hit a cash goal, so keep a buffer banked."]),
        MoneyMethod(id: "cars", name: "Sell stolen cars", symbol: "car.side",
                    unlock: "Chapter 2", pay: "$1,000 – $5,000 per car",
                    how: [
                        "Sell to the car buyer. Cars with a tracker can't be sold until Pay 'n' Spray lets you clear them.",
                        "Scan cars with the WAiNK phone app to check what they're worth.",
                        "The buyer's cooldown resets when you sleep at a safe house.",
                        "A higher-paying buyer opens later.",
                    ]),
        MoneyMethod(id: "smash", name: "Pawn & jewelry", symbol: "diamond",
                    unlock: "Later in the story (reported Ch 2–3)", pay: "Pawn shops reported at $1,000 – $12,000",
                    how: ["Hover the map marker for the estimated take.", "Fence the goods, then bank the cash."]),
        MoneyMethod(id: "hideouts", name: "Gang hideouts & deals", symbol: "shippingbox",
                    unlock: "After you can sell drugs", pay: "Varies: cheap stuff pays little, hard stuff pays a lot",
                    how: ["Look for the yellow map icon.", "Later buyers may offer a garage drop-off for a bigger cut."]),
        MoneyMethod(id: "banks", name: "Banks & heists", symbol: "building.columns",
                    unlock: "Story", pay: "The biggest tier",
                    how: ["Needs the dye pack jammer.", "Plan the escape before you go in."]),
    ]
}
