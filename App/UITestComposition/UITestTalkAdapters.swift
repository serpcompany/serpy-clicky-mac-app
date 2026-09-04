import Foundation
import GuideCore
import GuideMac

final class UITestCredentialStore: TalkCredentialStoring, DeterministicUITestAdapter, @unchecked Sendable {
    private var value: String?
    func credential() throws -> String? { value }
    func saveCredential(_ credential: String) throws { value = credential }
    func deleteCredential() throws { value = nil }
}

struct UITestCredentialVerifier: TalkCredentialVerifying, DeterministicUITestAdapter {
    func verifyCredential(_ credential: String) async throws -> Bool { true }
}

struct UITestExpirySleeper: TalkVerificationExpirySleeping, DeterministicUITestAdapter {
    func sleep(until: Date) async throws { try await Task.sleep(for: .seconds(3_600)) }
}

final class UITestCloudGenerator: GuidanceGenerating, DeterministicUITestAdapter, @unchecked Sendable {
    private let sessionRoot: URL
    private let block: Bool
    private let lock = NSLock()
    private var continuation: AsyncThrowingStream<GuidanceStreamEvent, Error>.Continuation?

    init(sessionRoot: URL, block: Bool) {
        self.sessionRoot = sessionRoot
        self.block = block
    }

    func stream(_ request: MultimodalGuideRequest) -> AsyncThrowingStream<GuidanceStreamEvent, Error> {
        let receipt = "question=\(request.question);raster=\(request.raster.bytes.count);evidence=\(request.evidence.count)"
        do {
            try receipt.write(
                to: sessionRoot.appendingPathComponent("cloud-request.fixture"),
                atomically: true,
                encoding: .utf8
            )
        } catch {
            return AsyncThrowingStream { $0.finish(throwing: error) }
        }
        return AsyncThrowingStream { continuation in
            if block {
                lock.withLock { self.continuation = continuation }
            } else {
                let plan = GuidancePlan(answer: "Cloud fixture answer.", confidence: 1)
                continuation.yield(.textDelta(plan.answer))
                continuation.yield(.planReady(plan))
                continuation.yield(.completed)
                continuation.finish()
            }
        }
    }
    func cancel() {
        lock.withLock {
            continuation?.finish(throwing: CancellationError())
            continuation = nil
        }
    }
}

final class UITestIncidentReporter: DiagnosticIncidentReporting, DeterministicUITestAdapter, @unchecked Sendable {
    private let sessionRoot: URL
    private let lock = NSLock()
    private var reportCount = 0

    init(sessionRoot: URL) { self.sessionRoot = sessionRoot }

    func report(_ incident: DiagnosticIncident) {
        let receipt = lock.withLock {
            reportCount += 1
            return "count=\(reportCount);code=\(incident.code.rawValue)"
        }
        do {
            try receipt.write(
                to: sessionRoot.appendingPathComponent("incident.fixture"),
                atomically: true,
                encoding: .utf8
            )
        } catch {
            preconditionFailure("ephemeral diagnostic receipt could not be exposed to XCUI")
        }
    }
}

@MainActor
final class UITestShortcutMonitor: GlobalShortcutMonitoring, DeterministicUITestAdapter {
    func start() throws {}
    func stop() {}
}
