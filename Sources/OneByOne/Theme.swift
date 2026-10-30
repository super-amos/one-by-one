import AppKit
import SwiftUI

extension Color {
    /// A color with separate light-mode and dark-mode values.
    init(light: NSColor, dark: NSColor) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
}

private func rgb(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

enum Theme {
    static let background = Color(light: rgb(0xF5F4F0), dark: rgb(0x111214))
    static let card = Color(light: rgb(0xFFFFFF), dark: rgb(0x1C1D21))
    static let hairline = Color(light: rgb(0x000000, alpha: 0.07), dark: rgb(0xFFFFFF, alpha: 0.08))
    static let shadow = Color(light: rgb(0x2B2A26, alpha: 0.10), dark: rgb(0x000000, alpha: 0.45))
    static let ink = Color(light: rgb(0x1D1D1F), dark: rgb(0xF2F2F4))
    static let inkSecondary = Color(light: rgb(0x6E6E73), dark: rgb(0x9A9AA2))
    static let done = Color(light: rgb(0x1E9E62), dark: rgb(0x34C77F))
    /// Darker than `done` so white text on it stays readable in both modes.
    static let doneFill = Color(light: rgb(0x17834F), dark: rgb(0x17834F))
    static let later = Color(light: rgb(0xA86508), dark: rgb(0xE4A23A))
    static let debt = Color(light: rgb(0xC23A30), dark: rgb(0xFF6B5E))
    /// Rewards are warm: amber running into coral.
    static let reward = Color(light: rgb(0xF08A24), dark: rgb(0xFFA94D))
    static let rewardText = Color(light: rgb(0xA3480A), dark: rgb(0xFFB866))
    static let rewardGlow = Color(light: rgb(0xFF8A3D, alpha: 0.45), dark: rgb(0xFFA94D, alpha: 0.55))
    static let cardCornerRadius: CGFloat = 28

    static var rewardGradient: LinearGradient {
        LinearGradient(
            colors: [Color(light: rgb(0xFFC152), dark: rgb(0xFFC152)), Color(light: rgb(0xFF6B6B), dark: rgb(0xFF6B6B))],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension Animation {
    /// The spring used whenever a card enters or leaves.
    static let card = Animation.spring(response: 0.45, dampingFraction: 0.82)
}

/// The big buttons under the card, and their smaller versions in page headers.
struct PillButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    let kind: Kind
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 13 : 15, weight: .semibold))
            .foregroundStyle(kind == .primary ? Color.white : Theme.ink)
            .padding(.horizontal, compact ? 16 : 26)
            .frame(height: compact ? 32 : 44)
            .background(Capsule().fill(kind == .primary ? Theme.doneFill : Theme.card))
            .overlay(Capsule().strokeBorder(kind == .primary ? Color.clear : Theme.hairline, lineWidth: 1))
            .shadow(color: Theme.shadow.opacity(kind == .primary ? 1 : 0.5), radius: compact ? 4 : 8, y: compact ? 1 : 3)
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// The warm button for logging what you spent: a flat tint, with no gradient
/// or glow.
struct RewardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        RewardButton(configuration: configuration)
    }

    private struct RewardButton: View {
        let configuration: ButtonStyleConfiguration
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.rewardText)
                .padding(.horizontal, 24)
                .frame(height: 42)
                .background(Capsule().fill(Theme.reward.opacity(configuration.isPressed ? 0.28 : isHovering ? 0.22 : 0.15)))
                .contentShape(Capsule())
                .onHover { isHovering = $0 }
                .animation(.easeOut(duration: 0.15), value: isHovering)
        }
    }
}

/// Small text buttons, like Undo and New task in Home's corners.
struct QuietButtonStyle: ButtonStyle {
    var tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        QuietButton(configuration: configuration, tint: tint)
    }

    private struct QuietButton: View {
        let configuration: ButtonStyleConfiguration
        let tint: Color?
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tint ?? (isHovering ? Theme.ink : Theme.inkSecondary))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Theme.card.opacity(isHovering ? 1 : 0)))
                .contentShape(Capsule())
                .opacity(configuration.isPressed ? 0.6 : 1)
                .onHover { isHovering = $0 }
                .animation(.easeOut(duration: 0.15), value: isHovering)
        }
    }
}

/// A keyboard shortcut shown next to a button's label.
struct ShortcutHint: View {
    let keys: String

    init(_ keys: String) {
        self.keys = keys
    }

    var body: some View {
        Text(keys)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.inkSecondary)
    }
}
