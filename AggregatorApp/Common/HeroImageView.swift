import SwiftUI
import UIKit

/// Full-width hero header image with a neutral placeholder.
///
/// Uses a `@State`-backed loader rather than `AsyncImage` so it renders reliably
/// inside lazy paging containers (the paged readers), where `AsyncImage` can
/// fail to load. The fixed-size container + clipped overlay keeps `scaledToFill`
/// from overflowing and forcing the content column wider than the screen.
struct HeroImageView: View {
    let urlString: String
    var height: CGFloat = 240

    @State private var image: UIImage? = nil

    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.15))
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            // .task(id:) reloads if the page is recycled for a different article.
            .task(id: urlString) {
                guard let url = URL(string: urlString) else { return }
                image = await RemoteImageLoader.shared.image(for: url)
            }
    }
}
