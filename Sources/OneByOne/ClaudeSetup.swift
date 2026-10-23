import AppKit

/// Registers One by One as an MCP server with Claude Code or Claude Desktop.
/// Either way, Claude runs this app's own executable with `--mcp`.
enum ClaudeSetup {
    static var executablePath: String {
        Bundle.main.executablePath ?? CommandLine.arguments[0]
    }

    static var isInApplications: Bool {
        let path = Bundle.main.bundlePath
        return path.hasPrefix("/Applications/") || path.hasPrefix(NSHomeDirectory() + "/Applications/")
    }

    static var claudeCodeCommand: String {
        "claude mcp add --scope user one-by-one -- \"\(executablePath)\" --mcp"
    }

    static func copyClaudeCodeCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(claudeCodeCommand, forType: .string)
    }

    /// Adds One by One to Claude Desktop's config file and keeps everything
    /// else in it. Returns what to tell the user.
    static func addToClaudeDesktop() throws -> String {
        let folder = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Claude")
        guard FileManager.default.fileExists(atPath: folder.path) else {
            return "Claude Desktop doesn't seem to be installed on this Mac."
        }
        let url = folder.appendingPathComponent("claude_desktop_config.json")
        var config: [String: Any] = [:]
        if let data = try? Data(contentsOf: url), !data.isEmpty {
            // A config we can't read is left alone rather than overwritten.
            guard let existing = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: url.path])
            }
            config = existing
        }
        var servers = config["mcpServers"] as? [String: Any] ?? [:]
        servers["one-by-one"] = ["command": executablePath, "args": ["--mcp"]]
        config["mcpServers"] = servers
        let data = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: url, options: .atomic)
        return "Added. Quit and reopen Claude Desktop to start using it."
    }
}
