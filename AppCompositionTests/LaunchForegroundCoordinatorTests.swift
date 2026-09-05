import Foundation
import Testing
import XCTest

@MainActor
@Suite("Launch foreground coordination")
struct LaunchForegroundCoordinatorOwnerTests {
    @Test func alreadyForegroundLaunchFinishesWithoutSchedulingARetry() {
        let fixture = LaunchForegroundOwnerFixture(snapshots: [.ready])

        fixture.coordinator.start()

        #expect(fixture.recoveryAttempts == 0)
        #expect(fixture.scheduler.scheduledDelays.isEmpty)
        #expect(fixture.outcomes == [.succeeded(retryAttempts: 0)])
    }

    @Test func ownerChangeBeforeFirstCallbackRelinquishesWithoutRetrying() throws {
        let fixture = LaunchForegroundOwnerFixture(snapshots: [
            .background(owner: .external(101)),
            .background(owner: .external(202)),
        ])

        fixture.coordinator.start()
        let lateCallback = try fixture.scheduler.takeNext()
        lateCallback()

        #expect(fixture.recoveryAttempts == 0)
        #expect(fixture.outcomes == [.relinquished(
            retryAttempts: 0,
            reason: LaunchForegroundRelinquishment(
                stage: "app-launch-foreground",
                cause: "The frontmost application changed while serpy was recovering its launch presentation.",
                recovery: "No action is required. Open serpy from the Dock or menu bar when you want Settings."
            )
        )])
    }

    @Test func ownerChangeAfterOneRetryRelinquishesWithoutSchedulingASecondRetry() throws {
        let fixture = LaunchForegroundOwnerFixture(snapshots: [
            .background(owner: .external(101)),
            .background(owner: .external(101)),
            .background(owner: .external(202)),
        ])

        fixture.coordinator.start()
        try fixture.scheduler.runNext()

        #expect(fixture.recoveryAttempts == 1)
        #expect(fixture.scheduler.scheduledDelays == [.zero])
        #expect(fixture.outcomes == [.relinquished(
            retryAttempts: 1,
            reason: .userChangedForegroundApplication
        )])
    }

    @Test func returningToInitialOwnerAfterProductWasFrontmostRelinquishesWithoutAnotherRetry() throws {
        let fixture = LaunchForegroundOwnerFixture(snapshots: [
            .background(owner: .external(101)),
            .background(owner: .external(101)),
            .currentApplicationNotReady,
            .background(owner: .external(101)),
        ])

        fixture.coordinator.start()
        try fixture.scheduler.runNext()
        try fixture.scheduler.runNext()

        #expect(fixture.snapshotReads == 4)
        #expect(fixture.recoveryAttempts == 1)
        #expect(fixture.scheduler.scheduledDelays == [.zero, .milliseconds(100)])
        #expect(fixture.outcomes == [.relinquished(
            retryAttempts: 1,
            reason: .userChangedForegroundApplication
        )])
    }

    @Test func unchangedExternalOwnerAllowsTheEntireBoundedRetrySchedule() throws {
        let sameOwner = LaunchForegroundSnapshot.background(owner: .external(101))
        let fixture = LaunchForegroundOwnerFixture(
            snapshots: Array(repeating: sameOwner, count: 9)
        )

        fixture.coordinator.start()
        try fixture.scheduler.runAll()

        #expect(fixture.recoveryAttempts == 4)
        #expect(fixture.scheduler.scheduledDelays == [
            .zero,
            .milliseconds(100),
            .milliseconds(250),
            .milliseconds(500),
        ])
        #expect(fixture.outcomes == [.failed(
            retryAttempts: 4,
            failure: LaunchForegroundFailure(
                stage: "app-launch-foreground",
                cause: "serpy could not make its visible Settings window active and key after bounded retries.",
                recovery: "Open serpy from the Dock or menu bar to show Settings."
            )
        )])
    }

    @Test func twoDroppedRetriesCanStillFinishWhenTheProductBecomesForeground() throws {
        let fixture = LaunchForegroundOwnerFixture(snapshots: [
            .background(owner: .external(101)),
            .background(owner: .external(101)),
            .background(owner: .external(101)),
            .background(owner: .external(101)),
            .ready,
        ])

        fixture.coordinator.start()
        try fixture.scheduler.runNext()
        try fixture.scheduler.runNext()

        #expect(fixture.recoveryAttempts == 2)
        #expect(fixture.scheduler.scheduledDelays == [.zero, .milliseconds(100)])
        #expect(fixture.outcomes == [.succeeded(retryAttempts: 2)])
    }

    @Test func retryFinishesWhenTheProductBecomesTheForegroundOwner() throws {
        let fixture = LaunchForegroundOwnerFixture(snapshots: [
            .background(owner: .external(101)),
            .background(owner: .external(101)),
            .ready,
        ])

        fixture.coordinator.start()
        try fixture.scheduler.runNext()

        #expect(fixture.recoveryAttempts == 1)
        #expect(fixture.outcomes == [.succeeded(retryAttempts: 1)])
    }

    @Test func lateCallbacksAndRepeatedStartsDoNothingAfterRelinquishing() throws {
        let fixture = LaunchForegroundOwnerFixture(snapshots: [
            .background(owner: .external(101)),
            .background(owner: .external(202)),
        ])

        fixture.coordinator.start()
        let lateCallback = try fixture.scheduler.takeNext()
        lateCallback()
        lateCallback()
        fixture.coordinator.start()

        #expect(fixture.recoveryAttempts == 0)
        #expect(fixture.scheduler.scheduledDelays == [.zero])
        #expect(fixture.outcomes == [.relinquished(
            retryAttempts: 0,
            reason: .userChangedForegroundApplication
        )])
    }

    @Test func lateCallbacksAndRepeatedStartsDoNothingAfterSuccess() throws {
        let fixture = LaunchForegroundOwnerFixture(snapshots: [
            .background(owner: .external(101)),
            .background(owner: .external(101)),
            .ready,
        ])

        fixture.coordinator.start()
        let lateCallback = try fixture.scheduler.takeNext()
        lateCallback()
        lateCallback()
        fixture.coordinator.start()

        #expect(fixture.recoveryAttempts == 1)
        #expect(fixture.scheduler.scheduledDelays == [.zero])
        #expect(fixture.outcomes == [.succeeded(retryAttempts: 1)])
    }

    @Test(arguments: LaunchForegroundSnapshot.eachIncompleteReadinessState)
    func everyReadinessSignalIsRequiredBeforeFinishing(snapshot: LaunchForegroundSnapshot) {
        let fixture = LaunchForegroundOwnerFixture(snapshots: [snapshot])

        fixture.coordinator.start()

        #expect(fixture.recoveryAttempts == 0)
        #expect(fixture.scheduler.scheduledDelays == [.zero])
        #expect(fixture.outcomes.isEmpty)
    }
}

@MainActor
private final class LaunchForegroundOwnerFixture {
    let scheduler = ManualLaunchForegroundOwnerScheduler()
    private(set) var recoveryAttempts = 0
    private(set) var outcomes: [LaunchForegroundOutcome] = []
    private(set) var snapshotReads = 0
    private let snapshots: [LaunchForegroundSnapshot]
    lazy var coordinator = LaunchForegroundCoordinator(
        retryDelays: [.zero, .milliseconds(100), .milliseconds(250), .milliseconds(500)],
        schedule: { [scheduler] delay, action in
            scheduler.schedule(after: delay, action)
        },
        snapshot: { [unowned self] in
            precondition(!snapshots.isEmpty, "fixture needs at least one snapshot")
            let snapshot = snapshots[min(snapshotReads, snapshots.count - 1)]
            snapshotReads += 1
            return snapshot
        },
        recoverSettingsForeground: { [unowned self] in recoveryAttempts += 1 },
        finished: { [unowned self] outcome in outcomes.append(outcome) }
    )

    init(snapshots: [LaunchForegroundSnapshot]) {
        self.snapshots = snapshots
    }
}

@MainActor
private final class ManualLaunchForegroundOwnerScheduler {
    private(set) var scheduledDelays: [Duration] = []
    private var actions: [@MainActor () -> Void] = []

    func schedule(after delay: Duration, _ action: @escaping @MainActor () -> Void) {
        scheduledDelays.append(delay)
        actions.append(action)
    }

    func takeNext() throws -> @MainActor () -> Void {
        try XCTUnwrap(actions.isEmpty ? nil : actions.removeFirst())
    }

    func runNext() throws {
        try takeNext()()
    }

    func runAll() throws {
        while !actions.isEmpty {
            try runNext()
        }
    }
}

private extension LaunchForegroundSnapshot {
    static let ready = LaunchForegroundSnapshot(
        applicationIsActive: true,
        frontmostOwner: .currentApplication,
        settingsWindowIsVisible: true,
        settingsWindowIsKey: true,
        activationPolicyIsRegular: true
    )

    static func background(owner: LaunchForegroundOwner) -> LaunchForegroundSnapshot {
        LaunchForegroundSnapshot(
            applicationIsActive: false,
            frontmostOwner: owner,
            settingsWindowIsVisible: true,
            settingsWindowIsKey: false,
            activationPolicyIsRegular: true
        )
    }

    static let currentApplicationNotReady = LaunchForegroundSnapshot(
        applicationIsActive: true,
        frontmostOwner: .currentApplication,
        settingsWindowIsVisible: true,
        settingsWindowIsKey: false,
        activationPolicyIsRegular: true
    )

    static let eachIncompleteReadinessState = [
        LaunchForegroundSnapshot(
            applicationIsActive: false,
            frontmostOwner: .currentApplication,
            settingsWindowIsVisible: true,
            settingsWindowIsKey: true,
            activationPolicyIsRegular: true
        ),
        LaunchForegroundSnapshot(
            applicationIsActive: true,
            frontmostOwner: .external(101),
            settingsWindowIsVisible: true,
            settingsWindowIsKey: true,
            activationPolicyIsRegular: true
        ),
        LaunchForegroundSnapshot(
            applicationIsActive: true,
            frontmostOwner: .currentApplication,
            settingsWindowIsVisible: false,
            settingsWindowIsKey: true,
            activationPolicyIsRegular: true
        ),
        LaunchForegroundSnapshot(
            applicationIsActive: true,
            frontmostOwner: .currentApplication,
            settingsWindowIsVisible: true,
            settingsWindowIsKey: false,
            activationPolicyIsRegular: true
        ),
        LaunchForegroundSnapshot(
            applicationIsActive: true,
            frontmostOwner: .currentApplication,
            settingsWindowIsVisible: true,
            settingsWindowIsKey: true,
            activationPolicyIsRegular: false
        ),
    ]
}
