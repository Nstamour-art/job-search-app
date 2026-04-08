import SwiftUI
import SwiftData

struct JobDetailView: View {
    let job: JobPosting
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showGenerateDocs = false
    @State private var applyItem: ApplyItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                headerAndPriority

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

                // Apply button — only shown when the posting has a URL
                if let url = URL(string: job.url), !job.url.isEmpty {
                    Button("Apply") { applyItem = ApplyItem(url: url) }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                }

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
        .sheet(item: $applyItem) { item in
            SafariView(url: item.url)
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

private struct ApplyItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Liquid Glass helpers

enum PriorityCardStyle: Equatable {
    case glass(cornerRadius: CGFloat)
    case material(cornerRadius: CGFloat)
}

func priorityCardStyle() -> PriorityCardStyle {
    if #available(iOS 26, *) {
        .glass(cornerRadius: 12)
    } else {
        .material(cornerRadius: 12)
    }
}

private extension JobDetailView {
    @ViewBuilder
    var headerAndPriority: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 12) {
                priorityHeaderGlass(headerSection)
                priorityCardGlass(prioritySection)
            }
        } else {
            headerSection
            priorityCardGlass(prioritySection)
        }
    }

    @ViewBuilder
    var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(job.title).font(.title2.bold())
            Text(job.company).font(.headline).foregroundStyle(.secondary)
            Text(job.location).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    var prioritySection: some View {
        HStack(spacing: 10) {
            PriorityBadge(score: job.priorityScore)
            Text(job.priorityReasoning)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    @ViewBuilder
    func priorityHeaderGlass<Content: View>(_ content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 14))
        } else {
            content
        }
    }

    @ViewBuilder
    func priorityCardGlass<Content: View>(_ content: Content) -> some View {
        switch priorityCardStyle() {
        case .glass(let radius):
            if #available(iOS 26, *) {
                content.glassEffect(.regular, in: .rect(cornerRadius: radius))
            }
        case .material(let radius):
            content.background(.ultraThinMaterial, in: .rect(cornerRadius: radius))
        }
    }
}
