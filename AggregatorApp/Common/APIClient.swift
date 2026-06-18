import Foundation

struct APIClient {
    let store: CredentialsStore

    func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: store.baseURL + path) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.setValue(store.clientId, forHTTPHeaderField: "CF-Access-Client-Id")
        request.setValue(store.clientSecret, forHTTPHeaderField: "CF-Access-Client-Secret")
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func post(_ path: String) async throws {
        guard let url = URL(string: store.baseURL + path) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(store.clientId, forHTTPHeaderField: "CF-Access-Client-Id")
        request.setValue(store.clientSecret, forHTTPHeaderField: "CF-Access-Client-Secret")
        _ = try await URLSession.shared.data(for: request)
    }

    func getSources() async throws -> [Source] {
        return try await get("/sources")
    }

    func healthCheck() async throws -> HealthResponse {
        return try await get("/healthz")
    }
}
