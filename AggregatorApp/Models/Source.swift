import Foundation

struct Source: Codable, Identifiable {
    let id: Int
    let name: String
    let feedURL: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case feedURL = "feed_url"
    }
}
