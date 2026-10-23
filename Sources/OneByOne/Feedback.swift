import AppKit

/// The small sounds and trackpad taps that confirm an action.
@MainActor
enum Feedback {
    static func thresholdCrossed() {
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    static func rewardLanded() {
        guard let sound = NSSound(named: "Glass") else { return }
        sound.volume = 0.25
        sound.stop()
        sound.play()
    }
}
