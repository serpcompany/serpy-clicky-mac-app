import Foundation

public struct ScreenRaster: Equatable, Sendable {
    public let encodedImage: Data

    public init(encodedImage: Data) {
        self.encodedImage = encodedImage
    }
}

public protocol ScreenWindowCaptureProviding: Sendable {
    func availableWindows() async throws -> [GuideWindowTarget]
    func captureWindow(_ target: GuideWindowTarget) async throws -> ScreenRaster
}

public protocol ScreenTextRecognizing: Sendable {
    func recognizeText(in raster: ScreenRaster) async throws -> [ScreenTextBlock]
}
