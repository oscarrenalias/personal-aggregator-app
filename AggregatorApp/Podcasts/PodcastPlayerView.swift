import SwiftUI
import AVFoundation

private func formatTime(_ seconds: Double) -> String {
    guard seconds.isFinite && seconds >= 0 else { return "0:00" }
    let total = Int(seconds)
    return String(format: "%d:%02d", total / 60, total % 60)
}

struct PodcastPlayerView: View {
    let episode: PodcastEpisode
    @State private var viewModel: AudioPlayerViewModel
    // Local drag tracking: currentTime is private(set) on the ViewModel; we track
    // the scrubber position here during active drags and commit via seek(to:) on release.
    @State private var dragTime: Double = 0

    init(episode: PodcastEpisode, credentialsStore: CredentialsStore) {
        self.episode = episode
        _viewModel = State(wrappedValue: AudioPlayerViewModel(episode: episode, store: credentialsStore))
    }

    var body: some View {
        Group {
            if viewModel.playerError {
                ContentUnavailableView("Cannot play episode", systemImage: "exclamationmark.triangle")
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        calendarBadge
                            .frame(maxWidth: .infinity)

                        Text("Daily Podcast")
                            .font(.title2.bold())
                            .multilineTextAlignment(.center)

                        metaLine

                        if let theme = episode.episodeTheme {
                            ParagraphText(theme)
                        }

                        scrubber

                        timeLabels

                        playPauseButton

                        speedPicker
                    }
                    .padding(.horizontal, ReaderLayout.hPadding)
                    .padding(.vertical, 24)
                }
            }
        }
        .navigationTitle("Episode")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var calendarBadge: some View {
        if let comps = DateDisplay.monthDay(episode.date) {
            VStack(spacing: 1) {
                Text(comps.month)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.tint)
                Text(comps.day)
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
            .frame(width: 48, height: 48)
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
            .accessibilityHidden(true)
        }
    }

    private var metaLine: some View {
        let datePart = DateDisplay.mediumDate(episode.date)
        let segmentPart = episode.segmentCount == 1 ? "1 segment" : "\(episode.segmentCount) segments"
        return Text("\(datePart) · \(segmentPart)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var scrubber: some View {
        Slider(
            value: Binding(
                get: { viewModel.isSeeking ? dragTime : viewModel.currentTime },
                set: { dragTime = $0; viewModel.isSeeking = true }
            ),
            in: 0...max(viewModel.duration, 1)
        )
        .onEditingChanged { editing in
            if editing {
                dragTime = viewModel.currentTime
                viewModel.isSeeking = true
            } else {
                viewModel.seek(to: dragTime)
            }
        }
        .accessibilityLabel("Playback position")
    }

    private var timeLabels: some View {
        HStack {
            Text(formatTime(viewModel.currentTime))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(formatTime(viewModel.duration))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var playPauseButton: some View {
        Button {
            viewModel.togglePlayPause()
        } label: {
            Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: 64))
        }
        .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")
    }

    private var speedPicker: some View {
        Picker("Speed", selection: Binding(
            get: { viewModel.playbackSpeed },
            set: { viewModel.setSpeed($0) }
        )) {
            Text("1×").tag(Float(1.0))
            Text("1.5×").tag(Float(1.5))
            Text("2×").tag(Float(2.0))
        }
        .pickerStyle(.segmented)
    }
}
