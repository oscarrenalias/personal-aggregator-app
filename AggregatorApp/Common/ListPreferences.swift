import Foundation
import Observation

/// Persists user list-display preferences across launches.
///
/// Each property is backed by a `UserDefaults` key under the `aggregator.` prefix and is
/// written on every `didSet`. Pass a custom `defaults` suite in tests to avoid touching
/// the real defaults:
/// ```swift
/// ListPreferences(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
/// ```
@Observable
final class ListPreferences {
    private let defaults: UserDefaults

    var threadsSort: ThreadSort {
        didSet { defaults.set(threadsSort.rawValue, forKey: "aggregator.threadsSort") }
    }

    var threadsShowDismissed: Bool {
        didSet { defaults.set(threadsShowDismissed, forKey: "aggregator.threadsShowDismissed") }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.threadsSort = ThreadSort(rawValue: defaults.string(forKey: "aggregator.threadsSort") ?? "") ?? .importance
        self.threadsShowDismissed = defaults.bool(forKey: "aggregator.threadsShowDismissed")
    }
}
