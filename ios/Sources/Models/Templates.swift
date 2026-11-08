import Foundation

/// A starter habit the user can add with one tap, then tweak.
struct HabitTemplate: Identifiable {
    let id = UUID()
    let name: String
    let emoji: String
    let colorHex: String
    let kind: HabitKind
    var goalTarget: Int? = nil
    var goalUnit: String? = nil
    var timeOfDay: TimeOfDay = .anytime

    func makeHabit() -> Habit {
        Habit(name: name, emoji: emoji, colorHex: colorHex, kind: kind,
              goalTarget: goalTarget, goalUnit: goalUnit, timeOfDay: timeOfDay)
    }
}

enum TemplateCategory: String, CaseIterable, Identifiable {
    case popular = "Popular"
    case health = "Health"
    case sports = "Sports"
    case lifestyle = "Lifestyle"
    case quit = "Quit"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .popular: return "flame.fill"
        case .health: return "heart.fill"
        case .sports: return "figure.run"
        case .lifestyle: return "house.fill"
        case .quit: return "nosign"
        }
    }
}

/// Our own curated starter library. Generic activities, original palette.
enum Templates {
    static func items(for category: TemplateCategory) -> [HabitTemplate] {
        let c = Palette.habitColors
        switch category {
        case .popular:
            return [
                HabitTemplate(name: "Walk", emoji: "🚶", colorHex: c[2], kind: .build),
                HabitTemplate(name: "Sleep", emoji: "😴", colorHex: c[8], kind: .build, timeOfDay: .evening),
                HabitTemplate(name: "Drink water", emoji: "💧", colorHex: c[1], kind: .build, goalTarget: 8, goalUnit: "glasses"),
                HabitTemplate(name: "Meditate", emoji: "🧘", colorHex: c[3], kind: .build, timeOfDay: .morning),
                HabitTemplate(name: "Run", emoji: "🏃", colorHex: c[4], kind: .build),
                HabitTemplate(name: "Read", emoji: "📖", colorHex: c[9], kind: .build, goalTarget: 20, goalUnit: "minutes"),
                HabitTemplate(name: "Stretch", emoji: "🤸", colorHex: c[6], kind: .build, timeOfDay: .morning),
                HabitTemplate(name: "Workout", emoji: "💪", colorHex: c[5], kind: .build)
            ]
        case .health:
            return [
                HabitTemplate(name: "Drink water", emoji: "💧", colorHex: c[1], kind: .build, goalTarget: 8, goalUnit: "glasses"),
                HabitTemplate(name: "Eat fruit", emoji: "🍎", colorHex: c[11], kind: .build),
                HabitTemplate(name: "Vitamins", emoji: "💊", colorHex: c[7], kind: .build, timeOfDay: .morning),
                HabitTemplate(name: "Sleep 8h", emoji: "😴", colorHex: c[8], kind: .build, timeOfDay: .evening),
                HabitTemplate(name: "Stand up", emoji: "🧍", colorHex: c[5], kind: .build),
                HabitTemplate(name: "Breathe", emoji: "🌬️", colorHex: c[10], kind: .build)
            ]
        case .sports:
            return [
                HabitTemplate(name: "Run", emoji: "🏃", colorHex: c[4], kind: .build),
                HabitTemplate(name: "Cycling", emoji: "🚴", colorHex: c[2], kind: .build),
                HabitTemplate(name: "Swim", emoji: "🏊", colorHex: c[1], kind: .build),
                HabitTemplate(name: "Yoga", emoji: "🧘", colorHex: c[3], kind: .build, timeOfDay: .morning),
                HabitTemplate(name: "Pushups", emoji: "💪", colorHex: c[5], kind: .build, goalTarget: 30, goalUnit: "reps"),
                HabitTemplate(name: "Steps", emoji: "👟", colorHex: c[6], kind: .build, goalTarget: 8000, goalUnit: "steps")
            ]
        case .lifestyle:
            return [
                HabitTemplate(name: "Journal", emoji: "✍️", colorHex: c[9], kind: .build, timeOfDay: .evening),
                HabitTemplate(name: "Learn", emoji: "🎓", colorHex: c[0], kind: .build),
                HabitTemplate(name: "Save money", emoji: "💰", colorHex: c[5], kind: .build),
                HabitTemplate(name: "Tidy up", emoji: "🧹", colorHex: c[10], kind: .build),
                HabitTemplate(name: "Call family", emoji: "📞", colorHex: c[4], kind: .build),
                HabitTemplate(name: "Plan the day", emoji: "🗒️", colorHex: c[7], kind: .build, timeOfDay: .morning)
            ]
        case .quit:
            return [
                HabitTemplate(name: "No late snacks", emoji: "🍫", colorHex: c[4], kind: .quit, timeOfDay: .evening),
                HabitTemplate(name: "Less sugar", emoji: "🍬", colorHex: c[6], kind: .quit),
                HabitTemplate(name: "Less caffeine", emoji: "☕", colorHex: c[7], kind: .quit),
                HabitTemplate(name: "Quit smoking", emoji: "🚭", colorHex: c[11], kind: .quit),
                HabitTemplate(name: "Less screen time", emoji: "📵", colorHex: c[8], kind: .quit, timeOfDay: .evening),
                HabitTemplate(name: "Less alcohol", emoji: "🍺", colorHex: c[5], kind: .quit)
            ]
        }
    }
}
