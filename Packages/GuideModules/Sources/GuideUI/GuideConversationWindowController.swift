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
        window.title = "SERPy AI Guide"
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
    @FocusState private var isComposerFocused: Bool

    public init(model: GuideAppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            conversation
            Divider()
            composer
        }
        .frame(minWidth: 440, minHeight: 460)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { isComposerFocused = true }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.title2)
                .foregroundStyle(.purple)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("AI Guide")
                    .font(.title2.weight(.semibold))
                Text(model.guidanceContextLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button("New Conversation", systemImage: "square.and.pencil") {
                model.startNewGuidanceConversation()
                isComposerFocused = true
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
                            Label("Ask about your screen", systemImage: "bubble.left.and.text.bubble.right")
                        } description: {
                            Text("Ask a question, then follow up naturally. SERPy reads the app that was in front when you opened the guide.")
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
                            Spacer()
                        }
                        .id("guidance-activity")
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

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask something about the current app…", text: $model.guidanceDraft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .focused($isComposerFocused)
                    .onSubmit { send() }

                Button("Send", systemImage: "arrow.up.circle.fill") {
                    send()
                }
                .labelStyle(.iconOnly)
                .font(.title2)
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityHint("Reads the selected app window and asks the local guide")
            }
            Text("Local and private. Each message captures one window; screenshots and chat are not saved.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private var canSend: Bool {
        !model.guidanceDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !model.guidancePhase.isActive
    }

    private var activityLabel: String {
        switch model.guidancePhase {
        case .requestingPermission: "Waiting for screen permission…"
        case .capturing, .reading: "Reading the selected window…"
        case .thinking: "Thinking locally…"
        default: "Working…"
        }
    }

    private func send() {
        guard canSend else { return }
        Task {
            await model.sendGuidanceMessage()
            isComposerFocused = true
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
        .accessibilityLabel(message.role == .user ? "You" : "SERPy")
        .accessibilityValue(message.content)
    }
}
