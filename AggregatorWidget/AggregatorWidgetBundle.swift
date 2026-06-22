import AppIntents
import SwiftUI
import WidgetKit

private struct AggregatorRadarEntryView: View {
    let entry: WidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemMedium:
            MediumWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct AggregatorRadarWidget: Widget {
    let kind: String = "AggregatorRadarWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ContentSourceIntent.self, provider: AggregatorRadarProvider()) { entry in
            AggregatorRadarEntryView(entry: entry)
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
