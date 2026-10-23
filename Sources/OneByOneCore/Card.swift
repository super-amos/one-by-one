import Foundation

/// One task. Which list of `Deck` holds it decides whether it's still to do,
/// finished, or in the trash.
public struct Card: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var note: String
    /// The card's own reward. `nil` means it's worth the deck's default value.
    public var value: Decimal?
    /// How many times the card has been put off.
    public var skipCount: Int
    public var createdAt: Date
    /// True for cards Claude added through the MCP server.
    public var fromClaude: Bool
    public var completedAt: Date?
    /// What finishing the card added to the balance, fixed at that moment.
    public var earned: Decimal?
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        note: String = "",
        value: Decimal? = nil,
        skipCount: Int = 0,
        createdAt: Date = .now,
        fromClaude: Bool = false
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.value = value
        self.skipCount = skipCount
        self.createdAt = createdAt
        self.fromClaude = fromClaude
    }
}
