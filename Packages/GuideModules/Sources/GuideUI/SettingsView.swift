import AppKit
import GuideCore
import SwiftUI

enum SERPySettingsRoute: String, CaseIterable, Hashable {
    case setup
    case guidance
    case companion
    case history
    case privacy

    var title: String {
        switch self {
        case .setup: "Dictation & permissions"
        case .guidance: "Voice guide"
        case .companion: "Cursor companion"
        case .history: "Local recovery"
        case .privacy: "Privacy"
        }
    }

    var summary: String {
        switch self {
        case .setup: "Shortcut, microphone, speech, and insertion"
        case .guidance: "Screen-aware Talk provider and voice controls"
        case .companion: "Buddy visibility and ambient behavior"
        case .history: "Recover transcripts and optional local audio"
        case .privacy: "What stays local and what can leave this Mac"
        }
    }

    var symbol: String {
        switch self {
        case .setup: "waveform.and.mic"
        case .guidance: "sparkles"
        case .companion: "location.north.circle.fill"
        case .history: "clock.arrow.circlepath"
        case .privacy: "hand.raised.fill"
        }
    }
}

public struct SettingsView: View {
    @Bindable private var model: GuideAppModel
    @State private var selectedRoute: SERPySettingsRoute?

    public init(model: GuideAppModel) {
        self.model = model
    }

    public var body: some View {
        ZStack {
            SERPyVisual.ColorToken.canvas.ignoresSafeArea()
            VStack(spacing: 0) {
                topRail
                Divider().overlay(SERPyVisual.ColorToken.border)
                if let selectedRoute {
                    detailPage(selectedRoute)
                } else {
                    homePage
                }
            }
        }
        .foregroundStyle(SERPyVisual.ColorToken.primaryText)
        .tint(SERPyVisual.ColorToken.accent)
        .frame(minWidth: 680, idealWidth: 720, minHeight: 620, idealHeight: 700)
        .preferredColorScheme(.dark)
        .task { model.refreshPermissions() }
        .onAppear { settingsWindowLifecycle.didAppear() }
        .onDisappear { settingsWindowLifecycle.didDisappear() }
    }

    private var topRail: some View {
        HStack(spacing: SERPyVisual.Space.small) {
            railButton("Home", symbol: "house.fill", identifier: "settings-home") {
                selectedRoute = nil
            }
            railButton("Guide", symbol: "sparkles", identifier: "settings-guide") {
                selectedRoute = .guidance
            }
            Spacer()
            providerBadge
            Button {
                selectedRoute = .setup
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(SERPyHoverButtonStyle())
            .accessibilityLabel("Setup")
        }
        .padding(.horizontal, SERPyVisual.Space.large)
        .padding(.vertical, SERPyVisual.Space.small)
        .background(SERPyVisual.ColorToken.canvas.opacity(0.98))
    }

    private func railButton(
        _ title: String,
        symbol: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
        }
        .buttonStyle(SERPyHoverButtonStyle())
        .accessibilityIdentifier(identifier)
    }

    private var providerBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(model.talkProviderSelection == .openAI && !model.openAITalkReady
                    ? SERPyVisual.ColorToken.warning
                    : SERPyVisual.ColorToken.success)
                .frame(width: 7, height: 7)
            Text(model.talkProviderSelection == .openAI ? "OpenAI Talk" : "On-device")
                .font(.caption.weight(.medium))
        }
        .foregroundStyle(SERPyVisual.ColorToken.secondaryText)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(SERPyVisual.ColorToken.raised, in: Capsule())
        .accessibilityElement(children: .combine)
    }

    private var homePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SERPyVisual.Space.section) {
                heroCard
                settingsGroup("VOICE & INPUT", routes: [.setup, .guidance])
                settingsGroup("COMPANION", routes: [.companion])
                settingsGroup("DATA & PRIVACY", routes: [.history, .privacy])
                Text("SERPy 0.1.0 · Private internal build")
                    .font(.caption2)
                    .foregroundStyle(SERPyVisual.ColorToken.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 8)
            }
            .padding(SERPyVisual.Space.large)
        }
        .scrollIndicators(.automatic)
        .accessibilityIdentifier("settings-home-page")
    }

    private var heroCard: some View {
        SERPyCard {
            HStack(alignment: .center, spacing: SERPyVisual.Space.large) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.black)
                    SERPyArrowMark().padding(15)
                }
                .frame(width: 68, height: 68)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("SERPy")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("Private voice-first computer guide")
                        .font(.callout)
                        .foregroundStyle(SERPyVisual.ColorToken.secondaryText)
                    Label(
                        model.dictationReady ? "Ready to listen" : "Setup needs attention",
                        systemImage: model.dictationReady ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(model.dictationReady
                        ? SERPyVisual.ColorToken.success
                        : SERPyVisual.ColorToken.warning)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    shortcutLabel("DICTATE", value: model.shortcutDescription)
                    shortcutLabel("TALK", value: "⌃⌥G")
                }
            }
            .padding(SERPyVisual.Space.large)
        }
    }

    private func shortcutLabel(_ title: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(SERPyVisual.ColorToken.tertiaryText)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
        }
    }

    private func settingsGroup(_ title: String, routes: [SERPySettingsRoute]) -> some View {
        VStack(alignment: .leading, spacing: SERPyVisual.Space.small) {
            SERPySectionTitle(title: title)
            SERPyCard {
                ForEach(Array(routes.enumerated()), id: \.element) { index, route in
                    settingsNavigationRow(route)
                    if index < routes.count - 1 {
                        Divider().overlay(SERPyVisual.ColorToken.border).padding(.leading, 58)
                    }
                }
            }
        }
    }

    private func settingsNavigationRow(_ route: SERPySettingsRoute) -> some View {
        Button {
            selectedRoute = route
        } label: {
            HStack(spacing: 13) {
                Image(systemName: route.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(SERPyVisual.ColorToken.accent)
                    .frame(width: 32, height: 32)
                    .background(SERPyVisual.ColorToken.accentSoft, in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(route.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(SERPyVisual.ColorToken.primaryText)
                    Text(route.summary)
                        .font(.caption)
                        .foregroundStyle(SERPyVisual.ColorToken.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SERPyVisual.ColorToken.tertiaryText)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
        }
        .buttonStyle(SERPyHoverButtonStyle())
        .accessibilityIdentifier("settings-route-\(route.rawValue)")
    }

    @ViewBuilder
    private func detailPage(_ route: SERPySettingsRoute) -> some View {
        VStack(spacing: 0) {
            detailHeader(route)
            ScrollView {
                Group {
                    switch route {
                    case .setup: setupContent
                    case .guidance: guidanceContent
                    case .companion: companionContent
                    case .history: historyContent
                    case .privacy: privacyContent
                    }
                }
                .padding(SERPyVisual.Space.large)
            }
            .scrollIndicators(.automatic)
        }
        .accessibilityIdentifier("settings-detail-\(route.rawValue)")
    }

    private func detailHeader(_ route: SERPySettingsRoute) -> some View {
        HStack(spacing: 12) {
            Button {
                selectedRoute = nil
            } label: {
                Image(systemName: "chevron.left").frame(width: 30, height: 30)
            }
            .buttonStyle(SERPyHoverButtonStyle())
            .accessibilityLabel("Back to Settings Home")
            VStack(alignment: .leading, spacing: 2) {
                Text(route.title).font(.title2.weight(.bold))
                Text(route.summary)
                    .font(.caption)
                    .foregroundStyle(SERPyVisual.ColorToken.secondaryText)
            }
            Spacer()
        }
        .padding(.horizontal, SERPyVisual.Space.large)
        .padding(.vertical, SERPyVisual.Space.regular)
        .background(SERPyVisual.ColorToken.canvas)
    }

    private var setupContent: some View {
        VStack(alignment: .leading, spacing: SERPyVisual.Space.section) {
            cardSection("DICTATION") {
                labeledRow("Start / stop shortcut") {
                    ShortcutRecorderView(configuration: model.dictationShortcut) {
                        model.setDictationShortcut($0)
                    }
                    .frame(width: 150, height: 26)
                }
                divider
                labeledRow("Speech engine") { Text("Apple on-device Speech") }
                divider
                labeledRow("Readiness") {
                    statusText(model.dictationReady ? "Ready" : "Setup needed", ready: model.dictationReady)
                }
                Text("Press once to start, again to insert, or Escape to cancel. Dictation never calls an assistant or paid API.")
                    .detailNote()
                    .padding(14)
            }
            cardSection("PERMISSIONS") {
                permissionRow("Microphone", state: model.permissions.microphone, permission: .microphone)
                divider
                permissionRow("Speech Recognition", state: model.permissions.speechRecognition, permission: .speechRecognition)
                divider
                permissionRow("Accessibility", state: model.permissions.accessibility, permission: .accessibility)
                divider
                permissionRow("Screen Recording", state: model.permissions.screenRecording, permission: .screenRecording)
                divider
                HStack {
                    Button("Request Microphone") { Task { await model.requestMicrophonePermission() } }
                    Button("Request Speech") { Task { await model.requestSpeechPermission() } }
                    Button("Enable Accessibility") { model.requestAccessibility() }
                    Spacer()
                    Button("Refresh") { model.refreshPermissions() }
                }
                .padding(14)
            }
            cardSection("DIAGNOSTICS") {
                diagnosticRow("Shortcut", model.hotKeyRegistered ? "Registered" : "Unavailable")
                divider
                diagnosticRow("Last activation", model.lastActivationMessage)
                divider
                diagnosticRow("Last stage", model.lastDictationStage)
                divider
                diagnosticRow("Last failure", model.lastFailureMessage)
                divider
                HStack {
                    if model.phase == .recording {
                        Button("Stop & Insert") { model.finishManualDictationTest() }
                            .buttonStyle(.borderedProminent)
                    } else if !model.phase.isActive {
                        Button("Manual dictation test") { model.beginManualDictationTest() }
                        Button("Test text insertion") { model.beginInsertionTest() }
                    }
                    Spacer()
                }
                .padding(14)
                if !model.recoveryMessage.isEmpty {
                    Text(model.recoveryMessage)
                        .detailNote(color: SERPyVisual.ColorToken.warning)
                        .padding([.horizontal, .bottom], 14)
                        .textSelection(.enabled)
                }
            }
            if model.hasRecoverableTranscript {
                cardSection("LAST DICTATION") {
                    Text(model.recoverableTranscript)
                        .lineLimit(5)
                        .textSelection(.enabled)
                        .padding(14)
                    divider
                    HStack {
                        Button("Retry in 4 Seconds") { model.retryLastTranscript() }
                            .disabled(model.phase.isActive)
                        Button("Copy") { model.copyLastTranscript() }
                        Spacer()
                        Button("Clear", role: .destructive) { model.clearLastTranscript() }
                    }
                    .padding(14)
                }
            }
        }
    }

    private var guidanceContent: some View {
        VStack(alignment: .leading, spacing: SERPyVisual.Space.section) {
            cardSection("TALK PROVIDER") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Screen guidance", selection: $model.talkProviderSelection) {
                        ForEach(TalkProviderSelection.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                    if model.talkProviderSelection == .openAI {
                        Text("Sends the current spoken question, bounded recent Talk context, and pixels from the exact locked window. Normal API charges may apply.")
                            .detailNote()
                        Toggle("Allow request-scoped transmission on this Mac", isOn: $model.talkDisclosureAccepted)
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
                            Spacer()
                            Button("Delete Key", role: .destructive) { model.deleteTalkCredential() }
                                .disabled(!model.talkCredentialAvailable || model.talkCredentialVerification == .verifying)
                        }
                        Text(model.talkCredentialStatus)
                            .detailNote(color: model.openAITalkReady
                                ? SERPyVisual.ColorToken.success
                                : SERPyVisual.ColorToken.secondaryText)
                            .textSelection(.enabled)
                    } else {
                        Text("Private and on-device. Screen reasoning is limited to OCR text and the local Apple model.")
                            .detailNote()
                    }
                }
                .padding(14)
            }
            cardSection("VOICE GUIDE") {
                labeledRow("Shortcut") {
                    Text("⌃⌥G").font(.system(.body, design: .rounded, weight: .semibold))
                }
                divider
                permissionRow("Screen Recording", state: model.permissions.screenRecording, permission: .screenRecording)
                divider
                VStack(alignment: .leading, spacing: 10) {
                    Text("Ask about the app on screen out loud. SERPy locks that exact window, streams its answer beside the cursor, and speaks it.")
                        .detailNote()
                    HStack {
                        Button(model.guidancePhase == .listening ? "Finish Voice Question" : "Start Voice Question") {
                            model.toggleGuidanceVoice()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.guidancePhase.isActive && model.guidancePhase != .listening)
                        if model.guidancePhase == .listening {
                            Button("Cancel", role: .cancel) { model.cancelGuidanceVoice() }
                        }
                        if !model.guidanceMessages.isEmpty {
                            Button("View Transcript") { model.openGuidanceTranscript() }
                        }
                    }
                }
                .padding(14)
            }
        }
    }

    private var companionContent: some View {
        VStack(alignment: .leading, spacing: SERPyVisual.Space.section) {
            cardSection("CURSOR COMPANION") {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.black)
                        SERPyArrowMark().padding(10)
                    }
                    .frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Keep SERPy beside the pointer").font(.headline)
                        Text("Talk always shows the companion temporarily, even when this is off.")
                            .detailNote()
                    }
                    Spacer()
                    Toggle("", isOn: $model.companionEnabled).labelsHidden()
                }
                .padding(14)
            }
        }
    }

    private var privacyContent: some View {
        VStack(alignment: .leading, spacing: SERPyVisual.Space.section) {
            cardSection("PRIVACY MODEL") {
                privacyRow("Dictation", "Always on-device; no API key or assistant dependency.", symbol: "lock.fill")
                divider
                privacyRow("On-device Talk", "Uses local OCR and Apple models; sends nothing to OpenAI.", symbol: "cpu")
                divider
                privacyRow("OpenAI Talk", "Opt-in only; exact-window pixels and bounded Talk context are sent for one request.", symbol: "network")
                divider
                privacyRow("Guide history", "Questions, screenshots, and guide answers are not written to disk by SERPy.", symbol: "internaldrive")
            }
            cardSection("LOCAL STORAGE") {
                Text("~/Library/Application Support/SERPy/History")
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(14)
                divider
                Text("History files use owner-only permissions and are excluded from backup.")
                    .detailNote()
                    .padding(14)
            }
        }
    }

    private var historyContent: some View {
        VStack(alignment: .leading, spacing: SERPyVisual.Space.section) {
            cardSection("LOCAL RECOVERY") {
                Toggle("Save transcript history locally", isOn: $model.historyEnabled).padding(14)
                divider
                Toggle("Save dictation audio with history", isOn: $model.saveAudioHistory)
                    .disabled(!model.historyEnabled)
                    .padding(14)
                divider
                Text(model.historyStatusMessage).detailNote().padding(14)
            }
            cardSection(model.historyEnabled ? "SAVED DICTATIONS" : "LAST DICTATION") {
                if model.transcriptHistory.isEmpty {
                    ContentUnavailableView(
                        "No saved dictations",
                        systemImage: "waveform.badge.magnifyingglass",
                        description: Text("Finished dictations will appear here according to your recovery settings.")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    ForEach(Array(model.transcriptHistory.enumerated()), id: \.element.id) { index, entry in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(entry.createdAt, style: .date)
                                Text(entry.createdAt, style: .time)
                                Spacer()
                                statusText(entry.deliveryState.rawValue.capitalized, ready: entry.deliveryState == .confirmed)
                            }
                            .font(.caption)
                            Text(entry.text).lineLimit(4).textSelection(.enabled)
                            HStack {
                                Button("Copy") { model.copyHistoryEntry(entry) }
                                Button("Retry") { model.retryHistoryEntry(entry) }.disabled(model.phase.isActive)
                                Spacer()
                                Button("Delete", role: .destructive) { model.deleteHistoryEntry(id: entry.id) }
                            }
                        }
                        .padding(14)
                        if index < model.transcriptHistory.count - 1 { divider }
                    }
                }
            }
            Button("Clear Transcript and Audio History", role: .destructive) {
                model.clearTranscriptHistory()
            }
            .disabled(model.transcriptHistory.isEmpty)
        }
    }

    private func cardSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: SERPyVisual.Space.small) {
            SERPySectionTitle(title: title)
            SERPyCard { content() }
        }
    }

    private func labeledRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Text(title).font(.callout.weight(.medium))
            Spacer()
            content().foregroundStyle(SERPyVisual.ColorToken.secondaryText)
        }
        .padding(14)
    }

    private func diagnosticRow(_ title: String, _ value: String) -> some View {
        labeledRow(title) { Text(value).lineLimit(1).textSelection(.enabled) }
    }

    private func privacyRow(_ title: String, _ detail: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(SERPyVisual.ColorToken.accent)
                .frame(width: 28, height: 28)
                .background(SERPyVisual.ColorToken.accentSoft, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.callout.weight(.semibold))
                Text(detail).detailNote()
            }
            Spacer()
        }
        .padding(14)
    }

    @ViewBuilder
    private func permissionRow(
        _ title: String,
        state: PermissionState,
        permission: GuidePermission
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: state.isGranted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(state.isGranted
                    ? SERPyVisual.ColorToken.success
                    : SERPyVisual.ColorToken.warning)
            Text(title).font(.callout.weight(.medium))
            Spacer()
            Text(state.displayName)
                .font(.caption)
                .foregroundStyle(SERPyVisual.ColorToken.secondaryText)
            Button("Open Settings") { model.openSettings(for: permission) }
        }
        .padding(14)
        .accessibilityElement(children: .contain)
    }

    private func statusText(_ text: String, ready: Bool) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(ready ? SERPyVisual.ColorToken.success : SERPyVisual.ColorToken.warning)
    }

    private var divider: some View {
        Divider().overlay(SERPyVisual.ColorToken.border)
    }

    private var settingsWindowLifecycle: SettingsWindowVisibilityLifecycle {
        SettingsWindowVisibilityLifecycle(
            enterRegularMode: { NSApplication.shared.setActivationPolicy(.regular) },
            activateApplication: { NSApplication.shared.activate(ignoringOtherApps: true) },
            restoreMenuBarMode: { NSApplication.shared.setActivationPolicy(.accessory) }
        )
    }
}

private extension Text {
    func detailNote(color: Color = SERPyVisual.ColorToken.secondaryText) -> some View {
        font(.caption)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}
