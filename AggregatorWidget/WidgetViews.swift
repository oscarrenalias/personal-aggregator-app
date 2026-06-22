import SwiftUI
import UIKit
import WidgetKit

// MARK: - Default background

struct RadarDefaultBackground: View {
    var body: some View {
        Image("RadarDefault")
            .resizable()
            .scaledToFill()
    }
}

// MARK: - Shared background components

struct WidgetHeroBackground: View {
    let image: UIImage?

    var body: some View {
        if let uiImage = image {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            RadarDefaultBackground()
        }
    }
}

/// Bottom-anchored darkening scrim so text over images stays legible.
/// `.heavy` darkens the whole frame (for bright/light images where a bottom-only
/// fade leaves the upper title lines unreadable); `.standard` is a lighter
/// bottom fade that preserves more of a dark image.
struct WidgetScrim: View {
    enum Strength { case standard, heavy }
    var strength: Strength = .standard

    var body: some View {
        // Full-frame (bottom-biased) gradients: the title is vertically centered,
        // so the darkening must reach the middle, not just the bottom edge.
        let stops: [Gradient.Stop]
        switch strength {
        case .standard:
            stops = [
                .init(color: .black.opacity(0.6), location: 0),
                .init(color: .black.opacity(0.2), location: 1)
            ]
        case .heavy:
            stops = [
                .init(color: .black.opacity(0.9), location: 0),
                .init(color: .black.opacity(0.5), location: 1)
            ]
        }
        return LinearGradient(stops: stops, startPoint: .bottom, endPoint: .top)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Full-bleed widget background. Lives inside `.containerBackground` (not the
/// content layer) so the scrim covers the whole image edge-to-edge rather than
/// being inset by the widget's content margins.
///
/// In tinted ("accented") / lock-screen ("vibrant") rendering the system
/// desaturates everything and applies the user's tint by luminance, which turns
/// a photo into a muddy wash and any solid-filled shape into a tint blob. In
/// those modes we drop the photo + scrim for a clean dark surface so the tinted
/// text reads cleanly.
struct WidgetContentBackground: View {
    let image: UIImage?
    let renderingMode: WidgetRenderingMode

    var body: some View {
        if renderingMode == .fullColor {
            WidgetHeroBackground(image: image)
                .overlay { WidgetScrim(strength: scrimStrength) }
        } else {
            Color.black
        }
    }

    /// Darken more aggressively when the hero's text region is bright, so white
    /// text stays legible on light images; keep the lighter scrim for dark ones.
    private var scrimStrength: WidgetScrim.Strength {
        guard let luminance = image?.bottomRegionLuminance() else { return .standard }
        return luminance > 0.6 ? .heavy : .standard
    }
}

private extension UIImage {
    /// Average perceived luminance (0...1) of the bottom `fraction` of the image —
    /// the region the widget's text sits over. Computed by averaging the cropped
    /// region down to a single pixel. Returns nil if it can't be measured.
    func bottomRegionLuminance(fraction: CGFloat = 0.5) -> CGFloat? {
        guard let cg = cgImage else { return nil }
        let cropY = Int(CGFloat(cg.height) * (1 - fraction))
        let rect = CGRect(x: 0, y: cropY, width: cg.width, height: cg.height - cropY)
        guard let region = cg.cropping(to: rect),
              let ctx = CGContext(
                data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }
        ctx.draw(region, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        guard let data = ctx.data else { return nil }
        let p = data.bindMemory(to: UInt8.self, capacity: 4)
        let r = CGFloat(p[0]) / 255, g = CGFloat(p[1]) / 255, b = CGFloat(p[2]) / 255
        return 0.299 * r + 0.587 * g + 0.114 * b
    }
}

// MARK: - Non-content state views

struct WidgetNotConfiguredView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "key.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .accessibilityHidden(true)
            Text("Open app to sign in")
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
        .containerBackground(for: .widget) {
            RadarDefaultBackground()
        }
        .accessibilityLabel("Widget not configured. Open app to sign in.")
    }
}

struct WidgetEmptyView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.8))
                .accessibilityHidden(true)
            Text("Nothing here yet")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
        .containerBackground(for: .widget) {
            RadarDefaultBackground()
        }
        .accessibilityLabel("No content available.")
    }
}

struct WidgetOfflineNoDataView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.8))
                .accessibilityHidden(true)
            Text("Can't update")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(12)
        .containerBackground(for: .widget) {
            RadarDefaultBackground()
        }
        .accessibilityLabel("Widget offline, no cached content.")
    }
}

// MARK: - Content item display helpers

private extension WidgetContentItem {
    var displayTitle: String {
        switch self {
        case .thread(let t): return t.representativeTitle
        case .article(let a): return a.title ?? ""
        }
    }

    var displaySourceName: String {
        switch self {
        case .thread(let t): return t.sourceCount == 1 ? "1 source" : "\(t.sourceCount) sources"
        case .article(let a): return a.sourceName ?? ""
        }
    }

    var displayPublishedAt: String? {
        switch self {
        case .thread(let t): return t.lastUpdated
        case .article(let a): return a.feedPublishedAt
        }
    }

    /// "<source> · <relative time>", omitting whichever part is empty.
    var metaText: String {
        [displaySourceName, DateDisplay.relative(displayPublishedAt)]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    /// Article summary for the medium widget. Nil for threads (handled separately).
    var articleSummary: String? {
        switch self {
        case .article(let a): return a.summary
        case .thread: return nil
        }
    }
}

// MARK: - Content views (used by both small and medium when data is available)

private struct SmallContentView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: WidgetEntry
    let contentItem: WidgetContentItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(contentItem.displayTitle)
                .font(.headline)
                .lineLimit(4)
                .minimumScaleFactor(0.85)
                .foregroundStyle(.white)
            Text(contentItem.metaText)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.85))
        }
        .shadow(color: renderingMode == .fullColor ? .black.opacity(0.45) : .clear, radius: 3, y: 1)
        // Vertically centered, leading-aligned — consistent across full-color and
        // tinted modes.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            WidgetContentBackground(image: entry.heroImage, renderingMode: renderingMode)
        }
        .widgetURL(entry.deepLinkURL)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(contentItem.displayTitle), \(contentItem.displaySourceName)")
    }
}

private struct MediumContentView: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: WidgetEntry
    let contentItem: WidgetContentItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(contentItem.displayTitle)
                .font(.headline)
                // Capped at 2 lines so the article summary has room below.
                .lineLimit(2)
                .foregroundStyle(.white)
            if let summary = contentItem.articleSummary, !summary.isEmpty {
                Text(summary)
                    .font(.footnote)
                    .lineLimit(3)
                    .foregroundStyle(.white.opacity(0.85))
            }
            // Hairline rule separating the title/summary from the meta line.
            Rectangle()
                .fill(.white.opacity(0.35))
                .frame(maxWidth: 150, maxHeight: 1)
                .padding(.vertical, 2)
            metaLine
        }
        .shadow(color: renderingMode == .fullColor ? .black.opacity(0.45) : .clear, radius: 3, y: 1)
        // Vertically centered, leading-aligned — consistent across full-color and
        // tinted modes.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .containerBackground(for: .widget) {
            WidgetContentBackground(image: entry.heroImage, renderingMode: renderingMode)
        }
        .widgetURL(entry.deepLinkURL)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var metaLine: some View {
        Text(contentItem.metaText)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.85))
    }
}

// MARK: - Small Widget View

/// State precedence: notConfigured > empty > offline (no cache) > content.
struct SmallWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        stateView
    }

    @ViewBuilder
    private var stateView: some View {
        switch entry.widgetState {
        case .notConfigured:
            WidgetNotConfiguredView()
        case .empty:
            WidgetEmptyView()
        case .offline where entry.contentItem == nil:
            WidgetOfflineNoDataView()
        default:
            if let contentItem = entry.contentItem {
                SmallContentView(entry: entry, contentItem: contentItem)
            } else {
                WidgetEmptyView()
            }
        }
    }
}

// MARK: - Medium Widget View

/// State precedence: notConfigured > empty > offline (no cache) > content.
struct MediumWidgetView: View {
    let entry: WidgetEntry

    var body: some View {
        stateView
    }

    @ViewBuilder
    private var stateView: some View {
        switch entry.widgetState {
        case .notConfigured:
            WidgetNotConfiguredView()
        case .empty:
            WidgetEmptyView()
        case .offline where entry.contentItem == nil:
            WidgetOfflineNoDataView()
        default:
            if let contentItem = entry.contentItem {
                MediumContentView(entry: entry, contentItem: contentItem)
            } else {
                WidgetEmptyView()
            }
        }
    }
}

// MARK: - Previews

struct WidgetViews_Previews: PreviewProvider {
    static let sampleEntry = WidgetEntry(
        date: .now,
        contentItem: .thread(.sample),
        heroImage: nil,
        deepLinkURL: URL(string: "aggregator://thread/1"),
        widgetState: .loaded,
        isPlaceholder: false
    )

    static let notConfiguredEntry = WidgetEntry(
        date: .now,
        contentItem: nil,
        heroImage: nil,
        deepLinkURL: nil,
        widgetState: .notConfigured,
        isPlaceholder: false
    )

    static let emptyEntry = WidgetEntry(
        date: .now,
        contentItem: nil,
        heroImage: nil,
        deepLinkURL: nil,
        widgetState: .empty,
        isPlaceholder: false
    )

    static let offlineEntry = WidgetEntry(
        date: .now,
        contentItem: nil,
        heroImage: nil,
        deepLinkURL: nil,
        widgetState: .offline,
        isPlaceholder: false
    )

    static var previews: some View {
        SmallWidgetView(entry: sampleEntry)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small – Loaded")
        MediumWidgetView(entry: sampleEntry)
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .previewDisplayName("Medium – Loaded")
        SmallWidgetView(entry: notConfiguredEntry)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small – Not Configured")
        SmallWidgetView(entry: emptyEntry)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small – Empty")
        SmallWidgetView(entry: offlineEntry)
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .previewDisplayName("Small – Offline")
    }
}
