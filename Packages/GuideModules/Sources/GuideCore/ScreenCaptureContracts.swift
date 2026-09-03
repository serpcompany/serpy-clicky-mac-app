import Foundation

public struct ScreenRaster: Equatable, Sendable {
    public let encodedImage: Data
    public let mimeType: String
    public let pixelWidth: Int
    public let pixelHeight: Int

    public init(
        encodedImage: Data,
        mimeType: String = "image/png",
        pixelWidth: Int = 0,
        pixelHeight: Int = 0
    ) {
        self.encodedImage = encodedImage
        self.mimeType = mimeType
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }

    public var guideRaster: GuideRaster {
        GuideRaster(bytes: encodedImage, mimeType: mimeType, pixelWidth: pixelWidth, pixelHeight: pixelHeight)
    }
}

public protocol ScreenWindowCaptureProviding: Sendable {
    func availableWindows() async throws -> [GuideWindowTarget]
    func captureWindow(_ target: GuideWindowTarget) async throws -> ScreenRaster
}

public protocol ScreenTextRecognizing: Sendable {
    func recognizeText(in raster: ScreenRaster) async throws -> [ScreenTextBlock]
}
