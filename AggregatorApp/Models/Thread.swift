import Foundation

struct Thread: Codable, Identifiable {
    let id: Int
    let representativeTitle: String
    let rollingSummary: String?
    let knownFacts: [String]
    let status: String
    let noveltyLabel: String?
    let firstSeen: String
    let lastUpdated: String
    let sourceCount: Int
    let memberCount: Int
    let imageURL: String?
    let hasUpdates: Bool
    let dismissed: Bool
    let topGrade: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case representativeTitle = "representative_title"
        case rollingSummary = "rolling_summary"
        case knownFacts = "known_facts"
        case status
        case noveltyLabel = "novelty_label"
        case firstSeen = "first_seen"
        case lastUpdated = "last_updated"
        case sourceCount = "source_count"
        case memberCount = "member_count"
        case imageURL = "image_url"
        case hasUpdates = "has_updates"
        case dismissed
        case topGrade = "top_grade"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(representativeTitle, forKey: .representativeTitle)
        try container.encodeIfPresent(rollingSummary, forKey: .rollingSummary)
        try container.encode(knownFacts, forKey: .knownFacts)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(noveltyLabel, forKey: .noveltyLabel)
        try container.encode(firstSeen, forKey: .firstSeen)
        try container.encode(lastUpdated, forKey: .lastUpdated)
        try container.encode(sourceCount, forKey: .sourceCount)
        try container.encode(memberCount, forKey: .memberCount)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encode(hasUpdates, forKey: .hasUpdates)
        try container.encode(dismissed, forKey: .dismissed)
        try container.encodeIfPresent(topGrade, forKey: .topGrade)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        representativeTitle = try container.decode(String.self, forKey: .representativeTitle)
        rollingSummary = try container.decodeIfPresent(String.self, forKey: .rollingSummary)
        // Absent or malformed known_facts (null, non-string items) degrades to []
        knownFacts = (try? container.decode([String].self, forKey: .knownFacts)) ?? []
        status = try container.decode(String.self, forKey: .status)
        noveltyLabel = try container.decodeIfPresent(String.self, forKey: .noveltyLabel)
        firstSeen = try container.decode(String.self, forKey: .firstSeen)
        lastUpdated = try container.decode(String.self, forKey: .lastUpdated)
        sourceCount = try container.decode(Int.self, forKey: .sourceCount)
        memberCount = try container.decode(Int.self, forKey: .memberCount)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        hasUpdates = try container.decode(Bool.self, forKey: .hasUpdates)
        dismissed = try container.decode(Bool.self, forKey: .dismissed)
        topGrade = try container.decodeIfPresent(Int.self, forKey: .topGrade)
    }
}
