import SwiftUI

struct DocumentsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView("Documents", systemImage: "doc.text",
                description: Text("Generated resumes and cover letters — coming in Plan 4"))
            .navigationTitle("Documents")
        }
    }
}
