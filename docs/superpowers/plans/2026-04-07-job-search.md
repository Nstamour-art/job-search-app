# Job Search (Flow 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable users to type a natural-language job search query ("Senior iOS engineer, Toronto, remote"), which calls the Tavily Search API to get a list of matching job URLs, fetches each posting's content, runs AI analysis on each, and saves them as `JobPosting` objects that appear in the Discover tab.

**Architecture:** `TavilyService` gains a `search(query:)` method using the Tavily Search endpoint. A new `JobSearchViewModel` (`@MainActor ObservableObject`) orchestrates the batch fetch-and-analyze pipeline with progress reporting. `DiscoverView` gains a `.searchable` bar + submit handler, a progress banner during search, and an inline error display; search results appear automatically via the existing `@Query`.

**Tech Stack:** SwiftUI, SwiftData, `TavilyService` (extended), `JobAnalysisService` (existing), `AppContainer.llmService` (existing)

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Modify | `JobSearchApp/Services/TavilyService.swift` | Add `search(query:)` + `TavilySearchResult` |
| Create | `JobSearchApp/ViewModels/JobSearchViewModel.swift` | Batch fetch → analyze → save pipeline |
| Modify | `JobSearchApp/Views/Discover/DiscoverView.swift` | Search bar + progress banner + error |
| Create | `JobSearchAppTests/Services/TavilyServiceSearchTests.swift` | Tests for search endpoint |
| Create | `JobSearchAppTests/ViewModels/JobSearchViewModelTests.swift` | Tests for the pipeline |

---

## Task 1: Extend TavilyService with search (TDD)

**Files:**
- Modify: `JobSearchApp/Services/TavilyService.swift`
- Create: `JobSearchAppTests/Services/TavilyServiceSearchTests.swift`

- [ ] **Step 1: Write failing tests**

Create `JobSearchAppTests/Services/TavilyServiceSearchTests.swift`:

```swift
import XCTest
@testable import JobSearchApp

final class TavilyServiceSearchTests: XCTestCase {

    func test_search_decodesResults() async throws {
        let json = """
        {"results":[
          {"title":"iOS Engineer at Acme","url":"https://acme.com/jobs/1","content":"We need Swift engineers"},
          {"title":"Mobile Dev at Beta","url":"https://beta.com/jobs/2","content":"SwiftUI experience required"}
        ]}
        """
        let session = MockURLSession(data: json.data(using: .utf8)!, statusCode: 200)
        let service = TavilyService(apiKey: "test-key", session: session)
        let results = try await service.search(query: "iOS engineer Toronto")
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].title, "iOS Engineer at Acme")
        XCTAssertEqual(results[0].url, "https://acme.com/jobs/1")
        XCTAssertEqual(results[0].content, "We need Swift engineers")
    }

    func test_search_throwsOnHTTPError() async {
        let session = MockURLSession(data: Data(), statusCode: 401)
        let service = TavilyService(apiKey: "bad-key", session: session)
        do {
            _ = try await service.search(query: "iOS")
            XCTFail("Expected error")
        } catch TavilyError.httpError(let code) {
            XCTAssertEqual(code, 401)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_search_throwsNoResultsOnEmptyArray() async throws {
        let json = """{"results":[]}"""
        let session = MockURLSession(data: json.data(using: .utf8)!, statusCode: 200)
        let service = TavilyService(apiKey: "test-key", session: session)
        do {
            _ = try await service.search(query: "obscure query")
            XCTFail("Expected noResults")
        } catch TavilyError.noResults {
            // expected
        }
    }
}
```

This requires `TavilyService` to accept a `URLSession` parameter (for testability) and a `MockURLSession` test helper.

- [ ] **Step 2: Create MockURLSession test helper**

Check if `MockURLSession` already exists in the test target:

```bash
grep -rn "MockURLSession" /Users/nstamour/Documents/GitHub/job-search-app/JobSearchAppTests/
```

If it doesn't exist, create `JobSearchAppTests/Helpers/MockURLSession.swift`:

```swift
import Foundation
@testable import JobSearchApp

final class MockURLSession: URLSessionProtocol {
    let data: Data
    let statusCode: Int
    var lastRequest: URLRequest?

    init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}
```

And define `URLSessionProtocol` in `JobSearchApp/Services/URLSessionProtocol.swift`:

```swift
import Foundation

protocol URLSessionProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
cd /Users/nstamour/Documents/GitHub/job-search-app && xcodegen generate && xcodebuild test \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:JobSearchAppTests/TavilyServiceSearchTests \
  2>&1 | grep -E "error:|FAILED|passed|failed|Test Suite"
```

Expected: compile error — `search(query:)` not defined.

- [ ] **Step 4: Extend TavilyService with search endpoint + URLSessionProtocol**

Update `JobSearchApp/Services/TavilyService.swift` — add `TavilySearchResult`, update `TavilyService.init` to accept `URLSessionProtocol`, and add `search(query:)`. Also update `fetchContent(url:)` to use the protocol:

```swift
import Foundation

enum TavilyError: LocalizedError {
    case noResults
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .noResults:               return "Tavily returned no content for this URL."
        case .httpError(let code):     return "Tavily request failed with status \(code)."
        }
    }
}

struct TavilySearchResult {
    let title: String
    let url: String
    let content: String
}

final class TavilyService {
    private let apiKey: String
    private let session: any URLSessionProtocol

    init(apiKey: String, session: any URLSessionProtocol = URLSession.shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - Extract (existing)

    func fetchContent(url: String) async throws -> String {
        let endpoint = URL(string: "https://api.tavily.com/extract")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["urls": [url], "api_key": apiKey]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw TavilyError.httpError(http.statusCode)
        }

        struct TavilyExtractResponse: Decodable {
            struct Result: Decodable { let raw_content: String }
            let results: [Result]
        }
        let decoded = try JSONDecoder().decode(TavilyExtractResponse.self, from: data)
        guard let first = decoded.results.first else { throw TavilyError.noResults }
        return first.raw_content
    }

    // MARK: - Search

    func search(query: String, maxResults: Int = 7) async throws -> [TavilySearchResult] {
        let endpoint = URL(string: "https://api.tavily.com/search")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "api_key": apiKey,
            "query": query,
            "max_results": maxResults,
            "search_depth": "basic"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw TavilyError.httpError(http.statusCode)
        }

        struct TavilySearchResponse: Decodable {
            struct Result: Decodable {
                let title: String
                let url: String
                let content: String
            }
            let results: [Result]
        }
        let decoded = try JSONDecoder().decode(TavilySearchResponse.self, from: data)
        guard !decoded.results.isEmpty else { throw TavilyError.noResults }
        return decoded.results.map { TavilySearchResult(title: $0.title, url: $0.url, content: $0.content) }
    }
}
```

**Important:** Existing call sites (`AddJobView.fetchFromURL`) construct `TavilyService(apiKey: key)` — the new `session` parameter has a default of `.shared`, so no callsite changes needed.

- [ ] **Step 5: Run xcodegen and tests**

```bash
cd /Users/nstamour/Documents/GitHub/job-search-app && xcodegen generate && xcodebuild test \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:JobSearchAppTests/TavilyServiceSearchTests \
  2>&1 | grep -E "error:|FAILED|passed|failed|Test Suite"
```

Expected: 3 tests pass.

- [ ] **Step 6: Also check TavilyService existing tests pass**

```bash
xcodebuild test \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|FAILED|passed|failed|Test Suite"
```

Expected: All existing tests still pass.

- [ ] **Step 7: Commit**

```bash
git add JobSearchApp/Services/TavilyService.swift \
        JobSearchApp/Services/URLSessionProtocol.swift \
        JobSearchAppTests/Services/TavilyServiceSearchTests.swift \
        JobSearchAppTests/Helpers/MockURLSession.swift
git commit -m "feat: add Tavily search endpoint and URLSessionProtocol for testability"
```

---

## Task 2: JobSearchViewModel (TDD)

**Files:**
- Create: `JobSearchApp/ViewModels/JobSearchViewModel.swift`
- Create: `JobSearchAppTests/ViewModels/JobSearchViewModelTests.swift`

- [ ] **Step 1: Write failing tests**

Create `JobSearchAppTests/ViewModels/JobSearchViewModelTests.swift`:

```swift
import XCTest
import SwiftData
@testable import JobSearchApp

@MainActor
final class JobSearchViewModelTests: XCTestCase {
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

    private func makeProfile() -> UserProfile {
        let basics = ProfileBasics(
            name: "Jane Doe", email: "jane@example.com", phone: nil,
            location: "Toronto, ON", linkedIn: nil, github: nil, website: nil
        )
        let profile = UserProfile(basics: basics)
        profile.skills = ["Swift"]
        container.mainContext.insert(profile)
        return profile
    }

    func test_search_insertsJobPostings() async throws {
        let searchJSON = """
        {"results":[{"title":"iOS Dev","url":"https://co.com/1","content":"Build iOS apps with Swift"}]}
        """
        let analysisJSON = """
        {"title":"iOS Dev","company":"Co","location":"Remote","priorityScore":4,"priorityReasoning":"Good fit"}
        """
        let session = MockURLSession(data: searchJSON.data(using: .utf8)!, statusCode: 200)
        let llm = MockLLMService(response: analysisJSON)
        let vm = JobSearchViewModel()

        await vm.search(
            query: "iOS engineer",
            tavilyKey: "test",
            llmService: llm,
            profile: makeProfile(),
            context: container.mainContext,
            sessionOverride: session
        )

        let postings = try container.mainContext.fetch(FetchDescriptor<JobPosting>())
        XCTAssertEqual(postings.count, 1)
        XCTAssertEqual(postings[0].title, "iOS Dev")
        XCTAssertEqual(postings[0].company, "Co")
        XCTAssertEqual(postings[0].status, .saved)
    }

    func test_search_setsErrorOnMissingTavilyKey() async {
        let vm = JobSearchViewModel()
        await vm.search(
            query: "iOS engineer",
            tavilyKey: "",
            llmService: MockLLMService(response: ""),
            profile: makeProfile(),
            context: container.mainContext,
            sessionOverride: nil
        )
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.errorMessage!.contains("Tavily"))
    }

    func test_search_setsIsSearchingDuringWork() async {
        // isSearching should be true during the async call, false after
        let vm = JobSearchViewModel()
        XCTAssertFalse(vm.isSearching)
        let json = """{"results":[{"title":"T","url":"https://x.com","content":"c"}]}"""
        let session = MockURLSession(data: json.data(using: .utf8)!, statusCode: 200)
        let llm = MockLLMService(response: """{"title":"T","company":"X","location":"R","priorityScore":3,"priorityReasoning":"ok"}""")
        await vm.search(
            query: "q",
            tavilyKey: "key",
            llmService: llm,
            profile: makeProfile(),
            context: container.mainContext,
            sessionOverride: session
        )
        XCTAssertFalse(vm.isSearching)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail (compile error)**

```bash
cd /Users/nstamour/Documents/GitHub/job-search-app && xcodegen generate && xcodebuild test \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:JobSearchAppTests/JobSearchViewModelTests \
  2>&1 | grep -E "error:|FAILED|passed|failed|Test Suite"
```

Expected: compile error — `JobSearchViewModel` not found.

- [ ] **Step 3: Create the ViewModels directory and JobSearchViewModel.swift**

Create `JobSearchApp/ViewModels/JobSearchViewModel.swift`:

```swift
import Foundation
import SwiftData

@MainActor
final class JobSearchViewModel: ObservableObject {
    @Published var isSearching = false
    @Published var progress: String?
    @Published var errorMessage: String?

    func search(
        query: String,
        tavilyKey: String,
        llmService: any LLMService,
        profile: UserProfile?,
        context: ModelContext,
        sessionOverride: (any URLSessionProtocol)? = nil
    ) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return }
        guard !tavilyKey.isEmpty else {
            errorMessage = "Tavily API key not configured. Add it in Settings."
            return
        }
        guard let profile else {
            errorMessage = "No profile found. Complete onboarding first."
            return
        }

        isSearching = true
        progress = "Searching for jobs…"
        errorMessage = nil
        defer { isSearching = false; progress = nil }

        let session = sessionOverride ?? URLSession.shared
        let tavilyService = TavilyService(apiKey: tavilyKey, session: session)
        let analyzer = JobAnalysisService(llm: llmService)

        do {
            let results = try await tavilyService.search(query: trimmedQuery)
            for (index, result) in results.enumerated() {
                progress = "Analyzing job \(index + 1) of \(results.count)…"
                let parsed = try await analyzer.analyze(jobText: result.content, profile: profile)
                let posting = JobPosting(
                    url: result.url,
                    title: parsed.title,
                    company: parsed.company,
                    location: parsed.location,
                    scrapedDescription: result.content,
                    priorityScore: parsed.priorityScore,
                    priorityReasoning: parsed.priorityReasoning,
                    status: .saved,
                    dateFound: Date()
                )
                context.insert(posting)
                try? context.save()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

- [ ] **Step 4: Run xcodegen and tests**

```bash
cd /Users/nstamour/Documents/GitHub/job-search-app && xcodegen generate && xcodebuild test \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:JobSearchAppTests/JobSearchViewModelTests \
  2>&1 | grep -E "error:|FAILED|passed|failed|Test Suite"
```

Expected: 3 tests pass.

- [ ] **Step 5: Commit**

```bash
git add JobSearchApp/ViewModels/JobSearchViewModel.swift \
        JobSearchAppTests/ViewModels/JobSearchViewModelTests.swift
git commit -m "feat: JobSearchViewModel for batch Tavily search and job analysis"
```

---

## Task 3: Update DiscoverView with search bar

**Files:**
- Modify: `JobSearchApp/Views/Discover/DiscoverView.swift`

- [ ] **Step 1: Replace DiscoverView.swift**

The updated view adds a `@StateObject private var searchVM = JobSearchViewModel()`, a `@State private var searchQuery = ""`, a `.searchable` modifier, and a progress/error banner. The existing saved-jobs list is unchanged.

```swift
import SwiftUI
import SwiftData

struct DiscoverView: View {
    @Query(sort: \JobPosting.dateFound, order: .reverse) private var allJobs: [JobPosting]
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var container: AppContainer
    @Query private var profiles: [UserProfile]

    @State private var showAddJob = false
    @State private var searchQuery = ""
    @StateObject private var searchVM = JobSearchViewModel()

    private var savedJobs: [JobPosting] { allJobs.filter { $0.status == .saved } }
    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            Group {
                if savedJobs.isEmpty && !searchVM.isSearching {
                    ContentUnavailableView(
                        "No Saved Jobs",
                        systemImage: "briefcase.badge.plus",
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
```

- [ ] **Step 2: Build and run all tests**

```bash
cd /Users/nstamour/Documents/GitHub/job-search-app && xcodebuild test \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|FAILED|passed|failed|Test Suite"
```

Expected: All tests pass, `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
git add JobSearchApp/Views/Discover/DiscoverView.swift
git commit -m "feat: add search bar to DiscoverView with batch Tavily + AI job analysis"
```

---

## Self-Review Checklist

**Spec coverage:**
- [x] Tavily Search API call (`/search` endpoint, not `/extract`) — Task 1
- [x] `URLSessionProtocol` for testability — Task 1
- [x] `MockURLSession` test helper created — Task 1
- [x] `JobSearchViewModel` orchestrates search → analyze → insert pipeline — Task 2
- [x] Progress string updated per job ("Analyzing job N of M") — Task 2
- [x] Empty Tavily key shows inline error, not a crash — Task 2
- [x] `DiscoverView` uses `.searchable` + `.onSubmit(of: .search)` — Task 3
- [x] Progress and error displayed inline in List — Task 3
- [x] No regressions to AddJobView (manual URL) — implicit via full test run

**Type consistency:**
- `TavilyService.init(apiKey:session:)` — `session` defaults to `URLSession.shared` so existing callsites unchanged
- `JobSearchViewModel.search(query:tavilyKey:llmService:profile:context:sessionOverride:)` — `sessionOverride` defaults to `nil` in production callers
- `TavilySearchResult` fields (`title`, `url`, `content`) match the JSON response shape and the JobPosting init
