import Foundation
import Testing
@testable import OneByOneCore

private func deck(_ titles: String...) -> Deck {
    Deck(cards: titles.map { Card(title: $0) }, defaultValue: 2)
}

private func ids(_ deck: Deck, _ titles: String...) -> Set<UUID> {
    Set(deck.cards.filter { titles.contains($0.title) }.map(\.id))
}

@Test func movingACardShiftsTheOnesInBetween() {
    var deck = deck("A", "B", "C", "D")
    deck.move(deck.cards[0].id, toPositionOf: deck.cards[2].id)
    #expect(deck.cards.map(\.title) == ["B", "C", "A", "D"])

    deck.move(deck.cards[3].id, toPositionOf: deck.cards[0].id)
    #expect(deck.cards.map(\.title) == ["D", "B", "C", "A"])
}

@Test func movingToTopOrBottomKeepsTheMovedCardsInOrder() {
    var deck = deck("A", "B", "C", "D")
    deck.moveToTop(ids(deck, "D", "B"))
    #expect(deck.cards.map(\.title) == ["B", "D", "A", "C"])

    deck.moveToBottom(ids(deck, "B", "A"))
    #expect(deck.cards.map(\.title) == ["D", "C", "B", "A"])
}

@Test func deletingFromEditMovesCardsToTheTrash() {
    var deck = deck("A", "B", "C")
    deck.delete(ids(deck, "A", "C"))

    #expect(deck.cards.map(\.title) == ["B"])
    #expect(Set(deck.trash.map(\.title)) == ["A", "C"])
    #expect(deck.trash.allSatisfy { $0.deletedAt != nil })
}

@Test func settingAValueForSeveralCards() {
    var deck = deck("A", "B", "C")
    deck.setValue(7, for: ids(deck, "A", "C"))

    #expect(deck.cards.map(\.value) == [7, nil, 7])
}

@Test func splittingACardInTheMiddleKeepsItsPlace() {
    var deck = deck("A", "B", "C")
    deck.split(deck.cards[1].id, into: ["B1", "B2"])

    #expect(deck.cards.map(\.title) == ["A", "B1", "B2", "C"])
}

@Test func restoringAFinishedCardTakesItsRewardBack() {
    var deck = deck("A", "B")
    deck.completeCurrent()
    #expect(deck.earned == 2)

    deck.restoreFinished(deck.done[0].id)
    #expect(deck.earned == 0)
    #expect(deck.cards.map(\.title) == ["A", "B"])
    #expect(!deck.canUndo)
}

@Test func restoringFromTrashPutsTheCardOnTop() {
    var deck = deck("A", "B")
    deck.delete(ids(deck, "B"))
    deck.restoreDeleted(deck.trash[0].id)

    #expect(deck.cards.map(\.title) == ["B", "A"])
    #expect(deck.trash.isEmpty)
}

@Test func trashEmptiesItselfAfterThirtyDays() {
    var deck = deck("Old", "New")
    let now = Date(timeIntervalSince1970: 1_000_000_000)
    deck.delete(ids(deck, "Old"), at: now.addingTimeInterval(-31 * 86_400))
    deck.delete(ids(deck, "New"), at: now.addingTimeInterval(-29 * 86_400))
    deck.purgeTrash(now: now)

    #expect(deck.trash.map(\.title) == ["New"])
}

@Test func emptyingTheTrash() {
    var deck = deck("A", "B")
    deck.delete(ids(deck, "A", "B"))
    deck.emptyTrash()

    #expect(deck.trash.isEmpty)
}

@Test func reorderingBelowTheCurrentCardKeepsItOnTop() {
    var deck = deck("Now", "B", "C", "D")
    let byTitle = Dictionary(uniqueKeysWithValues: deck.cards.map { ($0.title, $0.id) })

    let accepted = deck.reorderBelowCurrent([byTitle["D"]!, byTitle["B"]!, byTitle["C"]!])
    #expect(accepted)
    #expect(deck.cards.map(\.title) == ["Now", "D", "B", "C"])
}

@Test func reorderingRejectsAnythingButTheExactSetOfCards() {
    var deck = deck("Now", "B", "C")
    let byTitle = Dictionary(uniqueKeysWithValues: deck.cards.map { ($0.title, $0.id) })

    let attempts = [
        [byTitle["B"]!],
        [byTitle["B"]!, byTitle["B"]!],
        [byTitle["Now"]!, byTitle["B"]!, byTitle["C"]!],
    ]
    for ids in attempts {
        let accepted = deck.reorderBelowCurrent(ids)
        #expect(!accepted)
    }
    #expect(deck.cards.map(\.title) == ["Now", "B", "C"])
}

@Test func addingAfterTheCurrentCardLeavesItOnTop() {
    var deck = deck("Now", "Later")
    deck.insertAfterCurrent([Card(title: "X"), Card(title: "Y")])
    #expect(deck.cards.map(\.title) == ["Now", "X", "Y", "Later"])

    var empty = Deck()
    empty.insertAfterCurrent([Card(title: "First")])
    #expect(empty.current?.title == "First")
}

@Test func pastedListsLoseTheirBulletsAndBlankLines() {
    let text = """
        - Buy milk

        1. Call mom
        - [ ] Pay rent
        • Walk the dog
        [x] Water plants
          Plain line
        """
    #expect(PastedList.titles(from: text) == ["Buy milk", "Call mom", "Pay rent", "Walk the dog", "Water plants", "Plain line"])
}
