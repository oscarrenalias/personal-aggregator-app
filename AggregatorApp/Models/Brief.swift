import Foundation

struct Brief: Decodable, Identifiable {
    let id: Int
    let headline: String?
    let intro: String?
    let generatedAt: String?
    let periodStart: String
    let periodEnd: String
    let model: String?
    let topics: [BriefTopic]

    enum CodingKeys: String, CodingKey {
        case id, headline, intro, model, topics
        case generatedAt = "generated_at"
        case periodStart = "period_start"
        case periodEnd = "period_end"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        headline = try container.decodeIfPresent(String.self, forKey: .headline)
        intro = try container.decodeIfPresent(String.self, forKey: .intro)
        generatedAt = try container.decodeIfPresent(String.self, forKey: .generatedAt)
        periodStart = try container.decode(String.self, forKey: .periodStart)
        periodEnd = try container.decode(String.self, forKey: .periodEnd)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        topics = (try container.decodeIfPresent([BriefTopic].self, forKey: .topics)) ?? []
    }
}

struct BriefTopic: Decodable, Identifiable {
    var id: Int { position }
    let position: Int
    let headline: String
    let whatHappened: String
    let whyItMatters: String
    let historicalContext: String?
    let refs: [BriefRef]

    enum CodingKeys: String, CodingKey {
        case position, headline
        case whatHappened = "what_happened"
        case whyItMatters = "why_it_matters"
        case historicalContext = "historical_context"
        case refs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        position = try container.decode(Int.self, forKey: .position)
        headline = try container.decode(String.self, forKey: .headline)
        whatHappened = try container.decode(String.self, forKey: .whatHappened)
        whyItMatters = try container.decode(String.self, forKey: .whyItMatters)
        historicalContext = try container.decodeIfPresent(String.self, forKey: .historicalContext)
        refs = (try container.decodeIfPresent([BriefRef].self, forKey: .refs)) ?? []
    }
}

struct BriefRef: Decodable, Identifiable, Hashable {
    let title: String?
    let url: String?
    let `internal`: Bool
    let articleId: Int?
    var id: String { articleId.map(String.init) ?? url ?? title ?? UUID().uuidString }

    enum CodingKeys: String, CodingKey {
        case title, url
        case `internal`
        case articleId = "article_id"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        `internal` = (try container.decodeIfPresent(Bool.self, forKey: .internal)) ?? false
        articleId = try container.decodeIfPresent(Int.self, forKey: .articleId)
    }
}
