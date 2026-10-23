import Foundation
import Testing
@testable import OneByOneCore

// MARK: The one-sentence rule

@Test(arguments: [
    "Call the dentist",
    "Book the cleaning for Tuesday morning.",
    "Ask Dr. Levi about the results, e.g. the blood test.",
    "Pay the $12.50 parking fine!",
])
func oneSentenceTitlesPass(_ title: String) {
    #expect(ClaudeTitleRule.problem(with: title) == nil)
}

@Test(arguments: [
    "",
    "Call the dentist. Then book the cleaning.",
    "Buy milk! And eggs",
    "Line one\nline two",
    String(repeating: "a", count: 121),
])
func otherTitlesAreRejected(_ title: String) {
    #expect(ClaudeTitleRule.problem(with: title) != nil)
}

// MARK: Tools

private func allowedState(_ titles: String...) -> AppState {
    var state = AppState(deck: Deck(cards: titles.map { Card(title: $0) }))
    state.settings.claudeCanEdit = true
    return state
}

@Test func everyToolRefusesUntilTheUserTurnsItOn() {
    var state = AppState(deck: Deck(cards: [Card(title: "A")]))
    let before = state
    for tool in ["list_tasks", "add_tasks", "reorder_tasks", "set_values"] {
        let outcome = ClaudeTools.call(tool, arguments: ["tasks": [["title": "Sneak in"]]], state: &state)
        #expect(outcome.isError)
        #expect(outcome.text.contains("Settings"))
    }
    #expect(state == before)
}

@Test func listMarksTheTaskOnScreen() throws {
    var state = allowedState("Now", "Later")
    let outcome = ClaudeTools.call("list_tasks", arguments: [:], state: &state)
    let listed = try JSONSerialization.jsonObject(with: Data(outcome.text.utf8)) as? [String: Any]
    let tasks = listed?["tasks"] as? [[String: Any]]

    #expect(!outcome.isError)
    #expect(listed?["currency"] as? String == "USD")
    #expect(tasks?.map { $0["title"] as? String } == ["Now", "Later"])
    #expect(tasks?.map { $0["on_screen"] as? Bool } == [true, false])
}

@Test func addingPutsClaudesTasksAfterTheOneOnScreen() {
    var state = allowedState("Now", "Later")
    let outcome = ClaudeTools.call("add_tasks", arguments: [
        "tasks": [["title": "Book flights", "value": 15], ["title": "Pack"]],
        "position": "next",
    ], state: &state)

    #expect(!outcome.isError)
    #expect(state.deck.cards.map(\.title) == ["Now", "Book flights", "Pack", "Later"])
    #expect(state.deck.cards[1].value == 15)
    #expect(state.deck.cards[2].value == nil)
    #expect(state.deck.cards[1].fromClaude)
}

@Test func oneBadTitleMeansNothingIsAdded() {
    var state = allowedState("Now")
    let outcome = ClaudeTools.call("add_tasks", arguments: [
        "tasks": [["title": "Fine"], ["title": "Not fine. Two sentences."]],
    ], state: &state)

    #expect(outcome.isError)
    #expect(outcome.text.contains("Task 2"))
    #expect(state.deck.cards.map(\.title) == ["Now"])
}

@Test func valuesMustBeSensibleNumbers() {
    var state = allowedState("Now")
    for bad: Any in [-1, 20_000, true, "5"] {
        let outcome = ClaudeTools.call("add_tasks", arguments: ["tasks": [["title": "Task", "value": bad]]], state: &state)
        #expect(outcome.isError)
    }
    #expect(state.deck.cards.count == 1)
}

@Test func reorderingThroughTheTool() {
    var state = allowedState("Now", "B", "C")
    let b = state.deck.cards[1].id.uuidString
    let c = state.deck.cards[2].id.uuidString.lowercased()

    let refused = ClaudeTools.call("reorder_tasks", arguments: ["ids": [c]], state: &state)
    #expect(refused.isError)
    #expect(refused.text.contains("Missing"))

    let outcome = ClaudeTools.call("reorder_tasks", arguments: ["ids": [c, b]], state: &state)
    #expect(!outcome.isError)
    #expect(state.deck.cards.map(\.title) == ["Now", "C", "B"])
}

@Test func settingValuesThroughTheTool() {
    var state = allowedState("Now", "B")
    let b = state.deck.cards[1].id.uuidString
    let outcome = ClaudeTools.call("set_values", arguments: ["values": [["id": b, "value": 7.5]]], state: &state)

    #expect(!outcome.isError)
    #expect(state.deck.cards[1].value == Decimal(string: "7.5"))
}

// MARK: Server

private func temporaryFile() -> StateFile {
    StateFile(url: FileManager.default.temporaryDirectory
        .appendingPathComponent("OneByOneTests-\(UUID().uuidString)")
        .appendingPathComponent("state.json"))
}

@Test func stateFileRoundTrips() throws {
    let file = temporaryFile()
    var state = AppState(deck: Deck(cards: [Card(title: "Saved", value: 3)]))
    state.deck.completeCurrent()
    state.logSpend(Spend(amount: 1, note: "Gum"))
    try file.save(state)

    let loaded = try file.load()
    #expect(loaded.deck.done.map(\.title) == ["Saved"])
    #expect(loaded.balance == 2)
}

@Test func serverAnswersTheHandshakeAndListsFourTools() throws {
    let server = MCPServer(file: temporaryFile())
    let hello = try #require(server.handle(#"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}"#))
    #expect(hello.contains("one-by-one"))
    #expect(server.handle(#"{"jsonrpc":"2.0","method":"notifications/initialized"}"#) == nil)

    let listed = try #require(server.handle(#"{"jsonrpc":"2.0","id":2,"method":"tools/list"}"#))
    let reply = try JSONSerialization.jsonObject(with: Data(listed.utf8)) as? [String: Any]
    let tools = (reply?["result"] as? [String: Any])?["tools"] as? [[String: Any]]
    #expect(tools?.compactMap { $0["name"] as? String } == ["list_tasks", "add_tasks", "reorder_tasks", "set_values"])
}

@Test func serverToolCallsChangeTheSavedFile() throws {
    let file = temporaryFile()
    var state = AppState()
    state.settings.claudeCanEdit = true
    try file.save(state)
    let server = MCPServer(file: file)

    let reply = try #require(server.handle(#"{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"add_tasks","arguments":{"tasks":[{"title":"Water the plants"}]}}}"#))
    #expect(reply.contains(#""isError":false"#))
    #expect(try file.load().deck.current?.title == "Water the plants")
}

@Test func serverRejectsUnknownMethods() throws {
    let server = MCPServer(file: temporaryFile())
    let reply = try #require(server.handle(#"{"jsonrpc":"2.0","id":4,"method":"resources/list"}"#))
    #expect(reply.contains("-32601"))
}
