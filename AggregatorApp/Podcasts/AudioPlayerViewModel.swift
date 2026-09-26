import AVFoundation
import Foundation
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
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    init(episode: PodcastEpisode, store: CredentialsStore) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}

        let headers: [String: String] = [
            "CF-Access-Client-Id": store.clientId,
            "CF-Access-Client-Secret": store.clientSecret
        ]

        guard let url = URL(string: episode.audioUrl) else {
            playerError = true
            return
        }

        // "AVURLAssetHTTPHeaderFieldsKey" used as string literal — the typed constant
        // is not available in all SDK versions; the string form is stable since iOS 10.
        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        player.defaultRate = playbackSpeed
        self.player = player

        // Capture duration inside the periodic observer rather than via KVO — avoids
        // NSKeyValueObservation type-inference ambiguity inside @Observable classes.
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] (time: CMTime) in
            guard let self else { return }
            if let d = self.player?.currentItem?.duration {
                let secs = CMTimeGetSeconds(d)
                if secs.isFinite && secs > 0 { self.duration = secs }
            }
            guard !self.isSeeking else { return }
            self.currentTime = CMTimeGetSeconds(time)
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
    }

    func seek(to seconds: Double) {
        player?.seek(to: CMTime(seconds: seconds, preferredTimescale: 1000))
        isSeeking = false
        currentTime = seconds
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
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }
}
