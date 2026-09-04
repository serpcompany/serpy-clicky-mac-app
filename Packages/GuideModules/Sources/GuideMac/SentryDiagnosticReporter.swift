import Foundation
import GuideCore
import Sentry

public struct SentryRuntimeConfiguration: Equatable, Sendable {
    public let dsn: String
    public let environment: String
    public let debug: Bool

    public static func resolve(
        processEnvironment: [String: String],
        bundleInfo: [String: Any]
    ) -> SentryRuntimeConfiguration? {
        let candidate = processEnvironment["SENTRY_DSN"]
            ?? bundleInfo["SentryDSN"] as? String
        guard let candidate else { return nil }
        let dsn = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !dsn.isEmpty, !dsn.hasPrefix("$(") else { return nil }
        let environment = processEnvironment["SENTRY_ENVIRONMENT"]
            ?? bundleInfo["SentryEnvironment"] as? String
            ?? "development"
        guard environment == "development" else { return nil }
        return SentryRuntimeConfiguration(
            dsn: dsn,
            environment: environment,
            debug: processEnvironment["SENTRY_DEBUG"] == "1"
        )
    }
}

public struct SentryDiagnosticEventDescriptor: Equatable, Sendable {
    public let message: String
    public let fingerprint: [String]
    public let tags: [String: String]

    public init(incident: DiagnosticIncident) {
        message = incident.code.rawValue
        fingerprint = [incident.code.rawValue]
        tags = [
            "failure_stage": incident.stage.rawValue,
            "provider_kind": incident.provider.rawValue,
            "serpy_schema": "handled-v1"
        ]
    }
}

public struct SentryHandledEventScrubber {
    public init() {}

    public func scrub(_ event: Event) -> Event? {
        guard event.environment == "development",
              event.tags?["serpy_schema"] == "handled-v1",
              let message = event.message?.formatted,
              let code = GuideFailureCode(rawValue: message),
              code != .unclassified,
              let stageValue = event.tags?["failure_stage"],
              stageValue == GuideFailureStage.guidance.rawValue,
              let providerValue = event.tags?["provider_kind"],
              providerValue == GuideFailureProvider.local.rawValue
                || providerValue == GuideFailureProvider.openAI.rawValue
        else { return nil }
        event.message = SentryMessage(formatted: code.rawValue)
        event.fingerprint = [code.rawValue]
        event.tags = [
            "failure_stage": stageValue,
            "provider_kind": providerValue,
            "serpy_schema": "handled-v1"
        ]
        event.user = nil
        event.error = nil
        event.startTimestamp = nil
        event.logger = nil
        event.serverName = nil
        if event.releaseName?.hasPrefix("com.serpcompany.guidecompanion.internal@") != true {
            event.releaseName = nil
        }
        if event.dist?.allSatisfy(\.isNumber) != true {
            event.dist = nil
        }
        event.type = nil
        event.platform = "cocoa"
        event.level = .error
        if let sdk = event.sdk,
           let name = sdk["name"] as? String,
           let version = sdk["version"] as? String {
            event.sdk = ["name": name, "version": version]
        } else {
            event.sdk = nil
        }
        event.context = nil
        event.extra = nil
        event.modules = nil
        event.breadcrumbs = nil
        event.threads = nil
        event.debugMeta = nil
        event.request = nil
        event.transaction = nil
        event.stacktrace = nil
        event.exceptions = nil
        return event
    }
}

public final class SentryDiagnosticReporter: DiagnosticIncidentReporting {
    public init() {}

    public func report(_ incident: DiagnosticIncident) {
        let descriptor = SentryDiagnosticEventDescriptor(incident: incident)
        let event = Event(level: .error)
        event.message = SentryMessage(formatted: descriptor.message)
        event.fingerprint = descriptor.fingerprint
        event.tags = descriptor.tags
        SentrySDK.capture(event: event)
    }
}

@MainActor
public enum SentryDiagnosticBootstrap {
    @discardableResult
    public static func startIfConfigured(
        dsn: String?,
        environment: String = "development",
        debug: Bool = false
    ) -> Bool {
        guard let dsn, !dsn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = environment
            options.debug = debug
            options.sendDefaultPii = false
            options.enableCrashHandler = false
            options.enableMemoryIntrospection = false
            options.tracesSampleRate = nil
            options.enableAutoPerformanceTracing = false
            options.enableNetworkBreadcrumbs = false
            options.enableNetworkTracking = false
            options.enableFileIOTracing = false
            options.enableCoreDataTracing = false
            options.enableCaptureFailedRequests = false
            options.enableAutoBreadcrumbTracking = false
            options.enableAutoSessionTracking = false
            options.enableAppHangTracking = false
            options.enableMetricKit = false
            options.enableMetricKitRawPayload = false
            options.enableSwizzling = false
            options.enableDataSwizzling = false
            options.enableLogs = false
            options.enableMetrics = false
            options.maxBreadcrumbs = 0
            options.maxCacheItems = 10
            options.sampleRate = 1
            let scrubber = SentryHandledEventScrubber()
            options.beforeSend = { event in scrubber.scrub(event) }
        }
        return true
    }
}
