import Foundation

enum ThreadSort: String {
    case importance
    case recent
}

enum APIError: Error, LocalizedError {
    case cloudflareRejected
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

    func getThread(id: Int) async throws -> Thread {
        return try await get("/threads/\(id)")
    }

    func getThreadMembers(id: Int, cursor: String? = nil) async throws -> PaginatedResponse<ThreadMember> {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "50"),
        ]
        if let cursor {
            query.append(URLQueryItem(name: "cursor", value: cursor))
        }
        return try await get("/threads/\(id)/members", query: query)
    }

    func getArticle(id: Int) async throws -> Article {
        return try await get("/articles/\(id)")
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
