import Foundation
import Testing
@testable import OneByOneCore

private func deck(_ titles: String..., defaultValue: Decimal = 2) -> Deck {
    Deck(cards: titles.map { Card(title: $0) }, defaultValue: defaultValue)
}

@Test func completingEarnsTheCardsOwnValueOrTheDefault() {
    var deck = Deck(cards: [Card(title: "A", value: 5), Card(title: "B")], defaultValue: 2)

    #expect(deck.completeCurrent() == 5)
    #expect(deck.completeCurrent() == 2)
    #expect(deck.earned == 7)
    #expect(deck.cards.isEmpty)
    #expect(deck.done.map(\.title) == ["B", "A"])
}

@Test func changingTheDefaultLaterDoesNotChangeWhatWasEarned() {
    var deck = deck("A")
    deck.completeCurrent()
    deck.defaultValue = 10

    #expect(deck.earned == 2)
    #expect(deck.done[0].earned == 2)
}

@Test func puttingOffSendsTheCardToTheBottomAndCountsIt() {
    var deck = deck("A", "B", "C")
    deck.deferCurrent()

    #expect(deck.cards.map(\.title) == ["B", "C", "A"])
    #expect(deck.cards[2].skipCount == 1)
}

@Test func asksBeforeTheThirdPutOff() {
    var deck = deck("A")
    deck.deferCurrent()
    #expect(!deck.shouldAskBeforeSkipping(deck.current!))
    deck.deferCurrent()
    #expect(deck.shouldAskBeforeSkipping(deck.current!))
}

@Test func undoingADoneTakesTheMoneyBack() {
    var deck = deck("A", "B")
    deck.completeCurrent()
    deck.undo()

    #expect(deck.earned == 0)
    #expect(deck.done.isEmpty)
    #expect(deck.current?.title == "A")
    #expect(deck.current?.earned == nil)
}

@Test func undoingALaterPutsTheCardBackOnTopAndUncountsIt() {
    var deck = deck("A", "B", "C")
    deck.deferCurrent()
    deck.undo()

    #expect(deck.cards.map(\.title) == ["A", "B", "C"])
    #expect(deck.current?.skipCount == 0)
}

@Test func undoingADeleteBringsTheCardBackFromTheTrash() {
    var deck = deck("A", "B")
    deck.deleteCurrent()
    #expect(deck.trash.map(\.title) == ["A"])

    deck.undo()
    #expect(deck.trash.isEmpty)
    #expect(deck.current?.title == "A")
    #expect(deck.current?.deletedAt == nil)
}

@Test func thereIsOnlyOneLevelOfUndo() {
    var deck = deck("A", "B")
    deck.completeCurrent()
    deck.completeCurrent()
    deck.undo()

    #expect(!deck.canUndo)
    #expect(deck.undo() == nil)
    #expect(deck.cards.map(\.title) == ["B"])
}

@Test func undoKeepsEditsMadeAfterTheAction() {
    var deck = deck("A", "B")
    deck.deferCurrent()
    var edited = deck.cards[1]
    edited.title = "A, edited"
    deck.update(edited)
    deck.undo()

    #expect(deck.current?.title == "A, edited")
}

@Test func newCardsGoNextOrLast() {
    var deck = deck("A")
    deck.add(Card(title: "Next"), placement: .next)
    deck.add(Card(title: "Last"), placement: .last)

    #expect(deck.cards.map(\.title) == ["Next", "A", "Last"])
}

@Test func splittingSharesTheValueWithoutCreatingMoney() {
    var deck = deck("Big", "Other")
    deck.splitCurrent(into: ["One", " ", "Two", "Three"])

    #expect(deck.cards.map(\.title) == ["One", "Two", "Three", "Other"])
    #expect(deck.cards.prefix(3).map(\.value) == [0.66, 0.66, 0.68])
    let total = deck.cards.prefix(3).reduce(Decimal(0)) { $0 + ($1.value ?? 0) }
    #expect(total == 2)
}

@Test func undoIsSafeWhenItsCardWasSplitAway() {
    var deck = deck("Only")
    deck.deferCurrent()
    deck.splitCurrent(into: ["Part"])

    #expect(deck.undo() == nil)
    #expect(deck.cards.map(\.title) == ["Part"])
}
