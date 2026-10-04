import SafariServices
import SwiftUI
import UIKit

/// An identifiable URL for driving `.sheet(item:)` presentation. Using an item
/// (rather than `.sheet(isPresented:)` + a separate URL `@State`) avoids the
/// race where the sheet builds before the URL is set — which presented a blank
/// SafariView and "worked on the second try". One item-sheet also replaces
/// having multiple `.sheet` modifiers on one view (which SwiftUI presents
/// unreliably) for the "open original" and "open comments" actions.
struct SafariURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }

    /// Convenience: build from an optional URL string, returning nil when invalid.
    init?(_ string: String?) {
        guard let string, let url = URL(string: string) else { return nil }
        self.url = url
    }
}

/// SwiftUI wrapper around `SFSafariViewController` for in-app browsing with Reader and sharing.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Presentation

// On iPad a sheet renders as a small floating form sheet, which leaves the
// browser far narrower than the screen. A full-screen cover is the only way to
// get full width there. iPhone keeps the sheet so swipe-to-dismiss still works.
// The idiom never changes at runtime, so branching on it here is stable.
extension View {
    @ViewBuilder
    func inAppBrowser<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            fullScreenCover(item: item, content: content)
        } else {
            sheet(item: item, content: content)
        }
    }

    @ViewBuilder
    func inAppBrowser<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            fullScreenCover(isPresented: isPresented, content: content)
        } else {
            sheet(isPresented: isPresented, content: content)
        }
    }
}
