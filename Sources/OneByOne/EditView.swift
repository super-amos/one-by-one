import AppKit
import OneByOneCore
import SwiftUI

/// The whole deck as blocks: drag to reorder, double-click to edit, select
/// several to change them together, paste a list to add many.
struct EditView: View {
    @Environment(AppModel.self) private var model
    @State private var selection = Set<UUID>()
    /// Where a shift-click range starts.
    @State private var anchor: UUID?
    @State private var dragging: UUID?
    @FocusState private var isFocused: Bool

    private var cards: [Card] { model.deck.cards }

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            PageHeader(title: "Edit", subtitle: count(cards.count, "task")) {
                HStack(spacing: 6) {
                    Button { model.sheet = .addMany } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "text.badge.plus")
                            Text("Add a list")
                        }
                    }
                    .buttonStyle(QuietButtonStyle())
                    Button { model.sheet = .add } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text("New task")
                        }
                    }
                    .buttonStyle(PillButtonStyle(kind: .secondary, compact: true))
                }
            }
            if cards.isEmpty {
                PageEmpty(
                    symbol: "list.bullet",
                    title: "No tasks yet.",
                    detail: "Add one, or copy a list from your notes and press ⌘V here."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                            row(card, isNow: index == 0)
                        }
                        Text("Drag to reorder. Double-click to edit. Paste a list with ⌘V.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.inkSecondary.opacity(0.8))
                            .padding(.top, 10)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 2)
                    .padding(.bottom, 24)
                }
            }
            if !selection.isEmpty {
                selectionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onAppear { isFocused = true }
        .onDeleteCommand { delete(selection) }
        .onKeyPress(.escape) {
            guard !selection.isEmpty else { return .ignored }
            withAnimation(.snappy) { selection = [] }
            return .handled
        }
        .onPasteCommand(of: [.plainText]) { _ in paste() }
        .onChange(of: cards.map(\.id)) { _, ids in
            selection.formIntersection(ids)
        }
    }

    private func row(_ card: Card, isNow: Bool) -> some View {
        EditRow(
            card: card,
            isNow: isNow,
            value: model.money(model.deck.value(of: card)),
            isSelected: selection.contains(card.id)
        )
        .onTapGesture { select(card.id) }
        .simultaneousGesture(TapGesture(count: 2).onEnded { model.sheet = .edit(card) })
        .onDrag {
            dragging = card.id
            return NSItemProvider(object: card.id.uuidString as NSString)
        }
        .onDrop(of: [.text], delegate: ReorderDrop(target: card.id, dragging: $dragging, model: model))
        .contextMenu { menu(for: card) }
    }

    @ViewBuilder
    private func menu(for card: Card) -> some View {
        let ids: Set<UUID> = selection.contains(card.id) ? selection : [card.id]
        if ids.count == 1 {
            Button("Edit…") { model.sheet = .edit(card) }
            Button("Split…") { model.sheet = .split(card) }
            Divider()
        }
        Button("Move to Top") { withAnimation(.card) { model.moveToTop(ids) } }
        Button("Move to Bottom") { withAnimation(.card) { model.moveToBottom(ids) } }
        Button("Set Reward…") { model.sheet = .setValue(ids) }
        Divider()
        Button(ids.count == 1 ? "Delete" : "Delete \(ids.count) Tasks", role: .destructive) {
            delete(ids)
        }
    }

    private var selectionBar: some View {
        HStack(spacing: 4) {
            Text("\(selection.count) selected")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.leading, 8)
            Spacer()
            Button("Move to Top") { withAnimation(.card) { model.moveToTop(selection) } }
                .buttonStyle(QuietButtonStyle())
            Button("Set Reward…") { model.sheet = .setValue(selection) }
                .buttonStyle(QuietButtonStyle())
            Button("Delete") { delete(selection) }
                .buttonStyle(QuietButtonStyle(tint: Theme.debt))
            Button("Done") { withAnimation(.snappy) { selection = [] } }
                .buttonStyle(PillButtonStyle(kind: .secondary, compact: true))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.card)
                .shadow(color: Theme.shadow, radius: 14, y: 4)
        )
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    /// A plain click picks one block, ⌘-click adds or removes one, and
    /// ⇧-click picks a range.
    private func select(_ id: UUID) {
        let modifiers = NSEvent.modifierFlags
        withAnimation(.snappy(duration: 0.2)) {
            if modifiers.contains(.command) {
                if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
                anchor = id
            } else if modifiers.contains(.shift),
                      let anchor,
                      let from = cards.firstIndex(where: { $0.id == anchor }),
                      let to = cards.firstIndex(where: { $0.id == id }) {
                selection = Set(cards[min(from, to)...max(from, to)].map(\.id))
            } else {
                selection = selection == [id] ? [] : [id]
                anchor = id
            }
        }
        isFocused = true
    }

    private func delete(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        withAnimation(.card) {
            model.delete(ids)
            selection.subtract(ids)
        }
    }

    private func paste() {
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        withAnimation(.card) { _ = model.addLines(text) }
    }
}

private struct EditRow: View {
    let card: Card
    let isNow: Bool
    let value: String
    let isSelected: Bool
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.inkSecondary.opacity(isHovering ? 1 : 0.45))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    if isNow {
                        Text("NOW")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Theme.doneFill))
                    }
                    Text(card.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                }
                if !card.note.isEmpty {
                    Text(card.note)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            if card.skipCount >= Deck.skipsBeforeAsking {
                Label("Put off \(card.skipCount)×", systemImage: "arrow.uturn.left")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.later)
                    .help("You've put this off \(card.skipCount) times.")
            }
            if card.fromClaude {
                Label("Claude", systemImage: "sparkles")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary)
                    .help("Claude added this task.")
            }
            RewardTag(text: value)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : Theme.hairline, lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: Theme.shadow.opacity(isHovering ? 0.7 : 0.3), radius: isHovering ? 8 : 4, y: 2)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
    }
}

/// Moves the dragged block into each block's place as the pointer passes
/// over it, so the list reshuffles live.
private struct ReorderDrop: DropDelegate {
    let target: UUID
    @Binding var dragging: UUID?
    let model: AppModel

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != target else { return }
        withAnimation(.snappy(duration: 0.2)) { model.move(dragging, toPositionOf: target) }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}
