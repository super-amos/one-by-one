import OneByOneCore
import SwiftUI

/// Deleted tasks, kept for 30 days in case you want them back.
struct TrashView: View {
    @Environment(AppModel.self) private var model
    @State private var isConfirmingEmpty = false
    @State private var deletingForever: Card?

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            PageHeader(title: "Trash", subtitle: "Deleted tasks stay here for 30 days, then they're gone for good.") {
                if !model.deck.trash.isEmpty {
                    Button("Empty Trash") { isConfirmingEmpty = true }
                        .buttonStyle(PillButtonStyle(kind: .secondary, compact: true))
                }
            }
            if model.deck.trash.isEmpty {
                PageEmpty(
                    symbol: "trash",
                    title: "The trash is empty.",
                    detail: "Deleted tasks wait here for 30 days in case you want them back."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(model.deck.trash) { card in
                            TrashRow(
                                card: card,
                                onRestore: { withAnimation(.snappy) { model.restoreDeleted(card.id) } },
                                onDelete: { deletingForever = card }
                            )
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
                }
            }
        }
        .confirmationDialog("Empty the trash?", isPresented: $isConfirmingEmpty) {
            Button("Delete \(count(model.deck.trash.count, "Task")) Forever", role: .destructive) {
                withAnimation(.snappy) { model.emptyTrash() }
            }
        } message: {
            Text("This can't be undone.")
        }
        .confirmationDialog(
            "Delete this task forever?",
            isPresented: Binding(get: { deletingForever != nil }, set: { if !$0 { deletingForever = nil } }),
            presenting: deletingForever
        ) { card in
            Button("Delete Forever", role: .destructive) {
                withAnimation(.snappy) { model.deleteForever([card.id]) }
            }
        } message: { card in
            Text("“\(card.title)” will be gone for good.")
        }
    }
}

private struct TrashRow: View {
    let card: Card
    let onRestore: () -> Void
    let onDelete: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(card.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                if let deletedAt = card.deletedAt {
                    Text("Deleted \(deletedAt.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            Spacer()
            Button("Delete Forever", action: onDelete)
                .buttonStyle(QuietButtonStyle(tint: Theme.debt))
                .opacity(isHovering ? 1 : 0)
            Button("Restore", action: onRestore)
                .buttonStyle(QuietButtonStyle())
                .help("Put it back on top of your deck.")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.card.opacity(isHovering ? 1 : 0.7)))
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Restore to Top of Deck", action: onRestore)
            Button("Delete Forever…", role: .destructive, action: onDelete)
        }
    }
}
