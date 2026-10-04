import SwiftUI

private enum LoadPhase {
    case loading, loaded, error(Error)
}

struct SidebarView: View {
    @Environment(iPadNavigationModel.self) private var navigationModel
    @Environment(CredentialsStore.self) private var credentialsStore

    @State private var sources: [Source] = []
    @State private var categories: [Category] = []
    @State private var phase: LoadPhase = .loading
    @State private var showSettings = false
    @State private var showSearch = false

    private var apiClient: APIClient { APIClient(store: credentialsStore) }

    var body: some View {
        @Bindable var nav = navigationModel
        let selection = Binding<SidebarItem?>(
            get: { nav.selectedSidebarItem },
            set: { newItem in
                nav.selectedSidebarItem = newItem ?? .threads
                nav.clearSelection()
            }
        )

        Group {
            if !credentialsStore.isConfigured {
                ContentUnavailableView(
                    "Not configured",
                    systemImage: "gearshape",
                    description: Text("Enter your server credentials in Settings.")
                )
            } else {
                sourceList(selection: selection)
            }
        }
        // No navigationTitle: the sidebar is permanently visible in landscape and
        // its section headers already name the content, so a title only repeats
        // what is on screen. It also cannot fit — the toolbar's glass pills fill
        // the 200-260pt column, truncating any title to an ellipsis.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSearch = true } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .accessibilityLabel("Search")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack { SettingsIPadView() }
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showSearch) {
            NavigationStack { SearchIPadView() }
                .presentationDetents([.large])
        }
        .task {
            guard credentialsStore.isConfigured else { return }
            await loadAll()
        }
        .refreshable { await loadAll() }
    }

    @ViewBuilder
    private func sourceList(selection: Binding<SidebarItem?>) -> some View {
        switch phase {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let error):
            VStack(spacing: 16) {
                Text(error.localizedDescription)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Retry") { Task { await loadAll() } }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded:
            GlassEffectContainer {
                List(selection: selection) {
                    Section("Reading") {
                        feedRow(.feed(.important), label: "Important", icon: "exclamationmark.circle")
                        feedRow(.feed(.unread),    label: "Unread",    icon: "envelope.badge")
                        feedRow(.feed(.saved),     label: "Saved",     icon: "bookmark")
                    }

                    Section("Sections") {
                        feedRow(.threads, label: "Threads",  icon: "rectangle.stack")
                        feedRow(.today,   label: "Today",    icon: "calendar")
                        feedRow(.podcasts, label: "Podcasts", icon: "headphones")
                    }

                    if !categories.isEmpty {
                        Section("Categories") {
                            ForEach(categories) { cat in
                                feedRow(
                                    .feed(.category(name: cat.name)),
                                    label: cat.name,
                                    icon: "tag",
                                    subtitle: cat.freshnessPhrase()
                                )
                            }
                        }
                    }

                    if !sources.isEmpty {
                        Section("Sources") {
                            ForEach(sources) { source in
                                sourceRow(source)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func feedRow(_ item: SidebarItem, label: String, icon: String, subtitle: String? = nil) -> some View {
        if let subtitle {
            VStack(alignment: .leading, spacing: 2) {
                Label(label, systemImage: icon).font(.body)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            .tag(item)
            .accessibilityLabel(label)
        } else {
            Label(label, systemImage: icon)
                .tag(item)
                .accessibilityLabel(label)
        }
    }

    private func sourceRow(_ source: Source) -> some View {
        HStack {
            SourceFaviconView(feedURL: source.feedURL)
            Text(source.name).font(.body)
            Spacer()
            SourceActivityDot(source: source)
        }
        .tag(SidebarItem.feed(.source(id: source.id, name: source.name)))
        .accessibilityLabel(source.hasPriority ? "\(source.name), important updates"
                            : source.hasNew ? "\(source.name), new updates"
                            : source.name)
    }

    private func loadAll() async {
        phase = .loading
        async let fetchSources = apiClient.getSources()
        async let fetchCategories = apiClient.getCategories()
        do { categories = try await fetchCategories } catch { /* non-fatal */ }
        do {
            sources = try await fetchSources
            phase = .loaded
        } catch {
            if isCancellation(error) { return }
            phase = .error(error)
        }
    }
}
