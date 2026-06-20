import SwiftUI

struct BriefDetailView: View {
    let brief: Brief
    var onRefresh: (() async -> Void)? = nil

    @State private var safariURL: URL? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(brief.headline ?? "Daily Brief")
                    .font(.title2)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(captionString())
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let intro = brief.intro, !intro.isEmpty {
                    ParagraphText(intro)
                        .font(.body)
                }

                ForEach(brief.topics.sorted { $0.position < $1.position }) { topic in
                    BriefTopicView(topic: topic) { url in
                        safariURL = url
                    }
                }
            }
            .padding(.horizontal, ReaderLayout.hPadding)
            .padding(.vertical, 16)
        }
        .refreshable {
            await onRefresh?()
        }
        .sheet(isPresented: Binding(
            get: { safariURL != nil },
            set: { if !$0 { safariURL = nil } }
        )) {
            if let url = safariURL {
                SafariView(url: url)
            }
        }
    }

    private func captionString() -> String {
        var parts = [DateDisplay.mediumDate(brief.periodStart)]
        if let model = brief.model {
            parts.append(model)
        }
        return parts.joined(separator: " · ")
    }
}
