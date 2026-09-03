import Foundation

@MainActor
public struct SettingsWindowPresentation {
    private let activateApplication: () -> Void
    private let openSettings: () -> Void

    public init(
        activateApplication: @escaping () -> Void,
        openSettings: @escaping () -> Void
    ) {
        self.activateApplication = activateApplication
        self.openSettings = openSettings
    }

    public func present() {
        activateApplication()
        openSettings()
    }
}
