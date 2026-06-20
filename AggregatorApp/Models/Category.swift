import Foundation

struct Category: Decodable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let sortOrder: Int
    let lastActivity: String?
    let hasPriority: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case sortOrder = "sort_order"
        case lastActivity = "last_activity"
        case hasPriority = "has_priority"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        sortOrder = try container.decode(Int.self, forKey: .sortOrder)
        lastActivity = try container.decodeIfPresent(String.self, forKey: .lastActivity)
        hasPriority = try container.decodeIfPresent(Bool.self, forKey: .hasPriority) ?? false
    }
}
