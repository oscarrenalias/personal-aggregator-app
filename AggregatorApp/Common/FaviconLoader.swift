import UIKit

/// Loads and caches favicons from DuckDuckGo's icon service.
///
/// Lookup order: in-memory NSCache → on-disk Caches/favicons/ → network.
/// All failures are swallowed; callers receive nil on any error.
/// Concurrent requests for the same host are deduplicated via in-flight task tracking.
actor FaviconLoader {
    static let shared = FaviconLoader()

    private let memoryCache = NSCache<NSString, UIImage>()
    private var inFlightTasks: [String: Task<UIImage?, Never>] = [:]

    private init() {}

    // MARK: - Public

    /// Derives the DuckDuckGo favicon URL for a given feed URL.
    /// Returns nil if `feedURL` cannot be parsed or has no host component.
    static func iconURL(forFeedURL feedURL: String) -> URL? {
        guard let host = URLComponents(string: feedURL)?.host, !host.isEmpty else { return nil }
        return URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico")
    }

    func icon(forFeedURL feedURL: String) async -> UIImage? {
        guard let host = URLComponents(string: feedURL)?.host, !host.isEmpty else { return nil }

        if let cached = memoryCache.object(forKey: host as NSString) {
            return cached
        }

        if let existing = inFlightTasks[host] {
            return await existing.value
        }

        let task = Task<UIImage?, Never> {
            defer { inFlightTasks.removeValue(forKey: host) }
            return await self.resolve(host: host)
        }
        inFlightTasks[host] = task
        return await task.value
    }

    // MARK: - Private

    private func resolve(host: String) async -> UIImage? {
        if let image = readFromDisk(host: host) {
            memoryCache.setObject(image, forKey: host as NSString)
            return image
        }
        return await fetchFromNetwork(host: host)
    }

    private func diskURL(for host: String) -> URL? {
        let sanitized = host.replacingOccurrences(of: ":", with: "_")
        return FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("favicons/\(sanitized).png")
    }

    private func readFromDisk(host: String) -> UIImage? {
        guard let url = diskURL(for: host),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private func fetchFromNetwork(host: String) async -> UIImage? {
        guard let iconURL = URL(string: "https://icons.duckduckgo.com/ip3/\(host).ico"),
              let (data, response) = try? await URLSession.shared.data(from: iconURL),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let image = UIImage(data: data) else { return nil }
        writeToDisk(data: data, host: host)
        memoryCache.setObject(image, forKey: host as NSString)
        return image
    }

    private func writeToDisk(data: Data, host: String) {
        guard let url = diskURL(for: host) else { return }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url)
        } catch {}
    }
}
