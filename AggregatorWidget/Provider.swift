import UIKit

// MARK: - Widget Image Cache

/// Image cache backed by the App Group container.
/// Cache directory is created lazily on first write.
/// Call `prune(retaining:)` on every timeline build to keep the container bounded.
struct WidgetImageCache {
    static let appGroupID = "group.net.renalias.AggregatorApp"
    private static let directoryName = "WidgetImageCache"

    /// Cache filename encodes both itemId and targetSize.
    /// Format: "<itemId>_<w>x<h>.cache"
    static func cacheFileName(itemId: String, targetSize: CGSize) -> String {
        "\(itemId)_\(Int(targetSize.width))x\(Int(targetSize.height)).cache"
    }

    static func read(itemId: String, targetSize: CGSize) -> UIImage? {
        guard let dir = cacheDirectory else { return nil }
        let file = dir.appendingPathComponent(cacheFileName(itemId: itemId, targetSize: targetSize))
        guard let data = try? Data(contentsOf: file) else { return nil }
        return UIImage(data: data)
    }

    static func write(_ image: UIImage, itemId: String, targetSize: CGSize) {
        guard let dir = cacheDirectory else { return }
        ensureDirectoryExists(dir)
        let file = dir.appendingPathComponent(cacheFileName(itemId: itemId, targetSize: targetSize))
        try? image.pngData()?.write(to: file)
    }

    /// Returns a cached image if available; otherwise downloads, downsamples, caches, and returns it.
    static func downloadAndCache(from url: URL, itemId: String, targetSize: CGSize) async -> UIImage? {
        if let cached = read(itemId: itemId, targetSize: targetSize) {
            return cached
        }
        guard let image = await ImageDownsampler.downloadAndDownsample(url: url, targetSize: targetSize) else {
            return nil
        }
        write(image, itemId: itemId, targetSize: targetSize)
        return image
    }

    /// Deletes cached files for any item id not present in `itemIds`.
    /// Splits each filename at the last underscore to recover the item id portion.
    static func prune(retaining itemIds: Set<String>) {
        guard let dir = cacheDirectory,
              let contents = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil
              )
        else { return }
        for url in contents {
            let stem = url.deletingPathExtension().lastPathComponent
            guard let range = stem.range(of: "_", options: .backwards) else { continue }
            let itemId = String(stem[stem.startIndex..<range.lowerBound])
            if !itemIds.contains(itemId) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private static var cacheDirectory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    private static func ensureDirectoryExists(_ url: URL) {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
}
