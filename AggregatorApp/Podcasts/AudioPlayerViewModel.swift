import AVFoundation
import Foundation
import MediaPlayer
import Observation

@Observable
final class AudioPlayerViewModel {
    private(set) var isPlaying: Bool = false
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    private(set) var playerError: Bool = false
    var isSeeking: Bool = false
    var playbackSpeed: Float = 1.0

    private var player: AVPlayer?
    private var asset: AVURLAsset?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var failObserver: NSObjectProtocol?

    init(episode: PodcastEpisode, store: CredentialsStore) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}

        let headers: [String: String] = [
            "CF-Access-Client-Id": store.clientId,
            "CF-Access-Client-Secret": store.clientSecret
        ]

        // Resolve relative audio_url against the store baseURL scheme+host.
        // The API may return either a full URL or a path like /api/v1/podcasts/1/audio.mp3.
        var urlString = episode.audioUrl
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            if let base = URLComponents(string: store.baseURL),
               let scheme = base.scheme, let host = base.host {
                let prefix = "\(scheme)://\(host)"
                urlString = prefix + (urlString.hasPrefix("/") ? "" : "/") + urlString
            }
        }

        #if DEBUG
        print("[AudioPlayer] URL: \(urlString)")
        print("[AudioPlayer] CF-Access-Client-Id set: \(!store.clientId.isEmpty)")
        print("[AudioPlayer] CF-Access-Client-Secret set: \(!store.clientSecret.isEmpty)")
        #endif

        guard let url = URL(string: urlString), url.scheme != nil else {
            #if DEBUG
            print("[AudioPlayer] ERROR: cannot parse URL '\(urlString)'")
            #endif
            playerError = true
            return
        }

        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        player.defaultRate = playbackSpeed
        self.player = player
        self.asset = asset

        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] (time: CMTime) in
            guard let self else { return }
            if let d = self.player?.currentItem?.duration {
                let secs = CMTimeGetSeconds(d)
                if secs.isFinite && secs > 0 { self.duration = secs }
            }
            guard !self.isSeeking else { return }
            self.currentTime = CMTimeGetSeconds(time)
            self.updateNowPlayingPlaybackState()
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] (_: Notification) in
            guard let self else { return }
            self.isPlaying = false
            self.currentTime = 0
            self.player?.seek(to: .zero)
            self.updateNowPlayingPlaybackState()
        }

        failObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.failedToPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] (_: Notification) in
            self?.playerError = true
        }

        setupNowPlaying(episode: episode)
        setupRemoteCommands()
    }

    /// Proactively loads the asset duration via async AVFoundation API.
    /// Call from the view's .task so the scrubber shows the correct total
    /// before the user taps play. Also surfaces load failures to the UI.
    func loadDuration() async {
        guard let asset, let item = player?.currentItem else { return }
        do {
            let d = try await asset.load(.duration)
            let secs = CMTimeGetSeconds(d)
            if secs.isFinite && secs > 0 {
                duration = secs
                updateNowPlayingPlaybackState()
            }
            #if DEBUG
            print("[AudioPlayer] loadDuration: \(secs)s, item.status=\(item.status.rawValue)")
            #endif
        } catch {
            #if DEBUG
            print("[AudioPlayer] loadDuration error: \(error)")
            #endif
            if item.status == .failed {
                #if DEBUG
                print("[AudioPlayer] Player item error: \(String(describing: item.error))")
                #endif
                playerError = true
            }
        }
    }

    func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
        updateNowPlayingPlaybackState()
    }

    func seek(to seconds: Double) {
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 1000))
        isSeeking = false
        currentTime = seconds
        updateNowPlayingPlaybackState()
    }

    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        player?.defaultRate = speed
        if isPlaying { player?.rate = speed }
    }

    deinit {
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        if let failObserver { NotificationCenter.default.removeObserver(failObserver) }

        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func setupNowPlaying(episode: PodcastEpisode) {
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = "Daily Podcast"
        info[MPMediaItemPropertyArtist] = DateDisplay.mediumDate(episode.date)
        info[MPNowPlayingInfoPropertyPlaybackRate] = Float(0.0)
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = Double(0.0)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause()
            return .success
        }

        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self, !self.isPlaying else { return .success }
            self.togglePlayPause()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self, self.isPlaying else { return .success }
            self.togglePlayPause()
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self.seek(to: posEvent.positionTime)
            return .success
        }
    }

    private func updateNowPlayingPlaybackState() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? Float(1.0) : Float(0.0)
        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
