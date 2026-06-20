import Foundation

struct Source: Codable, Identifiable {
    let id: Int
    let name: String
    let feedURL: String
    let hasNew: Bool
    let hasPriority: Bool

    enum CodingKeys: String, CodingKey {
        case id, name
        case feedURL = "feed_url"
        case hasNew = "has_new"
        case hasPriority = "has_priority"
    }

    init(id: Int, name: String, feedURL: String, hasNew: Bool, hasPriority: Bool) {
        self.id = id
        self.name = name
        self.feedURL = feedURL
        self.hasNew = hasNew
        self.hasPriority = hasPriority
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        feedURL = try container.decode(String.self, forKey: .feedURL)
        hasNew = try container.decodeIfPresent(Bool.self, forKey: .hasNew) ?? false
        hasPriority = try container.decodeIfPresent(Bool.self, forKey: .hasPriority) ?? false
    }
}
