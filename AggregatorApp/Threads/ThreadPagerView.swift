import SwiftUI

struct ThreadPagerView: View {
    let threads: [Thread]
    let startIndex: Int

    @State private var selectedIndex: Int

    init(threads: [Thread], startIndex: Int) {
        self.threads = threads
        self.startIndex = startIndex
        self._selectedIndex = State(initialValue: startIndex)
    }

    var body: some View {
        TabView(selection: $selectedIndex) {
            ForEach(Array(threads.enumerated()), id: \.offset) { index, thread in
                ThreadDetailView(threadId: thread.id)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .navigationBarTitleDisplayMode(.inline)
    }
}
