import AppKit
import GuideCore
import GuideMac
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
    public var pointCue: GuidePointCue?
    public var guideTarget: GuideWindowTarget?

    public init() {}
}

@MainActor
public final class CompanionPanelController {
    private let presentation: CompanionPresentation
    private let panel: CompanionPanel
    private let responsePanel: CompanionPanel
    private let pointCuePanel: CompanionPanel
    private let responseLayoutPolicy = CompanionResponseLayoutPolicy()
    private let responseAnchorPolicy = CompanionResponseAnchorPolicy()
    private let responseInteractionPolicy = CompanionResponseInteractionPolicy()
    private let responseSizingPolicy = CompanionResponseSizingPolicy()
    private let guideLayoutPolicy = GuideAmbientPanelLayoutPolicy()
    private let guideInteractionPolicy = GuideSurfaceInteractionPolicy()
    private let pointCueProjector = GuidePointCueProjector()
    private var trackingTimer: Timer?
    private var statusAnchorFrame: CGRect?
    private var responseAnchorFrame: CGRect?
    private var pointCuePositionIsValid = false

    public init(presentation: CompanionPresentation) {
        self.presentation = presentation
        panel = CompanionPanel(
            contentRect: NSRect(x: 0, y: 0, width: 46, height: 46),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        responsePanel = CompanionPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        pointCuePanel = CompanionPanel(
            contentRect: NSRect(x: 0, y: 0, width: 56, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        configurePanel()
    }

    public func show() {
        updateContentSizeAndPosition()
        panel.orderFrontRegardless()
        if presentation.guideStage == nil, !presentation.responseText.isEmpty {
            responsePanel.orderFrontRegardless()
        }
        if pointCuePositionIsValid {
            pointCuePanel.orderFrontRegardless()
        }
        startTracking()
    }

    public func hide() {
        trackingTimer?.invalidate()
        trackingTimer = nil
        panel.orderOut(nil)
        responsePanel.orderOut(nil)
        pointCuePanel.orderOut(nil)
    }

    public func refresh() {
        updateContentSizeAndPosition()
        if panel.isVisible {
            panel.orderFrontRegardless()
        }
        if presentation.guideStage == nil, !presentation.responseText.isEmpty {
            responsePanel.orderFrontRegardless()
        } else {
            responseAnchorFrame = nil
            responsePanel.orderOut(nil)
        }
        if pointCuePositionIsValid {
            pointCuePanel.orderFrontRegardless()
        } else {
            pointCuePanel.orderOut(nil)
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

        pointCuePanel.isOpaque = false
        pointCuePanel.backgroundColor = .clear
        pointCuePanel.hasShadow = false
        pointCuePanel.ignoresMouseEvents = true
        pointCuePanel.hidesOnDeactivate = false
        pointCuePanel.isReleasedWhenClosed = false
        pointCuePanel.level = .floating
        pointCuePanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        pointCuePanel.contentView = NSHostingView(rootView: GuidePointCueView(presentation: presentation))
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
        let targetPoint = presentation.guideTarget.flatMap { target in
            pointCueProjector.appKitPoint(for: GuidePointCue(
                target: target,
                normalizedPoint: CGPoint(x: 0.5, y: 0.5),
                label: "Locked window"
            ))
        }
        let screen = targetPoint.flatMap { point in NSScreen.screens.first(where: { $0.frame.contains(point) }) }
            ?? NSScreen.screens.first(where: { $0.frame.contains(pointer) })
            ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return }
        let hasCaption = !presentation.caption.isEmpty
        let isGuideVisible = presentation.guideStage != nil
        let guideSizing = isGuideVisible && hasCaption
            ? measuredGuidePanelSizing(visibleFrame: visibleFrame)
            : nil
        let size: NSSize
        if let guideSizing {
            size = guideSizing.size
        } else {
            size = hasCaption ? NSSize(width: 250, height: 58) : NSSize(width: 46, height: 46)
        }

        let proposedStatusFrame: CGRect
        if isGuideVisible {
            proposedStatusFrame = guideLayoutPolicy.frame(visibleFrame: visibleFrame, contentSize: size)
        } else {
            var origin = NSPoint(x: pointer.x + 14, y: pointer.y - size.height - 16)
            origin.x = min(max(origin.x, visibleFrame.minX + 8), visibleFrame.maxX - size.width - 8)
            origin.y = min(max(origin.y, visibleFrame.minY + 8), visibleFrame.maxY - size.height - 8)
            proposedStatusFrame = NSRect(origin: origin, size: size)
        }
        let newFrame = isGuideVisible
            ? proposedStatusFrame
            : responseAnchorPolicy.frame(
                current: statusAnchorFrame,
                proposed: proposedStatusFrame,
                responseIsVisible: false
            )
        statusAnchorFrame = isGuideVisible ? newFrame : nil
        panel.ignoresMouseEvents = !isGuideVisible
            || guideInteractionPolicy.mode == .clickThrough
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.setFrame(newFrame, display: true)
        } else {
            panel.setFrame(newFrame, display: true, animate: false)
        }

        if isGuideVisible {
            responseAnchorFrame = nil
            responsePanel.orderOut(nil)
        } else if !presentation.responseText.isEmpty {
            let maximumResponseHeight = responseInteractionPolicy.maximumNonOverlappingHeight(
                visibleFrame: visibleFrame,
                avoidedFrame: newFrame
            )
            let responseSizing = measuredResponseSizing(
                presentation.responseText,
                availableHeight: maximumResponseHeight
            )
            responsePanel.ignoresMouseEvents = guideInteractionPolicy.mode == .clickThrough
            let placementFrame = responseLayoutPolicy.frame(
                pointer: pointer,
                visibleFrame: visibleFrame,
                contentSize: CGSize(width: responseSizing.size.width, height: maximumResponseHeight),
                avoiding: newFrame
            )
            let proposedFrame = CGRect(origin: placementFrame.origin, size: responseSizing.size)
            let responseFrame = responseAnchorPolicy.frame(
                current: responseAnchorFrame,
                proposed: proposedFrame,
                responseIsVisible: responsePanel.isVisible,
                visibleFrame: visibleFrame,
                avoiding: newFrame
            )
            responseAnchorFrame = responseFrame
            responsePanel.setFrame(responseFrame, display: true)
        } else {
            statusAnchorFrame = nil
            responseAnchorFrame = nil
            responsePanel.ignoresMouseEvents = true
        }


        if let cue = presentation.pointCue,
           let cueFrame = pointCueProjector.panelFrame(
               for: cue,
               panelSize: CGSize(width: 56, height: 56),
               displays: GuidePointCueProjector.systemDisplayMappings()
           ) {
            pointCuePositionIsValid = true
            pointCuePanel.setFrame(cueFrame, display: true)
        } else {
            pointCuePositionIsValid = false
            pointCuePanel.orderOut(nil)
        }
    }

    private func measuredResponseSizing(_ text: String, availableHeight: CGFloat) -> CompanionResponseSizing {
        let panelWidth = min(600, max(300, visibleFrameWidthFallback - 16))
        let textWidth = panelWidth - 40
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        let bounds = (text as NSString).boundingRect(
            with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        let measuredHeight = ceil(bounds.height) + 48
        return responseSizingPolicy.resolve(
            width: panelWidth,
            measuredContentHeight: measuredHeight,
            maximumPanelHeight: availableHeight,
            minimumPanelHeight: 92
        )
    }

    private var visibleFrameWidthFallback: CGFloat {
        let pointer = NSEvent.mouseLocation
        return (NSScreen.screens.first(where: { $0.frame.contains(pointer) }) ?? NSScreen.main)?.visibleFrame.width ?? 600
    }

    private func measuredGuidePanelSizing(visibleFrame: CGRect) -> CompanionResponseSizing {
        let panelWidth = min(520, max(300, visibleFrame.width - 16))
        let textWidth = panelWidth - 48
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
        let answerHeight: CGFloat
        if presentation.responseText.isEmpty {
            answerHeight = 0
        } else {
            let answerFont = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            answerHeight = (presentation.responseText as NSString).boundingRect(
                with: NSSize(width: textWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: answerFont]
            ).height + 18
        }
        let measuredHeight = ceil(captionBounds.height + contextHeight + answerHeight) + 30
        return responseSizingPolicy.resolve(
            width: panelWidth,
            measuredContentHeight: measuredHeight,
            maximumPanelHeight: min(visibleFrame.height * 0.45, 420),
            minimumPanelHeight: 58
        )
    }
}

private struct GuidePointCueView: View {
    let presentation: CompanionPresentation

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.18))
            Circle()
                .stroke(Color.accentColor, lineWidth: 4)
            Circle()
                .fill(Color.white)
                .frame(width: 10, height: 10)
        }
        .padding(5)
        .shadow(color: .black.opacity(0.28), radius: 6, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("SERPy points here")
        .accessibilityValue(presentation.pointCue?.label ?? "Suggested target")
    }
}

private struct CompanionResponseView: View {
    let presentation: CompanionPresentation

    var body: some View {
        ScrollView {
            Text(presentation.responseText)
                .font(.callout.weight(.medium))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(18)
        }
        .scrollIndicators(.automatic)
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
        Group {
            if presentation.guideStage != nil {
                guideContent
            } else {
                cursorContent
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityValue(presentation.responseText.isEmpty ? (presentation.contextLabel ?? "") : presentation.responseText)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: presentation.caption)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: presentation.mode)
    }

    private var cursorContent: some View {
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
    }

    private var guideContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(color.gradient)
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(presentation.caption)
                        .font(.callout.weight(.semibold))
                        .lineLimit(presentation.guideStage == .liveTranscript ? 3 : 2)
                    if let contextLabel = presentation.contextLabel, !contextLabel.isEmpty {
                        Text(contextLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !presentation.responseText.isEmpty {
                Divider()
                ScrollView {
                    Text(presentation.responseText)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .scrollIndicators(.automatic)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.28), radius: 14, y: 6)
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
            return ["SERPy is listening", presentation.caption, presentation.contextLabel]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: ". ")
        }
        let description = [presentation.caption, presentation.contextLabel]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ". ")
        return description.isEmpty ? "SERPy is ready" : description
    }
}
