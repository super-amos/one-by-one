import Foundation

/// Something the user bought with reward money.
public struct Spend: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var amount: Decimal
    public var note: String
    public var date: Date

    public init(id: UUID = UUID(), amount: Decimal, note: String, date: Date = .now) {
        self.id = id
        self.amount = amount
        self.note = note
        self.date = date
    }
}

/// One day's mock credit-card interest on a negative balance.
public struct InterestCharge: Codable, Equatable, Sendable {
    public var day: Date
    public var amount: Decimal
}

public enum Currency: String, CaseIterable, Codable, Identifiable, Sendable {
    // Dollars and shekels first, then the rest of the ten most-traded currencies.
    case usd = "USD", ils = "ILS", eur = "EUR", jpy = "JPY", gbp = "GBP"
    case cny = "CNY", aud = "AUD", cad = "CAD", chf = "CHF", hkd = "HKD", sgd = "SGD"

    public var id: String { rawValue }
    public var code: String { rawValue }

    public var name: String {
        switch self {
        case .usd: "US dollar"
        case .ils: "Israeli shekel"
        case .eur: "Euro"
        case .jpy: "Japanese yen"
        case .gbp: "British pound"
        case .cny: "Chinese yuan"
        case .aud: "Australian dollar"
        case .cad: "Canadian dollar"
        case .chf: "Swiss franc"
        case .hkd: "Hong Kong dollar"
        case .sgd: "Singapore dollar"
        }
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var currency = Currency.usd
    /// Yearly interest on a negative balance, as a fraction: 0.10 is 10%.
    public var interestRate: Decimal = 0.10
    public var soundsOn = true
    /// Whether Claude's MCP tools may read and change the deck.
    public var claudeCanEdit = false

    public init() {}
}

/// Everything the app saves: the deck, the reward ledger and the settings.
public struct AppState: Codable, Equatable, Sendable {
    public var deck = Deck()
    /// Newest first.
    public private(set) var spending: [Spend] = []
    /// Oldest first, one per day that ended below zero.
    public private(set) var interest: [InterestCharge] = []
    /// Interest has been charged for every day before this one.
    public private(set) var interestChargedThrough: Date?
    public var settings = AppSettings()

    public init(deck: Deck = Deck()) {
        self.deck = deck
    }

    public var spent: Decimal {
        spending.reduce(0) { $0 + $1.amount }
    }

    public var interestCharged: Decimal {
        interest.reduce(0) { $0 + $1.amount }
    }

    /// Reward money left to spend. Negative means the user has spent more than
    /// they've earned.
    public var balance: Decimal {
        deck.earned - spent - interestCharged
    }

    public mutating func logSpend(_ spend: Spend) {
        spending.append(spend)
        spending.sort { $0.date > $1.date }
    }

    public mutating func updateSpend(_ spend: Spend) {
        guard let index = spending.firstIndex(where: { $0.id == spend.id }) else { return }
        spending[index] = spend
        spending.sort { $0.date > $1.date }
    }

    public mutating func deleteSpend(_ id: UUID) {
        spending.removeAll { $0.id == id }
    }

    /// Charges one day's interest for each day that has ended since the last
    /// charge, compounding on the debt. The first call only records today.
    /// Returns the total charged.
    @discardableResult
    public mutating func chargeInterest(now: Date = .now, calendar: Calendar = .current) -> Decimal {
        let today = calendar.startOfDay(for: now)
        guard var day = interestChargedThrough else {
            interestChargedThrough = today
            return 0
        }
        var total: Decimal = 0
        while day < today {
            if balance < 0, settings.interestRate > 0 {
                let charge = -balance * settings.interestRate / 365
                interest.append(InterestCharge(day: day, amount: charge))
                total += charge
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        interestChargedThrough = today
        return total
    }
}
