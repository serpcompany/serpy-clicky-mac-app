import AppKit
import GuideCore
import SwiftUI

@MainActor
final class GuideConversationWindowController: NSWindowController {
    init(model: GuideAppModel) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "SERPy Voice Transcript"
        window.level = .normal
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 440, height: 460)
        window.setFrameAutosaveName("SERPyAIConversationWindow")
        window.contentView = NSHostingView(rootView: GuideConversationView(model: model))
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        guard let window else { return }
        showWindow(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

public struct GuideConversationView: View {
    @Bindable private var model: GuideAppModel

    public init(model: GuideAppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            conversation
        }
        .frame(minWidth: 440, minHeight: 460)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.title2)
                .foregroundStyle(.purple)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Voice Conversation")
                    .font(.title2.weight(.semibold))
                Text(model.guidanceContextLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button(
                model.guidancePhase == .listening ? "Finish Question" : "Talk",
                systemImage: model.guidancePhase == .listening ? "stop.circle.fill" : "waveform.and.mic"
            ) {
                model.toggleGuidanceVoice()
            }
            .disabled(model.guidancePhase.isActive && model.guidancePhase != .listening)
            if model.guidancePhase == .listening {
                Button("Cancel", role: .cancel) {
                    model.cancelGuidanceVoice()
                }
            }
            Button("New Conversation", systemImage: "square.and.pencil") {
                model.startNewGuidanceConversation()
            }
            .disabled(model.guidancePhase.isActive || model.guidanceMessages.isEmpty)
        }
        .padding(16)
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    if model.guidanceMessages.isEmpty {
                        ContentUnavailableView {
                            Label("Talk to SERPy", systemImage: "waveform.and.mic")
                        } description: {
                            Text("Hold \(model.guideShortcut.displayName) while you ask your question, then release to send. Escape cancels.")
                        }
                        .padding(.vertical, 60)
                    } else {
                        ForEach(model.guidanceMessages) { message in
                            GuidanceMessageRow(message: message)
                                .id(message.id)
                        }
                    }

                    if model.guidancePhase.isActive {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(activityLabel)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("guide.activity")
                            Spacer()
                        }
                        .id("guidance-activity")
                    } else if !model.guidancePartialTranscript.isEmpty {
                        Text("Last heard: \(model.guidancePartialTranscript)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
                .padding(18)
            }
            .onChange(of: model.guidanceMessages.last?.id) {
                guard let id = model.guidanceMessages.last?.id else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(id, anchor: .bottom)
                }
            }
        }
    }

    private var activityLabel: String {
        switch model.guidancePhase {
        case .requestingPermission: "Waiting for screen permission…"
        case .listening:
            model.guidancePartialTranscript.isEmpty
                ? "Listening to your question…"
                : "Heard: \(model.guidancePartialTranscript)"
        case .transcribing: "Finishing your local transcript…"
        case .capturing, .reading: "Reading the selected window…"
        case .thinking: model.talkThinkingStatus
        default: "Working…"
        }
    }
}

private struct GuidanceMessageRow: View {
    let message: GuidanceMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 72)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(message.role == .user ? "You" : "SERPy")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(message.content)
                    .textSelection(.enabled)
                if let contextLabel = message.contextLabel {
                    Text("Based on \(contextLabel)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(12)
            .background(
                message.role == .user ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.12),
                in: .rect(cornerRadius: 12)
            )
            if message.role == .guide {
                Spacer(minLength: 72)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(message.role == .user ? "guide.message.user" : "guide.message.guide")
        .accessibilityLabel(message.role == .user ? "You" : "SERPy")
        .accessibilityValue(message.content)
    }
}
