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
    public var responseText = ""
    public var guideStage: GuidanceAmbientStage?
    public var contextLabel: String?

    public init() {}
}

@MainActor
public final class CompanionPanelController {
    private let presentation: CompanionPresentation
    private let panel: CompanionPanel
    private let responsePanel: CompanionPanel
    private let responseLayoutPolicy = CompanionResponseLayoutPolicy()
    private let responseAnchorPolicy = CompanionResponseAnchorPolicy()
    private var trackingTimer: Timer?
    private var statusAnchorFrame: CGRect?
    private var responseAnchorFrame: CGRect?

    public init(presentation: CompanionPresentation) {
        self.presentation = presentation
        panel = CompanionPanel(
            contentRect: NSRect(x: 0, y: 0, width: 46, height: 46),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        responsePanel = CompanionPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configurePanel()
    }

    public func show() {
        updateContentSizeAndPosition()
        panel.orderFrontRegardless()
        if !presentation.responseText.isEmpty {
            responsePanel.orderFrontRegardless()
        }
        startTracking()
    }

    public func hide() {
        trackingTimer?.invalidate()
        trackingTimer = nil
        panel.orderOut(nil)
        responsePanel.orderOut(nil)
    }

    public func refresh() {
        updateContentSizeAndPosition()
        if panel.isVisible {
            panel.orderFrontRegardless()
        }
        if !presentation.responseText.isEmpty {
            responsePanel.orderFrontRegardless()
        } else {
            responseAnchorFrame = nil
            responsePanel.orderOut(nil)
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

        responsePanel.isOpaque = false
        responsePanel.backgroundColor = .clear
        responsePanel.hasShadow = false
        responsePanel.ignoresMouseEvents = true
        responsePanel.hidesOnDeactivate = false
        responsePanel.isReleasedWhenClosed = false
        responsePanel.level = .floating
        responsePanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        responsePanel.contentView = NSHostingView(rootView: CompanionResponseView(presentation: presentation))
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
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return }
        let hasCaption = !presentation.caption.isEmpty
        let size: NSSize
        if presentation.guideStage != nil, hasCaption {
            size = measuredGuideStatusSize(availableHeight: visibleFrame.height - 16)
        } else {
            size = hasCaption ? NSSize(width: 250, height: 58) : NSSize(width: 46, height: 46)
        }

        var origin = NSPoint(x: pointer.x + 14, y: pointer.y - size.height - 16)
        origin.x = min(max(origin.x, visibleFrame.minX + 8), visibleFrame.maxX - size.width - 8)
        origin.y = min(max(origin.y, visibleFrame.minY + 8), visibleFrame.maxY - size.height - 8)

        let proposedStatusFrame = NSRect(origin: origin, size: size)
        let newFrame = responseAnchorPolicy.frame(
            current: statusAnchorFrame,
            proposed: proposedStatusFrame,
            responseIsVisible: !presentation.responseText.isEmpty
        )
        statusAnchorFrame = presentation.responseText.isEmpty ? nil : newFrame
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.setFrame(newFrame, display: true)
        } else {
            panel.setFrame(newFrame, display: true, animate: false)
        }

        if !presentation.responseText.isEmpty {
            let responseSize = measuredResponseSize(
                presentation.responseText,
                availableHeight: visibleFrame.height - 16
            )
            let proposedFrame = responseLayoutPolicy.frame(
                pointer: pointer,
                visibleFrame: visibleFrame,
                contentSize: responseSize,
                avoiding: newFrame
            )
            let responseFrame = responseAnchorPolicy.frame(
                current: responseAnchorFrame,
                proposed: proposedFrame,
                responseIsVisible: responsePanel.isVisible
            )
            responseAnchorFrame = responseFrame
            responsePanel.setFrame(responseFrame, display: true)
        } else {
            statusAnchorFrame = nil
            responseAnchorFrame = nil
        }
    }

    private func measuredResponseSize(_ text: String, availableHeight: CGFloat) -> CGSize {
        let textWidth: CGFloat = 340
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        let bounds = (text as NSString).boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        return NSSize(
            width: 380,
            height: min(max(92, ceil(bounds.height) + 48), availableHeight)
        )
    }

    private func measuredGuideStatusSize(availableHeight: CGFloat) -> CGSize {
        let textWidth: CGFloat = 276
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        let contextFont = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        let captionBounds = (presentation.caption as NSString).boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        let contextHeight: CGFloat
        if let contextLabel = presentation.contextLabel, !contextLabel.isEmpty {
            contextHeight = (contextLabel as NSString).boundingRect(
                with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: contextFont]
            ).height + 4
        } else {
            contextHeight = 0
        }
        return NSSize(
            width: 350,
            height: min(max(62, ceil(captionBounds.height + contextHeight) + 28), availableHeight)
        )
    }
}

private struct CompanionResponseView: View {
    let presentation: CompanionPresentation

    var body: some View {
        Text(presentation.responseText)
            .font(.callout.weight(.medium))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("SERPy answer")
        .accessibilityValue(presentation.responseText)
    }
}

private final class CompanionPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct CompanionBubbleView: View {
    let presentation: CompanionPresentation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                VStack(alignment: .leading, spacing: 3) {
                    Text(presentation.caption)
                        .font(.callout.weight(.medium))
                        .lineLimit(presentation.guideStage == .liveTranscript ? 3 : (presentation.guideStage == nil ? 2 : nil))
                        .foregroundStyle(.primary)
                    if let contextLabel = presentation.contextLabel, !contextLabel.isEmpty {
                        Text(contextLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
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
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: presentation.caption)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: presentation.mode)
    }

    private var symbol: String {
        if let guideStage = presentation.guideStage {
            return switch guideStage {
            case .ready, .readyForFollowUp: "location.north.fill"
            case .listening, .liveTranscript: "waveform"
            case .capturing: "viewfinder"
            case .thinking: "ellipsis"
            case .speaking: "speaker.wave.2.fill"
            case .error: "exclamationmark"
            case .cancelled: "xmark"
            }
        }
        return switch presentation.mode {
        case .ready: "location.north.fill"
        case .recording: "waveform"
        case .working: "ellipsis"
        case .success: "checkmark"
        case .error: "exclamationmark"
        }
    }

    private var color: Color {
        if let guideStage = presentation.guideStage {
            return switch guideStage {
            case .ready, .readyForFollowUp: .blue
            case .listening, .liveTranscript: .red
            case .capturing: .cyan
            case .thinking: .orange
            case .speaking: .purple
            case .error, .cancelled: .red
            }
        }
        return switch presentation.mode {
        case .ready: .blue
        case .recording: .red
        case .working: .orange
        case .success: .green
        case .error: .red
        }
    }

    private var accessibilityDescription: String {
        if presentation.guideStage == .liveTranscript {
            return ["SERPy is listening", presentation.contextLabel]
                .compactMap { $0 }
                .joined(separator: ". ")
        }
        let description = [presentation.caption, presentation.contextLabel]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
        return description.isEmpty ? "SERPy is ready" : description
    }
}
