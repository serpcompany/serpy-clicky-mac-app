import AppKit
import GuideCore
import SwiftUI

public struct MenuPanelView: View {
    @Bindable private var model: GuideAppModel

    public init(model: GuideAppModel) {
        self.model = model
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            statusCard

            if !model.dictationReady {
                setupCard
            } else {
                readyCard
            }

            if model.hasRecoverableTranscript {
                recoveryCard
            }

            Toggle("Show cursor companion", isOn: $model.companionEnabled)
                .toggleStyle(.switch)

            guidanceCard

            Divider()

            HStack {
                SettingsLink {
                    Label("Settings", systemImage: "gear")
                }
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
        .padding(18)
        .frame(width: 360)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.north.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Guide Companion")
                    .font(.title2.weight(.semibold))
                Text("Private local dictation")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(model.shortStatus.capitalized, systemImage: model.menuBarSymbol)
                .font(.headline)
            Text(model.statusMessage)
                .font(.body)
            if !model.partialTranscript.isEmpty {
                Text(model.partialTranscript)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            if !model.recoveryMessage.isEmpty {
                Text(model.recoveryMessage)
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
            if model.phase.isActive {
                Button("Cancel", role: .cancel) {
                    model.cancelDictation()
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Finish dictation setup")
                .font(.headline)
            Text("Permissions are requested only when you choose an action. Screen access is not required for dictation.")
                .font(.callout)
                .foregroundStyle(.secondary)

            permissionRow(
                title: "Microphone and Speech",
                granted: model.permissions.microphone.isGranted && model.permissions.speechRecognition.isGranted,
                actionTitle: "Enable"
            ) {
                Task { await model.requestVoicePermissions() }
            }

            permissionRow(
                title: "Accessibility insertion",
                granted: model.permissions.accessibility.isGranted,
                actionTitle: "Enable"
            ) {
                model.requestAccessibility()
            }

            HStack {
                Button("Refresh status") {
                    model.refreshPermissions()
                }
                Spacer()
                Text(model.speechAvailability)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.quaternary, in: .rect(cornerRadius: 12))
    }

    private var readyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Hold to dictate")
                .font(.headline)
            Text(model.shortcutDescription)
                .font(.title3.monospaced().weight(.semibold))
            Text("Focus any text field, hold the shortcut, speak normally, then release. Guide Companion inserts the local transcript without sending it.")
                .font(.callout)
                .foregroundStyle(.secondary)

            Divider()

            Label(
                model.hotKeyRegistered ? "Global shortcut registered" : "Global shortcut unavailable",
                systemImage: model.hotKeyRegistered ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
            )
            .font(.callout)
            .foregroundStyle(model.hotKeyRegistered ? .green : .orange)

            Text("Last stage: \(model.lastDictationStage)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(model.lastActivationMessage)
                .font(.caption)
                .foregroundStyle(.secondary)

            if model.phase == .recording {
                Button("Stop & Insert") {
                    model.finishManualDictationTest()
                }
                .buttonStyle(.borderedProminent)
            } else if !model.phase.isActive {
                Button("Manual dictation test") {
                    model.beginManualDictationTest()
                }
                Text("Starts after 4 seconds so you can click the destination field. Reopen this menu to stop and insert.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.blue.opacity(0.10), in: .rect(cornerRadius: 12))
    }

    private var guidanceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Guide current screen")
                .font(.headline)
            TextField("What should I do next?", text: $model.guidanceQuestion)
                .textFieldStyle(.roundedBorder)
            Button {
                Task { await model.guideCurrentScreen() }
            } label: {
                Label(model.guidancePhase.isActive ? "Reading screen…" : "Guide Current Screen", systemImage: "sparkles.rectangle.stack")
            }
            .disabled(model.guidancePhase.isActive)
            Text("Control–Option–G · Captures one window only after you ask. No clicks or automatic actions.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !model.guidanceAnswer.isEmpty {
                Text(model.guidanceAnswer)
                    .font(.callout)
                    .textSelection(.enabled)
            }
        }
        .padding(14)
        .background(.purple.opacity(0.10), in: .rect(cornerRadius: 12))
    }

    private var recoveryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Last dictation", systemImage: "arrow.counterclockwise.circle")
                .font(.headline)
            Text(model.recoverableTranscript)
                .font(.callout)
                .lineLimit(3)
                .textSelection(.enabled)
            Text("Kept only in memory until you clear it or quit. Retry gives you 4 seconds to focus a destination field.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Retry") { model.retryLastTranscript() }
                    .disabled(model.phase.isActive)
                Button("Copy") { model.copyLastTranscript() }
                Spacer()
                Button("Clear", role: .destructive) { model.clearLastTranscript() }
            }
        }
        .padding(14)
        .background(.orange.opacity(0.10), in: .rect(cornerRadius: 12))
    }

    private func permissionRow(
        title: String,
        granted: Bool,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Label(title, systemImage: granted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(granted ? .green : .primary)
            Spacer()
            if !granted {
                Button(actionTitle, action: action)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
