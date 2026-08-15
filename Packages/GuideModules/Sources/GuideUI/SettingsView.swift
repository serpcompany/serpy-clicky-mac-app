import GuideCore
import SwiftUI

public struct SettingsView: View {
    @Bindable private var model: GuideAppModel
    @State private var selectedTab = SettingsTab.setup

    private enum SettingsTab: Hashable {
        case setup
        case companion
        case guidance
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
            privacyForm
                .tabItem { Label("Privacy", systemImage: "hand.raised") }
                .tag(SettingsTab.privacy)
        }
        .padding()
        .frame(minWidth: 640, minHeight: 560)
        .task {
            model.refreshPermissions()
        }
    }

    private var setupForm: some View {
        Form {
            Section("Dictation") {
                LabeledContent("Shortcut", value: model.shortcutDescription)
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
            Section("Local screen guidance") {
                LabeledContent("Shortcut", value: "Control–Option–G")
                permissionRow("Screen Recording", state: model.permissions.screenRecording, permission: .screenRecording)
                Text("Screen access is requested only after you invoke guidance. Guide Companion reads one visible window, uses on-device intelligence, and never clicks or types for you.")
                    .foregroundStyle(.secondary)
                Button("Guide Current Screen") { Task { await model.guideCurrentScreen() } }
                    .disabled(model.guidancePhase.isActive)
            }
        }
        .formStyle(.grouped)
    }

    private var privacyForm: some View {
        Form {
            Section("Privacy") {
                Text("Audio, transcripts, and screenshots are not stored. Dictation and guidance use on-device system models without an API key.")
                    .foregroundStyle(.secondary)
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
