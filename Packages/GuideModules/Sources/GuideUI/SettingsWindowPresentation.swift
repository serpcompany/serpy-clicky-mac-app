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
    private let restoreMenuBarMode: () -> Void

    public init(
        enterRegularMode: @escaping () -> Void,
        activateApplication: @escaping () -> Void,
        restoreMenuBarMode: @escaping () -> Void
    ) {
        self.enterRegularMode = enterRegularMode
        self.activateApplication = activateApplication
        self.restoreMenuBarMode = restoreMenuBarMode
    }

    public func didAppear() {
        enterRegularMode()
        activateApplication()
    }

    public func didDisappear() {
        restoreMenuBarMode()
    }
}
