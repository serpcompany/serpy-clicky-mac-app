import AppKit
import GuideCore
import GuideMac
import XCTest

final class ScreenContextServiceTests: XCTestCase {
    func testCaptureRequestsExactCatalogDescriptorAndPreservesLockedMetadata() async throws {
        let locked = target(id: 42, title: "Billing")
        let sibling = target(id: 41, title: "Other chat")
        let refreshed = target(id: 42, title: "Renamed after invocation")
        let provider = FakeWindowProvider(windows: [sibling, refreshed])
        let service = ScreenContextService(
            windowProvider: provider,
            recognizer: FakeTextRecognizer(text: "ORCHID RIVER 731")
        )

        let context = try await service.capture(locked)

        let captured = await provider.capturedTargets
        XCTAssertEqual(captured, [refreshed])
        XCTAssertEqual(context.applicationName, locked.applicationName)
        XCTAssertEqual(context.windowTitle, locked.windowTitle)
        XCTAssertEqual(context.windowFrame, locked.frame)
        XCTAssertEqual(context.promptText, "ORCHID RIVER 731")
    }

    func testMissingExactCatalogDescriptorNeverRequestsSiblingCapture() async throws {
        let locked = target(id: 42, title: "Billing")
        let provider = FakeWindowProvider(windows: [target(id: 41, title: "Other chat")])
        let service = ScreenContextService(
            windowProvider: provider,
            recognizer: FakeTextRecognizer(text: "unused")
        )

        do {
            _ = try await service.capture(locked)
            XCTFail("Expected exact-window failure")
        } catch let failure as GuideFailure {
            XCTAssertEqual(failure.stage, .capture)
        }
        let captured = await provider.capturedTargets
        XCTAssertTrue(captured.isEmpty)
    }

    @MainActor
    func testRealVisionAdapterReadsDeterministicGeneratedImage() async throws {
        let image = NSImage(size: NSSize(width: 900, height: 180))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 900, height: 180).fill()
        ("ORCHID RIVER 731" as NSString).draw(
            at: NSPoint(x: 40, y: 60),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 52, weight: .semibold),
                .foregroundColor: NSColor.black
            ]
        )
        image.unlockFocus()
        let tiff = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: tiff))
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))

        let blocks = try await VisionScreenTextRecognizer().recognizeText(
            in: ScreenRaster(encodedImage: png)
        )

        XCTAssertTrue(blocks.map(\.text).joined(separator: " ").contains("ORCHID RIVER 731"))
    }

    private func target(id: UInt32, title: String) -> GuideWindowTarget {
        GuideWindowTarget(
            processIdentifier: 101,
            windowIdentifier: id,
            applicationName: "ChatGPT",
            windowTitle: title,
            frame: CGRect(x: 10, y: 20, width: 800, height: 600)
        )
    }
}

private actor FakeWindowProvider: ScreenWindowCaptureProviding {
    let windows: [GuideWindowTarget]
    var capturedTargets: [GuideWindowTarget] = []

    init(windows: [GuideWindowTarget]) {
        self.windows = windows
    }

    func availableWindows() async throws -> [GuideWindowTarget] { windows }

    func captureWindow(_ target: GuideWindowTarget) async throws -> ScreenRaster {
        capturedTargets.append(target)
        return ScreenRaster(encodedImage: Data([1]))
    }
}

private struct FakeTextRecognizer: ScreenTextRecognizing {
    let text: String

    func recognizeText(in raster: ScreenRaster) async throws -> [ScreenTextBlock] {
        [ScreenTextBlock(text: text, normalizedBounds: .zero, confidence: 0.99)]
    }
}
