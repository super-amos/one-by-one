import SwiftUI

/// A gift in a warm circle: the mark for rewards everywhere in the app. It
/// wiggles each time `wiggle` changes.
struct GiftIcon: View {
    var size: CGFloat = 24
    var wiggle = 0

    var body: some View {
        Image(systemName: "gift.fill")
            .font(.system(size: size * 0.48, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(Theme.rewardGradient))
            .shadow(color: Theme.rewardGlow, radius: size * 0.18, y: size * 0.05)
            .keyframeAnimator(initialValue: 0.0, trigger: wiggle) { content, angle in
                content.rotationEffect(.degrees(angle))
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(-14, duration: 0.08)
                    CubicKeyframe(12, duration: 0.1)
                    CubicKeyframe(-6, duration: 0.1)
                    CubicKeyframe(0, duration: 0.12)
                }
            }
    }
}

/// A task's reward, as shown on cards and in lists.
struct RewardTag: View {
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "gift.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
        }
        .foregroundStyle(Theme.rewardText)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.reward.opacity(0.14)))
    }
}

/// The rewards in the top right corner of every page. It pulses when a
/// reward lands.
struct RewardBadge: View {
    let amount: Decimal
    let text: String
    let pulse: Int
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            GiftIcon(size: 24, wiggle: pulse)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(text)
                    .font(.system(size: 15, weight: .semibold).monospacedDigit())
                    .foregroundStyle(amount < 0 ? Theme.debt : Theme.ink)
                    .contentTransition(.numericText(value: NSDecimalNumber(decimal: amount).doubleValue))
                Text(amount < 0 ? "owed" : "rewards")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.inkSecondary)
            }
        }
        .padding(.leading, 5)
        .padding(.trailing, 13)
        .padding(.vertical, 5)
        .background(Capsule().fill(Theme.card))
        .overlay(
            Capsule().strokeBorder(isSelected ? Theme.reward.opacity(0.7) : Theme.hairline, lineWidth: isSelected ? 1.5 : 1)
        )
        .shadow(color: Theme.shadow.opacity(0.5), radius: 6, y: 2)
        .keyframeAnimator(initialValue: 1.0, trigger: pulse) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(1.1, duration: 0.14, spring: .snappy)
                SpringKeyframe(1.0, duration: 0.4, spring: .bouncy)
            }
        }
    }
}

/// A reward on its way from a finished card to the badge.
struct RewardFlight: Identifiable {
    let id = UUID()
    let amount: Decimal
    let label: String
    let from: CGPoint
    let to: CGPoint
}

/// Sparkles that burst off a finished card and arc into the reward badge.
struct RewardFlightView: View {
    let flight: RewardFlight
    let onLanded: () -> Void

    private static let spread: [CGSize] = [
        .zero, CGSize(width: -46, height: 22), CGSize(width: 40, height: -14),
        CGSize(width: -20, height: -34), CGSize(width: 28, height: 30),
    ]
    private static let sizes: [CGFloat] = [24, 14, 17, 12, 15]

    var body: some View {
        ZStack {
            ForEach(Self.spread.indices, id: \.self) { index in
                Sparkle(
                    from: CGPoint(x: flight.from.x + Self.spread[index].width, y: flight.from.y + Self.spread[index].height),
                    to: flight.to,
                    size: Self.sizes[index],
                    delay: Double(index) * 0.05,
                    onLanded: index == Self.spread.count - 1 ? onLanded : nil
                )
            }
        }
    }
}

private struct SparkleLook {
    var scale = 0.2
    var angle = 0.0
    var opacity = 0.0
}

/// One sparkle. Moving across and up on different curves is what bends its path.
private struct Sparkle: View {
    let from: CGPoint
    let to: CGPoint
    let size: CGFloat
    let delay: Double
    let onLanded: (() -> Void)?

    @State private var dx: CGFloat = 0
    @State private var dy: CGFloat = 0
    @State private var launched = false

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(Theme.rewardGradient)
            .shadow(color: Theme.rewardGlow, radius: 5)
            .keyframeAnimator(initialValue: SparkleLook(), trigger: launched) { content, look in
                content
                    .scaleEffect(look.scale)
                    .rotationEffect(.degrees(look.angle))
                    .opacity(look.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.scale) {
                    SpringKeyframe(1.3, duration: 0.18, spring: .snappy)
                    CubicKeyframe(0.45, duration: 0.5)
                }
                KeyframeTrack(\.angle) {
                    LinearKeyframe(200, duration: 0.68)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1, duration: 0.06)
                    LinearKeyframe(1, duration: 0.5)
                    LinearKeyframe(0, duration: 0.12)
                }
            }
            .position(from)
            .offset(x: dx)
            .offset(y: dy)
            .task {
                try? await Task.sleep(for: .seconds(delay))
                launched = true
                withAnimation(.easeIn(duration: 0.62)) {
                    dx = to.x - from.x
                }
                withAnimation(.easeOut(duration: 0.62)) {
                    dy = to.y - from.y
                } completion: {
                    onLanded?()
                }
            }
    }
}

/// "+$5" popping out under the badge after a reward lands.
struct FloatingAmount: View {
    let text: String
    let at: CGPoint

    @State private var phase = 0

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .bold).monospacedDigit())
            .foregroundStyle(Theme.rewardText)
            .scaleEffect(phase == 1 ? 1 : 0.6)
            .opacity(phase == 1 ? 1 : 0)
            .offset(y: phase == 2 ? 10 : 0)
            .position(at)
            .task {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { phase = 1 }
                try? await Task.sleep(for: .seconds(0.9))
                withAnimation(.easeIn(duration: 0.35)) { phase = 2 }
            }
    }
}
