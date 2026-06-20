import SwiftUI

struct TodayView: View {
    @Environment(CredentialsStore.self) private var credentialsStore
    @State private var phase: Phase = .loading

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
                        BriefDetailView(brief: brief) {
                            await fetchBrief()
                        }
                    }
                }
            }
            .navigationTitle("Today")
        }
        .task {
            if credentialsStore.isConfigured {
                await fetchBrief()
            }
        }
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
