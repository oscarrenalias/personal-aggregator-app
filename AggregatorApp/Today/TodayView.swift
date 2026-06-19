import SwiftUI

struct TodayView: View {
    @Environment(CredentialsStore.self) private var credentialsStore
    @State private var phase: Phase = .loading
    @State private var safariURL: URL? = nil

    private enum Phase {
        case loading
        case loaded(Brief)
        case error(Error)
        case empty
    }

    private var apiClient: APIClient {
        APIClient(store: credentialsStore)
    }

    var body: some View {
        NavigationStack {
            Group {
                if !credentialsStore.isConfigured {
                    ContentUnavailableView(
                        "Not configured",
                        systemImage: "gearshape",
                        description: Text("Enter your server credentials in Settings.")
                    )
                } else {
                    switch phase {
                    case .loading:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .empty:
                        ContentUnavailableView(
                            "No Brief Today",
                            systemImage: "sparkles",
                            description: Text("Today's brief hasn't been generated yet.")
                        )
                    case .error(let error):
                        VStack(spacing: 16) {
                            Text(error.localizedDescription)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Retry") {
                                Task { await fetchBrief() }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .loaded(let brief):
                        briefContent(brief)
                    }
                }
            }
            .navigationTitle("Today")
        }
        .sheet(isPresented: Binding(
            get: { safariURL != nil },
            set: { if !$0 { safariURL = nil } }
        )) {
            if let url = safariURL {
                SafariView(url: url)
            }
        }
        .task {
            if credentialsStore.isConfigured {
                await fetchBrief()
            }
        }
    }

    @ViewBuilder
    private func briefContent(_ brief: Brief) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(brief.headline ?? "Daily Brief")
                    .font(.title2)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(captionString(brief))
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
            await fetchBrief()
        }
    }

    private func captionString(_ brief: Brief) -> String {
        var parts = [DateDisplay.mediumDate(brief.periodStart)]
        if let model = brief.model {
            parts.append(model)
        }
        return parts.joined(separator: " · ")
    }

    private func fetchBrief() async {
        phase = .loading
        do {
            let brief = try await apiClient.getTodayBrief()
            phase = .loaded(brief)
        } catch APIError.http(status: 404) {
            phase = .empty
        } catch {
            if isCancellation(error) { return }
            phase = .error(error)
        }
    }
}
