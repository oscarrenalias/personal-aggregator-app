import Foundation

/// Sort order for the `/threads` list endpoint.
enum ThreadSort: String {
    /// Rank by backend-computed importance score (default).
    case importance
    /// Most recently updated first.
    case recent
}

/// Sort order for the `/articles` list endpoint.
enum ArticleSort: String {
    /// Rank by backend-computed importance score (default).
    case importance
    /// Most recently published first.
    case recent
}

enum APIError: Error, LocalizedError {
    /// The backend returned 403 with an HTML body — Cloudflare Access rejected the request.
    /// Check that CF-Access credentials in Keychain are valid and not expired.
    case cloudflareRejected
    /// The backend returned a non-2xx status that is not a Cloudflare rejection.
    case http(status: Int)

    var errorDescription: String? {
        switch self {
        case .cloudflareRejected:
            return "Access denied by Cloudflare. Check your CF-Access credentials."
        case .http(let status):
            return "Server returned HTTP \(status)."
        }
    }
}

/// Thin HTTP client for the aggregator backend.
///
/// Every request URL is constructed by appending `path` to `store.baseURL`
/// (e.g. `baseURL = "https://…/api/v1"`, `path = "/sources"` → `"https://…/api/v1/sources"`).
/// `CF-Access-Client-Id` and `CF-Access-Client-Secret` headers are injected automatically from
/// `CredentialsStore` on every request. A 403 response with an HTML body is a Cloudflare Access
/// rejection, not an API error.
struct APIClient {
    let store: CredentialsStore

    /// Builds a URL from a base URL string, a path, and optional query items via URLComponents.
    /// Returns nil if `baseURL + path` cannot be parsed (rather than crashing).
    /// Query parameter values are percent-encoded automatically by URLComponents.
    static func makeURL(baseURL: String, path: String, query: [URLQueryItem] = []) -> URL? {
        guard var components = URLComponents(string: baseURL + path) else { return nil }
        if !query.isEmpty {
            components.queryItems = query
        }
        return components.url
    }

    /// Performs an authenticated GET request and decodes the response body as `T`.
    /// - Parameters:
    ///   - path: Path relative to `store.baseURL` (e.g. `"/threads"`).
    ///   - query: Optional query parameters; values are percent-encoded automatically.
    /// - Throws: `APIError.cloudflareRejected` on a 403 HTML response, `APIError.http` on any
    ///   other non-2xx status, or a `DecodingError` / `URLError` on malformed data or bad URL.
    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        guard let url = APIClient.makeURL(baseURL: store.baseURL, path: path, query: query) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.setValue(store.clientId, forHTTPHeaderField: "CF-Access-Client-Id")
        request.setValue(store.clientSecret, forHTTPHeaderField: "CF-Access-Client-Secret")
        let (data, response) = try await URLSession.shared.data(for: request)
        try inspectResponse(response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Performs an authenticated POST request and discards the response body.
    /// - Parameter path: Path relative to `store.baseURL` (e.g. `"/articles/42/read"`).
    /// - Throws: `APIError.cloudflareRejected`, `APIError.http`, or `URLError` on failure.
    func post(_ path: String) async throws {
        guard let url = APIClient.makeURL(baseURL: store.baseURL, path: path) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(store.clientId, forHTTPHeaderField: "CF-Access-Client-Id")
        request.setValue(store.clientSecret, forHTTPHeaderField: "CF-Access-Client-Secret")
        let (data, response) = try await URLSession.shared.data(for: request)
        try inspectResponse(response, data: data)
    }

    func getSources() async throws -> [Source] {
        return try await get("/sources")
    }

    func healthCheck() async throws -> HealthResponse {
        return try await get("/healthz")
    }

    /// Fetches a paginated list of threads.
    /// - Parameters:
    ///   - sort: Controls ranking — `.importance` or `.recent`.
    ///   - showDismissed: Pass `true` to include dismissed threads in results.
    ///   - cursor: Opaque pagination cursor from the previous page; `nil` fetches the first page.
    func getThreads(sort: ThreadSort, showDismissed: Bool, cursor: String? = nil) async throws -> PaginatedResponse<Thread> {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "sort", value: sort.rawValue),
            URLQueryItem(name: "show_dismissed", value: showDismissed ? "true" : "false"),
            URLQueryItem(name: "limit", value: "50"),
        ]
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return try await get("/threads", query: query)
    }

    /// Fetches the full detail for a single thread by its numeric ID.
    func getThread(id: Int) async throws -> Thread {
        return try await get("/threads/\(id)")
    }

    /// Fetches a paginated list of articles (members) belonging to a thread.
    /// - Parameters:
    ///   - id: The thread's numeric ID.
    ///   - cursor: Opaque pagination cursor; `nil` fetches the first page.
    func getThreadMembers(id: Int, cursor: String? = nil) async throws -> PaginatedResponse<ThreadMember> {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "50"),
        ]
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return try await get("/threads/\(id)/members", query: query)
    }

    /// Fetches a single article by its numeric ID. Does not mark the article as read.
    func getArticle(id: Int) async throws -> Article {
        return try await get("/articles/\(id)")
    }

    /// Fetches a paginated list of articles for the given feed.
    /// - Parameters:
    ///   - feed: The feed to query. `.source(id:name:)` sends `source_id=<id>`;
    ///     `.important` sends `view=important`; `.unread` sends `view=unread`.
    ///   - sort: Controls ranking — `.importance` or `.recent`.
    ///   - unreadOnly: When `true`, adds `unread_only=true`; param is omitted when `false`.
    ///   - limit: Page size (default 25).
    ///   - cursor: Opaque pagination cursor from the previous page; `nil` fetches the first page.
    func getArticles(feed: ArticleFeed, sort: ArticleSort, unreadOnly: Bool, limit: Int = 25, cursor: String? = nil) async throws -> PaginatedResponse<Article> {
        var query: [URLQueryItem] = []
        switch feed {
        case .source(let id, _):
            query.append(URLQueryItem(name: "source_id", value: "\(id)"))
        case .important:
            query.append(URLQueryItem(name: "view", value: "important"))
        case .unread:
            query.append(URLQueryItem(name: "view", value: "unread"))
        }
        query.append(URLQueryItem(name: "sort", value: sort.rawValue))
        if unreadOnly {
            query.append(URLQueryItem(name: "unread_only", value: "true"))
        }
        query.append(URLQueryItem(name: "limit", value: "\(limit)"))
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return try await get("/articles", query: query)
    }

    /// Fetches today's generated brief.
    ///
    /// A 404 surfaces as `APIError.http(status: 404)`. `TodayView` treats this as the
    /// empty state (no brief generated yet for today) rather than a hard error.
    func getTodayBrief() async throws -> Brief {
        return try await get("/brief/today")
    }

    /// Fetches a paginated list of briefs.
    /// - Parameters:
    ///   - cursor: Opaque pagination cursor from the previous page; `nil` fetches the first page.
    ///   - limit: Page size.
    func getBriefs(cursor: String? = nil, limit: Int) async throws -> PaginatedResponse<Brief> {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)"),
        ]
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return try await get("/briefs", query: query)
    }

    // MARK: - Write endpoints

    /// Dismisses a thread so it no longer appears in the default (non-dismissed) listing.
    func dismissThread(id: Int) async throws {
        try await post("/threads/\(id)/dismiss")
    }

    /// Restores a previously dismissed thread back into the active listing.
    func restoreThread(id: Int) async throws {
        try await post("/threads/\(id)/restore")
    }

    /// Marks an article as read. Use `getArticle` to fetch without side effects.
    func markArticleRead(id: Int) async throws {
        try await post("/articles/\(id)/read")
    }

    /// Marks a previously-read article as unread.
    func markArticleUnread(id: Int) async throws {
        try await post("/articles/\(id)/unread")
    }

    /// Saves an article to the user's saved list.
    func saveArticle(id: Int) async throws {
        try await post("/articles/\(id)/save")
    }

    /// Removes an article from the user's saved list.
    func unsaveArticle(id: Int) async throws {
        try await post("/articles/\(id)/unsave")
    }

    // MARK: - Private helpers

    private func inspectResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        let status = http.statusCode
        guard !(200...299).contains(status) else { return }
        if status == 403, !looksLikeJSON(data) {
            throw APIError.cloudflareRejected
        }
        throw APIError.http(status: status)
    }

    /// Returns true when `data` begins with `{` or `[` (ignoring leading whitespace).
    private func looksLikeJSON(_ data: Data) -> Bool {
        let whitespace: Set<UInt8> = [0x20, 0x09, 0x0A, 0x0D]
        guard let first = data.first(where: { !whitespace.contains($0) }) else { return false }
        return first == UInt8(ascii: "{") || first == UInt8(ascii: "[")
    }
}
