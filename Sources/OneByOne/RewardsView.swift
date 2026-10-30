import OneByOneCore
import SwiftUI

/// What you've earned, what you've spent it on, and what being in the red costs.
struct RewardsView: View {
    @Environment(AppModel.self) private var model

    /// A line in the spending history: something bought, or a month of interest.
    private struct Line: Identifiable {
        let id: String
        let title: String
        let date: Date
        let amount: Decimal
        let spend: Spend?
    }

    private var lines: [Line] {
        var lines = model.state.spending.map {
            Line(id: $0.id.uuidString, title: $0.note.isEmpty ? "A treat" : $0.note, date: $0.date, amount: $0.amount, spend: $0)
        }
        let calendar = Calendar.current
        let months = Dictionary(grouping: model.state.interest) { calendar.dateInterval(of: .month, for: $0.day)?.start ?? $0.day }
        for (month, charges) in months {
            lines.append(Line(
                id: "interest-\(month.timeIntervalSince1970)",
                title: "Interest, \(month.formatted(.dateTime.month(.wide).year()))",
                date: charges.map(\.day).max() ?? month,
                amount: charges.reduce(0) { $0 + $1.amount },
                spend: nil
            ))
        }
        return lines.sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            ScrollView {
                VStack(spacing: 24) {
                    hero
                    stats
                    history
                }
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
        }
    }

    private var hero: some View {
        let balance = model.state.balance
        return VStack(spacing: 10) {
            GiftIcon(size: 64, wiggle: model.rewardPulse)
                .padding(.bottom, 6)
            Text(model.money(balance))
                .font(.system(size: 52, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(balance < 0 ? Theme.debt : Theme.ink)
                .contentTransition(.numericText(value: NSDecimalNumber(decimal: balance).doubleValue))
            Text(balance < 0 ? "owed" : "yours to spend on yourself")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.inkSecondary)
            Text(caption(balance))
                .font(.system(size: 14))
                .foregroundStyle(balance < 0 ? Theme.debt : Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
            // The app has nothing to buy. This logs what you spent out in the world.
            Button("I spent some rewards") { model.sheet = .spend(nil) }
                .buttonStyle(RewardButtonStyle())
            .padding(.top, 10)
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(RadialGradient(
                            colors: [Theme.reward.opacity(0.16), .clear],
                            center: .top,
                            startRadius: 0,
                            endRadius: 280
                        ))
                )
                .shadow(color: Theme.shadow, radius: 20, y: 8)
        )
    }

    private func caption(_ balance: Decimal) -> String {
        if balance < 0 {
            let rate = (model.settings.interestRate * 100).formatted(.number.precision(.fractionLength(0...2)))
            return Copy.rewardsNegative(model.money(-balance)) + " Interest is \(rate)% a year, added daily."
        }
        return model.deck.done.isEmpty ? Copy.rewardsNothingYet : Copy.rewardsPositive
    }

    private var stats: some View {
        HStack(spacing: 12) {
            StatTile(title: "Earned", value: model.money(model.deck.earned), symbol: "sparkles")
            StatTile(title: "Spent", value: model.money(model.state.spent), symbol: "bag")
            StatTile(title: "Interest", value: model.money(model.state.interestCharged), symbol: "percent")
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Spending history")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.bottom, 4)
            if lines.isEmpty {
                Text("Nothing spent yet. When you treat yourself, log it here and it comes off your rewards.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(lines) { line in
                    SpendRow(
                        title: line.title,
                        date: line.date,
                        amount: "\u{2212}" + model.money(line.amount),
                        isInterest: line.spend == nil,
                        onEdit: line.spend.map { spend in { model.sheet = .spend(spend) } },
                        onDelete: line.spend.map { spend in { withAnimation { model.deleteSpend(spend.id) } } }
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.inkSecondary)
            Text(value)
                .font(.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(Theme.ink)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.hairline))
    }
}

private struct SpendRow: View {
    let title: String
    let date: Date
    let amount: String
    let isInterest: Bool
    /// Only spending can be edited or deleted; interest can't.
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isInterest ? "percent" : "bag.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isInterest ? Theme.debt : Theme.rewardText)
                .frame(width: 28, height: 28)
                .background(Circle().fill((isInterest ? Theme.debt : Theme.reward).opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
            Text(amount)
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .foregroundStyle(isInterest ? Theme.debt : Theme.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.card.opacity(isHovering ? 1 : 0.7)))
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2) { onEdit?() }
        .contextMenu {
            if let onEdit, let onDelete {
                Button("Edit…", action: onEdit)
                Button("Delete", role: .destructive, action: onDelete)
            }
        }
    }
}
