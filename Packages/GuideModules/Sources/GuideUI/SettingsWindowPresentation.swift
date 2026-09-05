import Foundation

@MainActor
public struct SettingsWindowPresentation {
    private let enterRegularMode: () -> Void
    private let activateApplication: () -> Void
    private let openSettings: () -> Void
    private let scheduleAfterMenuCloses: (@escaping () -> Void) -> Void

    public init(
        enterRegularMode: @escaping () -> Void,
        activateApplication: @escaping () -> Void,
        openSettings: @escaping () -> Void,
        scheduleAfterMenuCloses: @escaping (@escaping () -> Void) -> Void
    ) {
        self.enterRegularMode = enterRegularMode
        self.activateApplication = activateApplication
        self.openSettings = openSettings
        self.scheduleAfterMenuCloses = scheduleAfterMenuCloses
    }

    public func present() {
        enterRegularMode()
        activateApplication()
        openSettings()
        scheduleAfterMenuCloses(activateApplication)
    }
}

@MainActor
public struct SettingsWindowVisibilityLifecycle {
    private let enterRegularMode: () -> Void
    private let activateApplication: () -> Void

    public init(
        enterRegularMode: @escaping () -> Void,
        activateApplication: @escaping () -> Void
    ) {
        self.enterRegularMode = enterRegularMode
        self.activateApplication = activateApplication
    }

    public func didAppear() {
        enterRegularMode()
        activateApplication()
    }
}

@MainActor
public struct SettingsWindowForegroundRecovery {
    private let enterRegularMode: () -> Void
    private let showSettings: () -> Void
    private let forceActivateApplication: () -> Void

    public init(
        enterRegularMode: @escaping () -> Void,
        showSettings: @escaping () -> Void,
        forceActivateApplication: @escaping () -> Void
    ) {
        self.enterRegularMode = enterRegularMode
        self.showSettings = showSettings
        self.forceActivateApplication = forceActivateApplication
    }

    public func recover() {
        enterRegularMode()
        showSettings()
        forceActivateApplication()
    }
}
