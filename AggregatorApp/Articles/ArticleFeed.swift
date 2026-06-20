import Foundation

enum ArticleFeed: Hashable, Identifiable {
    case source(id: Int, name: String)
    case important
    case unread
    case category(name: String)

    var id: String {
        switch self {
        case .source(let id, _): return "source-\(id)"
        case .important: return "important"
        case .unread: return "unread"
        case .category(let name): return "category-\(name)"
        }
    }

    var title: String {
        switch self {
        case .source(_, let name): return name
        case .important: return "Important"
        case .unread: return "Unread"
        case .category(let name): return name
        }
    }

    var systemImage: String? {
        switch self {
        case .source: return nil
        case .important: return "exclamationmark.circle"
        case .unread: return "envelope.badge"
        case .category: return "tag"
        }
    }

    var allowsUnreadFilter: Bool {
        switch self {
        case .unread: return false
        default: return true
        }
    }
}
