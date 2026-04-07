import SwiftUI
import SwiftData

struct DiscoverView: View {
    @Query(sort: \JobPosting.dateFound, order: .reverse) private var allJobs: [JobPosting]
    @Environment(\.modelContext) private var modelContext
    @State private var showAddJob = false

    private var savedJobs: [JobPosting] { allJobs.filter { $0.status == .saved } }

    var body: some View {
        NavigationStack {
            Group {
                if savedJobs.isEmpty {
                    ContentUnavailableView(
                        "No Saved Jobs",
                        systemImage: "briefcase.badge.plus",
                        description: Text("Tap + to add a job posting and let AI score it against your profile.")
                    )
                } else {
                    List {
                        ForEach(savedJobs) { job in
                            NavigationLink(destination: JobDetailView(job: job)) {
                                JobRow(job: job)
                            }
                        }
                        .onDelete { offsets in
                            offsets.forEach { savedJobs[$0].status = .archived }
                            try? modelContext.save()
                        }
                    }
                }
            }
            .navigationTitle("Discover")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddJob = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddJob) {
                AddJobView()
            }
        }
    }
}

// MARK: - Row

private struct JobRow: View {
    let job: JobPosting

    var body: some View {
        HStack(spacing: 12) {
            PriorityBadge(score: job.priorityScore)
            VStack(alignment: .leading, spacing: 2) {
                Text(job.title).font(.subheadline.bold())
                Text("\(job.company) · \(job.location)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}
