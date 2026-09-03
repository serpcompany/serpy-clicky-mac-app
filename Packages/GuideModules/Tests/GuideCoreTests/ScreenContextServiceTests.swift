import CoreGraphics
import GuideCore
@testable import GuideMac
import XCTest

final class ScreenContextServiceTests: XCTestCase {
    func testVisionRecognitionWorkRunsOffMainActorQueue() async throws {
        let probe = ThreadProbe()
        let recognizer = VisionScreenTextRecognizer { _ in
            probe.record(Thread.isMainThread)
            return [ScreenTextBlock(text: "ORCHID RIVER 731", normalizedBounds: .zero, confidence: 0.99)]
        }
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let image = try XCTUnwrap(context.makeImage())

        let blocks = try await recognizer.recognizeText(in: image)

        XCTAssertEqual(blocks.map(\.text), ["ORCHID RIVER 731"])
        XCTAssertEqual(probe.wasMainThread, false)
    }
}

private final class ThreadProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: Bool?

    var wasMainThread: Bool? {
        lock.withLock { stored }
    }

    func record(_ value: Bool) {
        lock.withLock { stored = value }
    }
}
