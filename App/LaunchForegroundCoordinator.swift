import Foundation

struct LaunchForegroundSnapshot: Equatable, Sendable {
    let applicationIsActive: Bool
    let frontmostOwner: LaunchForegroundOwner
    let settingsWindowIsVisible: Bool
    let settingsWindowIsKey: Bool
    let activationPolicyIsRegular: Bool

    var isReady: Bool {
        applicationIsActive
            && frontmostOwner == .currentApplication
            && settingsWindowIsVisible
            && settingsWindowIsKey
            && activationPolicyIsRegular
    }
}

enum LaunchForegroundOwner: Equatable, Sendable {
    case currentApplication
    case external(Int32)
    case none
}

enum LaunchForegroundOutcome: Equatable, Sendable {
    case succeeded(retryAttempts: Int)
    case failed(retryAttempts: Int, failure: LaunchForegroundFailure)
    case relinquished(retryAttempts: Int, reason: LaunchForegroundRelinquishment)
}

struct LaunchForegroundFailure: Equatable, Sendable {
    let stage: String
    let cause: String
    let recovery: String

    static let retryBudgetExhausted = LaunchForegroundFailure(
        stage: "app-launch-foreground",
        cause: "serpy could not make its visible Settings window active and key after bounded retries.",
        recovery: "Open serpy from the Dock or menu bar to show Settings."
    )
}

struct LaunchForegroundRelinquishment: Equatable, Sendable {
    let stage: String
    let cause: String
    let recovery: String

    static let userChangedForegroundApplication = LaunchForegroundRelinquishment(
        stage: "app-launch-foreground",
        cause: "The frontmost application changed while serpy was recovering its launch presentation.",
        recovery: "No action is required. Open serpy from the Dock or menu bar when you want Settings."
    )
}

@MainActor
final class LaunchForegroundCoordinator {
    typealias Schedule = (Duration, @escaping @MainActor () -> Void) -> Void

    static let standardRetryDelays: [Duration] = [
        .zero,
        .milliseconds(100),
        .milliseconds(250),
        .milliseconds(500),
    ]

    private let retryDelays: [Duration]
    private let schedule: Schedule
    private let snapshot: () -> LaunchForegroundSnapshot
    private let retryActivation: () -> Void
    private let finished: (LaunchForegroundOutcome) -> Void

    private var started = false
    private var terminal = false
    private var nextRetryIndex = 0
    private var retryAttempts = 0
    private var initialForegroundOwner: LaunchForegroundOwner?
    private var hasObservedCurrentApplicationForeground = false

    init(
        retryDelays: [Duration] = standardRetryDelays,
        schedule: @escaping Schedule,
        snapshot: @escaping () -> LaunchForegroundSnapshot,
        retryActivation: @escaping () -> Void,
        finished: @escaping (LaunchForegroundOutcome) -> Void = { _ in }
    ) {
        precondition(!retryDelays.contains(where: { $0 < .zero }))
        self.retryDelays = retryDelays
        self.schedule = schedule
        self.snapshot = snapshot
        self.retryActivation = retryActivation
        self.finished = finished
    }

    func start() {
        guard !started else { return }
        started = true
        let initialSnapshot = snapshot()
        initialForegroundOwner = initialSnapshot.frontmostOwner
        observeOrScheduleRetry(using: initialSnapshot)
    }

    private func observeOrScheduleRetry(using currentSnapshot: LaunchForegroundSnapshot) {
        guard !terminal else { return }
        if shouldRelinquish(for: currentSnapshot.frontmostOwner) {
            finish(.relinquished(
                retryAttempts: retryAttempts,
                reason: .userChangedForegroundApplication
            ))
            return
        }
        if currentSnapshot.isReady {
            finish(.succeeded(retryAttempts: retryAttempts))
            return
        }
        guard nextRetryIndex < retryDelays.count else {
            finish(.failed(
                retryAttempts: retryAttempts,
                failure: .retryBudgetExhausted
            ))
            return
        }

        let delay = retryDelays[nextRetryIndex]
        nextRetryIndex += 1
        schedule(delay) { [weak self] in
            self?.performRetry()
        }
    }

    private func performRetry() {
        guard started, !terminal else { return }
        let beforeRetry = snapshot()
        if shouldRelinquish(for: beforeRetry.frontmostOwner) {
            finish(.relinquished(
                retryAttempts: retryAttempts,
                reason: .userChangedForegroundApplication
            ))
            return
        }
        if beforeRetry.isReady {
            finish(.succeeded(retryAttempts: retryAttempts))
            return
        }
        retryAttempts += 1
        retryActivation()
        observeOrScheduleRetry(using: snapshot())
    }

    private func shouldRelinquish(for owner: LaunchForegroundOwner) -> Bool {
        switch owner {
        case .currentApplication:
            hasObservedCurrentApplicationForeground = true
            return false
        case .external:
            return hasObservedCurrentApplicationForeground
                || owner != initialForegroundOwner
        case .none:
            return false
        }
    }

    private func finish(_ outcome: LaunchForegroundOutcome) {
        guard !terminal else { return }
        terminal = true
        finished(outcome)
    }
}

@MainActor
enum LaunchForegroundScheduler {
    static func schedule(after delay: Duration, action: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            if delay == .zero {
                await Task.yield()
            } else {
                try? await Task.sleep(for: delay)
            }
            guard !Task.isCancelled else { return }
            action()
        }
    }
}
