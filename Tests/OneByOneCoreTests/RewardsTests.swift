import Foundation
import Testing
@testable import OneByOneCore

private var utc: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}

private let day0 = Date(timeIntervalSince1970: 1_790_000_000)

private func days(_ count: Int) -> Date {
    utc.date(byAdding: .day, value: count, to: day0)!
}

private func state(earning values: [Decimal]) -> AppState {
    var state = AppState(deck: Deck(cards: values.map { Card(title: "Task", value: $0) }))
    for _ in values { state.deck.completeCurrent() }
    return state
}

@Test func balanceIsEarnedMinusSpentMinusInterest() {
    var state = state(earning: [10, 5])
    state.logSpend(Spend(amount: 4, note: "Coffee"))

    #expect(state.deck.earned == 15)
    #expect(state.spent == 4)
    #expect(state.balance == 11)
}

@Test func spendingCanBeEditedAndDeleted() {
    var state = state(earning: [10])
    var coffee = Spend(amount: 4, note: "Coffee")
    state.logSpend(coffee)
    coffee.amount = 6
    state.updateSpend(coffee)
    #expect(state.balance == 4)

    state.deleteSpend(coffee.id)
    #expect(state.balance == 10)
}

@Test func spendingIsKeptNewestFirst() {
    var state = AppState()
    state.logSpend(Spend(amount: 1, note: "Old", date: days(0)))
    state.logSpend(Spend(amount: 1, note: "New", date: days(2)))
    state.logSpend(Spend(amount: 1, note: "Middle", date: days(1)))

    #expect(state.spending.map(\.note) == ["New", "Middle", "Old"])
}

@Test func theFirstInterestCheckOnlyRecordsTheDay() {
    var state = AppState()
    state.logSpend(Spend(amount: 100, note: "Too much"))

    #expect(state.chargeInterest(now: days(0), calendar: utc) == 0)
    #expect(state.interest.isEmpty)
}

@Test func interestCompoundsDailyWhileTheBalanceIsNegative() {
    var state = AppState()
    state.logSpend(Spend(amount: 100, note: "Too much"))
    state.chargeInterest(now: days(0), calendar: utc)
    state.chargeInterest(now: days(2), calendar: utc)

    let first = Decimal(100) * Decimal(0.10) / 365
    let second = (100 + first) * Decimal(0.10) / 365
    #expect(state.interest.map(\.amount) == [first, second])
    // Decimal keeps 38 digits, so compare to the tenth decimal place.
    #expect(state.balance.rounded(scale: 10, .plain) == (-(100 + first + second)).rounded(scale: 10, .plain))
}

@Test func noInterestWhileTheBalanceIsPositive() {
    var state = state(earning: [10])
    state.chargeInterest(now: days(0), calendar: utc)
    state.chargeInterest(now: days(5), calendar: utc)

    #expect(state.interest.isEmpty)
    #expect(state.balance == 10)
}

@Test func aZeroRateTurnsInterestOff() {
    var state = AppState()
    state.settings.interestRate = 0
    state.logSpend(Spend(amount: 100, note: "Too much"))
    state.chargeInterest(now: days(0), calendar: utc)
    state.chargeInterest(now: days(3), calendar: utc)

    #expect(state.interest.isEmpty)
}

@Test func theDefaultRateIsTenPercentAYear() {
    #expect(AppSettings().interestRate == Decimal(string: "0.10"))
}
