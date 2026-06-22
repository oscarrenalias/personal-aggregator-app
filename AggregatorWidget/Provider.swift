import AppIntents
import UIKit
import WidgetKit

// MARK: - Widget State

enum WidgetState {
    case placeholder
    case loaded
    case error(String)
}

// MARK: - Widget Content Item

enum WidgetContentItem {
    case thread(Thread)
    case article(Article)
}

// MARK: - Widget Entry

struct WidgetEntry: TimelineEntry {
    let date: Date
    let contentItem: WidgetContentItem?
    let heroImage: UIImage?
    let deepLinkURL: URL?
    let widgetState: WidgetState
    let isPlaceholder: Bool
}

// MARK: - Sample Data

private extension Thread {
    // JSON is a hardcoded literal — force-try is safe; this never touches the network.
    static var sample: Thread {
        let json = Data("""
        {"id":1,"representative_title":"Swift 6 Concurrency Lands in Open Source",
         "rolling_summary":"The Swift community merges the full strict-concurrency model into the main branch.",
         "known_facts":["Actors replace locks for shared state","Sendable propagation is exhaustive"],
         "status":"active","novelty_label":"new",
         "first_seen":"2026-06-01T10:00:00Z","last_updated":"2026-06-22T09:00:00Z",
         "source_count":4,"member_count":12,"image_url":null,
         "has_updates":true,"dismissed":false,"top_grade":90}
        """.utf8)
        return try! JSONDecoder().decode(Thread.self, from: json)
    }
}

// MARK: - Timeline Provider

struct AggregatorRadarProvider: AppIntentTimelineProvider {
    typealias Intent = ContentSourceIntent
    typealias Entry = WidgetEntry

    func placeholder(in context: Context) -> WidgetEntry {
        WidgetEntry(
            date: .now,
            contentItem: .thread(.sample),
            heroImage: nil,
            deepLinkURL: nil,
            widgetState: .placeholder,
            isPlaceholder: true
        )
    }

    func snapshot(for configuration: ContentSourceIntent, in context: Context) async -> WidgetEntry {
        WidgetEntry(
            date: .now,
            contentItem: .thread(.sample),
            heroImage: nil,
            deepLinkURL: URL(string: "aggregator://thread/1"),
            widgetState: .loaded,
            isPlaceholder: false
        )
    }

    // Full timeline fetch with live network data is implemented in a downstream bead.
    func timeline(for configuration: ContentSourceIntent, in context: Context) async -> Timeline<WidgetEntry> {
        let entry = WidgetEntry(
            date: .now,
            contentItem: .thread(.sample),
            heroImage: nil,
            deepLinkURL: URL(string: "aggregator://thread/1"),
            widgetState: .loaded,
            isPlaceholder: false
        )
        return Timeline(entries: [entry], policy: .never)
    }
}

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
