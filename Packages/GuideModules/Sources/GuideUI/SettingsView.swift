import AppKit
import GuideCore
import SwiftUI

public struct SettingsView: View {
    @Bindable private var model: GuideAppModel
    @State private var selectedTab = SettingsTab.setup

    private enum SettingsTab: Hashable {
        case setup
        case companion
        case guidance
        case history
        case privacy
    }

    public init(model: GuideAppModel) {
        self.model = model
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            setupForm
                .tabItem { Label("Setup", systemImage: "checklist") }
                .tag(SettingsTab.setup)
            companionForm
                .tabItem { Label("Companion", systemImage: "location.north.circle") }
                .tag(SettingsTab.companion)
            guidanceForm
                .tabItem { Label("Guidance", systemImage: "sparkles.rectangle.stack") }
                .tag(SettingsTab.guidance)
            historyForm
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(SettingsTab.history)
            privacyForm
                .tabItem { Label("Privacy", systemImage: "hand.raised") }
                .tag(SettingsTab.privacy)
        }
        .padding()
        .frame(minWidth: 640, minHeight: 560)
        .task {
            model.refreshPermissions()
        }
        .onAppear {
            settingsWindowLifecycle.didAppear()
        }
        .onDisappear {
            settingsWindowLifecycle.didDisappear()
        }
    }

    private var settingsWindowLifecycle: SettingsWindowVisibilityLifecycle {
        SettingsWindowVisibilityLifecycle(
            enterRegularMode: {
                NSApplication.shared.setActivationPolicy(.regular)
            },
            activateApplication: {
                NSApplication.shared.activate(ignoringOtherApps: true)
            },
            restoreMenuBarMode: {
                NSApplication.shared.setActivationPolicy(.accessory)
            }
        )
    }

    private var setupForm: some View {
        Form {
            Section("Dictation") {
                LabeledContent("Start / stop shortcut") {
                    ShortcutRecorderView(configuration: model.dictationShortcut) {
                        model.setDictationShortcut($0)
                    }
                    .frame(width: 150, height: 26)
                }
                Text("Click the shortcut to record a new one. Press it once to start listening, press it again to insert, or press Escape to cancel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LabeledContent("Speech engine", value: "Apple on-device Speech")
                LabeledContent("Readiness", value: model.dictationReady ? "Ready" : "Setup needed")
                Text("Plain dictation never calls an assistant or paid API.")
                    .foregroundStyle(.secondary)
            }

            Section("Permissions") {
                permissionRow("Microphone", state: model.permissions.microphone, permission: .microphone)
                permissionRow("Speech Recognition", state: model.permissions.speechRecognition, permission: .speechRecognition)
                permissionRow("Accessibility", state: model.permissions.accessibility, permission: .accessibility)
                permissionRow("Screen Recording", state: model.permissions.screenRecording, permission: .screenRecording)

                HStack {
                    Button("Request Microphone") { Task { await model.requestMicrophonePermission() } }
                    Button("Request Speech Recognition") { Task { await model.requestSpeechPermission() } }
                    Button("Enable Accessibility") { model.requestAccessibility() }
                    Button("Refresh") { model.refreshPermissions() }
                }
                Text("macOS prompts only once. If a request was denied, use Open Settings on its row.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Dictation diagnostics") {
                LabeledContent("Shortcut registration", value: model.hotKeyRegistered ? "Registered" : "Unavailable")
                LabeledContent("Attempts", value: "\(model.dictationAttemptCount)")
                LabeledContent("Last activation", value: model.lastActivationMessage)
                LabeledContent("Last stage", value: model.lastDictationStage)
                LabeledContent("Last failure", value: model.lastFailureMessage)
                if model.phase == .recording {
                    Button("Stop & Insert Manual Test") {
                        model.finishManualDictationTest()
                    }
                    .buttonStyle(.borderedProminent)
                } else if !model.phase.isActive {
                    Button("Start Manual Dictation Test") {
                        model.beginManualDictationTest()
                    }
                    Text("After clicking, select the destination text field within 4 seconds. Speak, then return here and click Stop & Insert.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Test Text Insertion Only") {
                        model.beginInsertionTest()
                    }
                    Text("Inserts a fixed harmless phrase after 4 seconds. This tests Accessibility without using the microphone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(model.statusMessage)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                if !model.recoveryMessage.isEmpty {
                    Text(model.recoveryMessage)
                        .foregroundStyle(.orange)
                        .textSelection(.enabled)
                }
            }

            if model.hasRecoverableTranscript {
                Section("Last dictation recovery") {
                    Text(model.recoverableTranscript)
                        .lineLimit(4)
                        .textSelection(.enabled)
                    HStack {
                        Button("Retry in 4 Seconds") { model.retryLastTranscript() }
                            .disabled(model.phase.isActive)
                        Button("Copy") { model.copyLastTranscript() }
                        Button("Clear", role: .destructive) { model.clearLastTranscript() }
                    }
                    Text("Saved locally before delivery and retained according to History settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var companionForm: some View {
        Form {
            Section("Cursor companion") {
                Toggle("Keep the cursor companion visible", isOn: $model.companionEnabled)
                Text("The companion is click-through, follows the pointer, and stays below the usable menu-bar area.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var guidanceForm: some View {
        Form {
            Section("Talk provider") {
                Picker("Screen guidance", selection: $model.talkProviderSelection) {
                    ForEach(TalkProviderSelection.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)

                if model.talkProviderSelection == .openAI {
                    Text("OpenAI Talk sends only the current spoken question, a bounded recent Talk transcript, and screenshot pixels of the exact window locked when this turn starts. SERPy requests store:false. OpenAI processes the request under your API account and normal API charges may apply.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Toggle(
                        "I accept this request-scoped transmission on this Mac",
                        isOn: $model.talkDisclosureAccepted
                    )

                    SecureField("OpenAI API key", text: $model.talkCredentialDraft)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Save to Keychain") { model.saveTalkCredential() }
                            .disabled(
                                model.talkCredentialDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    || model.talkCredentialVerification == .verifying
                            )
                        Button("Verify Provider") { Task { await model.testSavedTalkCredential() } }
                            .disabled(!model.talkCredentialAvailable || model.talkCredentialVerification == .verifying)
                        Button("Delete Key", role: .destructive) { model.deleteTalkCredential() }
                            .disabled(!model.talkCredentialAvailable || model.talkCredentialVerification == .verifying)
                    }
                    Text(model.talkCredentialStatus)
                        .font(.caption)
                        .foregroundStyle(model.openAITalkReady ? .green : .secondary)
                        .textSelection(.enabled)
                    Text("Verify Provider makes a credential-only OpenAI model lookup. It sends no screenshot, question, or Talk context and creates no model response. Verification expires after 15 minutes. SERPy never silently switches providers.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("On-device Talk sends nothing to OpenAI. Its screen reasoning is limited to OCR text and the local Apple model.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("Plain dictation is always on-device and does not use this setting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Voice guide") {
                LabeledContent("Shortcut", value: "Control–Option–G")
                permissionRow("Screen Recording", state: model.permissions.screenRecording, permission: .screenRecording)
                Text("Press the shortcut, ask about the app on screen out loud, then press it again. SERPy reads the exact window locked at the start of the turn, streams the answer through the cursor companion when supported, and speaks it.")
                    .foregroundStyle(.secondary)
                Button(model.guidancePhase == .listening ? "Finish Voice Question" : "Start Voice Question") {
                    model.toggleGuidanceVoice()
                }
                .disabled(model.guidancePhase.isActive && model.guidancePhase != .listening)
                if model.guidancePhase == .listening {
                    Button("Cancel Voice Question", role: .cancel) {
                        model.cancelGuidanceVoice()
                    }
                }
                if !model.guidanceMessages.isEmpty {
                    Button("View Conversation Transcript") { model.openGuidanceTranscript() }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var privacyForm: some View {
        Form {
            Section("Privacy") {
                Text("Dictation always uses on-device system models without an API key. On-device Talk also remains local. OpenAI Talk is a separate opt-in: when selected, disclosed, and credentialed, one request sends the current question, bounded recent Talk text, and the exact locked-window screenshot. Guide screenshots, questions, and answers are not written to disk by SERPy.")
                    .foregroundStyle(.secondary)
            }
            Section("Storage location") {
                Text("~/Library/Application Support/SERPy/History")
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                Text("History files are excluded from backup and written with owner-only permissions.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var historyForm: some View {
        Form {
            Section("Local recovery") {
                Toggle("Save transcript history locally", isOn: $model.historyEnabled)
                Text("Off by default. When enabled, up to 25 transcripts are kept for 30 days. Without it, only the newest Last Dictation is kept: 10 minutes after confirmed delivery or 24 hours when delivery is unconfirmed or failed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Save dictation audio with history", isOn: $model.saveAudioHistory)
                    .disabled(!model.historyEnabled)
                Text("Off by default. When enabled, audio is local, follows the same retention limit, and is deleted with its transcript.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(model.historyStatusMessage)
                    .foregroundStyle(.secondary)
            }

            Section(model.historyEnabled ? "Saved dictations" : "Last Dictation recovery") {
                if model.transcriptHistory.isEmpty {
                    Text("No saved dictations yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.transcriptHistory) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(entry.createdAt, style: .date)
                                Text(entry.createdAt, style: .time)
                                Spacer()
                                Text(entry.deliveryState.rawValue.capitalized)
                                    .foregroundStyle(entry.deliveryState == .confirmed ? .green : .orange)
                            }
                            .font(.caption)
                            Text(entry.text)
                                .lineLimit(3)
                                .textSelection(.enabled)
                            HStack {
                                Button("Copy") { model.copyHistoryEntry(entry) }
                                Button("Retry in 4 Seconds") { model.retryHistoryEntry(entry) }
                                    .disabled(model.phase.isActive)
                                Spacer()
                                Button("Delete", role: .destructive) {
                                    model.deleteHistoryEntry(id: entry.id)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section {
                Button("Clear Transcript and Audio History", role: .destructive) {
                    model.clearTranscriptHistory()
                }
                .disabled(model.transcriptHistory.isEmpty)
            }
        }
        .formStyle(.grouped)
    }

    @ViewBuilder
    private func permissionRow(
        _ title: String,
        state: PermissionState,
        permission: GuidePermission
    ) -> some View {
        HStack {
            Label(title, systemImage: state.isGranted ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(state.isGranted ? .green : .orange)
            Spacer()
            Text(state.displayName)
                .foregroundStyle(.secondary)
            Button("Open Settings") {
                model.openSettings(for: permission)
            }
        }
        .accessibilityElement(children: .contain)
    }
}
