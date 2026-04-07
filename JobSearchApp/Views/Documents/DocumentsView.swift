import SwiftUI
import SwiftData

struct DocumentsView: View {
    @Query(sort: \GeneratedDocument.lastModified, order: .reverse)
    private var documents: [GeneratedDocument]

    var body: some View {
        NavigationStack {
            Group {
                if documents.isEmpty {
                    ContentUnavailableView(
                        "No Documents",
                        systemImage: "doc.text",
                        description: Text("Generate resumes and cover letters from job postings in the Discover tab.")
                    )
                } else {
                    List(documents) { doc in
                        NavigationLink(destination: DocumentDetailView(document: doc)) {
                            DocumentRow(document: doc)
                        }
                    }
                }
            }
            .navigationTitle("Documents")
        }
    }
}
