import UIKit

/// Loads and memory-caches images from arbitrary URLs (e.g. article/thread hero
/// images). Used instead of `AsyncImage`, which can silently fail to render
/// inside lazy paging containers (`LazyHStack` + `containerRelativeFrame`).
///
/// Concurrent requests for the same URL are deduplicated. All failures are
/// swallowed; callers receive nil.
actor RemoteImageLoader {
    static let shared = RemoteImageLoader()

    private let memoryCache = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    private init() {
        memoryCache.countLimit = 80
    }

    func image(for url: URL) async -> UIImage? {
        if let cached = memoryCache.object(forKey: url as NSURL) {
            return cached
        }
        if let existing = inFlight[url] {
            return await existing.value
        }
        let task = Task<UIImage?, Never> {
            defer { inFlight.removeValue(forKey: url) }
            guard let (data, response) = try? await URLSession.shared.data(from: url) else { return nil }
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { return nil }
            guard let image = UIImage(data: data) else { return nil }
            memoryCache.setObject(image, forKey: url as NSURL)
            return image
        }
        inFlight[url] = task
        return await task.value
    }
}
