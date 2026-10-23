/// Every line the app says to the user, kept together so the voice stays the
/// same everywhere. SPEC.md has the full table.
enum Copy {
    static let headline = "This is what we need to get done now."
    static let subhead = "Forget everything else."

    /// Rotates between a few lines so finishing doesn't read the same every time.
    static func done(_ amount: String, finishedCount: Int, wasLast: Bool) -> String {
        if wasLast { return "Done. \(amount) earned. That was the last one." }
        let lines = [
            "Done. \(amount) added to your rewards.",
            "That one's gone. You earned \(amount).",
            "\(amount) earned. Now just this one.",
        ]
        return lines[finishedCount % lines.count]
    }

    static let later = "Okay, later. Right now, this one."
    static let undone = "Brought it back."
    static let deleted = "Moved to Trash."
    static let split = "Smaller now. Start with this one."
    static let addedNext = "Added. It's up now."
    static let addedLast = "Added. It'll come up later."

    static let skipPromptTitle = "You keep putting this one off."
    static let skipPromptBody = "Make it smaller, or let it go."

    static let emptyTitle = "That's everything."
    static let emptyBody = "Nothing left to do."
    static func emptyReward(_ amount: String) -> String {
        "You have \(amount) in rewards. Go enjoy some of it."
    }

    static let firstTitle = "Start with one thing."
    static let firstBody = "What needs doing?"

    static let rewardsPositive = "You earned this. Spend it without guilt."
    static let rewardsNothingYet = "Finish a task to earn your first reward."
    static func rewardsNegative(_ debt: String) -> String {
        "You're \(debt) in the red, and interest is adding up. A few tasks will clear it."
    }
}
