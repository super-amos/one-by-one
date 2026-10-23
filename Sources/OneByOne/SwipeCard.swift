import OneByOneCore
import SwiftUI

/// A request from a button or key to swipe the card, so it animates the same
/// way a drag does.
struct SwipeRequest: Equatable {
    let direction: SwipeDirection
    let id = UUID()
}

/// The card on Home. It follows a drag, tilts, shows a DONE or LATER stamp,
/// and flies off when the drag goes far enough or a request comes in.
struct SwipeCard: View {
    let card: Card
    let valueText: String
    let canSkip: Bool
    /// How far the card has to travel to leave the window.
    let travel: CGFloat
    let request: SwipeRequest?
    let onCommit: (SwipeDirection) -> Void
    let onBlockedSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset = CGSize.zero
    @State private var isLeaving = false
    @State private var isPastThreshold = false

    private let threshold: CGFloat = 130

    var body: some View {
        CardFace(card: card, valueText: valueText)
            .overlay { stamps }
            .offset(offset)
            .rotationEffect(.degrees(rotation), anchor: .bottom)
            .gesture(drag)
            .onChange(of: request) { _, request in
                if let request { commit(request.direction) }
            }
    }

    private var rotation: Double {
        min(max(Double(offset.width) / 24, -20), 20)
    }

    private var progress: CGFloat {
        min(abs(offset.width) / threshold, 1)
    }

    private var stamps: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                .fill((offset.width >= 0 ? Theme.done : Theme.later).opacity(0.10 * progress))
            Stamp(text: "DONE", color: Theme.done, angle: -12)
                .opacity(offset.width > 0 ? progress : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Stamp(text: "LATER", color: Theme.later, angle: 12)
                .opacity(offset.width < 0 ? progress : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .allowsHitTesting(false)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                guard !isLeaving else { return }
                offset = CGSize(width: value.translation.width, height: value.translation.height * 0.2)
                let isPast = abs(offset.width) > threshold
                if isPast != isPastThreshold {
                    isPastThreshold = isPast
                    if isPast { Feedback.thresholdCrossed() }
                }
            }
            .onEnded { value in
                guard !isLeaving else { return }
                isPastThreshold = false
                let distance = value.translation.width
                let flung = value.predictedEndTranslation.width
                if distance > threshold || flung > threshold * 2.2 {
                    commit(.done)
                } else if distance < -threshold || flung < -threshold * 2.2 {
                    commit(.later)
                } else {
                    springBack()
                }
            }
    }

    private func springBack() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { offset = .zero }
    }

    private func commit(_ direction: SwipeDirection) {
        guard !isLeaving else { return }
        if direction == .later && !canSkip {
            springBack()
            onBlockedSkip()
            return
        }
        if reduceMotion {
            onCommit(direction)
            return
        }
        isLeaving = true
        let sign: CGFloat = direction == .done ? 1 : -1
        withAnimation(.easeIn(duration: 0.24)) {
            offset = CGSize(width: sign * travel, height: offset.height + 60)
        } completion: {
            onCommit(direction)
        }
    }
}

/// The card's contents, without any of the dragging.
struct CardFace: View {
    let card: Card
    let valueText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("NOW")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(Theme.inkSecondary)
                Spacer()
                RewardTag(text: valueText)
            }
            Spacer(minLength: 20)
            Text(card.title)
                .font(.system(size: 30, weight: .semibold))
                .tracking(-0.3)
                .lineSpacing(2)
                .lineLimit(4)
                .minimumScaleFactor(0.6)
            if !card.note.isEmpty {
                Text(card.note)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.inkSecondary)
                    .lineLimit(4)
                    .padding(.top, 12)
            }
            Spacer(minLength: 20)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CardBackground())
    }
}

struct CardBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
            .fill(Theme.card)
            .shadow(color: Theme.shadow, radius: 28, y: 14)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
    }
}

private struct Stamp: View {
    let text: String
    let color: Color
    let angle: Double

    var body: some View {
        Text(text)
            .font(.system(size: 22, weight: .heavy))
            .tracking(2)
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(color, lineWidth: 3))
            .rotationEffect(.degrees(angle))
            .padding(26)
    }
}

/// What the card turns into when you try to put it off a third time.
struct SkipPrompt: View {
    let card: Card
    let onSplit: () -> Void
    let onLetGo: () -> Void
    let onLaterAnyway: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(card.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.inkSecondary)
                .lineLimit(1)
            Spacer(minLength: 16)
            Text(Copy.skipPromptTitle)
                .font(.system(size: 24, weight: .semibold))
            Text(Copy.skipPromptBody)
                .font(.system(size: 16))
                .foregroundStyle(Theme.inkSecondary)
                .padding(.top, 8)
            Spacer(minLength: 16)
            HStack(spacing: 10) {
                Button("Split it", action: onSplit)
                    .buttonStyle(PillButtonStyle(kind: .secondary))
                Button("Let it go", action: onLetGo)
                    .buttonStyle(PillButtonStyle(kind: .secondary))
                Button("Later anyway", action: onLaterAnyway)
                    .buttonStyle(QuietButtonStyle())
            }
        }
        .multilineTextAlignment(.center)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CardBackground())
    }
}
