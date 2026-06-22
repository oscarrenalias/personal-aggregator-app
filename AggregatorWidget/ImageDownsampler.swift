import UIKit
import ImageIO

struct ImageDownsampler {
    /// Downloads an image from `url` and resizes it to `targetSize` (in points at @3x).
    /// Uses CGImageSource thumbnail API so the full-size bitmap is never fully decoded into memory.
    static func downloadAndDownsample(url: URL, targetSize: CGSize) async -> UIImage? {
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              !data.isEmpty else {
            return nil
        }
        return downsample(data: data, targetSize: targetSize)
    }

    static func downsample(data: Data, targetSize: CGSize) -> UIImage? {
        // kCGImageSourceShouldCache: false avoids storing the decoded full-size bitmap
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }

        let maxPixelSize = max(targetSize.width, targetSize.height) * 3 // @3x
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
