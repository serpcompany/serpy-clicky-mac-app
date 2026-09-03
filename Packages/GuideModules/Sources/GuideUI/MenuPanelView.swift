import AppKit
import GuideCore
import SwiftUI

public struct MenuPanelView: View {
    @Environment(\.openSettings) private var openSettings
    @Bindable private var model: GuideAppModel

    public init(model: GuideAppModel) {
        self.model = model
    }

    public var body: some View {
        Group {
            Section("Status") {
                Label(model.shortStatus.capitalized, systemImage: model.menuBarSymbol)
                if !model.recoveryMessage.isEmpty {
                    Text("Needs attention — open Settings")
                }
            }

            Section("Dictation · \(model.shortcutDescription)") {
                Button {
                    model.toggleDictationFromMenu()
                } label: {
                    Label(dictationActionTitle, systemImage: dictationActionSymbol)
                }
                .disabled(!canToggleDictation)

                if model.phase == .recording {
                    Button("Cancel Dictation", role: .cancel) {
                        model.cancelDictation()
                    }
                }
            }

            Section("Voice Guide · Hold \(model.guideShortcut.displayName)") {
                Button {
                    model.toggleGuidanceVoice()
                } label: {
                    Label(guideActionTitle, systemImage: guideActionSymbol)
                }
                .disabled(model.guidancePhase.isActive && model.guidancePhase != .listening)

                if model.guidancePhase == .listening {
                    Button("Cancel Voice Question", role: .cancel) {
                        model.cancelGuidanceVoice()
                    }
                }

                if !model.guidanceMessages.isEmpty {
                    Button("View Conversation Transcript") {
                        model.openGuidanceTranscript()
                    }
                }
            }

            Toggle("Show Cursor Companion", isOn: $model.companionEnabled)

            if model.hasRecoverableTranscript {
                Menu("Last Dictation") {
                    Button("Retry in 4 Seconds") {
                        model.retryLastTranscript()
                    }
                    .disabled(model.phase.isActive)
                    Button("Copy") {
                        model.copyLastTranscript()
                    }
                    Divider()
                    Button("Clear", role: .destructive) {
                        model.clearLastTranscript()
                    }
                }
            }

            Divider()

            Button {
                SettingsWindowPresentation(
                    enterRegularMode: {
                        NSApplication.shared.setActivationPolicy(.regular)
                    },
                    activateApplication: {
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    },
                    openSettings: {
                        openSettings()
                    },
                    scheduleAfterMenuCloses: { action in
                        DispatchQueue.main.async {
                            action()
                        }
                    }
                ).present()
            } label: {
                Label("Settings…", systemImage: "gear")
            }

            Button("Quit SERPy", systemImage: "power", role: .destructive) {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private var dictationActionTitle: String {
        model.phase == .recording ? "Stop & Insert Dictation" : "Start Dictation"
    }

    private var dictationActionSymbol: String {
        model.phase == .recording ? "stop.circle.fill" : "mic.fill"
    }

    private var canToggleDictation: Bool {
        model.dictationReady && (!model.phase.isActive || model.phase == .recording)
    }

    private var guideActionTitle: String {
        model.guidancePhase == .listening ? "Finish Voice Question" : "Start Voice Question"
    }

    private var guideActionSymbol: String {
        model.guidancePhase == .listening ? "stop.circle.fill" : "waveform.and.mic"
    }
}
