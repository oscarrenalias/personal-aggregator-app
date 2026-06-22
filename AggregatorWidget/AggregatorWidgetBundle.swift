import AppIntents
import SwiftUI
import WidgetKit

// Stub entry point — replaced by full AggregatorRadarWidget implementation in a subsequent bead.
struct AggregatorRadarPlaceholderEntry: TimelineEntry {
    let date: Date = .now
}

struct AggregatorRadarPlaceholderProvider: AppIntentTimelineProvider {
    typealias Intent = ContentSourceIntent
    typealias Entry = AggregatorRadarPlaceholderEntry

    func placeholder(in context: Context) -> AggregatorRadarPlaceholderEntry { .init() }

    func snapshot(for configuration: ContentSourceIntent, in context: Context) async -> AggregatorRadarPlaceholderEntry { .init() }

    func timeline(for configuration: ContentSourceIntent, in context: Context) async -> Timeline<AggregatorRadarPlaceholderEntry> {
        Timeline(entries: [.init()], policy: .never)
    }
}

struct AggregatorRadarWidget: Widget {
    let kind: String = "AggregatorRadarWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ContentSourceIntent.self, provider: AggregatorRadarPlaceholderProvider()) { _ in
            Color.clear
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Aggregator Radar")
        .description("Latest threads and unread important articles.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct AggregatorWidgetBundle: WidgetBundle {
    var body: some Widget {
        AggregatorRadarWidget()
    }
}
