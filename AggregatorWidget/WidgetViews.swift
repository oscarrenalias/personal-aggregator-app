import SwiftUI
import UIKit
import WidgetKit

// MARK: - Default background

struct RadarDefaultBackground: View {
    var body: some View {
        Image("RadarDefault")
            .resizable()
            .scaledToFill()
    }
}

// MARK: - Shared background components

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

// MARK: - Non-content state views

struct WidgetNotConfiguredView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "key.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .accessibilityHidden(true)
            Text("Open app to sign in")
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
        .containerBackground(for: .widget) {
            RadarDefaultBackground()
        }
        .accessibilityLabel("Widget not configured. Open app to sign in.")
    }
}

struct WidgetEmptyView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.8))
                .accessibilityHidden(true)
            Text("Nothing here yet")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
        .containerBackground(for: .widget) {
            RadarDefaultBackground()
        }
        .accessibilityLabel("No content available.")
    }
}

struct WidgetOfflineNoDataView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.8))
                .accessibilityHidden(true)
            Text("Can't update")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
        .containerBackground(for: .widget) {
            RadarDefaultBackground()
        }
        .accessibilityLabel("Widget offline, no cached content.")
    }
}

// MARK: - Content item display helpers

private extension WidgetContentItem {
    var displayTitle: String {
        switch self {
        case .thread(let t): return t.representativeTitle
        case .article(let a): return a.title ?? ""
        }
    }

    var displaySourceName: String {
        switch self {
        case .thread(let t): return t.sourceCount == 1 ? "1 source" : "\(t.sourceCount) sources"
        case .article(let a): return a.sourceName ?? ""
        }
    }

    var displayPublishedAt: String? {
        switch self {
        case .thread(let t): return t.lastUpdated
        case .article(let a): return a.feedPublishedAt
        }
    }

    var displayImportanceScore: Int? {
        switch self {
        case .thread(let t): return t.topGrade
        case .article(let a): return a.importanceScore
        }
    }
}

// MARK: - Content views (used by both small and medium when data is available)

private struct SmallContentView: View {
    let entry: WidgetEntry
    let contentItem: WidgetContentItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            WidgetScrim()
            VStack(alignment: .leading, spacing: 2) {
                Text(contentItem.displayTitle)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundStyle(.white)
                Text(contentItem.displaySourceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
        .containerBackground(for: .widget) {
            WidgetHeroBackground(image: entry.heroImage)
        }
        .widgetURL(entry.deepLinkURL)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(contentItem.displayTitle), \(contentItem.displaySourceName)")
    }
}

private struct MediumContentView: View {
    let entry: WidgetEntry
    let contentItem: WidgetContentItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            WidgetScrim()
            VStack(alignment: .leading, spacing: 4) {
                Text(contentItem.displayTitle)
                    .font(.headline)
                    .lineLimit(3)
                    .foregroundStyle(.white)
                metaLine
                if let score = contentItem.displayImportanceScore {
                    importanceTag(score: score)
                }
            }
            .padding(12)
        }
        .containerBackground(for: .widget) {
            WidgetHeroBackground(image: entry.heroImage)
        }
        .widgetURL(entry.deepLinkURL)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var metaLine: some View {
        let relativeTime = DateDisplay.relative(contentItem.displayPublishedAt)
        let parts = [contentItem.displaySourceName, relativeTime].filter { !$0.isEmpty }
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

// MARK: - Small Widget View

/// State precedence: notConfigured > empty > offline (no cache) > content.
struct SmallWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        stateView
    }

    @ViewBuilder
    private var stateView: some View {
        switch entry.widgetState {
        case .notConfigured:
            WidgetNotConfiguredView()
        case .empty:
            WidgetEmptyView()
        case .offline where entry.contentItem == nil:
            WidgetOfflineNoDataView()
        default:
            if let contentItem = entry.contentItem {
                SmallContentView(entry: entry, contentItem: contentItem)
            } else {
                WidgetEmptyView()
            }
        }
    }
}

// MARK: - Medium Widget View

/// State precedence: notConfigured > empty > offline (no cache) > content.
struct MediumWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        stateView
    }

    @ViewBuilder
    private var stateView: some View {
        switch entry.widgetState {
        case .notConfigured:
            WidgetNotConfiguredView()
        case .empty:
            WidgetEmptyView()
        case .offline where entry.contentItem == nil:
            WidgetOfflineNoDataView()
        default:
            if let contentItem = entry.contentItem {
                MediumContentView(entry: entry, contentItem: contentItem)
            } else {
                WidgetEmptyView()
            }
        }
    }
}

// MARK: - Previews

struct WidgetViews_Previews: PreviewProvider {
    static let sampleEntry = WidgetEntry(
        date: .now,
        contentItem: .thread(.sample),
        heroImage: nil,
        deepLinkURL: URL(string: "aggregator://thread/1"),
        widgetState: .loaded,
        isPlaceholder: false
    )

    static let notConfiguredEntry = WidgetEntry(
        date: .now,
        contentItem: nil,
        heroImage: nil,
        deepLinkURL: nil,
        widgetState: .notConfigured,
        isPlaceholder: false
    )

    static let emptyEntry = WidgetEntry(
        date: .now,
        contentItem: nil,
        heroImage: nil,
        deepLinkURL: nil,
        widgetState: .empty,
        isPlaceholder: false
    )

    static let offlineEntry = WidgetEntry(
        date: .now,
        contentItem: nil,
        heroImage: nil,
        deepLinkURL: nil,
        widgetState: .offline,
        isPlaceholder: false
    )

    static var previews: some View {
        SmallWidgetView(entry: sampleEntry)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small – Loaded")
        MediumWidgetView(entry: sampleEntry)
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Medium – Loaded")
        SmallWidgetView(entry: notConfiguredEntry)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small – Not Configured")
        SmallWidgetView(entry: emptyEntry)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small – Empty")
        SmallWidgetView(entry: offlineEntry)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small – Offline")
    }
}
