import Foundation

enum ArticleFeed: Hashable, Identifiable {
    case source(id: Int, name: String)
    case important
    case unread
    case saved
    case category(name: String)

    var id: String {
        switch self {
        case .source(let id, _): return "source-\(id)"
        case .important: return "important"
        case .unread: return "unread"
        case .saved: return "saved"
        case .category(let name): return "category-\(name)"
        }
    }

    var title: String {
        switch self {
        case .source(_, let name): return name
        case .important: return "Important"
        case .unread: return "Unread"
        case .saved: return "Saved"
        case .category(let name): return name
        }
    }

    var systemImage: String? {
        switch self {
        case .source: return nil
        case .important: return "exclamationmark.circle"
        case .unread: return "envelope.badge"
        case .saved: return "bookmark"
        case .category: return "tag"
        }
    }

    var allowsUnreadFilter: Bool {
        switch self {
        case .unread, .saved: return false
        case .source, .important, .category: return true
        }
    }
}
