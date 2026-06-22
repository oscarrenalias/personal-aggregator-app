import SwiftUI
import UIKit
import WidgetKit

// MARK: - Widget Entry

struct AggregatorRadarEntry: TimelineEntry {
    let date: Date
    let title: String
    let sourceName: String
    let heroImage: UIImage?
    let deepLinkURL: URL
    let publishedAt: String?
    let importanceScore: Int?
}

// MARK: - Default background

/// Dark-navy radar background rendered when an entry carries no hero image URL.
struct RadarDefaultBackground: View {
    var body: some View {
        Image("RadarDefault")
            .resizable()
            .scaledToFill()
    }
}

// MARK: - Shared widget components

struct WidgetHeroBackground: View {
    let image: UIImage?

    var body: some View {
        if let uiImage = image {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            RadarDefaultBackground()
        }
    }
}

/// Black-to-clear scrim anchored at the bottom so text over images stays legible.
struct WidgetScrim: View {
    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.7), location: 0),
                .init(color: .clear, location: 0.6)
            ],
            startPoint: .bottom,
            endPoint: .top
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: AggregatorRadarEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            WidgetScrim()

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundStyle(.white)
                Text(entry.sourceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
        .containerBackground(for: .widget) {
            WidgetHeroBackground(image: entry.heroImage)
        }
        .widgetURL(entry.deepLinkURL)
    }
}

// MARK: - Medium Widget View

struct MediumWidgetView: View {
    let entry: AggregatorRadarEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            WidgetScrim()

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.headline)
                    .lineLimit(3)
                    .foregroundStyle(.white)

                metaLine

                if let score = entry.importanceScore {
                    importanceTag(score: score)
                }
            }
            .padding(12)
        }
        .containerBackground(for: .widget) {
            WidgetHeroBackground(image: entry.heroImage)
        }
        .widgetURL(entry.deepLinkURL)
    }

    @ViewBuilder
    private var metaLine: some View {
        let relativeTime = DateDisplay.relative(entry.publishedAt)
        let parts = [entry.sourceName, relativeTime].filter { !$0.isEmpty }
        Text(parts.joined(separator: " · "))
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func importanceTag(score: Int) -> some View {
        let label = score >= 80 ? "High importance" : score >= 50 ? "Medium importance" : "Low importance"
        let tint: Color = score >= 80 ? .red : score >= 50 ? .orange : .secondary
        Text(label)
            .font(.caption.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint)
            .clipShape(Capsule())
            .accessibilityLabel("Importance: \(label)")
    }
}

// MARK: - Previews

struct WidgetViews_Previews: PreviewProvider {
    static let sampleEntry = AggregatorRadarEntry(
        date: .now,
        title: "EU regulators weigh new rules on AI model disclosure requirements",
        sourceName: "TechCrunch",
        heroImage: nil,
        deepLinkURL: URL(string: "aggregator://article/1")!,
        publishedAt: "2026-06-22T09:00:00Z",
        importanceScore: 85
    )

    static var previews: some View {
        SmallWidgetView(entry: sampleEntry)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
        MediumWidgetView(entry: sampleEntry)
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
