import Foundation

struct PodcastEpisode: Codable, Identifiable {
    let id: Int
    let date: String
    let episodeTheme: String?
    let status: String
    let durationSeconds: Int?
    let audioUrl: String
    let segmentCount: Int
    let llmModel: String?
    let ttsModel: String?
    let ttsVoice: String?
    let generatedAt: String?
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, date, status
        case episodeTheme    = "episode_theme"
        case durationSeconds = "duration_seconds"
        case audioUrl        = "audio_url"
        case segmentCount    = "segment_count"
        case llmModel        = "llm_model"
        case ttsModel        = "tts_model"
        case ttsVoice        = "tts_voice"
        case generatedAt     = "generated_at"
        case createdAt       = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        date = try container.decode(String.self, forKey: .date)
        episodeTheme = try container.decodeIfPresent(String.self, forKey: .episodeTheme)
        status = try container.decode(String.self, forKey: .status)
        durationSeconds = try container.decodeIfPresent(Int.self, forKey: .durationSeconds)
        audioUrl = try container.decode(String.self, forKey: .audioUrl)
        segmentCount = try container.decode(Int.self, forKey: .segmentCount)
        llmModel = try container.decodeIfPresent(String.self, forKey: .llmModel)
        ttsModel = try container.decodeIfPresent(String.self, forKey: .ttsModel)
        ttsVoice = try container.decodeIfPresent(String.self, forKey: .ttsVoice)
        generatedAt = try container.decodeIfPresent(String.self, forKey: .generatedAt)
        createdAt = try container.decode(String.self, forKey: .createdAt)
    }
}
