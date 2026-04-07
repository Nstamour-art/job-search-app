import SwiftUI

struct DiscoverView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Job Discovery", systemImage: "magnifyingglass",
                description: Text("Search for jobs coming in Plan 3"))
            .navigationTitle("Discover")
        }
    }
}
