import SwiftUI
import UIKit

struct SourceFaviconView: View {
    let feedURL: String
    @State private var image: UIImage? = nil

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "globe")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 20, height: 20)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .onAppear {
            guard image == nil else { return }
            Task {
                image = await FaviconLoader.shared.icon(forFeedURL: feedURL)
            }
        }
    }
}

#Preview("With favicon") {
    SourceFaviconView(feedURL: "https://feeds.arstechnica.com/arstechnica/index")
        .padding()
}

#Preview("Placeholder") {
    SourceFaviconView(feedURL: "not-a-valid-url")
        .padding()
}
