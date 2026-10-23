import Foundation

/// A small MCP server that speaks JSON-RPC over stdin and stdout, one message
/// per line. Claude starts it by running the app with `--mcp`.
public struct MCPServer: Sendable {
    public let file: StateFile

    public init(file: StateFile) {
        self.file = file
    }

    public func run() {
        while let line = readLine() {
            guard let reply = handle(line) else { continue }
            FileHandle.standardOutput.write(Data((reply + "\n").utf8))
        }
    }

    /// Answers one message. Returns nil when no reply is due: blank lines and
    /// notifications, which are messages without an id.
    public func handle(_ line: String) -> String? {
        guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        guard let message = (try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any] else {
            return reply(id: NSNull(), error: (-32700, "Couldn't read that message as JSON."))
        }
        guard let id = message["id"] else { return nil }
        let params = message["params"] as? [String: Any] ?? [:]
        switch message["method"] as? String {
        case "initialize":
            return reply(id: id, result: [
                "protocolVersion": params["protocolVersion"] as? String ?? "2025-06-18",
                "capabilities": ["tools": [String: Any]()],
                "serverInfo": ["name": "one-by-one", "version": "0.1"],
                "instructions": ClaudeTools.instructions,
            ])
        case "ping":
            return reply(id: id, result: [:])
        case "tools/list":
            return reply(id: id, result: ["tools": ClaudeTools.definitions])
        case "tools/call":
            return reply(id: id, result: callTool(params))
        default:
            return reply(id: id, error: (-32601, "Unknown method."))
        }
    }

    private func callTool(_ params: [String: Any]) -> [String: Any] {
        let name = params["name"] as? String ?? ""
        let arguments = params["arguments"] as? [String: Any] ?? [:]
        let outcome: ClaudeTools.Outcome
        do {
            outcome = try file.update { ClaudeTools.call(name, arguments: arguments, state: &$0) }.result
        } catch {
            outcome = ClaudeTools.Outcome(text: "Couldn't read or save the task file: \(error.localizedDescription)", isError: true)
        }
        return ["content": [["type": "text", "text": outcome.text]], "isError": outcome.isError]
    }

    private func reply(id: Any, result: [String: Any]) -> String {
        encode(["jsonrpc": "2.0", "id": id, "result": result])
    }

    private func reply(id: Any, error: (code: Int, message: String)) -> String {
        encode(["jsonrpc": "2.0", "id": id, "error": ["code": error.code, "message": error.message]])
    }

    private func encode(_ object: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.withoutEscapingSlashes]) else {
            return #"{"jsonrpc":"2.0","id":null,"error":{"code":-32603,"message":"Couldn't encode the reply."}}"#
        }
        return String(decoding: data, as: UTF8.self)
    }
}
