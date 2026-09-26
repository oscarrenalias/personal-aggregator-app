import SwiftUI

struct PodcastEpisodeRowView: View {
    let episode: PodcastEpisode

    private var metaLine: String {
        var parts: [String] = [DateDisplay.mediumDate(episode.date)]
        if let secs = episode.durationSeconds {
            parts.append(formatDuration(secs))
        }
        let count = episode.segmentCount
        parts.append(count == 1 ? "1 segment" : "\(count) segments")
        return parts.joined(separator: " · ")
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    private var accessibilityLabel: String {
        var parts = ["Daily Podcast", DateDisplay.mediumDate(episode.date)]
        if let secs = episode.durationSeconds {
            parts.append(formatDuration(secs))
        }
        return parts.joined(separator: ", ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(metaLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Daily Podcast")
                    .font(.headline)

                if let theme = episode.episodeTheme, !theme.isEmpty {
                    Text(theme)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            calendarBadge
        }
        .listRowBackground(Color.clear)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var calendarBadge: some View {
        if let comps = DateDisplay.monthDay(episode.date) {
            VStack(spacing: 1) {
                Text(comps.month)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
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
}
