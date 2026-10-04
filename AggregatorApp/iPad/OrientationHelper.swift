import UIKit

/// Returns true when the device is in portrait orientation.
/// Uses the active UIWindowScene bounds — the iOS 26-safe alternative to the
/// deprecated UIScreen.main.bounds.
func iPadIsPortrait() -> Bool {
    let scene = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .first { $0.activationState == .foregroundActive }
        ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }.first
    let size = scene?.coordinateSpace.bounds.size ?? CGSize(width: 1024, height: 768)
    return size.width < size.height
}
