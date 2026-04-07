import SwiftUI
import SwiftData

struct ApplicationsView: View {
    @Query(sort: \JobPosting.dateFound, order: .reverse) private var allJobs: [JobPosting]
    @State private var selectedStatus: ApplicationTab = .applied

    enum ApplicationTab: String, CaseIterable {
        case applied = "Applied"
        case archived = "Archived"

        var jobStatus: JobStatus {
            switch self {
            case .applied:  return .applied
            case .archived: return .archived
            }
        }
    }

    private var filteredJobs: [JobPosting] {
        allJobs.filter { $0.status == selectedStatus.jobStatus }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Status", selection: $selectedStatus) {
                    ForEach(ApplicationTab.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                if filteredJobs.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "No \(selectedStatus.rawValue) Jobs",
                        systemImage: selectedStatus == .applied ? "paperplane" : "archivebox",
                        description: Text(
                            selectedStatus == .applied
                                ? "Mark a saved job as applied from its detail view."
                                : "Archive jobs from the Discover tab or job detail view."
                        )
                    )
                    Spacer()
                } else {
                    List(filteredJobs) { job in
                        NavigationLink(destination: JobDetailView(job: job)) {
                            ApplicationRow(job: job)
                        }
                    }
                }
            }
            .navigationTitle("Applications")
        }
    }
}

// MARK: - Row

private struct ApplicationRow: View {
    let job: JobPosting

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(job.title).font(.subheadline.bold())
            Text("\(job.company) · \(job.location)")
                .font(.caption).foregroundStyle(.secondary)
            Text(dateLabel(job.dateFound))
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private func dateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }
}
