# One by One

A Mac app that shows your to-do list one task at a time and gives you a pretend reward for each one you finish, which you're allowed to spend on yourself. [SPEC.md](SPEC.md) describes the whole app.

## Run it

Needs macOS 14 or later and Apple's Command Line Tools (`xcode-select --install`). Full Xcode isn't required.

```sh
make run    # builds "build/One by One.app" and opens it
make test   # runs the logic tests
```

The app starts empty. Press ⌘N to add a task, or go to Edit (⌘2) and paste a list from your notes. On Home, drag the card right or press → to finish it, and drag left or press ← to put it off. ⌘Z undoes.

`make install` builds the app and copies it into your Applications folder. Do that before connecting Claude, because Claude remembers where the app is.

## Your data

Everything lives in `~/Library/Application Support/One by One/state.json`. Settings → Your data can show it in Finder, export a backup and import one. If the file can't be read when the app starts, the app copies it aside before saving anything, so a bad file is never overwritten.

## Connecting Claude

In Settings → Claude, turn on "Let Claude add tasks, order them and set rewards", then click "Add to Claude Code" (copies a command to paste into a terminal) or "Add to Claude Desktop" (edits the desktop app's config; restart Claude Desktop afterwards). Claude can then list your tasks, add new ones of one sentence each, reorder everything below the card on screen, and set rewards. It can't finish or delete anything.

Under the hood the same binary runs as an MCP server when started with `--mcp`, talking JSON-RPC over stdin and stdout.

## Layout

- `Sources/OneByOneCore/` holds everything that isn't UI: the deck, rewards and interest, the saved file, the Claude tools and the MCP server. It's what the tests cover.
- `Sources/OneByOne/` holds the SwiftUI app.
- `Tests/OneByOneCoreTests/` holds the tests.
- `scripts/bundle.sh` wraps the release build in a `.app` and signs it ad hoc, so it runs on this Mac.
- `scripts/make-icon.swift` draws the app icon. `make icon` reruns it and rebuilds `Resources/AppIcon.icns`, which the bundle script copies in.
