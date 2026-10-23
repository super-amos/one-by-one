import OneByOneCore
import SwiftUI

/// A card's identity on screen. It includes the skip count so a card that's
/// put off and comes straight back (a one-card deck) still re-enters.
private struct CardKey: Hashable {
    let id: UUID
    let skips: Int
}

/// "+$5" shown under the badge after a reward lands.
private struct Floater: Identifiable {
    let id = UUID()
    let text: String
    let at: CGPoint
}

/// The only card you can see, and the few controls around it.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var swipeRequest: SwipeRequest?
    @State private var flights: [RewardFlight] = []
    @State private var floaters: [Floater] = []
    @State private var cardFrame = CGRect.zero
    @State private var badgeFrame = CGRect.zero
    @State private var width: CGFloat = 660
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                TopBar { badgeFrame = $0 }
                if let card = model.deck.current {
                    focus(on: card)
                } else {
                    EmptyDeckView(
                        isFirstRun: model.isFirstRun,
                        rewards: model.shownBalance > 0 ? model.money(model.shownBalance) : nil,
                        onAdd: { model.sheet = .add }
                    )
                    .transition(.opacity)
                }
                bottomBar
            }
            effects
        }
        .coordinateSpace(.named(Page.space))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .focusable()
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(.rightArrow) { swipe(.done) }
        .onKeyPress(.return) { swipe(.done) }
        .onKeyPress(.leftArrow) { swipe(.later) }
        .onKeyPress(.escape) {
            guard model.isAskingAboutSkip else { return .ignored }
            withAnimation(.card) { model.isAskingAboutSkip = false }
            return .handled
        }
        .onAppear { isFocused = true }
        .onChange(of: model.sheet == nil) { _, isClosed in
            if isClosed { isFocused = true }
        }
    }

    private func focus(on card: Card) -> some View {
        // Spacing follows the Paper design: 44 above the headline, 32 to the
        // card, 40 from the card to the buttons, with any message in that gap.
        VStack(spacing: 0) {
            Spacer(minLength: 12)
                .frame(maxHeight: 44)
            VStack(spacing: 6) {
                Text(Copy.headline)
                    .font(.system(size: 21, weight: .semibold))
                    .tracking(-0.2)
                Text(Copy.subhead)
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.inkSecondary)
            }
            .multilineTextAlignment(.center)
            cardArea(card)
                .padding(.top, 32)
            messageLine
                .padding(.top, 10)
            actionButtons
                .padding(.top, 10)
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 54)
    }

    private func cardArea(_ card: Card) -> some View {
        ZStack {
            SwipeCard(
                card: card,
                valueText: model.money(model.deck.value(of: card)),
                canSkip: model.canSkipCurrent,
                travel: width,
                request: swipeRequest,
                onCommit: commit,
                onBlockedSkip: { withAnimation(.card) { model.isAskingAboutSkip = true } }
            )
            .id(CardKey(id: card.id, skips: card.skipCount))
            .transition(cardTransition)
            .allowsHitTesting(!model.isAskingAboutSkip)
            .contextMenu {
                Button("Edit…") { model.sheet = .edit(card) }
                Button("Split…") { model.sheet = .split(card) }
                Button("Delete", role: .destructive) {
                    withAnimation(.card) { model.deleteCurrent() }
                }
            }
            if model.isAskingAboutSkip {
                SkipPrompt(
                    card: card,
                    onSplit: { model.sheet = .split(card) },
                    onLetGo: { withAnimation(.card) { model.deleteCurrent() } },
                    onLaterAnyway: {
                        withAnimation(.card) { model.approveSkip() }
                        swipe(.later)
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .frame(maxWidth: 552)
        .frame(height: 330)
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Page.space)) } action: { cardFrame = $0 }
    }

    private var cardTransition: AnyTransition {
        if reduceMotion { return .opacity }
        let leave = AnyTransition.scale(scale: 0.94).combined(with: .opacity)
        switch model.entrance {
        case .fresh, .returning(nil):
            return .asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: leave)
        case .returning(let side?):
            let x = side == .done ? width : -width
            return .asymmetric(insertion: .offset(x: x, y: 40), removal: leave)
        }
    }

    private var messageLine: some View {
        ZStack {
            if let message = model.message {
                Text(message)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary)
                    .id(message)
                    .transition(.opacity.combined(with: .offset(y: 4)))
            }
        }
        .frame(height: 20)
    }

    private var actionButtons: some View {
        HStack(spacing: 14) {
            Button { swipe(.later) } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.left")
                    Text("Later")
                }
            }
            .buttonStyle(PillButtonStyle(kind: .secondary))
            .help("Put it off until later (←)")
            Button { swipe(.done) } label: {
                HStack(spacing: 8) {
                    Text("Done")
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(PillButtonStyle(kind: .primary))
            .help("Mark it done (→)")
        }
        .disabled(model.isAskingAboutSkip)
        .opacity(model.isAskingAboutSkip ? 0.3 : 1)
    }

    private var bottomBar: some View {
        HStack {
            if model.deck.canUndo {
                Button {
                    withAnimation(.card) { model.undo() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Undo")
                        ShortcutHint("⌘Z")
                    }
                }
                .buttonStyle(QuietButtonStyle())
                .transition(.opacity)
            }
            Spacer()
            // The empty deck has its own, bigger New task button.
            if model.deck.current != nil {
                Button { model.sheet = .add } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("New task")
                        ShortcutHint("⌘N")
                    }
                }
                .buttonStyle(QuietButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
        .frame(height: 56)
    }

    /// Sparkles and amounts drawn over everything, in window coordinates.
    private var effects: some View {
        GeometryReader { proxy in
            let origin = proxy.frame(in: .named(Page.space)).origin
            ForEach(flights) { flight in
                RewardFlightView(flight: RewardFlight(
                    amount: flight.amount,
                    label: flight.label,
                    from: CGPoint(x: flight.from.x - origin.x, y: flight.from.y - origin.y),
                    to: CGPoint(x: flight.to.x - origin.x, y: flight.to.y - origin.y)
                )) {
                    land(flight)
                }
            }
            ForEach(floaters) { floater in
                FloatingAmount(text: floater.text, at: CGPoint(x: floater.at.x - origin.x, y: floater.at.y - origin.y))
            }
        }
        .allowsHitTesting(false)
    }

    @discardableResult
    private func swipe(_ direction: SwipeDirection) -> KeyPress.Result {
        guard model.deck.current != nil, !model.isAskingAboutSkip, model.sheet == nil else { return .ignored }
        swipeRequest = SwipeRequest(direction: direction)
        return .handled
    }

    private func commit(_ direction: SwipeDirection) {
        switch direction {
        case .done:
            if let earned = withAnimation(.card, { model.complete() }) {
                launchReward(earned)
            }
        case .later:
            withAnimation(.card) { model.deferCurrent() }
        }
    }

    private func launchReward(_ earned: Decimal) {
        guard !reduceMotion, cardFrame != .zero, badgeFrame != .zero else {
            withAnimation(.snappy) { model.rewardLanded(earned) }
            return
        }
        // The badge's gift sits 4pt in from its left edge and is 28pt wide.
        flights.append(RewardFlight(
            amount: earned,
            label: model.money(earned),
            from: CGPoint(x: cardFrame.midX, y: cardFrame.midY),
            to: CGPoint(x: badgeFrame.minX + 18, y: badgeFrame.midY)
        ))
    }

    private func land(_ flight: RewardFlight) {
        flights.removeAll { $0.id == flight.id }
        withAnimation(.snappy) { model.rewardLanded(flight.amount) }
        let floater = Floater(text: "+" + flight.label, at: CGPoint(x: badgeFrame.midX, y: badgeFrame.maxY + 16))
        floaters.append(floater)
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            floaters.removeAll { $0.id == floater.id }
        }
    }
}

private struct EmptyDeckView: View {
    let isFirstRun: Bool
    /// The rewards to nudge the user to spend, if there are any.
    let rewards: String?
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Spacer()
            if isFirstRun {
                Text(Copy.firstTitle)
                    .font(.system(size: 26, weight: .semibold))
                Text(Copy.firstBody)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.inkSecondary)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.done)
                    .padding(.bottom, 10)
                Text(Copy.emptyTitle)
                    .font(.system(size: 26, weight: .semibold))
                Text(Copy.emptyBody)
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.inkSecondary)
                if let rewards {
                    Text(Copy.emptyReward(rewards))
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.rewardText)
                        .padding(.top, 14)
                }
            }
            Button(action: onAdd) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("New task")
                }
            }
            .buttonStyle(PillButtonStyle(kind: .secondary))
            .padding(.top, 22)
            Spacer()
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}
