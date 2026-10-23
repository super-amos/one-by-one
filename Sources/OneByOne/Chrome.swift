import SwiftUI

/// Page buttons on the left, rewards on the right. Every page shows it.
struct TopBar: View {
    @Environment(AppModel.self) private var model
    @Environment(\.titleBarMetrics) private var titleBar
    /// Reports where the reward badge is, so Home can aim rewards at it.
    var onBadgeFrame: (CGRect) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 2) {
            ForEach([Page.home, .edit, .history, .trash]) { page in
                PageButton(page: page, isSelected: model.page == page) { model.go(to: page) }
            }
            Spacer()
            Button { model.go(to: .rewards) } label: {
                RewardBadge(
                    amount: model.shownBalance,
                    text: model.money(model.shownBalance),
                    pulse: model.rewardPulse,
                    isSelected: model.page == .rewards
                )
            }
            .buttonStyle(.plain)
            .help("Your rewards (⌘5)")
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Page.space)) } action: { onBadgeFrame($0) }
        }
        .padding(.leading, titleBar.buttonsEnd > 0 ? titleBar.buttonsEnd + 14 : 16)
        .padding(.trailing, 16)
        .frame(height: titleBar.height)
    }
}

private struct PageButton: View {
    let page: Page
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: page.symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected || isHovering ? Theme.ink : Theme.inkSecondary)
                .frame(width: 34, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Theme.card.opacity(isSelected ? 1 : isHovering ? 0.6 : 0))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(Theme.hairline.opacity(isSelected ? 1 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("\(page.title) (⌘\(page.rawValue + 1))")
    }
}

/// The title row at the top of every page except Home.
struct PageHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.inkSecondary)
            }
            Spacer()
            trailing
        }
        .padding(.horizontal, 28)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }
}

/// What a page shows when it has nothing in it.
struct PageEmpty: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: 30))
                .foregroundStyle(Theme.inkSecondary.opacity(0.6))
                .padding(.bottom, 6)
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(detail)
                .font(.system(size: 13))
                .foregroundStyle(Theme.inkSecondary)
            Spacer()
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity)
    }
}

struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Theme.inkSecondary)
            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .frame(width: 150)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(Theme.card))
        .overlay(Capsule().strokeBorder(Theme.hairline))
    }
}

/// "Today", "Yesterday", or the date written out.
func dayTitle(_ day: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(day) { return "Today" }
    if calendar.isDateInYesterday(day) { return "Yesterday" }
    return day.formatted(.dateTime.weekday(.wide).month(.wide).day())
}

func count(_ number: Int, _ noun: String) -> String {
    "\(number) \(noun)\(number == 1 ? "" : "s")"
}
