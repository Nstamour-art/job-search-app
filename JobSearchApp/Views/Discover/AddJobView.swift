import SwiftUI
import SwiftData

struct AddJobView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container

    @State private var urlText = ""
    @State private var descriptionText = ""
    @State private var isFetching = false
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var parsed: ParsedJobPosting?
    @State private var profile: UserProfile?

    private var hasTavilyKey: Bool {
        guard let key = try? KeychainManager.shared.retrieve(forKey: KeychainKeys.tavilyAPIKey)
        else { return false }
        return !key.isEmpty
    }

    private var canAnalyze: Bool {
        !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isAnalyzing && !isFetching
    }

    var body: some View {
        NavigationStack {
            Form {
                if hasTavilyKey {
                    Section {
                        TextField("https://company.com/jobs/…", text: $urlText)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        Button("Fetch from URL") { Task { await fetchFromURL() } }
                            .disabled(urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                      || isFetching || isAnalyzing)
                    } header: { Text("Job URL") } footer: {
                        Text("Tavily will fetch the job description automatically.")
                    }
                }

                Section {
                    TextEditor(text: $descriptionText)
                        .frame(minHeight: 160)
                        .disabled(isFetching)
                } header: { Text("Job Description") } footer: {
                    Text("Paste the full job posting.")
                }

                if isFetching {
                    Section { ProgressView("Fetching page…").frame(maxWidth: .infinity) }
                } else if isAnalyzing {
                    Section { ProgressView("Analyzing with AI…").frame(maxWidth: .infinity) }
                } else if let error = errorMessage {
                    Section { Text(error).foregroundStyle(.red).font(.caption) }
                }

                Section {
                    Button("Analyze with AI") { Task { await analyze() } }
                        .disabled(!canAnalyze)
                        .frame(maxWidth: .infinity)
                }

                if let p = parsed {
                    Section("Preview") {
                        LabeledContent("Title", value: p.title)
                        LabeledContent("Company", value: p.company)
                        LabeledContent("Location", value: p.location)
                        LabeledContent("Priority") {
                            PriorityBadge(score: p.priorityScore)
                        }
                        Text(p.priorityReasoning)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Section {
                        Button("Save Job") { save() }
                            .buttonStyle(.borderedProminent)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Add Job")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                profile = try? modelContext.fetch(FetchDescriptor<UserProfile>()).first
            }
        }
    }

    // MARK: - Actions

    private func fetchFromURL() async {
        guard let key = try? KeychainManager.shared.retrieve(forKey: KeychainKeys.tavilyAPIKey),
              !key.isEmpty else { return }
        isFetching = true
        errorMessage = nil
        defer { isFetching = false }
        do {
            descriptionText = try await TavilyService(apiKey: key)
                .fetchContent(url: urlText.trimmingCharacters(in: .whitespacesAndNewlines))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func analyze() async {
        guard let profile else {
            errorMessage = "No profile found. Complete onboarding first."
            return
        }
        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }
        do {
            parsed = try await JobAnalysisService(llm: container.llmService)
                .analyze(jobText: descriptionText, profile: profile)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save() {
        guard let p = parsed else { return }
        let posting = JobPosting(
            url: urlText,
            title: p.title,
            company: p.company,
            location: p.location,
            scrapedDescription: descriptionText,
            priorityScore: p.priorityScore,
            priorityReasoning: p.priorityReasoning,
            status: .saved,
            dateFound: Date()
        )
        modelContext.insert(posting)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Shared subview (also used in DiscoverView and JobDetailView)

struct PriorityBadge: View {
    let score: Int

    var body: some View {
        Text("\(score)")
            .font(.caption.bold())
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(color)
            .clipShape(Circle())
    }

    private var color: Color {
        switch score {
        case 4...5: return .green
        case 3:     return .orange
        default:    return .red
        }
    }
}
