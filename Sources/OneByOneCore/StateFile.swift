import Foundation

/// The one JSON file the app and its Claude server share. Every change goes
/// through `update`, which holds a lock while it reads, changes and writes the
/// file, so neither process overwrites the other's changes.
public struct StateFile: Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    /// `~/Library/Application Support/One by One/state.json`
    public static var standard: StateFile {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return StateFile(url: support.appendingPathComponent("One by One/state.json"))
    }

    public var folder: URL { url.deletingLastPathComponent() }
    private var lockURL: URL { folder.appendingPathComponent(".state.lock") }

    /// The saved state, or a fresh one if nothing has been saved yet.
    public func load() throws -> AppState {
        guard FileManager.default.fileExists(atPath: url.path) else { return AppState() }
        return try Self.decode(Data(contentsOf: url))
    }

    /// Reads the latest state, applies `change` and writes the result if it
    /// changed, all while holding the lock.
    @discardableResult
    public func update<T>(_ change: (inout AppState) throws -> T) throws -> (state: AppState, result: T) {
        try withLock {
            let before = try load()
            var state = before
            let result = try change(&state)
            if state != before { try save(state) }
            return (state, result)
        }
    }

    public func save(_ state: AppState) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Self.encode(state).write(to: url, options: .atomic)
    }

    public static func encode(_ state: AppState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(state)
    }

    public static func decode(_ data: Data) throws -> AppState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AppState.self, from: data)
    }

    private func withLock<T>(_ body: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let descriptor = open(lockURL.path, O_CREAT | O_RDWR | O_CLOEXEC, 0o644)
        guard descriptor >= 0 else { throw CocoaError(.fileWriteNoPermission, userInfo: [NSFilePathErrorKey: lockURL.path]) }
        defer { close(descriptor) }
        flock(descriptor, LOCK_EX)
        defer { flock(descriptor, LOCK_UN) }
        return try body()
    }
}
