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

// MARK: - Small Widget View

struct SmallWidgetView: View {
    let entry: AggregatorRadarEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Scrim: black at bottom fading to clear, so title text is always legible
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.7), location: 0),
                    .init(color: .clear, location: 0.6)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

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
            heroBackground
        }
        .widgetURL(entry.deepLinkURL)
    }

    @ViewBuilder
    private var heroBackground: some View {
        if let uiImage = entry.heroImage {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            RadarDefaultBackground()
        }
    }
}

// MARK: - Previews

struct SmallWidgetView_Previews: PreviewProvider {
    static let sampleEntry = AggregatorRadarEntry(
        date: .now,
        title: "EU regulators weigh new rules on AI model disclosure requirements",
        sourceName: "TechCrunch",
        heroImage: nil,
        deepLinkURL: URL(string: "aggregator://article/1")!
    )

    static var previews: some View {
        SmallWidgetView(entry: sampleEntry)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
