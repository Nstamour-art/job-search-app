import SwiftUI
import SwiftData

struct JobDetailView: View {
    let job: JobPosting
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showGenerateDocs = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text(job.title).font(.title2.bold())
                    Text(job.company).font(.headline).foregroundStyle(.secondary)
                    Text(job.location).font(.subheadline).foregroundStyle(.secondary)
                }

                // Priority
                HStack(spacing: 10) {
                    PriorityBadge(score: job.priorityScore)
                    Text(job.priorityReasoning)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // URL link
                if !job.url.isEmpty, let url = URL(string: job.url) {
                    Link(destination: url) {
                        Label("View Original Posting", systemImage: "arrow.up.right.square")
                            .font(.subheadline)
                    }
                }

                Divider()

                // Full description
                Text(job.scrapedDescription)
                    .font(.body)

                Divider()

                // Generate documents
                Button("Generate Documents") { showGenerateDocs = true }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

                if !job.documents.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Generated Documents")
                            .font(.headline)
                        ForEach(job.documents) { doc in
                            NavigationLink(destination: DocumentDetailView(document: doc)) {
                                DocumentRow(document: doc)
                            }
                        }
                    }
                }

                Divider()

                // Status actions
                statusActions
            }
            .padding()
        }
        .navigationTitle("Job Detail")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showGenerateDocs) {
            GenerateDocumentsView(job: job)
        }
    }

    @ViewBuilder
    private var statusActions: some View {
        VStack(spacing: 12) {
            switch job.status {
            case .saved:
                Button("Mark as Applied") { setStatus(.applied) }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                Button("Archive") { setStatus(.archived); dismiss() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

            case .applied:
                Text("Status: Applied")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                Button("Archive") { setStatus(.archived); dismiss() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)

            case .archived:
                Text("Status: Archived")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                Button("Restore to Saved") { setStatus(.saved) }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func setStatus(_ status: JobStatus) {
        job.status = status
        try? modelContext.save()
    }
}
