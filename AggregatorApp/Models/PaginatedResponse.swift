import Foundation

struct PaginatedResponse<Item: Decodable>: Decodable {
    let items: [Item]
    let nextCursor: String?

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}
