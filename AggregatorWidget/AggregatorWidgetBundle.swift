import WidgetKit
import SwiftUI

// Stub entry point — full widget implementation added in a subsequent bead.
struct AggregatorPlaceholderEntry: TimelineEntry {
    let date: Date = .now
}

struct AggregatorPlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> AggregatorPlaceholderEntry { .init() }
    func getSnapshot(in context: Context, completion: @escaping (AggregatorPlaceholderEntry) -> Void) { completion(.init()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<AggregatorPlaceholderEntry>) -> Void) {
        completion(Timeline(entries: [.init()], policy: .never))
    }
}

struct AggregatorPlaceholderWidget: Widget {
    let kind: String = "AggregatorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AggregatorPlaceholderProvider()) { _ in
            Color.clear
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Aggregator")
        .description("Latest articles and threads.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct AggregatorWidgetBundle: WidgetBundle {
    var body: some Widget {
        AggregatorPlaceholderWidget()
    }
}
