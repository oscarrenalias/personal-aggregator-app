import Foundation

struct ThreadMember: Decodable, Identifiable {
    let id: Int
    let threadId: Int
    let articleId: Int
    let cleanTitle: String?
    let url: String?
    let sourceName: String?
    let publishedAt: String?
    let classificationLabel: String?
    let suppressed: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case threadId = "thread_id"
        case articleId = "article_id"
        case cleanTitle = "clean_title"
        case url
        case sourceName = "source_name"
        case publishedAt = "published_at"
        case classificationLabel = "classification_label"
        case suppressed
    }
}
