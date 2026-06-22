import Foundation
import Observation
import WidgetKit

/// In-memory, session-scoped cache of article IDs that have been marked read (or
/// explicitly unread) during this app run.
///
/// The backend is the source of truth for `is_read` — this store only lets the
/// UI (e.g. the unread dot in `ArticleRowView`) reflect a read/unread change
/// immediately after the reader syncs it, without waiting for the list to
/// refetch. Entries are only added after a successful backend write, so the
/// store never claims a state the server doesn't have. It is intentionally not
/// persisted: on relaunch the list refetches real `is_read` values.
@Observable final class ArticleReadStore {
    private var readIDs: Set<Int> = []
    private var unreadIDs: Set<Int> = []

    /// Resolves the effective read state for an article, preferring a
    /// session override (from a successful backend write) over the fetched value.
    func isRead(id: Int, fetched: Bool) -> Bool {
        if readIDs.contains(id) { return true }
        if unreadIDs.contains(id) { return false }
        return fetched
    }

    func markRead(_ id: Int) {
        unreadIDs.remove(id)
        readIDs.insert(id)
        WidgetCenter.shared.reloadTimelines(ofKind: "AggregatorRadarWidget")
    }

    func markUnread(_ id: Int) {
        readIDs.remove(id)
        unreadIDs.insert(id)
    }
}
