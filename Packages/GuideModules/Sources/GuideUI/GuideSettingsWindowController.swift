import AppKit
import SwiftUI

@MainActor
public final class GuideSettingsWindowController: NSWindowController {
    public init(model: GuideAppModel) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SERPy Settings"
        window.level = .normal
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 640, height: 560)
        window.contentView = NSHostingView(rootView: SettingsView(model: model))
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    public func present() {
        NSApplication.shared.setActivationPolicy(.regular)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate()
    }

    public func recoverLaunchForeground() {
        SettingsWindowForegroundRecovery(
            enterRegularMode: {
                NSApplication.shared.setActivationPolicy(.regular)
            },
            showSettings: { [self] in
                showWindow(nil)
                window?.makeKeyAndOrderFront(nil)
            },
            forceActivateApplication: {
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        ).recover()
    }
}
