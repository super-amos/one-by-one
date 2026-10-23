import Foundation

/// The rule for tasks Claude writes: one sentence, at most 120 characters.
public enum ClaudeTitleRule {
    public static let maxLength = 120

    /// Why a title breaks the rule, or nil if it's fine.
    public static func problem(with title: String) -> String? {
        let text = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            return "The title is empty."
        }
        if text.contains(where: \.isNewline) {
            return "The title has a line break. Write one sentence on one line."
        }
        if text.count > maxLength {
            return "The title is \(text.count) characters. Keep it to \(maxLength) or fewer."
        }
        // Dots in abbreviations don't end a sentence. Only whole words count,
        // so the "st." at the end of "dentist." still does.
        let abbreviation = /\b(?:e\.g|i\.e|etc|vs|approx|a\.m|p\.m|dr|mr|mrs|ms|st|jr|sr)\./.ignoresCase()
        let scrubbed = text.replacing(abbreviation, with: "x")
        if scrubbed.contains(/[.!?]+["')\]]*\s+\S/) {
            return "The title is more than one sentence. Write one sentence."
        }
        return nil
    }
}

/// The tools Claude gets through the MCP server. Each one works on the saved
/// state and answers in text, which is what Claude reads.
public enum ClaudeTools {
    public struct Outcome: Equatable, Sendable {
        public let text: String
        public let isError: Bool

        public init(text: String, isError: Bool) {
            self.text = text
            self.isError = isError
        }

        static func ok(_ text: String) -> Outcome { Outcome(text: text, isError: false) }
        static func error(_ text: String) -> Outcome { Outcome(text: text, isError: true) }
    }

    /// The most a single task can be worth.
    static let maxValue: Decimal = 10_000

    public static let instructions = """
        One by One shows the user their to-do list one task at a time, in the order they chose. \
        The first task in the deck is the one on screen right now; you can't move it or put anything \
        above it. Every task you write must be a single sentence of at most 120 characters. Each task \
        has a reward value in the user's currency that they earn when they finish it.
        """

    public static var definitions: [[String: Any]] {
        let none: [String: Any] = [:]
        let titleSchema: [String: Any] = [
            "type": "string",
            "maxLength": ClaudeTitleRule.maxLength,
            "description": "One sentence, at most \(ClaudeTitleRule.maxLength) characters.",
        ]
        let valueSchema: [String: Any] = [
            "type": "number",
            "minimum": 0,
            "maximum": NSDecimalNumber(decimal: maxValue),
            "description": "Reward the user earns for finishing it, in their currency.",
        ]
        let newTask: [String: Any] = [
            "type": "object",
            "properties": ["title": titleSchema, "value": valueSchema],
            "required": ["title"],
        ]
        let position: [String: Any] = [
            "type": "string",
            "enum": ["next", "last"],
            "description": "next puts them right after the task on screen. last puts them at the bottom. Defaults to last.",
        ]
        let valueChange: [String: Any] = [
            "type": "object",
            "properties": ["id": ["type": "string"], "value": valueSchema],
            "required": ["id", "value"],
        ]
        return [
            [
                "name": "list_tasks",
                "description": "Lists the user's tasks in order, with ids, values and the currency. The first task, marked on_screen, is the one the user is looking at now.",
                "inputSchema": ["type": "object", "properties": none],
            ],
            [
                "name": "add_tasks",
                "description": "Adds tasks to the user's deck. Each title must be one sentence of at most \(ClaudeTitleRule.maxLength) characters; anything else is sent back. Leave out value to use the user's default reward.",
                "inputSchema": [
                    "type": "object",
                    "properties": [
                        "tasks": ["type": "array", "minItems": 1, "items": newTask],
                        "position": position,
                    ],
                    "required": ["tasks"],
                ],
            ],
            [
                "name": "reorder_tasks",
                "description": "Puts the user's tasks in a new order. Pass the id of every task except the one on screen, each once, in the order you want. The task on screen stays first.",
                "inputSchema": [
                    "type": "object",
                    "properties": ["ids": ["type": "array", "items": ["type": "string"]]],
                    "required": ["ids"],
                ],
            ],
            [
                "name": "set_values",
                "description": "Sets how much reward money tasks are worth.",
                "inputSchema": [
                    "type": "object",
                    "properties": ["values": ["type": "array", "minItems": 1, "items": valueChange]],
                    "required": ["values"],
                ],
            ],
        ]
    }

    public static func call(_ name: String, arguments: [String: Any], state: inout AppState) -> Outcome {
        guard state.settings.claudeCanEdit else {
            return .error("The user hasn't let Claude change their tasks. They can turn it on in One by One → Settings → Claude.")
        }
        switch name {
        case "list_tasks": return list(state)
        case "add_tasks": return add(arguments, to: &state)
        case "reorder_tasks": return reorder(arguments, in: &state)
        case "set_values": return setValues(arguments, in: &state)
        default: return .error("There's no tool called \(name).")
        }
    }

    private static func list(_ state: AppState) -> Outcome {
        let deck = state.deck
        let tasks: [[String: Any]] = deck.cards.enumerated().map { index, card in
            var task: [String: Any] = [
                "id": card.id.uuidString,
                "title": card.title,
                "value": number(deck.value(of: card)),
                "on_screen": index == 0,
            ]
            if !card.note.isEmpty { task["note"] = card.note }
            if card.fromClaude { task["added_by_claude"] = true }
            return task
        }
        return .ok(json([
            "currency": state.settings.currency.code,
            "default_value": number(deck.defaultValue),
            "tasks": tasks,
        ]))
    }

    private static func add(_ arguments: [String: Any], to state: inout AppState) -> Outcome {
        guard let items = arguments["tasks"] as? [[String: Any]], !items.isEmpty else {
            return .error("Pass `tasks`: a list of objects, each with a `title`.")
        }
        let position = arguments["position"] as? String ?? "last"
        guard position == "next" || position == "last" else {
            return .error("`position` must be \"next\" or \"last\".")
        }
        var cards: [Card] = []
        var problems: [String] = []
        for (index, item) in items.enumerated() {
            let title = (item["title"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if let problem = ClaudeTitleRule.problem(with: title) {
                problems.append("Task \(index + 1) (\"\(title)\"): \(problem)")
                continue
            }
            var value: Decimal?
            if let raw = item["value"] {
                guard let parsed = amount(raw) else {
                    problems.append("Task \(index + 1): `value` must be a number from 0 to \(maxValue).")
                    continue
                }
                value = parsed
            }
            cards.append(Card(title: title, value: value, fromClaude: true))
        }
        guard problems.isEmpty else {
            return .error("Nothing was added. Fix these and try again:\n" + problems.joined(separator: "\n"))
        }
        if position == "next" {
            state.deck.insertAfterCurrent(cards)
        } else {
            state.deck.add(contentsOf: cards, placement: .last)
        }
        let place = position == "next" ? "right after the task on screen" : "at the bottom of the deck"
        let added = cards.map { ["id": $0.id.uuidString, "title": $0.title] }
        return .ok("Added \(plural(cards.count, "task")) \(place).\n" + json(["added": added]))
    }

    private static func reorder(_ arguments: [String: Any], in state: inout AppState) -> Outcome {
        guard let given = (arguments["ids"] as? [String])?.map({ $0.uppercased() }) else {
            return .error("Pass `ids`: every task id except the one on screen, in the new order.")
        }
        let ids = given.compactMap(UUID.init(uuidString:))
        if ids.count == given.count, state.deck.reorderBelowCurrent(ids) {
            return .ok("Done. The deck is in the new order, and the task on screen is still first.")
        }
        let expected = state.deck.cards.dropFirst().map(\.id.uuidString)
        var lines = ["Nothing was moved. `ids` must list every task except the one on screen, each exactly once."]
        let missing = expected.filter { !given.contains($0) }
        let unknown = given.filter { !expected.contains($0) }
        if !missing.isEmpty { lines.append("Missing: " + missing.joined(separator: ", ")) }
        if !unknown.isEmpty { lines.append("Unknown, or the task on screen: " + unknown.joined(separator: ", ")) }
        if Set(given).count != given.count { lines.append("Some ids appear more than once.") }
        return .error(lines.joined(separator: "\n"))
    }

    private static func setValues(_ arguments: [String: Any], in state: inout AppState) -> Outcome {
        guard let items = arguments["values"] as? [[String: Any]], !items.isEmpty else {
            return .error("Pass `values`: a list of objects, each with an `id` and a `value`.")
        }
        let known = Set(state.deck.cards.map(\.id))
        var changes: [(UUID, Decimal)] = []
        var problems: [String] = []
        for item in items {
            let rawID = item["id"] as? String ?? ""
            guard let id = UUID(uuidString: rawID), known.contains(id) else {
                problems.append("No task to do has the id \"\(rawID)\".")
                continue
            }
            guard let raw = item["value"], let value = amount(raw) else {
                problems.append("\(rawID): `value` must be a number from 0 to \(maxValue).")
                continue
            }
            changes.append((id, value))
        }
        guard problems.isEmpty else {
            return .error("Nothing was changed. Fix these and try again:\n" + problems.joined(separator: "\n"))
        }
        for (id, value) in changes {
            state.deck.setValue(value, for: [id])
        }
        return .ok("Set the value of \(plural(changes.count, "task")).")
    }

    /// A JSON number between 0 and `maxValue`, rounded to cents. Booleans,
    /// which JSON parsing also turns into numbers, don't count.
    private static func amount(_ raw: Any) -> Decimal? {
        guard let number = raw as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let value = number.decimalValue.rounded(scale: 2, .plain)
        return value >= 0 && value <= maxValue ? value : nil
    }

    private static func number(_ value: Decimal) -> NSDecimalNumber {
        NSDecimalNumber(decimal: value.rounded(scale: 2, .plain))
    }

    private static func plural(_ count: Int, _ noun: String) -> String {
        "\(count) \(noun)\(count == 1 ? "" : "s")"
    }

    private static func json(_ object: Any) -> String {
        let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: options) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}
