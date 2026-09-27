import XCTest
import MediaPlayer
@testable import AggregatorApp

final class AudioPlayerViewModelTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "test-audio-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeFakeStore(clientId: String = "test-id", clientSecret: String = "test-secret") -> CredentialsStore {
        CredentialsStore(
            defaults: defaults,
            keychainRead: { key in
                if key == "aggregator.clientId" { return clientId }
                if key == "aggregator.clientSecret" { return clientSecret }
                return nil
            },
            keychainWrite: { _, _ in }
        )
    }

    private func makeFakeEpisode(date: String = "2024-01-15") throws -> PodcastEpisode {
        let json = """
        {
            "id": 99,
            "date": "\(date)",
            "status": "ready",
            "audio_url": "https://example.com/test.mp3",
            "segment_count": 1,
            "created_at": "2024-01-15T07:00:00+00:00"
        }
        """
        return try JSONDecoder().decode(PodcastEpisode.self, from: Data(json.utf8))
    }

    // MARK: - Background audio capability

    func testAudioBackgroundModeConfiguredInPlist() {
        let modes = Bundle.main.infoDictionary?["UIBackgroundModes"] as? [String]
        XCTAssertNotNil(modes, "UIBackgroundModes must be present in Info.plist for background audio")
        XCTAssertTrue(modes?.contains("audio") == true,
                      "UIBackgroundModes must include 'audio' so the app can play in the background")
    }

    // MARK: - MPNowPlayingInfoCenter metadata

    func testNowPlayingInfoTitleSetOnInit() throws {
        let episode = try makeFakeEpisode()
        let viewModel = AudioPlayerViewModel(episode: episode, store: makeFakeStore())
        defer { _ = viewModel }

        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        XCTAssertNotNil(info, "nowPlayingInfo must be set after init")
        XCTAssertEqual(info?[MPMediaItemPropertyTitle] as? String, "Daily Podcast")
    }

    func testNowPlayingInfoArtistIsFormattedEpisodeDate() throws {
        let episode = try makeFakeEpisode(date: "2024-01-15")
        let viewModel = AudioPlayerViewModel(episode: episode, store: makeFakeStore())
        defer { _ = viewModel }

        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        XCTAssertNotNil(info)
        let expectedArtist = DateDisplay.mediumDate("2024-01-15")
        XCTAssertFalse(expectedArtist.isEmpty, "DateDisplay.mediumDate must produce a non-empty string")
        XCTAssertEqual(info?[MPMediaItemPropertyArtist] as? String, expectedArtist)
    }

    func testNowPlayingPlaybackRateIsZeroAfterInit() throws {
        let episode = try makeFakeEpisode()
        let viewModel = AudioPlayerViewModel(episode: episode, store: makeFakeStore())
        defer { _ = viewModel }

        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        XCTAssertNotNil(info)
        let rate = info?[MPNowPlayingInfoPropertyPlaybackRate] as? Float
        XCTAssertEqual(rate, 0.0, "Playback rate must be 0.0 (paused) immediately after init")
    }

    // MARK: - updateNowPlayingPlaybackState via seek

    func testSeekUpdatesNowPlayingElapsedTime() throws {
        let episode = try makeFakeEpisode()
        let viewModel = AudioPlayerViewModel(episode: episode, store: makeFakeStore())

        viewModel.seek(to: 42.5)

        let info = MPNowPlayingInfoCenter.default().nowPlayingInfo
        XCTAssertNotNil(info)
        let elapsed = info?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double
        XCTAssertEqual(elapsed ?? -1, 42.5, accuracy: 0.01)
        _ = viewModel
    }

    // MARK: - deinit cleanup

    func testNowPlayingInfoClearedOnDeinit() throws {
        let episode = try makeFakeEpisode()
        let store = makeFakeStore()

        do {
            let viewModel = AudioPlayerViewModel(episode: episode, store: store)
            XCTAssertNotNil(MPNowPlayingInfoCenter.default().nowPlayingInfo,
                            "nowPlayingInfo must be populated while the view model is alive")
            _ = viewModel
        }
        // viewModel goes out of scope → deinit called synchronously
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo,
                     "nowPlayingInfo must be cleared in deinit to avoid ghost lock-screen session")
    }
}
