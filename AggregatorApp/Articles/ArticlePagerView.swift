import SwiftUI

struct ArticlePagerView: View {
    let articles: [Article]
    let startIndex: Int

    @State private var selectedIndex: Int

    init(articles: [Article], startIndex: Int) {
        self.articles = articles
        self.startIndex = startIndex
        self._selectedIndex = State(initialValue: startIndex)
    }

    var body: some View {
        // Pager is bounded to the provided articles slice; no additional page loading occurs at boundaries.
        TabView(selection: $selectedIndex) {
            ForEach(Array(articles.enumerated()), id: \.offset) { index, article in
                ArticleDetailView(articleId: article.id)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .navigationBarTitleDisplayMode(.inline)
    }
}
