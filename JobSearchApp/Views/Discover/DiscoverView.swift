import SwiftUI
import SwiftData

struct DiscoverView: View {
    @Query(sort: \JobPosting.dateFound, order: .reverse) private var allJobs: [JobPosting]
    @Environment(\.modelContext) private var modelContext
    @Environment(AppContainer.self) private var container
    @Query private var profiles: [UserProfile]

    @State private var showAddJob = false
    @State private var searchQuery = ""
    @State private var searchVM = JobSearchViewModel()

    private var savedJobs: [JobPosting] { allJobs.filter { $0.status == .saved } }
    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            Group {
                if savedJobs.isEmpty && !searchVM.isSearching {
                    ContentUnavailableView(
                        "No Saved Jobs",
                        systemImage: "magnifyingglass",
                        description: Text("Search for jobs above or tap + to add one manually.")
                    )
                } else {
                    List {
                        if searchVM.isSearching, let progress = searchVM.progress {
                            Section {
                                HStack(spacing: 12) {
                                    ProgressView()
                                    Text(progress).font(.subheadline).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if let error = searchVM.errorMessage {
                            Section {
                                Text(error).font(.caption).foregroundStyle(.red)
                            }
                        }

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
            .searchable(text: $searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search jobs (e.g. iOS engineer Toronto)")
            .onSubmit(of: .search) {
                Task {
                    let key = (try? KeychainManager.shared.retrieve(forKey: KeychainKeys.tavilyAPIKey)) ?? ""
                    await searchVM.search(
                        query: searchQuery,
                        tavilyKey: key,
                        llmService: container.llmService,
                        profile: profile,
                        context: modelContext
                    )
                }
            }
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
