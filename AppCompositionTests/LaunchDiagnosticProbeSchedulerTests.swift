import Foundation
import Dispatch
import XCTest

@MainActor
final class LaunchDiagnosticProbeSchedulerTests: XCTestCase {
    func testMainActorCanScheduleOwnedRootProbeWhileMainActorIsBlocked() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("serpy-launch-probe-test.\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data().write(to: root.appendingPathComponent("launch-stage.init-entered"))
        try Data().write(to: root.appendingPathComponent("launch-stage.not-allowlisted"))

        let reported = DispatchSemaphore(value: 0)
        let messages = ProbeMessages()
        let handles = LaunchDiagnosticProbeScheduler.schedule(
            in: root,
            delaysInSeconds: [0]
        ) { message in
            messages.append(message)
            reported.signal()
        }
        defer { handles.forEach { $0.cancel() } }

        XCTAssertEqual(reported.wait(timeout: .now() + 2), .success)
        XCTAssertEqual(
            messages.values,
            ["[DEBUG-cloud-launch] at=0s stages=init-entered\n"]
        )
    }

    func testCancellationStopsDelayedProbe() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("serpy-launch-probe-test.\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: root) }

        let messages = ProbeMessages()
        let handles = LaunchDiagnosticProbeScheduler.schedule(
            in: root,
            delaysInSeconds: [5]
        ) { message in
            messages.append(message)
        }

        handles.forEach { $0.cancel() }
        for handle in handles {
            await handle.waitForCompletion()
        }
        XCTAssertEqual(messages.values, [])
    }
}

private final class ProbeMessages: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []

    var values: [String] {
        lock.withLock { storage }
    }

    func append(_ message: String) {
        lock.withLock { storage.append(message) }
    }
}
