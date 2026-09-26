import SwiftUI
import AVFoundation

private func formatTime(_ seconds: Double) -> String {
    guard seconds.isFinite && seconds >= 0 else { return "0:00" }
    let total = Int(seconds)
    return String(format: "%d:%02d", total / 60, total % 60)
}

struct PodcastPlayerView: View {
    let episode: PodcastEpisode
    @Environment(CredentialsStore.self) private var credentialsStore
    // Initialized lazily in .task to ensure @Observable tracking is wired up
    // correctly by SwiftUI before the first view body evaluation.
    @State private var viewModel: AudioPlayerViewModel?
    @State private var dragTime: Double = 0

    var body: some View {
        Group {
            if let vm = viewModel {
                if vm.playerError {
                    ContentUnavailableView("Cannot play episode", systemImage: "exclamationmark.triangle")
                } else {
                    playerContent(vm: vm)
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Episode")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard viewModel == nil else { return }
            let vm = AudioPlayerViewModel(episode: episode, store: credentialsStore)
            viewModel = vm
            await vm.loadDuration()
        }
    }

    private func playerContent(vm: AudioPlayerViewModel) -> some View {
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

                Slider(
                    value: Binding(
                        get: { vm.isSeeking ? dragTime : vm.currentTime },
                        set: { dragTime = $0; vm.isSeeking = true }
                    ),
                    in: 0...max(vm.duration, 1),
                    onEditingChanged: { editing in
                        if editing {
                            dragTime = vm.currentTime
                            vm.isSeeking = true
                        } else {
                            vm.seek(to: dragTime)
                        }
                    }
                )
                .accessibilityLabel("Playback position")

                HStack {
                    Text(formatTime(vm.currentTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatTime(vm.duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    vm.togglePlayPause()
                } label: {
                    Image(systemName: vm.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                }
                .accessibilityLabel(vm.isPlaying ? "Pause" : "Play")

                Picker("Speed", selection: Binding(
                    get: { vm.playbackSpeed },
                    set: { vm.setSpeed($0) }
                )) {
                    Text("1×").tag(Float(1.0))
                    Text("1.5×").tag(Float(1.5))
                    Text("2×").tag(Float(2.0))
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, ReaderLayout.hPadding)
            .padding(.vertical, 24)
        }
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
}
