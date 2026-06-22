import Foundation

struct Article: Codable, Identifiable {
    let id: Int
    let title: String?
    let url: String?
    let sourceId: Int
    let sourceName: String?
    let feedPublishedAt: String?
    let summary: String?
    let cleanText: String?
    let importanceScore: Int?
    let importanceReason: String?
    let topics: [String]
    let categories: [String]
    let isRead: Bool
    let isSaved: Bool
    let author: String?
    let wordCount: Int?
    let language: String?
    let imageURL: String?
    let commentsURL: String?

    enum CodingKeys: String, CodingKey {
        case id, title, url, summary, author, language
        case sourceId = "source_id"
        case sourceName = "source_name"
        case feedPublishedAt = "feed_published_at"
        case cleanText = "clean_text"
        case importanceScore = "importance_score"
        case importanceReason = "importance_reason"
        case topics, categories
        case isRead = "is_read"
        case isSaved = "is_saved"
        case wordCount = "word_count"
        case imageURL = "image_url"
        case commentsURL = "comments_url"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encode(sourceId, forKey: .sourceId)
        try container.encodeIfPresent(sourceName, forKey: .sourceName)
        try container.encodeIfPresent(feedPublishedAt, forKey: .feedPublishedAt)
        try container.encodeIfPresent(summary, forKey: .summary)
        try container.encodeIfPresent(cleanText, forKey: .cleanText)
        try container.encodeIfPresent(importanceScore, forKey: .importanceScore)
        try container.encodeIfPresent(importanceReason, forKey: .importanceReason)
        try container.encode(topics, forKey: .topics)
        try container.encode(categories, forKey: .categories)
        try container.encode(isRead, forKey: .isRead)
        try container.encode(isSaved, forKey: .isSaved)
        try container.encodeIfPresent(author, forKey: .author)
        try container.encodeIfPresent(wordCount, forKey: .wordCount)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encodeIfPresent(commentsURL, forKey: .commentsURL)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        sourceId = try container.decode(Int.self, forKey: .sourceId)
        sourceName = try container.decodeIfPresent(String.self, forKey: .sourceName)
        feedPublishedAt = try container.decodeIfPresent(String.self, forKey: .feedPublishedAt)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        cleanText = try container.decodeIfPresent(String.self, forKey: .cleanText)
        importanceScore = try container.decodeIfPresent(Int.self, forKey: .importanceScore)
        importanceReason = try container.decodeIfPresent(String.self, forKey: .importanceReason)
        // Defensive: backend may omit or null these arrays; treat both as empty rather than failing decode.
        topics = (try? container.decodeIfPresent([String].self, forKey: .topics)).flatMap { $0 } ?? []
        categories = (try? container.decodeIfPresent([String].self, forKey: .categories)).flatMap { $0 } ?? []
        isRead = try container.decode(Bool.self, forKey: .isRead)
        isSaved = try container.decode(Bool.self, forKey: .isSaved)
        author = try container.decodeIfPresent(String.self, forKey: .author)
        wordCount = try container.decodeIfPresent(Int.self, forKey: .wordCount)
        language = try container.decodeIfPresent(String.self, forKey: .language)
        // imageURL: backend field is absent today; try? future-proofs against type changes without breaking decode.
        imageURL = (try? container.decodeIfPresent(String.self, forKey: .imageURL)).flatMap { $0 }
        // commentsURL: not yet in the API response; decodeIfPresent treats a missing key as nil without failing decode.
        commentsURL = try container.decodeIfPresent(String.self, forKey: .commentsURL)
    }
}
