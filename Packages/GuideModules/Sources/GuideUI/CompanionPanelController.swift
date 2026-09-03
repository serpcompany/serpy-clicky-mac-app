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
        if !presentation.responseText.isEmpty {
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
        if !presentation.responseText.isEmpty {
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
            let maximumResponseHeight = responseInteractionPolicy.maximumNonOverlappingHeight(
                visibleFrame: visibleFrame,
                avoidedFrame: newFrame
            )
            let responseSizing = measuredResponseSizing(
                presentation.responseText,
                availableHeight: maximumResponseHeight
            )
            responsePanel.ignoresMouseEvents = responseSizing.interactionMode == .clickThrough
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
           let point = pointCueProjector.appKitPoint(for: cue) {
            pointCuePositionIsValid = true
            let size = NSSize(width: 56, height: 56)
            pointCuePanel.setFrame(
                NSRect(
                    x: point.x - size.width / 2,
                    y: point.y - size.height / 2,
                    width: size.width,
                    height: size.height
                ),
                display: true
            )
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

private struct GuidePointCueView: View {
    let presentation: CompanionPresentation

    var body: some View {
        ZStack {
            Circle()
                .fill(SERPyVisual.ColorToken.accent.opacity(0.18))
            Circle()
                .stroke(SERPyVisual.ColorToken.accent, lineWidth: 4)
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
                .foregroundStyle(SERPyVisual.ColorToken.primaryText)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(18)
        }
        .scrollIndicators(.automatic)
        .background(
            SERPyVisual.ColorToken.surface.opacity(0.97),
            in: RoundedRectangle(cornerRadius: SERPyVisual.Radius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: SERPyVisual.Radius.card, style: .continuous)
                .stroke(SERPyVisual.ColorToken.border, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.34), radius: 14, y: 6)
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
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.black)
                companionIndicator
            }
            .frame(width: 42, height: 42)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(color.opacity(0.6), lineWidth: 1)
            }
            .shadow(color: color.opacity(0.28), radius: 9, y: 3)

            if !presentation.caption.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text(presentation.caption)
                        .font(.callout.weight(.medium))
                        .lineLimit(presentation.guideStage == .liveTranscript ? 3 : (presentation.guideStage == nil ? 2 : nil))
                        .foregroundStyle(SERPyVisual.ColorToken.primaryText)
                    if let contextLabel = presentation.contextLabel, !contextLabel.isEmpty {
                        Text(contextLabel)
                            .font(.caption)
                            .foregroundStyle(SERPyVisual.ColorToken.secondaryText)
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
                    .fill(SERPyVisual.ColorToken.surface.opacity(0.96))
                    .overlay {
                        Capsule().stroke(SERPyVisual.ColorToken.border, lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: presentation.caption)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: presentation.mode)
    }

    @ViewBuilder
    private var companionIndicator: some View {
        if presentation.guideStage == .listening || presentation.guideStage == .liveTranscript || presentation.mode == .recording {
            SERPyWaveformIndicator(color: color)
                .frame(width: 24, height: 20)
                .accessibilityHidden(true)
        } else if presentation.guideStage == .capturing || presentation.guideStage == .thinking || presentation.mode == .working {
            ProgressView()
                .controlSize(.small)
                .tint(color)
                .accessibilityHidden(true)
        } else if presentation.guideStage == .speaking {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .symbolEffect(.variableColor.iterative, isActive: !reduceMotion)
                .accessibilityHidden(true)
        } else if presentation.guideStage == .error || presentation.guideStage == .cancelled || presentation.mode == .error {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(color)
                .accessibilityHidden(true)
        } else {
            SERPyArrowMark(color: color)
                .padding(10)
                .accessibilityHidden(true)
        }
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
            case .ready, .readyForFollowUp: SERPyVisual.ColorToken.accent
            case .listening, .liveTranscript: SERPyVisual.ColorToken.accent
            case .capturing: .cyan
            case .thinking: SERPyVisual.ColorToken.warning
            case .speaking: SERPyVisual.ColorToken.accent
            case .error, .cancelled: SERPyVisual.ColorToken.danger
            }
        }
        return switch presentation.mode {
        case .ready: SERPyVisual.ColorToken.accent
        case .recording: SERPyVisual.ColorToken.accent
        case .working: SERPyVisual.ColorToken.warning
        case .success: SERPyVisual.ColorToken.success
        case .error: SERPyVisual.ColorToken.danger
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

private struct SERPyWaveformIndicator: View {
    let color: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.5 : 1.0 / 24.0)) { context in
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(color)
                        .frame(width: 2.5, height: barHeight(index: index, date: context.date))
                }
            }
        }
    }

    private func barHeight(index: Int, date: Date) -> CGFloat {
        guard !reduceMotion else { return [7, 12, 17, 12, 7][index] }
        let phase = date.timeIntervalSinceReferenceDate * 5 + Double(index) * 0.75
        let profile: [CGFloat] = [0.5, 0.78, 1, 0.78, 0.5]
        return 5 + ((sin(phase) + 1) * 0.5) * 13 * profile[index]
    }
}
