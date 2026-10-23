import OneByOneCore

// Claude starts the app with --mcp to use its tools. Everyone else gets the window.
if CommandLine.arguments.contains("--mcp") {
    MCPServer(file: .standard).run()
} else {
    OneByOneApp.main()
}
