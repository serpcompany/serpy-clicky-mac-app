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
        guard environment == "development" || environment == "internal-test" else { return nil }
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

public struct SentryHandledEventMetadata: Equatable, Sendable {
    public let releaseName: String
    public let dist: String
    public let sdkName: String
    public let sdkVersion: String

    public init?(appVersion: String, appBuild: String, sdkVersion: String) {
        let versionCharacters = CharacterSet(charactersIn: "0123456789.-")
        guard !appVersion.isEmpty,
              !appBuild.isEmpty,
              !sdkVersion.isEmpty,
              appVersion.unicodeScalars.allSatisfy(versionCharacters.contains),
              appBuild.allSatisfy(\.isNumber),
              sdkVersion.unicodeScalars.allSatisfy(versionCharacters.contains)
        else { return nil }
        releaseName = "com.serpcompany.guidecompanion.internal@\(appVersion)+\(appBuild)"
        dist = appBuild
        sdkName = "sentry.cocoa"
        self.sdkVersion = sdkVersion
    }
}

public struct SentryHandledEventScrubber {
    private let metadata: SentryHandledEventMetadata

    public init(metadata: SentryHandledEventMetadata) {
        self.metadata = metadata
    }

    public func scrub(_ event: Event) -> Event? {
        guard event.environment == "development" || event.environment == "internal-test",
              event.tags?["serpy_schema"] == "handled-v1",
              let message = event.message?.formatted,
              let code = GuideFailureCode(rawValue: message),
              let stageValue = event.tags?["failure_stage"],
              GuideFailureStage(rawValue: stageValue) != nil,
              let providerValue = event.tags?["provider_kind"],
              GuideFailureProvider(rawValue: providerValue) != nil
        else { return nil }
        if code == .guidancePlanMalformed {
            guard stageValue == GuideFailureStage.guidance.rawValue,
                  providerValue == GuideFailureProvider.local.rawValue
                    || providerValue == GuideFailureProvider.openAI.rawValue else { return nil }
        } else {
            // Broader stage-only reporting is approved solely for installed internal tests.
            guard event.environment == "internal-test", code == .unclassified else { return nil }
        }
        event.message = SentryMessage(formatted: code.rawValue)
        event.fingerprint = code == .unclassified ? [code.rawValue, stageValue] : [code.rawValue]
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
        event.releaseName = metadata.releaseName
        event.dist = metadata.dist
        event.type = nil
        event.platform = "cocoa"
        event.level = .error
        event.sdk = ["name": metadata.sdkName, "version": metadata.sdkVersion]
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
    private static let pinnedSDKVersion = "9.27.0"

    @discardableResult
    public static func startIfConfigured(
        dsn: String?,
        environment: String = "development",
        debug: Bool = false
    ) -> Bool {
        guard let dsn, !dsn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        let bundleInfo = Bundle.main.infoDictionary ?? [:]
        guard let appVersion = bundleInfo["CFBundleShortVersionString"] as? String,
              let appBuild = bundleInfo["CFBundleVersion"] as? String,
              let metadata = SentryHandledEventMetadata(
                appVersion: appVersion,
                appBuild: appBuild,
                sdkVersion: pinnedSDKVersion
              )
        else { return false }

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
            options.releaseName = metadata.releaseName
            let scrubber = SentryHandledEventScrubber(metadata: metadata)
            options.beforeSend = { event in scrubber.scrub(event) }
        }
        return true
    }
}
