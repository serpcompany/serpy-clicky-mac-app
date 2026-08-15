import GuideCore
import SwiftUI

public struct SettingsView: View {
    @Bindable private var model: GuideAppModel

    public init(model: GuideAppModel) {
        self.model = model
    }

    public var body: some View {
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
                    Button("Enable voice permissions") {
                        Task { await model.requestVoicePermissions() }
                    }
                    Button("Enable Accessibility") {
                        model.requestAccessibility()
                    }
                    Button("Refresh") {
                        model.refreshPermissions()
                    }
                }
            }

            Section("Companion") {
                Toggle("Keep the cursor companion visible", isOn: $model.companionEnabled)
                Text("The companion is click-through, follows the pointer, and stays below the usable menu-bar area.")
                    .foregroundStyle(.secondary)
            }

            Section("Local screen guidance") {
                LabeledContent("Shortcut", value: "Control–Option–G")
                Text("Screen access is requested only after you invoke guidance. Guide Companion reads one visible window, uses on-device intelligence, and never clicks or types for you.")
                    .foregroundStyle(.secondary)
                Button("Guide Current Screen") {
                    Task { await model.guideCurrentScreen() }
                }
                .disabled(model.guidancePhase.isActive)
            }

            Section("Privacy") {
                Text("Audio, transcripts, and screenshots are not stored. Dictation and guidance use on-device system models without an API key.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 560, minHeight: 460)
        .task {
            model.refreshPermissions()
        }
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
