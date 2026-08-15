import AppKit
import GuideCore
import Observation
import SwiftUI

public enum CompanionMode: Equatable, Sendable {
    case ready
    case recording
    case working
    case success
    case error
}

@MainActor
@Observable
public final class CompanionPresentation {
    public var mode: CompanionMode = .ready
    public var caption = ""

    public init() {}
}

@MainActor
public final class CompanionPanelController {
    private let presentation: CompanionPresentation
    private let panel: CompanionPanel
    private var trackingTimer: Timer?

    public init(presentation: CompanionPresentation) {
        self.presentation = presentation
        panel = CompanionPanel(
            contentRect: NSRect(x: 0, y: 0, width: 46, height: 46),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configurePanel()
    }

    public func show() {
        updateContentSizeAndPosition()
        panel.orderFrontRegardless()
        startTracking()
    }

    public func hide() {
        trackingTimer?.invalidate()
        trackingTimer = nil
        panel.orderOut(nil)
    }

    public func refresh() {
        updateContentSizeAndPosition()
        if panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    private func configurePanel() {
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = NSHostingView(rootView: CompanionBubbleView(presentation: presentation))
    }

    private func startTracking() {
        guard trackingTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateContentSizeAndPosition()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        trackingTimer = timer
    }

    private func updateContentSizeAndPosition() {
        let hasCaption = !presentation.caption.isEmpty
        let size = hasCaption ? NSSize(width: 250, height: 58) : NSSize(width: 46, height: 46)
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return }

        var origin = NSPoint(x: pointer.x + 14, y: pointer.y - size.height - 16)
        origin.x = min(max(origin.x, visibleFrame.minX + 8), visibleFrame.maxX - size.width - 8)
        origin.y = min(max(origin.y, visibleFrame.minY + 8), visibleFrame.maxY - size.height - 8)

        let newFrame = NSRect(origin: origin, size: size)
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.setFrame(newFrame, display: true)
        } else {
            panel.setFrame(newFrame, display: true, animate: false)
        }
    }
}

private final class CompanionPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct CompanionBubbleView: View {
    let presentation: CompanionPresentation

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(color.gradient)
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }
            .frame(width: 42, height: 42)
            .shadow(color: .black.opacity(0.22), radius: 8, y: 3)

            if !presentation.caption.isEmpty {
                Text(presentation.caption)
                    .font(.callout.weight(.medium))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                    .padding(.trailing, 12)
                    .transition(.opacity)
            }
        }
        .padding(2)
        .background {
            if !presentation.caption.isEmpty {
                Capsule()
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .animation(.easeInOut(duration: 0.16), value: presentation.caption)
        .animation(.easeInOut(duration: 0.16), value: presentation.mode)
    }

    private var symbol: String {
        switch presentation.mode {
        case .ready: "location.north.fill"
        case .recording: "waveform"
        case .working: "ellipsis"
        case .success: "checkmark"
        case .error: "exclamationmark"
        }
    }

    private var color: Color {
        switch presentation.mode {
        case .ready: .blue
        case .recording: .red
        case .working: .orange
        case .success: .green
        case .error: .red
        }
    }

    private var accessibilityDescription: String {
        presentation.caption.isEmpty ? "SERPy is ready" : presentation.caption
    }
}
