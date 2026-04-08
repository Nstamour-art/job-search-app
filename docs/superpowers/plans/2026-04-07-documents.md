# Documents Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add LLM-powered resume and cover letter generation, PDF export, and a Documents library view for browsing and sharing generated documents.

**Architecture:** `DocumentGenerationService` wraps `LLMService` to produce plain-text content; `GenerateDocumentsView` is a sheet launched from `JobDetailView`; generated text is stored as UTF-8 `Data` in `GeneratedDocument` SwiftData objects linked to the originating `JobPosting`; `DocumentDetailView` renders the text and offers share-as-text (`ShareLink`) or export-as-PDF (UIKit renderer → `UIActivityViewController`); `DocumentsView` replaces its placeholder with a live `@Query`-backed list.

**Tech Stack:** Swift, SwiftUI, SwiftData, UIKit (`UISimpleTextPrintFormatter`, `UIPrintPageRenderer`, `UIGraphicsBeginPDFContextToData`, `UIActivityViewController`), xcodegen (`project.yml`)

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `JobSearchApp/Services/DocumentGenerationService.swift` | LLM prompt construction + generation |
| Create | `JobSearchAppTests/Services/DocumentGenerationServiceTests.swift` | Unit tests for the service |
| Create | `JobSearchApp/Views/Documents/GenerateDocumentsView.swift` | Sheet: pick resume/cover letter/both → generate + save |
| Create | `JobSearchApp/Views/Documents/DocumentDetailView.swift` | Text view + PDF export + share (also defines `ActivityViewController`, `DocumentRow`) |
| Modify | `JobSearchApp/Views/Discover/JobDetailView.swift` | Add Generate Documents button + documents list |
| Modify | `JobSearchApp/Views/Documents/DocumentsView.swift` | Replace placeholder with live `@Query` list |

**Key model facts (read before writing code):**
- `GeneratedDocument.init(type:richContent:linkedJob:)` — `linkedJob: JobPosting` is **non-optional**
- `GeneratedDocument.richContent: Data` — UTF-8-encoded plain text
- `WorkExperience.startDate/endDate` are `Date` (not `String`) — must format with `DateFormatter`
- `Project.projectDescription: String` (not `.description`)
- `DocumentType`: `.resume`, `.coverLetter`

---

## Task 1: DocumentGenerationService (TDD)

**Files:**
- Create: `JobSearchApp/Services/DocumentGenerationService.swift`
- Create: `JobSearchAppTests/Services/DocumentGenerationServiceTests.swift`

- [ ] **Step 1: Add files to project.yml**

Open `project.yml` and verify `JobSearchApp/Services/` and `JobSearchAppTests/Services/` source directories are already included as source tree entries (they are — from prior plans). No change needed.

- [ ] **Step 2: Write the failing tests**

Create `JobSearchAppTests/Services/DocumentGenerationServiceTests.swift`:

```swift
import XCTest
import SwiftData
@testable import JobSearchApp

@MainActor
final class DocumentGenerationServiceTests: XCTestCase {
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
        profile.skills = ["Swift", "SwiftUI"]
        container.mainContext.insert(profile)
        return profile
    }

    private func makeJob() -> JobPosting {
        let job = JobPosting(
            url: "", title: "iOS Engineer", company: "TechCo", location: "Remote",
            scrapedDescription: "We build iOS apps.",
            priorityScore: 4, priorityReasoning: "Good fit",
            status: .saved, dateFound: Date()
        )
        container.mainContext.insert(job)
        return job
    }

    func test_generateResume_returnsLLMOutput() async throws {
        let service = DocumentGenerationService(llm: MockLLMService(response: "Resume content here"))
        let result = try await service.generateResume(profile: makeProfile(), job: makeJob())
        XCTAssertEqual(result, "Resume content here")
    }

    func test_generateCoverLetter_returnsLLMOutput() async throws {
        let service = DocumentGenerationService(llm: MockLLMService(response: "Cover letter content"))
        let result = try await service.generateCoverLetter(profile: makeProfile(), job: makeJob())
        XCTAssertEqual(result, "Cover letter content")
    }

    func test_generateResume_propagatesLLMError() async {
        let service = DocumentGenerationService(llm: MockLLMService(error: URLError(.badServerResponse)))
        do {
            _ = try await service.generateResume(profile: makeProfile(), job: makeJob())
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is URLError)
        }
    }

    func test_generateCoverLetter_propagatesLLMError() async {
        let service = DocumentGenerationService(llm: MockLLMService(error: URLError(.badServerResponse)))
        do {
            _ = try await service.generateCoverLetter(profile: makeProfile(), job: makeJob())
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is URLError)
        }
    }
}
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
xcodebuild test \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:JobSearchAppTests/DocumentGenerationServiceTests \
  2>&1 | grep -E "error:|FAILED|passed|failed"
```

Expected: compile error — `DocumentGenerationService` does not exist yet.

- [ ] **Step 4: Write minimal implementation**

Create `JobSearchApp/Services/DocumentGenerationService.swift`:

```swift
import Foundation
import SwiftData

final class DocumentGenerationService {
    private let llm: any LLMService

    init(llm: any LLMService) {
        self.llm = llm
    }

    func generateResume(profile: UserProfile, job: JobPosting) async throws -> String {
        let system = """
        You are a professional resume writer. Generate a clean, ATS-friendly resume in plain text.
        Tailor it to the job posting. Format sections clearly:
        CONTACT, SUMMARY, EXPERIENCE, EDUCATION, SKILLS, PROJECTS.
        Return only the resume text — no explanation, no markdown.
        """
        return try await llm.complete(prompt: buildPrompt(profile: profile, job: job), system: system)
    }

    func generateCoverLetter(profile: UserProfile, job: JobPosting) async throws -> String {
        let system = """
        You are a professional cover letter writer. Generate a concise, compelling cover letter in plain text.
        Tailor it to the specific job and company. Include: opening paragraph, 2–3 body paragraphs,
        closing paragraph, sign-off. Return only the cover letter text — no explanation, no markdown.
        """
        return try await llm.complete(prompt: buildPrompt(profile: profile, job: job), system: system)
    }

    // MARK: - Private

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()

    private func buildPrompt(profile: UserProfile, job: JobPosting) -> String {
        var lines: [String] = []

        lines.append("=== CANDIDATE PROFILE ===")
        lines.append("Name: \(profile.basics.name)")
        lines.append("Email: \(profile.basics.email)")
        if let phone = profile.basics.phone { lines.append("Phone: \(phone)") }
        lines.append("Location: \(profile.basics.location)")
        if let li = profile.basics.linkedIn { lines.append("LinkedIn: \(li)") }
        if let gh = profile.basics.github { lines.append("GitHub: \(gh)") }

        let sorted = profile.workHistory.sorted { $0.startDate > $1.startDate }
        if !sorted.isEmpty {
            lines.append("\nWORK EXPERIENCE:")
            for exp in sorted {
                let start = dateFormatter.string(from: exp.startDate)
                let end = exp.isCurrent ? "Present" : exp.endDate.map { dateFormatter.string(from: $0) } ?? ""
                lines.append("• \(exp.title) at \(exp.company) (\(start)–\(end))")
                for bullet in exp.bullets { lines.append("  - \(bullet)") }
            }
        }

        if !profile.education.isEmpty {
            lines.append("\nEDUCATION:")
            for edu in profile.education {
                let grad = edu.graduationDate.map { dateFormatter.string(from: $0) } ?? ""
                lines.append("• \(edu.degree) in \(edu.field) — \(edu.institution) (\(grad))")
            }
        }

        if !profile.skills.isEmpty {
            lines.append("\nSKILLS: \(profile.skills.joined(separator: ", "))")
        }

        if !profile.projects.isEmpty {
            lines.append("\nPROJECTS:")
            for proj in profile.projects {
                lines.append("• \(proj.name): \(proj.projectDescription)")
                for bullet in proj.bullets { lines.append("  - \(bullet)") }
            }
        }

        lines.append("\n=== JOB POSTING ===")
        lines.append("Title: \(job.title)")
        lines.append("Company: \(job.company)")
        lines.append("Location: \(job.location)")
        lines.append("\n\(job.scrapedDescription)")

        return lines.joined(separator: "\n")
    }
}
```

- [ ] **Step 5: Run xcodegen then run tests**

```bash
cd /Users/nstamour/Documents/GitHub/job-search-app && xcodegen generate
```

```bash
xcodebuild test \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:JobSearchAppTests/DocumentGenerationServiceTests \
  2>&1 | grep -E "error:|FAILED|passed|failed"
```

Expected: `Test Suite 'DocumentGenerationServiceTests' passed` with 4 tests.

- [ ] **Step 6: Commit**

```bash
git add JobSearchApp/Services/DocumentGenerationService.swift \
        JobSearchAppTests/Services/DocumentGenerationServiceTests.swift
git commit -m "feat: DocumentGenerationService with resume and cover letter generation"
```

---

## Task 2: GenerateDocumentsView

**Files:**
- Create: `JobSearchApp/Views/Documents/GenerateDocumentsView.swift`

- [ ] **Step 1: Create GenerateDocumentsView.swift**

```swift
import SwiftUI
import SwiftData

struct GenerateDocumentsView: View {
    let job: JobPosting
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var container: AppContainer
    @Query private var profiles: [UserProfile]

    enum GenerationTarget: String, CaseIterable, Identifiable {
        case resume = "Resume"
        case coverLetter = "Cover Letter"
        case both = "Both"
        var id: String { rawValue }
    }

    @State private var target: GenerationTarget = .both
    @State private var isGenerating = false
    @State private var errorMessage: String?

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            Form {
                Section("Document Type") {
                    Picker("Document", selection: $target) {
                        ForEach(GenerationTarget.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if isGenerating {
                    Section {
                        ProgressView("Generating with AI…").frame(maxWidth: .infinity)
                    }
                }

                if let error = errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red).font(.caption)
                    }
                }

                Section {
                    Button("Generate") { Task { await generate() } }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .disabled(isGenerating || profile == nil)
                }
            }
            .navigationTitle("Generate Documents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Actions

    private func generate() async {
        guard let profile else {
            errorMessage = "No profile found. Complete onboarding first."
            return
        }
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }
        let service = DocumentGenerationService(llm: container.llmService)
        do {
            switch target {
            case .resume:
                try await generateAndSave(type: .resume, using: service, profile: profile)
            case .coverLetter:
                try await generateAndSave(type: .coverLetter, using: service, profile: profile)
            case .both:
                try await generateAndSave(type: .resume, using: service, profile: profile)
                try await generateAndSave(type: .coverLetter, using: service, profile: profile)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func generateAndSave(
        type: DocumentType,
        using service: DocumentGenerationService,
        profile: UserProfile
    ) async throws {
        let text: String
        switch type {
        case .resume:        text = try await service.generateResume(profile: profile, job: job)
        case .coverLetter:   text = try await service.generateCoverLetter(profile: profile, job: job)
        }
        let doc = GeneratedDocument(type: type, richContent: Data(text.utf8), linkedJob: job)
        modelContext.insert(doc)
        try modelContext.save()
    }
}
```

- [ ] **Step 2: Run xcodegen and verify it builds**

```bash
cd /Users/nstamour/Documents/GitHub/job-search-app && xcodegen generate
xcodebuild build \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add JobSearchApp/Views/Documents/GenerateDocumentsView.swift
git commit -m "feat: GenerateDocumentsView sheet for LLM document generation"
```

---

## Task 3: Update JobDetailView

**Files:**
- Modify: `JobSearchApp/Views/Discover/JobDetailView.swift`

Current content at `JobSearchApp/Views/Discover/JobDetailView.swift` is 90 lines. Replace entirely with:

- [ ] **Step 1: Replace JobDetailView.swift**

```swift
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
```

- [ ] **Step 2: Build to verify no errors**

```bash
xcodebuild build \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add JobSearchApp/Views/Discover/JobDetailView.swift
git commit -m "feat: add Generate Documents button and document list to JobDetailView"
```

---

## Task 4: DocumentDetailView (text view + PDF export + share)

**Files:**
- Create: `JobSearchApp/Views/Documents/DocumentDetailView.swift`

This file also defines `ActivityViewController` (UIKit share sheet wrapper) and `DocumentRow` (used by both `JobDetailView` and `DocumentsView`).

- [ ] **Step 1: Create DocumentDetailView.swift**

```swift
import SwiftUI
import UIKit

struct DocumentDetailView: View {
    let document: GeneratedDocument
    @State private var showSharePDF = false
    @State private var pdfData: Data?

    private var textContent: String {
        String(data: document.richContent, encoding: .utf8) ?? ""
    }

    private var documentTitle: String {
        switch document.type {
        case .resume:       return "Resume"
        case .coverLetter:  return "Cover Letter"
        }
    }

    var body: some View {
        ScrollView {
            Text(textContent)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(documentTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ShareLink("Share as Text", item: textContent)
                    Button("Export as PDF") { exportPDF() }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showSharePDF) {
            if let data = pdfData {
                ActivityViewController(activityItems: [data])
            }
        }
    }

    private func exportPDF() {
        pdfData = makePDF(from: textContent)
        showSharePDF = true
    }

    private func makePDF(from text: String) -> Data {
        let formatter = UISimpleTextPrintFormatter(text: text)
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAtIndex: 0)
        // A4 in points (72 pts/inch): 8.27" × 11.69"
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)
        renderer.setValue(NSValue(cgRect: pageRect), forKey: "paperRect")
        renderer.setValue(NSValue(cgRect: pageRect.insetBy(dx: 36, dy: 54)), forKey: "printableRect")
        let data = NSMutableData()
        UIGraphicsBeginPDFContextToData(data, pageRect, nil)
        for i in 0..<renderer.numberOfPages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: i, in: UIGraphicsGetPDFContextBounds())
        }
        UIGraphicsEndPDFContext()
        return data as Data
    }
}

// MARK: - UIKit share sheet wrapper

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Shared document row (used by JobDetailView and DocumentsView)

struct DocumentRow: View {
    let document: GeneratedDocument

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: document.type == .resume ? "doc.text" : "envelope")
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(document.type == .resume ? "Resume" : "Cover Letter")
                    .font(.subheadline.bold())
                Text(document.linkedJob.company)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
```

- [ ] **Step 2: Run xcodegen and build**

```bash
cd /Users/nstamour/Documents/GitHub/job-search-app && xcodegen generate
xcodebuild build \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add JobSearchApp/Views/Documents/DocumentDetailView.swift
git commit -m "feat: DocumentDetailView with text view, PDF export, and share sheet"
```

---

## Task 5: DocumentsView library

**Files:**
- Modify: `JobSearchApp/Views/Documents/DocumentsView.swift`

Replace the placeholder entirely.

- [ ] **Step 1: Replace DocumentsView.swift**

```swift
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
```

- [ ] **Step 2: Run xcodegen and run all tests**

```bash
cd /Users/nstamour/Documents/GitHub/job-search-app && xcodegen generate
xcodebuild test \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|FAILED|passed|failed|Test Suite"
```

Expected: All tests pass (including 4 new `DocumentGenerationServiceTests`).

- [ ] **Step 3: Commit**

```bash
git add JobSearchApp/Views/Documents/DocumentsView.swift
git commit -m "feat: DocumentsView library with live query and navigation to DocumentDetailView"
```

---

## Self-Review Checklist

**Spec coverage:**
- [x] `DocumentGenerationService` with `generateResume` + `generateCoverLetter` — Task 1
- [x] TDD: tests written first, 4 cases covering pass-through and error propagation — Task 1
- [x] `GenerateDocumentsView` sheet: picker (resume/cover letter/both), loading state, error state, dismiss on success — Task 2
- [x] `JobDetailView` updated: Generate Documents button → sheet, documents list with `DocumentRow` → `DocumentDetailView` — Task 3
- [x] `DocumentDetailView`: renders plain-text content, share-as-text via `ShareLink`, export-as-PDF via UIKit + `UIActivityViewController` — Task 4
- [x] `ActivityViewController` (`UIViewControllerRepresentable`) for PDF share — Task 4
- [x] `DocumentRow` defined at module scope (accessible by both `JobDetailView` and `DocumentsView`) — Task 4
- [x] `DocumentsView` replaces placeholder with `@Query`-sorted list + `ContentUnavailableView` empty state — Task 5

**Type consistency:**
- `DocumentRow` defined in Task 4, referenced in Tasks 3 and 5 — Task 4 must be completed before Tasks 3 and 5 build successfully. However, the plan commits them independently — if a build error occurs in Task 3's verify step because `DocumentRow` doesn't exist yet, run xcodegen anyway (it's checking compile, not link). **Recommended order: 1 → 2 → 4 → 3 → 5** if doing a single build per task, or follow as written if you run a full build only at the end of each task.

**Note on build order:** Task 3 references `DocumentDetailView` and `DocumentRow` (defined in Task 4). If you build after Task 3 before Task 4, you'll get a compile error. This is expected — complete Task 4 before the final verification build, or skip the build step in Task 3 and run the full build after Task 4.
