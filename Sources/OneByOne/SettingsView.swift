import AppKit
import OneByOneCore
import SwiftUI

/// The Settings window (⌘,).
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var claudeStatus: String?

    var body: some View {
        Form {
            Section("Rewards") {
                LabeledContent("Default reward per task") {
                    TextField(
                        "Default reward",
                        value: Binding(get: { model.deck.defaultValue }, set: { model.setDefaultValue($0) }),
                        format: .number.precision(.fractionLength(0...2))
                    )
                    .labelsHidden()
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                }
                Picker("Currency", selection: Binding(get: { model.settings.currency }, set: { model.setCurrency($0) })) {
                    ForEach(Currency.allCases) { currency in
                        Text("\(currency.name) (\(Money.symbol(of: currency)))").tag(currency)
                    }
                }
                LabeledContent("Interest when you owe") {
                    HStack(spacing: 4) {
                        TextField(
                            "Interest",
                            value: Binding(get: { model.settings.interestRate * 100 }, set: { model.setInterestRate(percent: $0) }),
                            format: .number.precision(.fractionLength(0...2))
                        )
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 60)
                        Text("% a year")
                            .foregroundStyle(.secondary)
                    }
                }
                Text("Changing the currency only changes the symbol; amounts stay the same. Set interest to 0 to turn it off.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Sound") {
                Toggle(
                    "Play a chime when you earn a reward",
                    isOn: Binding(get: { model.settings.soundsOn }, set: { model.setSoundsOn($0) })
                )
            }

            Section("Claude") {
                Toggle(
                    "Let Claude add tasks, order them and set rewards",
                    isOn: Binding(get: { model.settings.claudeCanEdit }, set: { model.setClaudeCanEdit($0) })
                )
                Text("Claude can see your tasks, add new ones of one sentence each, reorder them and set their rewards. It can't finish or delete anything, and the task on your screen never changes under you.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Button("Add to Claude Code") {
                        ClaudeSetup.copyClaudeCodeCommand()
                        claudeStatus = "Copied a command. Paste it into a terminal and press Return."
                    }
                    Button("Add to Claude Desktop") {
                        do {
                            claudeStatus = try ClaudeSetup.addToClaudeDesktop()
                        } catch {
                            claudeStatus = "Couldn't update Claude Desktop's settings: \(error.localizedDescription)"
                        }
                    }
                }
                if let claudeStatus {
                    Text(claudeStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                if !ClaudeSetup.isInApplications {
                    Text("Move One by One into your Applications folder first. Claude remembers where the app is, so moving it later breaks the connection.")
                        .font(.caption)
                        .foregroundStyle(Theme.later)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section("Your data") {
                LabeledContent("Saved in") {
                    Text(model.file.url.path(percentEncoded: false))
                        .font(.caption)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([model.file.url])
                    }
                    Button("Export Backup…", action: exportBackup)
                    Button("Import Backup…", action: importBackup)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560)
        .frame(minHeight: 560)
    }

    private func exportBackup() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "One by One backup \(Date.now.formatted(.iso8601.year().month().day())).json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.exportBackup(to: url)
    }

    private func importBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let alert = NSAlert()
        alert.messageText = "Replace everything with this backup?"
        alert.informativeText = "Your current tasks, history and rewards will be replaced by the ones in the backup."
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        model.importBackup(from: url)
    }
}
