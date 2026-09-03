@MainActor
public protocol GlobalShortcutMonitoring: AnyObject {
    func start() throws
    func stop()
}
