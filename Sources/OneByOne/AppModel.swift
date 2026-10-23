import AppKit
import OneByOneCore
import SwiftUI

enum Page: Int, CaseIterable, Identifiable {
    case home, edit, history, trash, rewards

    /// The coordinate space each page measures frames in.
    static let space = "page"

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home: "Now"
        case .edit: "Edit"
        case .history: "History"
        case .trash: "Trash"
        case .rewards: "Rewards"
        }
    }

    var symbol: String {
        switch self {
        case .home: "rectangle.portrait"
        case .edit: "list.bullet"
        case .history: "clock.arrow.circlepath"
        case .trash: "trash"
        case .rewards: "gift"
        }
    }

    var shortcut: KeyEquivalent { KeyEquivalent(Character(String(rawValue + 1))) }
}

enum SwipeDirection: Equatable {
    case done, later
}

/// The saved state, plus the UI state that outlives any one view: the open
/// page, the open sheet, and Home's messages. Every change to the saved state
/// goes through `mutate`, which writes it to disk. Callers wrap changes in
/// `withAnimation` when cards should move as they change.
@MainActor @Observable
final class AppModel {
    enum Sheet: Identifiable {
        case add
        case edit(Card)
        case split(Card)
        case addMany
        case setValue(Set<UUID>)
        case spend(Spend?)

        var id: String {
            switch self {
            case .add: "add"
            case .edit(let card): "edit-\(card.id)"
            case .split(let card): "split-\(card.id)"
            case .addMany: "add-many"
            case .setValue(let ids): "value-\(ids.sorted { $0.uuidString < $1.uuidString })"
            case .spend(let spend): "spend-\(spend?.id.uuidString ?? "new")"
            }
        }
    }

    /// How the next card to appear on Home comes in: rising up as a fresh
    /// card, or flying back from the side it left by after an undo.
    enum Entrance: Equatable {
        case fresh
        case returning(SwipeDirection?)
    }

    private(set) var state: AppState
    var page = Page.home
    var sheet: Sheet?
    /// Something that went wrong, shown in an alert.
    var problem: String?

    private(set) var message: String?
    private(set) var entrance = Entrance.fresh
    /// Bumped each time a reward lands, to pulse the badge.
    private(set) var rewardPulse = 0
    /// True while the current card asks whether to split it or let it go.
    var isAskingAboutSkip = false
    /// Set by "Later anyway" so the next put-off goes through without asking.
    private var skipApproved = false
    /// Rewards earned but still flying toward the badge.
    private var inFlight: Decimal = 0

    let file: StateFile
    /// False when the saved file couldn't be read or copied aside, so saving
    /// would overwrite it.
    private let canSave: Bool
    @ObservationIgnored private var watcher: (any DispatchSourceFileSystemObject)?
    @ObservationIgnored private var upkeepTimer: Timer?
    @ObservationIgnored private var lastUpkeepDay: Date?
    @ObservationIgnored private var messageTimer: Task<Void, Never>?

    init(file: StateFile = .standard) {
        self.file = file
        do {
            state = try file.load()
            canSave = true
        } catch {
            state = AppState()
            (canSave, problem) = Self.keepUnreadable(file, because: error)
        }
        upkeep()
        watchForOutsideChanges()
        upkeepTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.upkeep() }
        }
    }

    var deck: Deck { state.deck }
    var settings: AppSettings { state.settings }

    /// What the reward badge shows. It trails the real balance while a reward
    /// is in the air, then counts up when it lands.
    var shownBalance: Decimal { state.balance - inFlight }

    func money(_ value: Decimal) -> String {
        Money.format(value, in: state.settings.currency)
    }

    var canSkipCurrent: Bool {
        guard let card = deck.current else { return false }
        return skipApproved || !deck.shouldAskBeforeSkipping(card)
    }

    var isFirstRun: Bool {
        deck.cards.isEmpty && deck.done.isEmpty && deck.trash.isEmpty
    }

    func go(to page: Page) {
        guard page != self.page else { return }
        isAskingAboutSkip = false
        withAnimation(.easeInOut(duration: 0.2)) { self.page = page }
    }

    // MARK: Home

    /// Finishes the current card and returns what it earned. The badge counts
    /// it when `rewardLanded` is called.
    func complete() -> Decimal? {
        guard let earned = mutate({ $0.deck.completeCurrent() }) else { return nil }
        inFlight += earned
        entrance = .fresh
        isAskingAboutSkip = false
        say(Copy.done(money(earned), finishedCount: deck.done.count, wasLast: deck.current == nil))
        return earned
    }

    func rewardLanded(_ amount: Decimal) {
        inFlight = max(0, inFlight - amount)
        rewardPulse += 1
        if settings.soundsOn { Feedback.rewardLanded() }
    }

    func deferCurrent() {
        mutate { $0.deck.deferCurrent() }
        entrance = .fresh
        skipApproved = false
        isAskingAboutSkip = false
        say(Copy.later)
    }

    func deleteCurrent() {
        mutate { $0.deck.deleteCurrent() }
        entrance = .fresh
        isAskingAboutSkip = false
        say(Copy.deleted)
    }

    func undo() {
        guard let action = mutate({ $0.deck.undo() }) else { return }
        switch action {
        case .completed: entrance = .returning(.done)
        case .deferred: entrance = .returning(.later)
        case .deleted: entrance = .returning(nil)
        }
        inFlight = 0
        isAskingAboutSkip = false
        say(Copy.undone)
    }

    func approveSkip() {
        skipApproved = true
        isAskingAboutSkip = false
    }

    // MARK: Cards

    func add(_ card: Card, placement: Placement) {
        entrance = .fresh
        mutate { $0.deck.add(card, placement: placement) }
        if page == .home { say(placement == .next ? Copy.addedNext : Copy.addedLast) }
    }

    /// Adds each line of pasted text as a task at the bottom of the deck.
    @discardableResult
    func addLines(_ text: String) -> Int {
        let titles = PastedList.titles(from: text)
        guard !titles.isEmpty else { return 0 }
        mutate { $0.deck.add(contentsOf: titles.map { Card(title: $0) }, placement: .last) }
        return titles.count
    }

    func update(_ card: Card) {
        mutate { $0.deck.update(card) }
    }

    func split(_ id: UUID, into titles: [String]) {
        entrance = .fresh
        mutate { $0.deck.split(id, into: titles) }
        isAskingAboutSkip = false
        if page == .home { say(Copy.split) }
    }

    func move(_ id: UUID, toPositionOf target: UUID) {
        mutate { $0.deck.move(id, toPositionOf: target) }
    }

    func moveToTop(_ ids: Set<UUID>) {
        mutate { $0.deck.moveToTop(ids) }
    }

    func moveToBottom(_ ids: Set<UUID>) {
        mutate { $0.deck.moveToBottom(ids) }
    }

    func setValue(_ value: Decimal?, for ids: Set<UUID>) {
        mutate { $0.deck.setValue(value, for: ids) }
    }

    func delete(_ ids: Set<UUID>) {
        mutate { $0.deck.delete(ids) }
    }

    // MARK: History and Trash

    func restoreFinished(_ id: UUID) {
        entrance = .fresh
        mutate { $0.deck.restoreFinished(id) }
    }

    func restoreDeleted(_ id: UUID) {
        entrance = .fresh
        mutate { $0.deck.restoreDeleted(id) }
    }

    func deleteForever(_ ids: Set<UUID>) {
        mutate { $0.deck.deleteForever(ids) }
    }

    func emptyTrash() {
        mutate { $0.deck.emptyTrash() }
    }

    // MARK: Rewards

    func logSpend(_ spend: Spend) {
        mutate { $0.logSpend(spend) }
    }

    func updateSpend(_ spend: Spend) {
        mutate { $0.updateSpend(spend) }
    }

    func deleteSpend(_ id: UUID) {
        mutate { $0.deleteSpend(id) }
    }

    // MARK: Settings

    func setDefaultValue(_ value: Decimal) {
        mutate { $0.deck.defaultValue = max(0, value.rounded(scale: 2, .plain)) }
    }

    func setCurrency(_ currency: Currency) {
        mutate { $0.settings.currency = currency }
    }

    func setInterestRate(percent: Decimal) {
        mutate { $0.settings.interestRate = max(0, percent) / 100 }
    }

    func setSoundsOn(_ isOn: Bool) {
        mutate { $0.settings.soundsOn = isOn }
    }

    func setClaudeCanEdit(_ isOn: Bool) {
        mutate { $0.settings.claudeCanEdit = isOn }
    }

    func exportBackup(to url: URL) {
        do {
            try StateFile.encode(state).write(to: url, options: .atomic)
        } catch {
            problem = "Couldn't save the backup: \(error.localizedDescription)"
        }
    }

    func importBackup(from url: URL) {
        do {
            let imported = try StateFile.decode(Data(contentsOf: url))
            mutate { $0 = imported }
            inFlight = 0
        } catch {
            problem = "That file isn't a One by One backup. (\(error.localizedDescription))"
        }
    }

    // MARK: Saving

    /// Applies a change to the saved state. It re-reads the file first, in
    /// case Claude changed it, then writes the result back.
    @discardableResult
    func mutate<T>(_ change: (inout AppState) -> T) -> T {
        if canSave {
            do {
                let (latest, result) = try file.update(change)
                state = latest
                return result
            } catch {
                problem = "Couldn't save your tasks: \(error.localizedDescription)"
            }
        }
        var copy = state
        let result = change(&copy)
        state = copy
        return result
    }

    /// Once a day: charge interest for days that ended below zero, and clear
    /// out anything that's been in the trash for 30 days.
    private func upkeep() {
        let today = Calendar.current.startOfDay(for: .now)
        guard lastUpkeepDay != today else { return }
        lastUpkeepDay = today
        mutate { state in
            state.chargeInterest()
            state.deck.purgeTrash()
        }
    }

    /// Reloads when the file changes on disk, which is how Claude's changes
    /// show up while the app is open.
    private func watchForOutsideChanges() {
        try? FileManager.default.createDirectory(at: file.folder, withIntermediateDirectories: true)
        let descriptor = open(file.folder.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.reload() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        watcher = source
    }

    private func reload() {
        guard canSave, let latest = try? file.load(), latest != state else { return }
        withAnimation(.card) { state = latest }
    }

    /// Copies a save file that can't be read to one side, so starting fresh
    /// never destroys it. Returns whether saving is safe, and what to tell
    /// the user.
    private static func keepUnreadable(_ file: StateFile, because error: Error) -> (Bool, String) {
        let kept = file.folder.appendingPathComponent("state-unreadable-\(Int(Date.now.timeIntervalSince1970)).json")
        do {
            try FileManager.default.copyItem(at: file.url, to: kept)
            return (true, "Your saved tasks couldn't be read, so One by One started fresh. A copy of the old file is in \(kept.path).")
        } catch {
            return (false, "Your saved tasks couldn't be read (\(error.localizedDescription)). Nothing will be saved until this is fixed, so the old file stays as it is: \(file.url.path).")
        }
    }

    private func say(_ text: String) {
        message = text
        messageTimer?.cancel()
        messageTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.4)) { self?.message = nil }
        }
    }
}
