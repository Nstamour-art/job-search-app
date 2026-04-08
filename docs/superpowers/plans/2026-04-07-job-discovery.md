# Job Discovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the Discover and Applications tabs — users paste or fetch job postings, the LLM analyzes fit against their profile, and jobs move through a saved → applied → archived pipeline.

**Architecture:** `JobAnalysisService` wraps `LLMService` to extract structured job info and score fit against the user's `UserProfile`. `TavilyService` optionally fetches page content from a job URL using the Tavily Extract API (configured in Settings). `DiscoverView` lists saved jobs via `@Query`, `AddJobView` drives the paste/fetch/analyze/save flow, `JobDetailView` shows full detail and status actions, and `ApplicationsView` shows applied and archived jobs.

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData (`@Query`), `LLMService` protocol (Claude), Tavily Extract API, `MockLLMService` for unit tests

---

## File Structure

```
JobSearchApp/
├── Services/
│   ├── JobAnalysisService.swift          # Create: ParsedJobPosting + LLM analysis against profile
│   └── TavilyService.swift               # Create: URLSession-based fetch from Tavily Extract API
├── Views/
│   ├── Discover/
│   │   ├── DiscoverView.swift            # Modify: full job list, add button, swipe-to-archive
│   │   ├── AddJobView.swift              # Create: URL/text input → fetch → analyze → save sheet
│   │   └── JobDetailView.swift           # Create: full job detail + status action buttons
│   └── Applications/
│       └── ApplicationsView.swift        # Modify: applied/archived jobs with status picker
└── JobSearchAppTests/
    └── Services/
        └── JobAnalysisServiceTests.swift  # Create: 4 tests
```

**No model changes.** `JobPosting` (url, title, company, location, scrapedDescription, priorityScore, priorityReasoning, status, dateFound, documents) and `JobStatus` (.saved, .applied, .archived) are already defined in `JobSearchApp/Models/JobModels.swift`.

---

## Task 1: JobAnalysisService

**Files:**
- Create: `JobSearchApp/Services/JobAnalysisService.swift`
- Create: `JobSearchAppTests/Services/JobAnalysisServiceTests.swift`

`JobAnalysisService` sends the job text + a profile summary to the LLM and returns a `ParsedJobPosting` with extracted title/company/location and a priority score 1–5.

- [ ] **Step 1: Write the failing tests**

  Create `JobSearchAppTests/Services/JobAnalysisServiceTests.swift`:

  ```swift
  import XCTest
  import SwiftData
  @testable import JobSearchApp

  @MainActor
  final class JobAnalysisServiceTests: XCTestCase {
      var container: ModelContainer!

      override func setUp() {
          super.setUp()
          let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
          container = try! ModelContainer(
              for: UserProfile.self, WorkExperience.self,
                   Education.self, Project.self, ResumeTheme.self,
                   JobPosting.self, GeneratedDocument.self,
              configurations: config
          )
      }

      override func tearDown() {
          container = nil
          super.tearDown()
      }

      private func makeProfile(skills: [String] = ["Swift", "SwiftUI", "iOS"]) -> UserProfile {
          let basics = ProfileBasics(
              name: "Jane Doe", email: "jane@example.com", phone: nil,
              location: "Toronto, ON", linkedIn: nil, github: nil, website: nil
          )
          let profile = UserProfile(basics: basics)
          profile.skills = skills
          container.mainContext.insert(profile)
          return profile
      }

      func test_analyze_extractsStructuredFields() async throws {
          let json = """
          {"title":"iOS Engineer","company":"Acme Corp","location":"Toronto, ON",
           "priorityScore":4,"priorityReasoning":"Strong Swift/SwiftUI match"}
          """
          let service = JobAnalysisService(llm: MockLLMService(response: json))
          let result = try await service.analyze(jobText: "We are hiring an iOS engineer...", profile: makeProfile())
          XCTAssertEqual(result.title, "iOS Engineer")
          XCTAssertEqual(result.company, "Acme Corp")
          XCTAssertEqual(result.location, "Toronto, ON")
          XCTAssertEqual(result.priorityScore, 4)
          XCTAssertFalse(result.priorityReasoning.isEmpty)
      }

      func test_analyze_handlesMarkdownFencedJSON() async throws {
          let response = """
          ```json
          {"title":"Dev","company":"Beta","location":"Remote","priorityScore":3,"priorityReasoning":"Decent fit"}
          ```
          """
          let service = JobAnalysisService(llm: MockLLMService(response: response))
          let result = try await service.analyze(jobText: "Job posting text...", profile: makeProfile())
          XCTAssertEqual(result.title, "Dev")
          XCTAssertEqual(result.priorityScore, 3)
      }

      func test_analyze_throwsOnInvalidJSON() async {
          let service = JobAnalysisService(llm: MockLLMService(response: "not json"))
          do {
              _ = try await service.analyze(jobText: "...", profile: makeProfile())
              XCTFail("Expected DecodingError")
          } catch {
              XCTAssertTrue(error is DecodingError)
          }
      }

      func test_analyze_propagatesLLMError() async {
          let service = JobAnalysisService(llm: MockLLMService(error: URLError(.badServerResponse)))
          do {
              _ = try await service.analyze(jobText: "...", profile: makeProfile())
              XCTFail("Expected error")
          } catch {
              XCTAssertTrue(error is URLError)
          }
      }
  }
  ```

- [ ] **Step 2: Run the tests to verify they fail**

  ```bash
  xcodebuild test \
    -scheme JobSearchApp \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    -only-testing:JobSearchAppTests/JobAnalysisServiceTests \
    > /tmp/test_out.txt 2>&1; tail -5 /tmp/test_out.txt
  ```
  Expected: Build error — `JobAnalysisService` not defined.

- [ ] **Step 3: Create `JobSearchApp/Services/JobAnalysisService.swift`**

  ```swift
  import Foundation
  import SwiftData

  struct ParsedJobPosting: Decodable {
      var title: String
      var company: String
      var location: String
      var priorityScore: Int         // 1–5
      var priorityReasoning: String
  }

  final class JobAnalysisService {
      private let llm: any LLMService

      init(llm: any LLMService) {
          self.llm = llm
      }

      func analyze(jobText: String, profile: UserProfile) async throws -> ParsedJobPosting {
          let system = buildSystem(profile: profile)
          let raw = try await llm.complete(prompt: jobText, system: system)
          return try decode(from: raw)
      }

      // MARK: - Private

      private func buildSystem(profile: UserProfile) -> String {
          let skills = profile.skills.prefix(20).joined(separator: ", ")
          let recentRole = profile.workHistory
              .sorted { $0.startDate > $1.startDate }
              .first
          let roleContext = recentRole.map {
              "Most recent role: \($0.title) at \($0.company)."
          } ?? ""
          return """
          You are a career coach helping a job seeker prioritize job postings.
          Candidate profile — skills: \(skills.isEmpty ? "not specified" : skills). \(roleContext)
          Analyze the following job posting and return ONLY valid JSON (no markdown, no explanation):
          {"title":"string","company":"string","location":"string","priorityScore":1-5,"priorityReasoning":"string"}
          Priority scale: 1=poor fit, 2=weak, 3=moderate, 4=strong, 5=excellent.
          Consider skill overlap, seniority level, and location/remote fit.
          """
      }

      private func decode(from raw: String) throws -> ParsedJobPosting {
          let json = stripFences(from: raw)
          return try JSONDecoder().decode(ParsedJobPosting.self, from: Data(json.utf8))
      }

      private func stripFences(from text: String) -> String {
          let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
          guard trimmed.hasPrefix("```") else { return trimmed }
          var lines = trimmed.components(separatedBy: "\n")
          lines.removeFirst()
          if lines.last?.trimmingCharacters(in: .whitespaces) == "```" { lines.removeLast() }
          return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
      }
  }
  ```

- [ ] **Step 4: Run xcodegen then run the tests**

  ```bash
  cd /Users/nstamour/Documents/GitHub/job-search-app && xcodegen generate
  xcodebuild test \
    -scheme JobSearchApp \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    -only-testing:JobSearchAppTests/JobAnalysisServiceTests \
    > /tmp/test_out.txt 2>&1; tail -10 /tmp/test_out.txt
  ```
  Expected: `Test Suite 'JobAnalysisServiceTests' passed` with 4 tests.

- [ ] **Step 5: Commit**

  ```bash
  git add JobSearchApp/Services/JobAnalysisService.swift \
          JobSearchAppTests/Services/JobAnalysisServiceTests.swift
  git commit -m "feat: JobAnalysisService — LLM-backed job scoring against user profile"
  ```

---

## Task 2: TavilyService

**Files:**
- Create: `JobSearchApp/Services/TavilyService.swift`

Thin URLSession wrapper around Tavily's Extract API. No unit tests — it's a pure network boundary. The Tavily key is stored in Keychain under `KeychainKeys.tavilyAPIKey`.

Tavily Extract API:
- `POST https://api.tavily.com/extract`
- Body JSON: `{"urls": ["<url>"], "api_key": "<key>"}`
- Response JSON: `{"results": [{"url": "...", "raw_content": "..."}], "failed_results": [...]}`

- [ ] **Step 1: Create `JobSearchApp/Services/TavilyService.swift`**

  ```swift
  import Foundation

  enum TavilyError: LocalizedError {
      case noResults
      case httpError(Int)

      var errorDescription: String? {
          switch self {
          case .noResults:    return "Tavily returned no content for this URL."
          case .httpError(let code): return "Tavily request failed with status \(code)."
          }
      }
  }

  final class TavilyService {
      private let apiKey: String

      init(apiKey: String) {
          self.apiKey = apiKey
      }

      func fetchContent(url: String) async throws -> String {
          let endpoint = URL(string: "https://api.tavily.com/extract")!
          var request = URLRequest(url: endpoint)
          request.httpMethod = "POST"
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")
          let body: [String: Any] = ["urls": [url], "api_key": apiKey]
          request.httpBody = try JSONSerialization.data(withJSONObject: body)

          let (data, response) = try await URLSession.shared.data(for: request)
          if let http = response as? HTTPURLResponse, http.statusCode != 200 {
              throw TavilyError.httpError(http.statusCode)
          }

          struct TavilyResponse: Decodable {
              struct Result: Decodable { let raw_content: String }
              let results: [Result]
          }
          let decoded = try JSONDecoder().decode(TavilyResponse.self, from: data)
          guard let first = decoded.results.first else { throw TavilyError.noResults }
          return first.raw_content
      }
  }
  ```

- [ ] **Step 2: Build to verify it compiles**

  ```bash
  cd /Users/nstamour/Documents/GitHub/job-search-app && xcodegen generate && \
  xcodebuild build \
    -scheme JobSearchApp \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    > /tmp/build_out.txt 2>&1; tail -5 /tmp/build_out.txt
  ```
  Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

  ```bash
  git add JobSearchApp/Services/TavilyService.swift
  git commit -m "feat: TavilyService — fetch job page content from URL"
  ```

---

## Task 3: AddJobView

**Files:**
- Create: `JobSearchApp/Views/Discover/AddJobView.swift`

Sheet that drives the full add-job workflow: enter URL (if Tavily key is configured) or paste text → analyze → review extracted info → save.

- [ ] **Step 1: Create `JobSearchApp/Views/Discover/AddJobView.swift`**

  ```swift
  import SwiftUI
  import SwiftData

  struct AddJobView: View {
      @Environment(\.modelContext) private var modelContext
      @Environment(\.dismiss) private var dismiss
      @EnvironmentObject private var container: AppContainer

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
  ```

- [ ] **Step 2: Build to verify it compiles**

  ```bash
  cd /Users/nstamour/Documents/GitHub/job-search-app && xcodegen generate && \
  xcodebuild build \
    -scheme JobSearchApp \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    > /tmp/build_out.txt 2>&1; tail -5 /tmp/build_out.txt
  ```
  Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

  ```bash
  git add JobSearchApp/Views/Discover/AddJobView.swift
  git commit -m "feat: AddJobView — paste or fetch job, analyze with AI, save"
  ```

---

## Task 4: JobDetailView

**Files:**
- Create: `JobSearchApp/Views/Discover/JobDetailView.swift`

Full-detail view for a single `JobPosting`. Created before `DiscoverView` because that view navigates to this one.

- [ ] **Step 1: Create `JobSearchApp/Views/Discover/JobDetailView.swift`**

  ```swift
  import SwiftUI

  struct JobDetailView: View {
      let job: JobPosting
      @Environment(\.modelContext) private var modelContext
      @Environment(\.dismiss) private var dismiss

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

                  // Status actions
                  statusActions

              }
              .padding()
          }
          .navigationTitle("Job Detail")
          .navigationBarTitleDisplayMode(.inline)
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
  ```

- [ ] **Step 2: Build to verify**

  ```bash
  cd /Users/nstamour/Documents/GitHub/job-search-app && xcodegen generate && \
  xcodebuild build \
    -scheme JobSearchApp \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    > /tmp/build_out.txt 2>&1; tail -5 /tmp/build_out.txt
  ```
  Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

  ```bash
  git add JobSearchApp/Views/Discover/JobDetailView.swift
  git commit -m "feat: JobDetailView — full job detail with status management"
  ```

---

## Task 5: DiscoverView

**Files:**
- Modify: `JobSearchApp/Views/Discover/DiscoverView.swift`

Replace the placeholder with a real job list. Uses `@Query` to fetch all `JobPosting` objects sorted by `dateFound` descending, then filters for `.saved` status in the view body. `JobDetailView` (Task 4) must exist before this builds.

- [ ] **Step 1: Replace `JobSearchApp/Views/Discover/DiscoverView.swift`**

  Read the file first, then overwrite with:

  ```swift
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
  ```

- [ ] **Step 2: Build to verify it compiles**

  ```bash
  xcodebuild build \
    -scheme JobSearchApp \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    > /tmp/build_out.txt 2>&1; tail -5 /tmp/build_out.txt
  ```
  Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

  ```bash
  git add JobSearchApp/Views/Discover/DiscoverView.swift
  git commit -m "feat: DiscoverView — saved jobs list with AI priority badges"
  ```

---

## Task 6: ApplicationsView

**Files:**
- Modify: `JobSearchApp/Views/Applications/ApplicationsView.swift`

Replace the placeholder. Shows jobs that are `.applied` or `.archived`, switchable via a `Picker`. Tapping a job navigates to `JobDetailView`.

- [ ] **Step 1: Replace `JobSearchApp/Views/Applications/ApplicationsView.swift`**

  Read the file first, then overwrite with:

  ```swift
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
  ```

- [ ] **Step 2: Build to verify**

  ```bash
  xcodebuild build \
    -scheme JobSearchApp \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    > /tmp/build_out.txt 2>&1; tail -5 /tmp/build_out.txt
  ```
  Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Run all tests**

  ```bash
  xcodebuild test \
    -scheme JobSearchApp \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    > /tmp/test_out.txt 2>&1; tail -20 /tmp/test_out.txt
  ```
  Expected: `Test Suite 'All tests' passed` (24 tests: 20 existing + 4 new JobAnalysisService tests).

- [ ] **Step 4: Commit**

  ```bash
  git add JobSearchApp/Views/Applications/ApplicationsView.swift
  git commit -m "feat: ApplicationsView — applied and archived jobs with status picker"
  ```

---

## What's Next

With Job Discovery complete:

- **Plan 4 — Documents:** `docs/superpowers/plans/2026-04-07-documents.md`
  - Generate tailored resumes and cover letters from a job posting + user profile
  - Export as PDF or plain text
