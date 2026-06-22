import AppIntents
import WidgetKit

enum ContentSource: String, AppEnum {
    // Raw values are persisted in saved widget configurations — keep
    // `latestThreads` and `unreadImportant` stable for backward compatibility.
    case latestThreads          // threads, sorted by importance
    case latestThreadsRecent    // threads, sorted by recent
    case unreadImportant        // unread important articles, sorted by importance
    case unreadImportantRecent  // unread important articles, sorted by recent

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Content Source"
    static var caseDisplayRepresentations: [ContentSource: DisplayRepresentation] = [
        .latestThreads: "Threads · Importance",
        .latestThreadsRecent: "Threads · Recent",
        .unreadImportant: "Unread Important · Importance",
        .unreadImportantRecent: "Unread Important · Recent"
    ]
}

struct ContentSourceIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Content Source"
    static var description = IntentDescription("Choose what to display in the widget.")

    @Parameter(title: "Content Source", default: .latestThreads)
    var contentSource: ContentSource
}
