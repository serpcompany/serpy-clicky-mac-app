import Foundation
import GuideCore
@testable import GuideMac
import Sentry
import Testing

struct InternalDiagnosticAuthorizationTests {
    @Test("explicit internal-test configuration is admitted but production remains off")
    func configuration() {
        let configured = SentryRuntimeConfiguration.resolve(
            processEnvironment: [:],
            bundleInfo: ["SentryDSN": "https://public@example.invalid/1",
                         "SentryEnvironment": "internal-test"])
        #expect(configured?.environment == "internal-test")
        #expect(SentryRuntimeConfiguration.resolve(processEnvironment: [:],
            bundleInfo: ["SentryEnvironment": "internal-test"]) == nil)
    }

    @Test("internal handled failures retain fixed classification and strip private context",
          arguments: GuideFailureStage.allCases)
    func stageOnlyFailure(stage: GuideFailureStage) throws {
        let event = Event(level: .error)
        event.environment = "internal-test"
        event.message = SentryMessage(formatted: GuideFailureCode.unclassified.rawValue)
        event.tags = ["serpy_schema": "handled-v1", "failure_stage": stage.rawValue,
                      "provider_kind": "none", "private": "SECRET-CONTENT"]
        event.extra = ["transcript": "SECRET-CONTENT"]
        event.error = NSError(domain: "SECRET-CONTENT", code: 1)
        let metadata = try #require(SentryHandledEventMetadata(
            appVersion: "0.1.0", appBuild: "45", sdkVersion: "9.27.0"))
        let scrubbed = try #require(SentryHandledEventScrubber(metadata: metadata).scrub(event))
        #expect(scrubbed.extra == nil)
        #expect(scrubbed.error == nil)
        #expect(scrubbed.tags?.count == 3)
        #expect(scrubbed.fingerprint == [GuideFailureCode.unclassified.rawValue, stage.rawValue])
        event.message = SentryMessage(formatted: "SECRET-CONTENT")
        #expect(SentryHandledEventScrubber(metadata: metadata).scrub(event) == nil)
    }
}
