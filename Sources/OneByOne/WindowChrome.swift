import AppKit
import SwiftUI

/// Where the window's title bar ends and how far its buttons reach, so the
/// top bar can share one row with the red, yellow and green buttons.
struct TitleBarMetrics: Equatable {
    var height: CGFloat = 52
    /// The right edge of the window buttons, or 0 when they're hidden.
    var buttonsEnd: CGFloat = 78
}

private struct TitleBarMetricsKey: EnvironmentKey {
    static let defaultValue = TitleBarMetrics()
}

extension EnvironmentValues {
    var titleBarMetrics: TitleBarMetrics {
        get { self[TitleBarMetricsKey.self] }
        set { self[TitleBarMetricsKey.self] = newValue }
    }
}

/// Gives the window an empty, see-through toolbar. That makes the title bar
/// as tall as the top bar and centers the window buttons in it, so the page
/// content can start at the very top of the window like the design.
struct WindowChrome: NSViewRepresentable {
    let onChange: (TitleBarMetrics) -> Void

    func makeNSView(context: Context) -> ChromeView {
        let view = ChromeView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ view: ChromeView, context: Context) {
        view.onChange = onChange
    }

    final class ChromeView: NSView {
        var onChange: (TitleBarMetrics) -> Void = { _ in }
        private var observers: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
            guard let window else { return }
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            if window.toolbar == nil {
                window.toolbar = NSToolbar(identifier: "OneByOne")
            }
            window.toolbarStyle = .unified
            let changes = [
                NSWindow.didResizeNotification,
                NSWindow.didEnterFullScreenNotification,
                NSWindow.didExitFullScreenNotification,
            ]
            for name in changes {
                observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.report() }
                })
            }
            report()
        }

        private func report() {
            guard let window else { return }
            let height = window.frame.height - window.contentLayoutRect.height
            // The title bar row holds the top bar, so it isn't a safe area.
            // Left as one, a scroll view that starts right under the top bar
            // stretches up beneath it and swallows clicks meant for the bar.
            window.contentView?.additionalSafeAreaInsets = NSEdgeInsets(top: -height, left: 0, bottom: 0, right: 0)
            var buttonsEnd: CGFloat = 0
            if let zoom = window.standardWindowButton(.zoomButton), !zoom.isHidden, zoom.window != nil {
                buttonsEnd = zoom.convert(zoom.bounds, to: nil).maxX
            }
            let metrics = TitleBarMetrics(height: height >= 40 ? height : 52, buttonsEnd: buttonsEnd)
            DispatchQueue.main.async { [onChange] in onChange(metrics) }
        }
    }
}
