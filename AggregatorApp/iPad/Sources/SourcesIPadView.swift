import SwiftUI
import UIKit

private enum LoadPhase {
    case loading
    case loaded
    case error(Error)
}

struct SourcesIPadView: View {
    @Environment(iPadNavigationModel.self) private var navigationModel
    @Environment(CredentialsStore.self) private var credentialsStore

    @State private var sources: [Source] = []
    @State private var categories: [Category] = []
    @State private var phase: LoadPhase = .loading
    @State private var loadGate = LoadOnceGate()
    @State private var isPortrait = false
    @State private var portraitPath = NavigationPath()

    private var apiClient: APIClient { APIClient(store: credentialsStore) }

    var body: some View {
        Group {
            if isPortrait {
                NavigationStack(path: $portraitPath) {
                    listBody
                        .navigationTitle("Sources")
                        .navigationDestination(for: ArticleFeed.self) { feed in
                            ArticleListView(feed: feed)
                        }
                }
            } else {
                listBody
                    .navigationTitle("Sources")
            }
        }
        .onAppear { updateOrientation() }
        .onReceive(
            NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
        ) { _ in
            updateOrientation()
        }
        .task {
            guard credentialsStore.isConfigured, loadGate.shouldLoad() else {
                if !credentialsStore.isConfigured { phase = .loaded }
                return
            }
            await loadAll()
        }
    }

    @ViewBuilder
    private var listBody: some View {
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
            case .error(let error):
                VStack(spacing: 16) {
                    Text(error.localizedDescription)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await loadAll() }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .loaded:
                sourcesList
            }
        }
    }

    private var sourcesList: some View {
        GlassEffectContainer {
            List {
                Section("Feeds") {
                    feedRow(feed: .important, label: "Important", systemImage: "exclamationmark.circle")
                    feedRow(feed: .unread, label: "Unread", systemImage: "envelope.badge")
                    feedRow(feed: .saved, label: "Saved", systemImage: "bookmark")
                }
                if !categories.isEmpty {
                    Section("Categories") {
                        ForEach(categories) { category in
                            feedRow(
                                feed: .category(name: category.name),
                                label: category.name,
                                systemImage: "tag",
                                subtitle: category.freshnessPhrase()
                            )
                        }
                    }
                }
                if !sources.isEmpty {
                    Section("Sources") {
                        ForEach(sources) { source in
                            sourceRow(source: source)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .refreshable {
                await loadAll()
            }
        }
    }

    @ViewBuilder
    private func feedRow(
        feed: ArticleFeed,
        label: String,
        systemImage: String,
        subtitle: String? = nil
    ) -> some View {
        if isPortrait {
            NavigationLink(value: feed) {
                feedRowLabel(label: label, systemImage: systemImage, subtitle: subtitle)
            }
            .accessibilityLabel(label)
            .listRowBackground(Color.clear)
        } else {
            Button {
                navigationModel.selectedFeed = feed
                navigationModel.selectedSource = nil
            } label: {
                feedRowLabel(label: label, systemImage: systemImage, subtitle: subtitle)
            }
            .buttonStyle(.plain)
            .listRowBackground(
                navigationModel.selectedFeed == feed && navigationModel.selectedSource == nil
                    ? Color.accentColor.opacity(0.12)
                    : Color.clear
            )
            .accessibilityLabel(label)
        }
    }

    @ViewBuilder
    private func feedRowLabel(label: String, systemImage: String, subtitle: String?) -> some View {
        if let subtitle {
            VStack(alignment: .leading, spacing: 2) {
                Label(label, systemImage: systemImage)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Label(label, systemImage: systemImage)
        }
    }

    @ViewBuilder
    private func sourceRow(source: Source) -> some View {
        if isPortrait {
            NavigationLink(value: ArticleFeed.source(id: source.id, name: source.name)) {
                sourceRowContent(source: source)
            }
            .accessibilityLabel(accessibilityLabel(for: source))
            .listRowBackground(Color.clear)
        } else {
            Button {
                navigationModel.selectedSource = source
                navigationModel.selectedFeed = .source(id: source.id, name: source.name)
            } label: {
                sourceRowContent(source: source)
            }
            .buttonStyle(.plain)
            .listRowBackground(
                navigationModel.selectedSource?.id == source.id
                    ? Color.accentColor.opacity(0.12)
                    : Color.clear
            )
            .accessibilityLabel(accessibilityLabel(for: source))
        }
    }

    private func sourceRowContent(source: Source) -> some View {
        HStack {
            SourceFaviconView(feedURL: source.feedURL)
            Text(source.name)
                .font(.body)
            Spacer()
            SourceActivityDot(source: source)
        }
    }

    private func accessibilityLabel(for source: Source) -> String {
        if source.hasPriority { return "\(source.name), important updates" }
        if source.hasNew { return "\(source.name), new updates" }
        return source.name
    }

    private func updateOrientation() {
        let bounds = UIScreen.main.bounds
        isPortrait = bounds.width < bounds.height
    }

    private func loadAll() async {
        phase = .loading
        sources = []
        categories = []

        async let fetchSources = apiClient.getSources()
        async let fetchCategories = apiClient.getCategories()

        do {
            categories = try await fetchCategories
        } catch {
            if isCancellation(error) { return }
            // non-fatal; categories section will not appear
        }

        do {
            sources = try await fetchSources
            phase = .loaded
        } catch {
            if isCancellation(error) { return }
            phase = .error(error)
        }
    }
}
