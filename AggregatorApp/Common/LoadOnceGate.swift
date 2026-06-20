import Foundation

/// Prevents list views from reloading when returning from a pushed detail view.
/// Call `shouldLoad()` from `.task`; it returns `true` exactly once per view lifetime.
/// Explicit reloads (pull-to-refresh, sort/filter changes) bypass this gate.
struct LoadOnceGate {
    private(set) var hasLoaded = false

    mutating func shouldLoad() -> Bool {
        guard !hasLoaded else { return false }
        hasLoaded = true
        return true
    }
}
