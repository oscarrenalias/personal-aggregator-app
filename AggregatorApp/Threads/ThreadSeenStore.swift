import Foundation
import Observation

/// Tracks which threads the user has already seen, persisted across launches.
///
/// Each entry maps a thread ID to the `lastUpdated` timestamp observed when the thread was last
/// opened. A thread is considered to have unseen updates when its current `lastUpdated` differs
/// from the stored value. State is serialised as JSON and stored in `UserDefaults` under the key
/// `aggregator.threadsSeen`. The store is injected into the SwiftUI environment by `AggregatorApp`
/// and consumed by `ThreadsView` / `ThreadCardView`.
@Observable final class ThreadSeenStore {
    private static let defaultsKey = "aggregator.threadsSeen"

    private var seen: [Int: String] = [:]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func markSeen(id: Int, lastUpdated: String) {
        seen[id] = lastUpdated
        persist()
    }

    func hasUnseenUpdate(_ thread: Thread) -> Bool {
        guard thread.hasUpdates else { return false }
        return seen[thread.id] != thread.lastUpdated
    }

    private func load() {
        guard
            let data = defaults.data(forKey: Self.defaultsKey),
            let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else { return }
        seen = Dictionary(uniqueKeysWithValues: decoded.compactMap { k, v in
            guard let intKey = Int(k) else { return nil }
            return (intKey, v)
        })
    }

    private func persist() {
        let stringKeyed = Dictionary(uniqueKeysWithValues: seen.map { ("\($0.key)", $0.value) })
        guard let data = try? JSONEncoder().encode(stringKeyed) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }
}
