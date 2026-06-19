import SwiftUI

struct BriefTopicView: View {
    let topic: BriefTopic
    let onExternalRef: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(topic.headline)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            topicSection(label: "What happened", text: topic.whatHappened)
            topicSection(label: "Why it matters", text: topic.whyItMatters)

            if let context = topic.historicalContext, !context.isEmpty {
                topicSection(label: "Background", text: context)
            }

            if !topic.refs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Read")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ForEach(topic.refs) { ref in
                        refRow(ref)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func topicSection(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ParagraphText(text)
                .font(.body)
        }
    }

    @ViewBuilder
    private func refRow(_ ref: BriefRef) -> some View {
        if ref.internal, let articleId = ref.articleId {
            NavigationLink(destination: ArticleDetailView(articleId: articleId)) {
                Label(ref.title ?? "Article", systemImage: "doc.text")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityLabel("Open article: \(ref.title ?? "Article")")
        } else if let urlString = ref.url, let url = URL(string: urlString) {
            Button {
                onExternalRef(url)
            } label: {
                Label(ref.title ?? urlString, systemImage: "safari")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityLabel("Open external link: \(ref.title ?? urlString)")
        } else {
            Text(ref.title ?? ref.url ?? "Reference")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
