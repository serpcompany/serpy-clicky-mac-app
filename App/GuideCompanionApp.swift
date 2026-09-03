import AppKit
import GuideUI
import SwiftUI

@main
struct GuideCompanionApp: App {
    @NSApplicationDelegateAdaptor(GuideAppDelegate.self) private var appDelegate
    @State private var model = GuideAppModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuPanelView(model: model)
        } label: {
            Label("SERPy", systemImage: model.menuBarSymbol)
                .accessibilityLabel("SERPy, \(model.shortStatus)")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(model: model)
        }
        .defaultSize(width: 620, height: 520)
    }
}

@MainActor
final class GuideAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            await GuideAppModel.shared.start()
            if CommandLine.arguments.contains("--ui-testing"),
               CommandLine.arguments.contains("--open-guide-transcript") {
                GuideAppModel.shared.openGuidanceTranscript()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        GuideAppModel.shared.stop()
    }
}
