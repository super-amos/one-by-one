import OneByOneCore
import SwiftUI

/// Finished tasks, grouped by day, with what each day earned.
struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""

    private struct Day: Identifiable {
        let id: Date
        let cards: [Card]
        let earned: Decimal
    }

    private var days: [Day] {
        let calendar = Calendar.current
        let matching = model.deck.done.filter {
            query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.note.localizedCaseInsensitiveContains(query)
        }
        return Dictionary(grouping: matching) { calendar.startOfDay(for: $0.completedAt ?? .distantPast) }
            .map { day, cards in
                Day(id: day, cards: cards, earned: cards.reduce(0) { $0 + ($1.earned ?? 0) })
            }
            .sorted { $0.id > $1.id }
    }

    private var weekSummary: String {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let thisWeek = model.deck.done.filter { ($0.completedAt ?? .distantPast) >= start }
        let earned = thisWeek.reduce(Decimal(0)) { $0 + ($1.earned ?? 0) }
        return "This week: \(count(thisWeek.count, "task")) done, \(model.money(earned)) earned."
    }

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            PageHeader(title: "History", subtitle: weekSummary) {
                if !model.deck.done.isEmpty {
                    SearchField(text: $query)
                }
            }
            if model.deck.done.isEmpty {
                PageEmpty(
                    symbol: "clock.arrow.circlepath",
                    title: "Nothing finished yet.",
                    detail: "Tasks you finish show up here, with the reward each one earned."
                )
            } else if days.isEmpty {
                PageEmpty(symbol: "magnifyingglass", title: "No matches.", detail: "Nothing you've finished matches “\(query)”.")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6, pinnedViews: .sectionHeaders) {
                        ForEach(days) { day in
                            Section {
                                ForEach(day.cards) { card in
                                    HistoryRow(card: card, earned: model.money(card.earned ?? 0)) {
                                        withAnimation(.snappy) { model.restoreFinished(card.id) }
                                    }
                                }
                            } header: {
                                DayHeader(
                                    title: dayTitle(day.id),
                                    detail: "\(day.cards.count) done · \(model.money(day.earned)) earned"
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

struct DayHeader: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSecondary)
            Spacer()
        }
        .padding(.top, 14)
        .padding(.bottom, 4)
        .background(Theme.background)
    }
}

private struct HistoryRow: View {
    let card: Card
    let earned: String
    let onRestore: () -> Void
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15))
                .foregroundStyle(Theme.done)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                if let completedAt = card.completedAt {
                    Text(completedAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.inkSecondary)
                }
            }
            Spacer()
            if isHovering {
                Button("Restore", action: onRestore)
                    .buttonStyle(QuietButtonStyle())
                    .help("Put it back on top of your deck. Its reward comes off your total.")
            }
            RewardTag(text: earned)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.card.opacity(isHovering ? 1 : 0.7)))
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Restore to Top of Deck", action: onRestore)
        }
    }
}
