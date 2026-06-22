import AppIntents
import WidgetKit

enum ContentSource: String, AppEnum {
    case latestThreads
    case unreadImportant

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Content Source"
    static var caseDisplayRepresentations: [ContentSource: DisplayRepresentation] = [
        .latestThreads: "Latest Threads",
        .unreadImportant: "Unread Important"
    ]
}

struct ContentSourceIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Content Source"
    static var description = IntentDescription("Choose what to display in the widget.")

    @Parameter(title: "Content Source", default: .latestThreads)
    var contentSource: ContentSource
}
