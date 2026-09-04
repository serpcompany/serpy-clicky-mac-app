import GuideCore
@testable import GuideMac
import Sentry
import XCTest

final class SentryDiagnosticReporterTests: XCTestCase {
    private let trustedMetadata = SentryHandledEventMetadata(
        appVersion: "0.1.0",
        appBuild: "42",
        sdkVersion: "9.27.0"
    )!

    func testRuntimeConfigurationUsesInjectedBundleValueWithoutCommittingADSN() throws {
        XCTAssertNil(SentryRuntimeConfiguration.resolve(
            processEnvironment: [:],
            bundleInfo: [:]
        ))

        let configuration = try XCTUnwrap(SentryRuntimeConfiguration.resolve(
            processEnvironment: [:],
            bundleInfo: [
                "SentryDSN": "https://public@example.invalid/1",
                "SentryEnvironment": "development"
            ]
        ))

        XCTAssertEqual(configuration.dsn, "https://public@example.invalid/1")
        XCTAssertEqual(configuration.environment, "development")
        XCTAssertFalse(configuration.debug)
        XCTAssertNil(SentryRuntimeConfiguration.resolve(
            processEnvironment: [
                "SENTRY_DSN": "https://public@example.invalid/1",
                "SENTRY_ENVIRONMENT": "production"
            ],
            bundleInfo: [:]
        ))
    }

    func testDescriptorUsesStableFingerprintAndOnlyAllowlistedTags() {
        let descriptor = SentryDiagnosticEventDescriptor(
            incident: DiagnosticIncident(failure: GuideFailure(
                stage: .guidance,
                code: .guidancePlanMalformed,
                provider: .local,
                message: "SECRET-QUESTION-ORCHID-731",
                recovery: "SECRET-RESPONSE-RIVER-924"
            ))
        )

        XCTAssertEqual(descriptor.message, "guidance.plan.malformed")
        XCTAssertEqual(descriptor.fingerprint, ["guidance.plan.malformed"])
        XCTAssertEqual(descriptor.tags, [
            "failure_stage": "guidance",
            "provider_kind": "local",
            "serpy_schema": "handled-v1"
        ])
        let rendered = "\(descriptor.message) \(descriptor.fingerprint) \(descriptor.tags)"
        XCTAssertFalse(rendered.contains("SECRET-QUESTION"))
        XCTAssertFalse(rendered.contains("SECRET-RESPONSE"))
    }

    func testHandledEventScrubberRemovesSDKAddedIdentityAndContext() throws {
        let secret = "SECRET-IDENTITY-ORCHID-731"
        let event = Event(level: .error)
        event.message = SentryMessage(formatted: "guidance.plan.malformed")
        event.environment = "development"
        event.error = NSError(domain: secret, code: 1)
        event.startTimestamp = Date()
        event.logger = secret
        event.serverName = secret
        event.releaseName = secret
        event.dist = secret
        event.type = secret
        event.platform = secret
        event.level = .fatal
        event.sdk = [
            "name": "sentry.cocoa",
            "version": "9.27.0",
            "unapproved": secret
        ]
        event.tags = [
            "serpy_schema": "handled-v1",
            "failure_stage": "guidance",
            "provider_kind": "local",
            "unapproved": secret
        ]
        event.fingerprint = ["unapproved-fingerprint"]
        let user = User()
        user.userId = secret
        event.user = user
        event.context = ["device": ["name": secret]]
        event.extra = ["raw_response": secret]
        event.modules = ["private_module": secret]
        let breadcrumb = Breadcrumb()
        breadcrumb.message = secret
        event.breadcrumbs = [breadcrumb]
        event.threads = []
        event.debugMeta = []

        let scrubbed = try XCTUnwrap(
            SentryHandledEventScrubber(metadata: trustedMetadata).scrub(event)
        )

        XCTAssertNil(scrubbed.user)
        XCTAssertNil(scrubbed.context)
        XCTAssertNil(scrubbed.extra)
        XCTAssertNil(scrubbed.modules)
        XCTAssertNil(scrubbed.breadcrumbs)
        XCTAssertNil(scrubbed.threads)
        XCTAssertNil(scrubbed.debugMeta)
        XCTAssertNil(scrubbed.request)
        XCTAssertNil(scrubbed.transaction)
        XCTAssertNil(scrubbed.stacktrace)
        XCTAssertNil(scrubbed.exceptions)
        XCTAssertNil(scrubbed.error)
        XCTAssertNil(scrubbed.startTimestamp)
        XCTAssertNil(scrubbed.logger)
        XCTAssertNil(scrubbed.serverName)
        XCTAssertEqual(scrubbed.releaseName, "com.serpcompany.guidecompanion.internal@0.1.0+42")
        XCTAssertEqual(scrubbed.dist, "42")
        XCTAssertNil(scrubbed.type)
        XCTAssertEqual(scrubbed.platform, "cocoa")
        XCTAssertEqual(scrubbed.level, .error)
        XCTAssertEqual(scrubbed.sdk?["name"] as? String, "sentry.cocoa")
        XCTAssertEqual(scrubbed.sdk?["version"] as? String, "9.27.0")
        XCTAssertEqual(scrubbed.sdk?.count, 2)
        XCTAssertEqual(scrubbed.message?.formatted, "guidance.plan.malformed")
        XCTAssertEqual(scrubbed.fingerprint, ["guidance.plan.malformed"])
        XCTAssertEqual(scrubbed.tags, [
            "failure_stage": "guidance",
            "provider_kind": "local",
            "serpy_schema": "handled-v1"
        ])

        let unclassified = Event(level: .error)
        unclassified.message = SentryMessage(formatted: secret)
        unclassified.tags = ["serpy_schema": "handled-v1"]
        XCTAssertNil(SentryHandledEventScrubber(metadata: trustedMetadata).scrub(unclassified))

        let wrongClassification = Event(level: .error)
        wrongClassification.environment = "development"
        wrongClassification.message = SentryMessage(formatted: "guidance.plan.malformed")
        wrongClassification.tags = [
            "serpy_schema": "handled-v1",
            "failure_stage": "permission",
            "provider_kind": "none"
        ]
        XCTAssertNil(
            SentryHandledEventScrubber(metadata: trustedMetadata).scrub(wrongClassification)
        )
        XCTAssertNil(SentryHandledEventMetadata(
            appVersion: "0.1.0-SECRET/../../../private",
            appBuild: "42-SECRET",
            sdkVersion: "9.27.0 SECRET"
        ))
    }
}
