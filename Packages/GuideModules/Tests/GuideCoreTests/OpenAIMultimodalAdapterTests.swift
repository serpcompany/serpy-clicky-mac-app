import CoreGraphics
import Foundation
import GuideCore
@testable import GuideMac
import Security
import XCTest

final class OpenAIMultimodalAdapterTests: XCTestCase {
    func testDefaultTalkSessionIsEphemeralCachelessCookielessAndBounded() {
        let configuration = OpenAITalkSessionFactory.configuration()

        XCTAssertNil(configuration.urlCache)
        XCTAssertEqual(configuration.requestCachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertNil(configuration.httpCookieStorage)
        XCTAssertFalse(configuration.httpShouldSetCookies)
        XCTAssertEqual(configuration.timeoutIntervalForRequest, 45)
        XCTAssertEqual(configuration.timeoutIntervalForResource, 60)
    }

    func testResponsesRequestContainsBenignImageStructuredEvidenceAndDoesNotStore() throws {
        let request = fixtureRequest()
        let urlRequest = try OpenAIResponsesRequestBuilder().makeRequest(
            request,
            apiKey: "test-key-never-sent",
            endpoint: URL(string: "https://example.invalid/v1/responses")!
        )
        let body = try XCTUnwrap(urlRequest.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(object["model"] as? String, "gpt-5.6-terra")
        XCTAssertEqual(object["store"] as? Bool, false)
        XCTAssertEqual(object["stream"] as? Bool, true)
        XCTAssertEqual(object["parallel_tool_calls"] as? Bool, false)
        let rendered = String(decoding: body, as: UTF8.self)
        XCTAssertTrue(rendered.contains("data:image/png;base64,iVBORw=="))
        XCTAssertFalse(rendered.contains("ORCHID RIVER 731"))
        XCTAssertFalse(rendered.contains("TextEdit"))
        XCTAssertFalse(rendered.contains("window_id"))
        XCTAssertTrue(rendered.contains("serpy_guidance"))
        XCTAssertTrue(rendered.contains("json_schema"))
        XCTAssertNil(object["tools"])
        XCTAssertTrue(rendered.contains("untrusted visual evidence"))
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Authorization"), "Bearer test-key-never-sent")
    }

    func testCredentialPreflightContainsNoScreenshotQuestionOrRequestBody() throws {
        let request = try OpenAITalkCredentialVerificationRequestBuilder().makeRequest(
            apiKey: "test-key-never-sent",
            endpoint: URL(string: "https://example.invalid/v1/models/gpt-5.6-terra")!
        )

        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertNil(request.httpBody)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-key-never-sent")
    }

    func testCredentialVerifierDistinguishesValidAndProviderRejectedWithoutModelRequest() async throws {
        let configuration = OpenAITalkSessionFactory.configuration()
        configuration.protocolClasses = [CredentialFixtureURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let store = MemoryTalkCredentialStore(value: "tester-key-value-long-enough")
        let valid = OpenAITalkCredentialVerifier(
            session: session,
            endpoint: URL(string: "https://credential-fixture.invalid/valid")!
        )
        let invalid = OpenAITalkCredentialVerifier(
            session: session,
            endpoint: URL(string: "https://credential-fixture.invalid/invalid")!
        )

        let credential = try XCTUnwrap(store.credential())
        let validResult = try await valid.verifyCredential(credential)
        let invalidResult = try await invalid.verifyCredential(credential)
        XCTAssertTrue(validResult)
        XCTAssertFalse(invalidResult)
    }

    func testSSEDecoderOrdersDeltasProducesEachSentenceOnceAndPreservesRemainder() throws {
        var decoder = OpenAIResponsesSSEDecoder()
        let lines = [
            #"data: {"type":"response.output_text.delta","delta":"{\"answer\":\"The phrase is "}"#,
            #"data: {"type":"response.output_text.delta","delta":"ORCHID RIVER 731. Next"}"#,
            #"data: {"type":"response.output_text.delta","delta":" step\",\"point\":null}"}"#,
            #"data: {"type":"response.completed"}"#
        ]
        let events = try lines.flatMap { try decoder.consume(line: $0) }

        XCTAssertEqual(events.filterTextDeltas, ["The phrase is ", "ORCHID RIVER 731. Next", " step"])
        XCTAssertEqual(events.filterSentences, ["The phrase is ORCHID RIVER 731.", "Next step"])
        XCTAssertEqual(events.filter { $0 == .completed }.count, 1)
    }

    func testSSEDecoderMapsProviderErrorWithoutEchoingSecretScreenContent() {
        var decoder = OpenAIResponsesSSEDecoder()
        XCTAssertThrowsError(try decoder.consume(line: #"data: {"type":"error","error":{"message":"bad request"}}"#)) { error in
            let failure = error as? GuideFailure
            XCTAssertEqual(failure?.stage, .guidance)
            XCTAssertFalse(failure?.message.contains("ORCHID") == true)
            XCTAssertTrue(failure?.recovery.contains("OpenAI") == true)
        }
    }

    func testSSEDecoderPreservesRequiredAnswerAndOptionalPointInOneStructuredOutput() throws {
        var decoder = OpenAIResponsesSSEDecoder()
        let lines = [
            #"data: {"type":"response.output_text.delta","delta":"{\"answer\":\"Choose Continue.\",\"point\":{\"x\":0.25,\"y\":0.75,\"confidence\":0.92,\"label\":\"Continue\"}}"}"#,
            #"data: {"type":"response.completed"}"#
        ]

        let events = try lines.flatMap { try decoder.consume(line: $0) }

        XCTAssertEqual(events.filterTextDeltas, ["Choose Continue."])
        XCTAssertTrue(events.contains(.spatialAction(.point(
            evidenceID: "locked-window",
            normalizedPoint: CGPoint(x: 0.25, y: 0.75),
            confidence: 0.92,
            label: "Continue"
        ))))
        XCTAssertEqual(events.last, .completed)
    }

    func testSSEDecoderAcceptsAnswerOnlyStructuredOutput() throws {
        var decoder = OpenAIResponsesSSEDecoder()
        let lines = [
            #"data: {"type":"response.output_text.delta","delta":"{\"answer\":\"Use Settings.\",\"point\":null}"}"#,
            #"data: {"type":"response.completed"}"#
        ]

        let events = try lines.flatMap { try decoder.consume(line: $0) }

        XCTAssertEqual(events.filterTextDeltas, ["Use Settings."])
        XCTAssertFalse(events.contains { if case .spatialAction = $0 { true } else { false } })
        XCTAssertEqual(events.last, .completed)
    }

    func testSSEDecoderRejectsMalformedOrMissingRequiredAnswer() throws {
        var missing = OpenAIResponsesSSEDecoder()
        _ = try missing.consume(line: #"data: {"type":"response.output_text.delta","delta":"{\"point\":null}"}"#)
        XCTAssertThrowsError(try missing.consume(line: #"data: {"type":"response.completed"}"#))

        var malformed = OpenAIResponsesSSEDecoder()
        _ = try malformed.consume(line: #"data: {"type":"response.output_text.delta","delta":"{\"answer\":"}"#)
        XCTAssertThrowsError(try malformed.consume(line: #"data: {"type":"response.completed"}"#))
    }

    func testImmediatelyFailingStreamDoesNotLeaveStaleRequestOwnership() async throws {
        let generator = OpenAIMultimodalGuidanceGenerator(
            credentialStore: MemoryTalkCredentialStore(value: nil),
            endpoint: URL(string: "https://example.invalid/v1/responses")!
        )

        do {
            for try await _ in generator.stream(fixtureRequest()) {}
            XCTFail("Expected missing-credential failure")
        } catch {
            XCTAssertEqual((error as? GuideFailure)?.stage, .guidance)
        }
        for _ in 0..<100 where generator.activeRequestCountForTesting != 0 {
            await Task.yield()
        }
        XCTAssertEqual(generator.activeRequestCountForTesting, 0)
    }

    func testCancellingLiveBytesTransportStopsURLProtocolAndYieldsNoLateCompletion() async throws {
        BlockingSSEURLProtocol.reset()
        let configuration = OpenAITalkSessionFactory.configuration()
        configuration.protocolClasses = [BlockingSSEURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let generator = OpenAIMultimodalGuidanceGenerator(
            credentialStore: MemoryTalkCredentialStore(value: "tester-key-value-long-enough"),
            session: session,
            endpoint: URL(string: "https://stream-fixture.invalid/v1/responses")!
        )
        let events = LockedEventBuffer()
        let request = fixtureRequest()
        let consumer = Task {
            do {
                for try await event in generator.stream(request) {
                    events.append(event)
                }
            } catch is CancellationError {
                // Expected cancellation path.
            }
        }
        for _ in 0..<2_000 where !BlockingSSEURLProtocol.didStart {
            try await Task.sleep(for: .milliseconds(1))
        }
        XCTAssertTrue(BlockingSSEURLProtocol.didStart)

        generator.cancel()
        _ = await consumer.result
        for _ in 0..<2_000 where !BlockingSSEURLProtocol.didStop {
            try await Task.sleep(for: .milliseconds(1))
        }

        XCTAssertTrue(BlockingSSEURLProtocol.didStop)
        XCTAssertFalse(events.values.contains(.completed))
        XCTAssertEqual(generator.activeRequestCountForTesting, 0)
    }

    func testKeychainCredentialContractUsesIsolatedServiceAndDeletesValue() throws {
        let service = "com.serpcompany.serpy.tests.\(UUID().uuidString)"
        let store = KeychainTalkCredentialStore(service: service, account: "fixture")
        defer { try? store.deleteCredential() }
        XCTAssertNil(try store.credential())
        try store.saveCredential("sk-fixture-not-real")
        XCTAssertEqual(try store.credential(), "sk-fixture-not-real")
        try store.saveCredential("sk-fixture-replaced")
        XCTAssertEqual(try store.credential(), "sk-fixture-replaced")
        XCTAssertTrue(CFEqual(
            KeychainTalkItemPolicy().accessibility,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ))
        try store.deleteCredential()
        XCTAssertNil(try store.credential())
    }

    @MainActor
    func testCloudRouterRefusesTransmissionUntilSelectionDisclosureAndCredentialAreAllPresent() throws {
        let cloud = RecordingGuidanceGenerator()
        let credentialStore = MemoryTalkCredentialStore(value: "tester-key-value-long-enough")
        let router = TalkGenerationRouter(
            local: LocalGuidanceService(),
            cloud: cloud,
            credentialStore: credentialStore,
            selection: .openAI,
            disclosureAccepted: true,
            credentialVerifiedUntil: nil,
            verifiedCredential: nil
        )
        let fixture = fixtureRequest()
        let context = ScreenContext(
            applicationName: fixture.target.applicationName,
            windowTitle: fixture.target.windowTitle,
            windowFrame: fixture.target.frame,
            textBlocks: [.init(text: "ORCHID RIVER 731", normalizedBounds: fixture.evidence[0].normalizedBounds, confidence: 0.99)],
            raster: fixture.raster
        )

        XCTAssertThrowsError(try router.streamAnswer(
            question: fixture.question,
            target: fixture.target,
            context: context,
            conversation: []
        ))
        XCTAssertEqual(cloud.requestCount, 0)

        router.configure(
            selection: .openAI,
            disclosureAccepted: false,
            credentialVerifiedUntil: Date().addingTimeInterval(900),
            verifiedCredential: "tester-key-value-long-enough"
        )
        XCTAssertThrowsError(try router.streamAnswer(
            question: fixture.question,
            target: fixture.target,
            context: context,
            conversation: []
        ))
        XCTAssertEqual(cloud.requestCount, 0)
    }

    @MainActor
    func testAuthorizedCloudRouterForwardsOnlyBoundedLockedWindowRequest() async throws {
        let cloud = RecordingGuidanceGenerator()
        let credentialStore = MemoryTalkCredentialStore(value: "tester-key-value-long-enough")
        let router = TalkGenerationRouter(
            local: LocalGuidanceService(),
            cloud: cloud,
            credentialStore: credentialStore,
            selection: .openAI,
            disclosureAccepted: true,
            credentialVerifiedUntil: Date().addingTimeInterval(900),
            verifiedCredential: "tester-key-value-long-enough"
        )
        let fixture = fixtureRequest()
        let context = ScreenContext(
            applicationName: fixture.target.applicationName,
            windowTitle: fixture.target.windowTitle,
            windowFrame: fixture.target.frame,
            textBlocks: [.init(text: "ORCHID RIVER 731", normalizedBounds: fixture.evidence[0].normalizedBounds, confidence: 0.99)],
            raster: fixture.raster
        )

        let stream = try router.streamAnswer(
            question: fixture.question,
            target: fixture.target,
            context: context,
            conversation: []
        )
        var events: [GuidanceStreamEvent] = []
        for try await event in stream { events.append(event) }

        XCTAssertEqual(events, [.textDelta("Fixture answer."), .sentenceReady("Fixture answer."), .completed])
        XCTAssertEqual(cloud.requestCount, 1)
        XCTAssertEqual(cloud.lastRequest?.target, fixture.target)
        XCTAssertEqual(cloud.lastRequest?.raster, fixture.raster)
        XCTAssertEqual(cloud.lastRequest?.evidence, [])

        try credentialStore.saveCredential("different-unverified-key")
        XCTAssertThrowsError(try router.streamAnswer(
            question: fixture.question,
            target: fixture.target,
            context: context,
            conversation: []
        ))
        XCTAssertEqual(cloud.requestCount, 1)
    }

    private func fixtureRequest() -> MultimodalGuideRequest {
        MultimodalGuideRequest(
            question: "What phrase is visible?",
            target: GuideWindowTarget(
                processIdentifier: 10,
                windowIdentifier: 20,
                applicationName: "TextEdit",
                windowTitle: "Fixture",
                frame: CGRect(x: 0, y: 0, width: 800, height: 600)
            ),
            raster: GuideRaster(bytes: Data([0x89, 0x50, 0x4E, 0x47]), mimeType: "image/png", pixelWidth: 2, pixelHeight: 2),
            evidence: [.init(id: "ocr-1", text: "ORCHID RIVER 731", normalizedBounds: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.1), confidence: 0.99, source: .ocr)],
            conversationSummary: "No prior turns."
        )
    }
}

private final class MemoryTalkCredentialStore: TalkCredentialStoring, @unchecked Sendable {
    private var value: String?

    init(value: String?) { self.value = value }

    func credential() throws -> String? { value }
    func saveCredential(_ credential: String) throws { value = credential }
    func deleteCredential() throws { value = nil }
}

private final class RecordingGuidanceGenerator: GuidanceGenerating, @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [MultimodalGuideRequest] = []

    var requestCount: Int { lock.withLock { requests.count } }
    var lastRequest: MultimodalGuideRequest? { lock.withLock { requests.last } }

    func stream(_ request: MultimodalGuideRequest) -> AsyncThrowingStream<GuidanceStreamEvent, Error> {
        lock.withLock { requests.append(request) }
        return AsyncThrowingStream { continuation in
            continuation.yield(.textDelta("Fixture answer."))
            continuation.yield(.sentenceReady("Fixture answer."))
            continuation.yield(.completed)
            continuation.finish()
        }
    }

    func cancel() {}
}

private final class LockedEventBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [GuidanceStreamEvent] = []

    var values: [GuidanceStreamEvent] { lock.withLock { storage } }
    func append(_ event: GuidanceStreamEvent) { lock.withLock { storage.append(event) } }
}

private final class CredentialFixtureURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let status = request.url?.path.contains("invalid") == true ? 401 : 200
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(#"{"id":"gpt-5.6-terra","object":"model"}"#.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class BlockingSSEURLProtocol: URLProtocol {
    private static let stateLock = NSLock()
    nonisolated(unsafe) private static var started = false
    nonisolated(unsafe) private static var stopped = false

    static var didStart: Bool { stateLock.withLock { started } }
    static var didStop: Bool { stateLock.withLock { stopped } }
    static func reset() { stateLock.withLock { started = false; stopped = false } }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.stateLock.withLock { Self.started = true }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/event-stream"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("data: {\"type\":\"response.output_text.delta\",\"delta\":\"early\"}\n\n".utf8))
        // Deliberately remains open until URLSession cancellation calls stopLoading.
    }

    override func stopLoading() {
        Self.stateLock.withLock { Self.stopped = true }
    }
}

private extension NSLock {
    func withLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}

private extension Array where Element == GuidanceStreamEvent {
    var filterTextDeltas: [String] {
        compactMap { if case let .textDelta(value) = $0 { value } else { nil } }
    }

    var filterSentences: [String] {
        compactMap { if case let .sentenceReady(value) = $0 { value } else { nil } }
    }
}
