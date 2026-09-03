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

@MainActor
final class ScreenCaptureKitWindowProviderContractTests: XCTestCase {
    func testSnapshotTranslationAndExactCaptureRequestConfiguration() async throws {
        let png = try makePNG(text: "fixture")
        let snapshot = ScreenCaptureKitWindowSnapshot(
            processIdentifier: 101,
            windowIdentifier: 42,
            applicationName: "ChatGPT",
            windowTitle: "Billing",
            frame: CGRect(x: 10, y: 20, width: 800, height: 600)
        )
        let facade = FakeScreenCaptureKitFacade(snapshots: [snapshot], png: png)
        let provider = ScreenCaptureKitWindowProvider(facade: facade)

        let targets = try await provider.availableWindows()
        let raster = try await provider.captureWindow(try XCTUnwrap(targets.first))

        XCTAssertEqual(targets.first?.windowIdentifier, 42)
        XCTAssertEqual(targets.first?.windowTitle, "Billing")
        XCTAssertEqual(raster.encodedImage, png)
        let requests = await facade.requests
        XCTAssertEqual(requests, [ScreenCaptureKitCaptureRequest(
            processIdentifier: 101,
            windowIdentifier: 42,
            pixelWidth: 1_600,
            pixelHeight: 1_200,
            showsCursor: false
        )])
    }

    func testProviderRejectsSameProcessSiblingWithoutCallingCaptureFacade() async throws {
        let png = try makePNG(text: "fixture")
        let sibling = ScreenCaptureKitWindowSnapshot(
            processIdentifier: 101,
            windowIdentifier: 41,
            applicationName: "ChatGPT",
            windowTitle: "Other",
            frame: CGRect(x: 0, y: 0, width: 800, height: 600)
        )
        let facade = FakeScreenCaptureKitFacade(snapshots: [sibling], png: png)
        let provider = ScreenCaptureKitWindowProvider(facade: facade)
        _ = try await provider.availableWindows()
        let missing = GuideWindowTarget(processIdentifier: 101, windowIdentifier: 42, applicationName: "ChatGPT", windowTitle: "Billing", frame: sibling.frame)

        do {
            _ = try await provider.captureWindow(missing)
            XCTFail("Expected exact identity failure")
        } catch let failure as GuideFailure {
            XCTAssertEqual(failure.stage, .capture)
            XCTAssertFalse(failure.recovery.isEmpty)
        }
        let requests = await facade.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testFacadeFailureMapsStageCauseAndActionableRecovery() async throws {
        let snapshot = ScreenCaptureKitWindowSnapshot(processIdentifier: 101, windowIdentifier: 42, applicationName: "ChatGPT", windowTitle: "Billing", frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        let facade = FakeScreenCaptureKitFacade(
            snapshots: [snapshot],
            png: Data(),
            error: NSError(domain: "fixture", code: 9, userInfo: [NSLocalizedDescriptionKey: "capture fixture failed"])
        )
        let provider = ScreenCaptureKitWindowProvider(facade: facade)
        let available = try await provider.availableWindows()
        let target = try XCTUnwrap(available.first)

        do {
            _ = try await provider.captureWindow(target)
            XCTFail("Expected mapped capture failure")
        } catch let failure as GuideFailure {
            XCTAssertEqual(failure.stage, .capture)
            XCTAssertTrue(failure.message.contains("capture fixture failed"))
            XCTAssertTrue(failure.recovery.contains("Screen Recording"))
        }
    }

    private func makePNG(text: String) throws -> Data {
        let image = NSImage(size: NSSize(width: 320, height: 100))
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 320, height: 100).fill()
        (text as NSString).draw(at: NSPoint(x: 20, y: 35), withAttributes: [.foregroundColor: NSColor.black])
        image.unlockFocus()
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: try XCTUnwrap(image.tiffRepresentation)))
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
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

private actor FakeScreenCaptureKitFacade: ScreenCaptureKitFacading {
    let snapshots: [ScreenCaptureKitWindowSnapshot]
    let png: Data
    let error: Error?
    var requests: [ScreenCaptureKitCaptureRequest] = []

    init(snapshots: [ScreenCaptureKitWindowSnapshot], png: Data, error: Error? = nil) {
        self.snapshots = snapshots
        self.png = png
        self.error = error
    }

    func windowSnapshots() async throws -> [ScreenCaptureKitWindowSnapshot] { snapshots }

    func capturePNG(_ request: ScreenCaptureKitCaptureRequest) async throws -> Data {
        requests.append(request)
        if let error { throw error }
        return png
    }
}
