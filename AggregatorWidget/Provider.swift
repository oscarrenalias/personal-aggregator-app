import AppIntents
import Foundation
import UIKit
import WidgetKit

// MARK: - Widget State

enum WidgetState {
    case placeholder
    case loaded
    case notConfigured
    case empty
    case offline
}

// MARK: - Widget Content Item

enum WidgetContentItem: Codable {
    case thread(Thread)
    case article(Article)

    private enum CodingKeys: String, CodingKey { case type, thread, article }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .thread(let t):
            try container.encode("thread", forKey: .type)
            try container.encode(t, forKey: .thread)
        case .article(let a):
            try container.encode("article", forKey: .type)
            try container.encode(a, forKey: .article)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "thread":
            self = .thread(try container.decode(Thread.self, forKey: .thread))
        case "article":
            self = .article(try container.decode(Article.self, forKey: .article))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unknown WidgetContentItem type: \(type)"
            )
        }
    }
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

extension Thread {
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

// MARK: - Cached Entry Data

/// Metadata persisted after a successful timeline fetch so entries can be
/// reconstructed when a subsequent fetch fails. Stores the full content item
/// so offline entries render title, source, and date instead of a generic message.
private struct CachedEntryData: Codable {
    let itemId: String
    let deepLinkURL: String?
    let contentItem: WidgetContentItem?
}

// MARK: - Last Good Cache

/// Persists the last successfully fetched entry list to the shared App Group container.
private struct LastGoodCache {
    private static let appGroupID = "group.net.renalias.AggregatorApp"
    private static let fileName = "widget_last_good_entries.json"

    static func save(_ entries: [CachedEntryData]) {
        guard let url = fileURL,
              let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url)
    }

    static func load() -> [CachedEntryData]? {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([CachedEntryData].self, from: data)
    }

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
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

    func timeline(for configuration: ContentSourceIntent, in context: Context) async -> Timeline<WidgetEntry> {
        let store = CredentialsStore()
        guard store.isConfigured else {
            return Timeline(entries: [notConfiguredEntry()], policy: .never)
        }

        let client = APIClient(store: store)
        do {
            let items = try await fetchItems(client: client, source: configuration.contentSource)
            return await buildTimeline(from: items)
        } catch {
            return makeOfflineTimeline()
        }
    }

    // MARK: - Private helpers

    private func fetchItems(client: APIClient, source: ContentSource) async throws -> [WidgetContentItem] {
        switch source {
        case .latestThreads:
            let resp: PaginatedResponse<Thread> = try await client.get("/threads", query: [
                URLQueryItem(name: "sort", value: ThreadSort.importance.rawValue),
                URLQueryItem(name: "show_dismissed", value: "false"),
                URLQueryItem(name: "limit", value: "5")
            ])
            return Array(resp.items.prefix(5)).map { .thread($0) }
        case .unreadImportant:
            let resp = try await client.getArticles(
                feed: .important,
                sort: .importance,
                unreadOnly: true,
                limit: 5
            )
            return Array(resp.items.prefix(5)).map { .article($0) }
        }
    }

    private func buildTimeline(from items: [WidgetContentItem]) async -> Timeline<WidgetEntry> {
        let now = Date()
        guard !items.isEmpty else {
            return Timeline(
                entries: [emptyEntry(date: now)],
                policy: .after(now.addingTimeInterval(1800))
            )
        }

        let targetSize = CGSize(width: 155, height: 155)
        var entries: [WidgetEntry] = []
        var toCache: [CachedEntryData] = []

        for (i, item) in items.enumerated() {
            let entryDate = now.addingTimeInterval(Double(i) * 180)
            let itemId: String
            let imageURLStr: String?
            let deepLink: URL?

            switch item {
            case .thread(let t):
                itemId = "thread-\(t.id)"
                imageURLStr = t.imageURL
                deepLink = URL(string: "aggregator://thread/\(t.id)")
            case .article(let a):
                itemId = "article-\(a.id)"
                imageURLStr = a.imageURL
                deepLink = a.url.flatMap { URL(string: $0) }
            }

            let heroImage: UIImage?
            if let urlStr = imageURLStr, let url = URL(string: urlStr) {
                heroImage = await WidgetImageCache.downloadAndCache(from: url, itemId: itemId, targetSize: targetSize)
            } else {
                heroImage = nil
            }

            entries.append(WidgetEntry(
                date: entryDate,
                contentItem: item,
                heroImage: heroImage,
                deepLinkURL: deepLink,
                widgetState: .loaded,
                isPlaceholder: false
            ))
            toCache.append(CachedEntryData(itemId: itemId, deepLinkURL: deepLink?.absoluteString, contentItem: item))
        }

        WidgetImageCache.prune(retaining: Set(toCache.map(\.itemId)))
        LastGoodCache.save(toCache)

        return Timeline(entries: entries, policy: .after(now.addingTimeInterval(1800)))
    }

    private func makeOfflineTimeline() -> Timeline<WidgetEntry> {
        let now = Date()
        let targetSize = CGSize(width: 155, height: 155)

        if let cached = LastGoodCache.load(), !cached.isEmpty {
            let entries: [WidgetEntry] = cached.prefix(5).enumerated().map { i, data in
                WidgetEntry(
                    date: now.addingTimeInterval(Double(i) * 180),
                    contentItem: data.contentItem,
                    heroImage: WidgetImageCache.read(itemId: data.itemId, targetSize: targetSize),
                    deepLinkURL: data.deepLinkURL.flatMap { URL(string: $0) },
                    widgetState: .offline,
                    isPlaceholder: false
                )
            }
            return Timeline(entries: entries, policy: .after(now.addingTimeInterval(1800)))
        }

        return Timeline(
            entries: [offlineEntry(date: now)],
            policy: .after(now.addingTimeInterval(1800))
        )
    }

    private func notConfiguredEntry() -> WidgetEntry {
        WidgetEntry(
            date: .now,
            contentItem: nil,
            heroImage: nil,
            deepLinkURL: nil,
            widgetState: .notConfigured,
            isPlaceholder: false
        )
    }

    private func offlineEntry(date: Date) -> WidgetEntry {
        WidgetEntry(
            date: date,
            contentItem: nil,
            heroImage: nil,
            deepLinkURL: nil,
            widgetState: .offline,
            isPlaceholder: false
        )
    }

    private func emptyEntry(date: Date) -> WidgetEntry {
        WidgetEntry(
            date: date,
            contentItem: nil,
            heroImage: nil,
            deepLinkURL: nil,
            widgetState: .empty,
            isPlaceholder: false
        )
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
