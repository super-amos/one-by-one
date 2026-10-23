import Foundation

/// Where a new card goes in the deck.
public enum Placement: String, Codable, Sendable {
    case next, last
}

/// The last done, later or delete on Home, kept so it can be undone.
public enum DeckAction: Codable, Equatable, Sendable {
    case completed(Card)
    case deferred(Card)
    case deleted(Card)

    var cardID: UUID {
        switch self {
        case .completed(let card), .deferred(let card), .deleted(let card): card.id
        }
    }
}

/// All of the user's cards: the ones to do, the finished ones, and the trash.
public struct Deck: Codable, Equatable, Sendable {
    /// From this many put-offs on, Home asks before putting a card off again.
    public static let skipsBeforeAsking = 2

    /// Cards still to do, in order. Home only ever shows the first.
    public private(set) var cards: [Card]
    /// Finished cards, most recent first.
    public private(set) var done: [Card] = []
    /// Deleted cards, most recent first.
    public private(set) var trash: [Card] = []
    /// What a card without its own value is worth.
    public var defaultValue: Decimal
    public private(set) var lastAction: DeckAction?

    public init(cards: [Card] = [], defaultValue: Decimal = 2) {
        self.cards = cards
        self.defaultValue = defaultValue
    }

    public var current: Card? { cards.first }
    public var canUndo: Bool { lastAction != nil }

    /// What all finished cards have earned together.
    public var earned: Decimal {
        done.reduce(0) { $0 + ($1.earned ?? 0) }
    }

    public func value(of card: Card) -> Decimal {
        card.value ?? defaultValue
    }

    public func shouldAskBeforeSkipping(_ card: Card) -> Bool {
        card.skipCount >= Self.skipsBeforeAsking
    }

    // MARK: Home

    /// Finishes the current card and returns what it earned.
    @discardableResult
    public mutating func completeCurrent(at date: Date = .now) -> Decimal? {
        guard !cards.isEmpty else { return nil }
        var card = cards.removeFirst()
        let earned = value(of: card)
        card.completedAt = date
        card.earned = earned
        done.insert(card, at: 0)
        lastAction = .completed(card)
        return earned
    }

    /// Puts the current card off by sending it to the bottom.
    public mutating func deferCurrent() {
        guard !cards.isEmpty else { return }
        var card = cards.removeFirst()
        card.skipCount += 1
        cards.append(card)
        lastAction = .deferred(card)
    }

    public mutating func deleteCurrent(at date: Date = .now) {
        guard !cards.isEmpty else { return }
        var card = cards.removeFirst()
        card.deletedAt = date
        trash.insert(card, at: 0)
        lastAction = .deleted(card)
    }

    /// Reverses the last done, later or delete and puts that card back on top.
    @discardableResult
    public mutating func undo() -> DeckAction? {
        guard let action = lastAction else { return nil }
        lastAction = nil
        switch action {
        case .completed(let card):
            guard var restored = Self.take(card.id, from: &done) else { return nil }
            restored.completedAt = nil
            restored.earned = nil
            cards.insert(restored, at: 0)
        case .deferred(let card):
            guard var restored = Self.take(card.id, from: &cards) else { return nil }
            restored.skipCount -= 1
            cards.insert(restored, at: 0)
        case .deleted(let card):
            guard var restored = Self.take(card.id, from: &trash) else { return nil }
            restored.deletedAt = nil
            cards.insert(restored, at: 0)
        }
        return action
    }

    public mutating func add(_ card: Card, placement: Placement) {
        add(contentsOf: [card], placement: placement)
    }

    public mutating func add(contentsOf newCards: [Card], placement: Placement) {
        switch placement {
        case .next: cards.insert(contentsOf: newCards, at: 0)
        case .last: cards.append(contentsOf: newCards)
        }
    }

    /// Adds cards right after the one on screen, so the card being worked on
    /// doesn't change.
    public mutating func insertAfterCurrent(_ newCards: [Card]) {
        cards.insert(contentsOf: newCards, at: min(1, cards.count))
    }

    /// Replaces a card that's still to do with an edited copy.
    public mutating func update(_ card: Card) {
        guard let index = cards.firstIndex(where: { $0.id == card.id }) else { return }
        cards[index] = card
    }

    public mutating func splitCurrent(into titles: [String]) {
        guard let id = current?.id else { return }
        split(id, into: titles)
    }

    /// Replaces a card with smaller ones, in its place and in the order given.
    /// They share the original card's value, so splitting never creates money.
    public mutating func split(_ id: UUID, into titles: [String]) {
        let titles = titles
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !titles.isEmpty, let index = cards.firstIndex(where: { $0.id == id }) else { return }
        let original = cards.remove(at: index)
        let shares = Self.split(value(of: original), into: titles.count)
        let parts = zip(titles, shares).map { Card(title: $0, value: $1) }
        cards.insert(contentsOf: parts, at: index)
        forget([id])
    }

    // MARK: Edit

    /// Moves a card to where `target` is now, shifting the cards in between.
    public mutating func move(_ id: UUID, toPositionOf target: UUID) {
        guard id != target,
              let from = cards.firstIndex(where: { $0.id == id }),
              let to = cards.firstIndex(where: { $0.id == target })
        else { return }
        let card = cards.remove(at: from)
        cards.insert(card, at: to)
    }

    /// Moves cards to the top, keeping their order relative to each other.
    public mutating func moveToTop(_ ids: Set<UUID>) {
        let moving = cards.filter { ids.contains($0.id) }
        cards.removeAll { ids.contains($0.id) }
        cards.insert(contentsOf: moving, at: 0)
    }

    public mutating func moveToBottom(_ ids: Set<UUID>) {
        let moving = cards.filter { ids.contains($0.id) }
        cards.removeAll { ids.contains($0.id) }
        cards.append(contentsOf: moving)
    }

    /// Reorders the cards below the one on screen. `ids` must name each of
    /// them exactly once; otherwise nothing changes and this returns false.
    @discardableResult
    public mutating func reorderBelowCurrent(_ ids: [UUID]) -> Bool {
        guard let current = cards.first else { return ids.isEmpty }
        let rest = cards.dropFirst()
        guard ids.count == rest.count, Set(ids) == Set(rest.map(\.id)) else { return false }
        let byID = Dictionary(uniqueKeysWithValues: rest.map { ($0.id, $0) })
        cards = [current] + ids.compactMap { byID[$0] }
        return true
    }

    public mutating func setValue(_ value: Decimal?, for ids: Set<UUID>) {
        for index in cards.indices where ids.contains(cards[index].id) {
            cards[index].value = value
        }
    }

    /// Moves cards that are still to do into the trash.
    public mutating func delete(_ ids: Set<UUID>, at date: Date = .now) {
        let removed = cards.filter { ids.contains($0.id) }
        cards.removeAll { ids.contains($0.id) }
        for var card in removed {
            card.deletedAt = date
            trash.insert(card, at: 0)
        }
        forget(ids)
    }

    // MARK: History and Trash

    /// Puts a finished card back on top of the deck. Its reward comes off the
    /// balance, since the balance counts only finished cards.
    public mutating func restoreFinished(_ id: UUID) {
        guard var card = Self.take(id, from: &done) else { return }
        card.completedAt = nil
        card.earned = nil
        cards.insert(card, at: 0)
        forget([id])
    }

    /// Puts a deleted card back on top of the deck.
    public mutating func restoreDeleted(_ id: UUID) {
        guard var card = Self.take(id, from: &trash) else { return }
        card.deletedAt = nil
        cards.insert(card, at: 0)
        forget([id])
    }

    public mutating func deleteForever(_ ids: Set<UUID>) {
        trash.removeAll { ids.contains($0.id) }
        forget(ids)
    }

    public mutating func emptyTrash() {
        deleteForever(Set(trash.map(\.id)))
    }

    /// Deletes for good anything that's been in the trash for `days` days.
    public mutating func purgeTrash(olderThan days: Int = 30, now: Date = .now) {
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        deleteForever(Set(trash.filter { ($0.deletedAt ?? now) < cutoff }.map(\.id)))
    }

    // MARK: Helpers

    /// Divides an amount into `count` shares of whole cents. The last share
    /// takes whatever cents are left over.
    static func split(_ total: Decimal, into count: Int) -> [Decimal] {
        let each = (total / Decimal(count)).rounded(scale: 2, .down)
        return Array(repeating: each, count: count - 1) + [total - each * Decimal(count - 1)]
    }

    private static func take(_ id: UUID, from list: inout [Card]) -> Card? {
        guard let index = list.firstIndex(where: { $0.id == id }) else { return nil }
        return list.remove(at: index)
    }

    /// Drops the undo when a later change took its card somewhere undo can't follow.
    private mutating func forget(_ ids: Set<UUID>) {
        if let action = lastAction, ids.contains(action.cardID) {
            lastAction = nil
        }
    }
}

extension Decimal {
    public func rounded(scale: Int, _ mode: NSDecimalNumber.RoundingMode) -> Decimal {
        var source = self
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, mode)
        return result
    }
}
