import SwiftUI

struct ApplicationsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Applications", systemImage: "briefcase",
                description: Text("Track your applications — coming in Plan 3"))
            .navigationTitle("Applications")
        }
    }
}
