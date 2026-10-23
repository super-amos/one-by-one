import AppKit
import SwiftUI

struct OneByOneApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @State private var model = AppModel()

    var body: some Scene {
        Window("One by One", id: "main") {
            RootView()
                .environment(model)
                .frame(minWidth: 560, minHeight: 640)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 660, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Task…") { model.sheet = .add }
                    .keyboardShortcut("n")
                    .disabled(model.sheet != nil)
            }
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    // Text fields keep their own undo; elsewhere ⌘Z undoes the last swipe.
                    if NSApp.keyWindow?.firstResponder is NSTextView {
                        NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
                    } else if model.page == .home, model.sheet == nil {
                        withAnimation(.card) { model.undo() }
                    }
                }
                .keyboardShortcut("z")
            }
            CommandMenu("Go") {
                ForEach(Page.allCases) { page in
                    Button(page.title) { model.go(to: page) }
                        .keyboardShortcut(page.shortcut)
                }
            }
        }

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
