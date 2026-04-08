# Profile & Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete Profile tab and first-launch onboarding flow — a conversational AI interview that extracts structured career data from free-form text, section-by-section confirmation, theme selection, and a full profile editing interface.

**Architecture:** Onboarding is a step-machine (`OnboardingViewModel`) driving an `OnboardingView` that routes to per-section SwiftUI views. Profile parsing is isolated in `ProfileParseService`, which wraps `LLMService` with structured JSON prompts and intermediate `Parsed*` Decodable types. SwiftData models are created only when the user finishes onboarding. The Profile tab replaces its placeholder with a real `ProfileView` backed by `ProfileViewModel`.

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData, `LLMService` protocol (Claude), `MockLLMService` for unit tests, `JSONDecoder`

---

## File Structure

```
JobSearchApp/
├── App/
│   ├── JobSearchApp.swift               # Modify: add OnboardingCoordinator, route to onboarding or main
│   └── OnboardingCoordinator.swift      # Create: first-launch detection (UserDefaults flag)
├── Services/
│   └── ProfileParseService.swift        # Create: Parsed* types + LLM prompts for all 5 profile sections
├── Views/
│   ├── Onboarding/
│   │   ├── OnboardingView.swift         # Create: OnboardingViewModel + step-switching View
│   │   ├── OnboardingHelpers.swift      # Create: StepHeader, LabeledTextField, FlowLayout, SkillsChipsView
│   │   ├── WelcomeView.swift            # Create: welcome screen with "Build My Profile" CTA
│   │   ├── BasicsStepView.swift         # Create: text input → parse → editable basics form
│   │   ├── WorkHistoryStepView.swift    # Create: text input → parse → work experience list
│   │   ├── EducationStepView.swift      # Create: text input → parse → education list
│   │   ├── SkillsStepView.swift         # Create: text input → parse → skills chips
│   │   ├── ProjectsStepView.swift       # Create: text input → parse → projects list
│   │   └── ThemePickerView.swift        # Create: theme grid + "Finish" saves to SwiftData
│   └── Profile/
│       ├── ProfileView.swift            # Modify: full profile display (replaces placeholder)
│       ├── ProfileViewModel.swift       # Create: fetch UserProfile + CRUD helpers
│       ├── EditBasicsView.swift         # Create: edit name/email/location/links (sheet)
│       ├── WorkExperienceFormView.swift # Create: add/edit work experience (sheet)
│       ├── EducationFormView.swift      # Create: add/edit education entry (sheet)
│       ├── ProjectFormView.swift        # Create: add/edit project (sheet)
│       └── SkillsEditorView.swift       # Create: add/delete/reorder skills (sheet)
└── JobSearchAppTests/
    └── Services/
        └── ProfileParseServiceTests.swift  # Create
```

---

## Task 1: ProfileParseService

**Files:**
- Create: `JobSearchApp/Services/ProfileParseService.swift`
- Create: `JobSearchAppTests/Services/ProfileParseServiceTests.swift`

`ProfileParseService` wraps `LLMService` with five structured prompts — one per profile section. Each method returns a `Parsed*` intermediate type (plain `Decodable` structs, **not** `@Model` classes). SwiftData models are created later, at onboarding save time.

- [ ] **Step 1: Write the failing tests**

  Create `JobSearchAppTests/Services/ProfileParseServiceTests.swift`:

  ```swift
  import XCTest
  @testable import JobSearchApp

  final class ProfileParseServiceTests: XCTestCase {

      func test_parseBasics_extractsFields() async throws {
          let json = """
          {"name":"Jane Doe","email":"jane@example.com","phone":"+1 416 555 0100",
           "location":"Toronto, ON","linkedIn":"linkedin.com/in/janedoe","github":null,"website":null}
          """
          let service = ProfileParseService(llm: MockLLMService(response: json))
          let result = try await service.parseBasics(from: "I'm Jane Doe...")
          XCTAssertEqual(result.name, "Jane Doe")
          XCTAssertEqual(result.email, "jane@example.com")
          XCTAssertEqual(result.location, "Toronto, ON")
          XCTAssertNil(result.github)
      }

      func test_parseBasics_handlesMarkdownFencedJSON() async throws {
          let response = """
          ```json
          {"name":"John","email":"john@test.com","phone":null,"location":"NYC","linkedIn":null,"github":null,"website":null}
          ```
          """
          let service = ProfileParseService(llm: MockLLMService(response: response))
          let result = try await service.parseBasics(from: "John from NYC")
          XCTAssertEqual(result.name, "John")
      }

      func test_parseWorkExperiences_extractsList() async throws {
          let json = """
          [{"company":"Acme","title":"iOS Engineer","startDate":"2022-01",
            "endDate":null,"isCurrent":true,"bullets":["Built features","Led team"]}]
          """
          let service = ProfileParseService(llm: MockLLMService(response: json))
          let result = try await service.parseWorkExperiences(from: "I work at Acme...")
          XCTAssertEqual(result.count, 1)
          XCTAssertEqual(result[0].company, "Acme")
          XCTAssertTrue(result[0].isCurrent)
          XCTAssertEqual(result[0].bullets.count, 2)
      }

      func test_parseEducation_extractsList() async throws {
          let json = """
          [{"institution":"U of T","degree":"Bachelor","field":"Computer Science","graduationDate":"2020-06"}]
          """
          let service = ProfileParseService(llm: MockLLMService(response: json))
          let result = try await service.parseEducation(from: "I studied CS at UofT...")
          XCTAssertEqual(result.count, 1)
          XCTAssertEqual(result[0].institution, "U of T")
          XCTAssertEqual(result[0].graduationDate, "2020-06")
      }

      func test_parseSkills_extractsArray() async throws {
          let json = #"["Swift","SwiftUI","Python","Git"]"#
          let service = ProfileParseService(llm: MockLLMService(response: json))
          let result = try await service.parseSkills(from: "I know Swift, SwiftUI...")
          XCTAssertEqual(result, ["Swift", "SwiftUI", "Python", "Git"])
      }

      func test_parseProjects_extractsList() async throws {
          let json = """
          [{"name":"MyApp","description":"An iOS app","url":"github.com/me/myapp","bullets":["SwiftUI"]}]
          """
          let service = ProfileParseService(llm: MockLLMService(response: json))
          let result = try await service.parseProjects(from: "I built MyApp...")
          XCTAssertEqual(result.count, 1)
          XCTAssertEqual(result[0].name, "MyApp")
      }

      func test_parseBasics_throwsOnInvalidJSON() async {
          let service = ProfileParseService(llm: MockLLMService(response: "not json"))
          do {
              _ = try await service.parseBasics(from: "some text")
              XCTFail("Expected error")
          } catch {
              XCTAssertTrue(error is DecodingError)
          }
      }
  }
  ```

- [ ] **Step 2: Run the test to verify it fails**

  ```bash
  xcodebuild test \
    -scheme JobSearchApp \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    -only-testing:JobSearchAppTests/ProfileParseServiceTests \
    > /tmp/test_out.txt 2>&1; tail -10 /tmp/test_out.txt
  ```
  Expected: Build error — `ProfileParseService` not defined.

- [ ] **Step 3: Create `JobSearchApp/Services/ProfileParseService.swift`**

  ```swift
  import Foundation

  // MARK: - Intermediate parsed types (Decodable, not @Model)

  struct ParsedBasics: Decodable {
      var name: String
      var email: String
      var phone: String?
      var location: String
      var linkedIn: String?
      var github: String?
      var website: String?
  }

  struct ParsedWorkExperience: Decodable {
      var company: String
      var title: String
      var startDate: String    // "YYYY-MM"
      var endDate: String?     // "YYYY-MM" or null
      var isCurrent: Bool
      var bullets: [String]
  }

  struct ParsedEducation: Decodable {
      var institution: String
      var degree: String
      var field: String
      var graduationDate: String?   // "YYYY-MM" or null
  }

  struct ParsedProject: Decodable {
      var name: String
      var description: String
      var url: String?
      var bullets: [String]
  }

  // MARK: - Service

  final class ProfileParseService {
      private let llm: any LLMService

      init(llm: any LLMService) {
          self.llm = llm
      }

      func parseBasics(from text: String) async throws -> ParsedBasics {
          let system = """
          You are a career profile extractor. Extract contact information from the user's text.
          Return ONLY valid JSON matching this exact schema (no markdown, no explanation):
          {"name":"string","email":"string","phone":"string or null","location":"string",\
          "linkedIn":"string or null","github":"string or null","website":"string or null"}
          """
          let raw = try await llm.complete(prompt: text, system: system)
          return try decode(ParsedBasics.self, from: raw)
      }

      func parseWorkExperiences(from text: String) async throws -> [ParsedWorkExperience] {
          let system = """
          You are a career profile extractor. Extract all work experiences from the user's text.
          Return ONLY valid JSON array (no markdown, no explanation):
          [{"company":"string","title":"string","startDate":"YYYY-MM",\
          "endDate":"YYYY-MM or null","isCurrent":true or false,"bullets":["string"]}]
          If no work experience found, return [].
          """
          let raw = try await llm.complete(prompt: text, system: system)
          return try decode([ParsedWorkExperience].self, from: raw)
      }

      func parseEducation(from text: String) async throws -> [ParsedEducation] {
          let system = """
          You are a career profile extractor. Extract all education entries from the user's text.
          Return ONLY valid JSON array (no markdown, no explanation):
          [{"institution":"string","degree":"string","field":"string","graduationDate":"YYYY-MM or null"}]
          If no education found, return [].
          """
          let raw = try await llm.complete(prompt: text, system: system)
          return try decode([ParsedEducation].self, from: raw)
      }

      func parseSkills(from text: String) async throws -> [String] {
          let system = """
          You are a career profile extractor. Extract a list of skills from the user's text.
          Return ONLY valid JSON array of strings (no markdown, no explanation): ["skill1","skill2"]
          If no skills found, return [].
          """
          let raw = try await llm.complete(prompt: text, system: system)
          return try decode([String].self, from: raw)
      }

      func parseProjects(from text: String) async throws -> [ParsedProject] {
          let system = """
          You are a career profile extractor. Extract all projects from the user's text.
          Return ONLY valid JSON array (no markdown, no explanation):
          [{"name":"string","description":"string","url":"string or null","bullets":["string"]}]
          If no projects found, return [].
          """
          let raw = try await llm.complete(prompt: text, system: system)
          return try decode([ParsedProject].self, from: raw)
      }

      // MARK: - Helpers

      /// Strips markdown code fences (```json ... ```) if Claude wraps the response.
      private func stripFences(from text: String) -> String {
          let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
          guard trimmed.hasPrefix("```") else { return trimmed }
          let lines = trimmed.components(separatedBy: "\n")
          let body = lines.dropFirst().dropLast().joined(separator: "\n")
          return body.trimmingCharacters(in: .whitespacesAndNewlines)
      }

      private func decode<T: Decodable>(_ type: T.Type, from raw: String) throws -> T {
          let json = stripFences(from: raw)
          return try JSONDecoder().decode(T.self, from: Data(json.utf8))
      }
  }
  ```

- [ ] **Step 4: Run the tests to verify they pass**

  ```bash
  xcodebuild test \
    -scheme JobSearchApp \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    -only-testing:JobSearchAppTests/ProfileParseServiceTests \
    > /tmp/test_out.txt 2>&1; tail -15 /tmp/test_out.txt
  ```
  Expected: `Test Suite 'ProfileParseServiceTests' passed`

- [ ] **Step 5: Commit**

  ```bash
  git add JobSearchApp/Services/ProfileParseService.swift \
          JobSearchAppTests/Services/ProfileParseServiceTests.swift
  git commit -m "feat: ProfileParseService — LLM-backed profile extraction"
  ```

---

## Task 2: OnboardingCoordinator + App Entry Point

**Files:**
- Create: `JobSearchApp/App/OnboardingCoordinator.swift`
- Modify: `JobSearchApp/App/JobSearchApp.swift`

`OnboardingCoordinator` is a simple `ObservableObject` that persists a boolean flag to `UserDefaults`. `JobSearchApp` observes it and routes to either `OnboardingView` or `MainTabView`.

- [ ] **Step 1: Create `JobSearchApp/App/OnboardingCoordinator.swift`**

  ```swift
  import Foundation

  @MainActor
  final class OnboardingCoordinator: ObservableObject {
      @Published private(set) var isOnboardingComplete: Bool

      private static let key = "com.jobsearch.onboardingComplete"

      init() {
          isOnboardingComplete = UserDefaults.standard.bool(forKey: Self.key)
      }

      func completeOnboarding() {
          UserDefaults.standard.set(true, forKey: Self.key)
          isOnboardingComplete = true
      }

      /// Call from Settings or debug menu to re-trigger onboarding.
      func resetOnboarding() {
          UserDefaults.standard.removeObject(forKey: Self.key)
          isOnboardingComplete = false
      }
  }
  ```

- [ ] **Step 2: Update `JobSearchApp/App/JobSearchApp.swift`**

  Replace the entire file:

  ```swift
  import SwiftUI
  import SwiftData

  @main
  struct JobSearchApp: App {
      @StateObject private var container = AppContainer()
      @StateObject private var onboardingCoordinator = OnboardingCoordinator()
      let sharedModelContainer: ModelContainer

      init() {
          let schema = Schema([
              UserProfile.self, WorkExperience.self, Education.self,
              Project.self, ResumeTheme.self, JobPosting.self, GeneratedDocument.self
          ])
          let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
          sharedModelContainer = try! ModelContainer(for: schema, configurations: [config])
      }

      var body: some Scene {
          WindowGroup {
              Group {
                  if onboardingCoordinator.isOnboardingComplete {
                      MainTabView()
                          .environmentObject(container)
                  } else {
                      OnboardingView(llmService: container.llmService)
                          .environmentObject(container)
                          .environmentObject(onboardingCoordinator)
                  }
              }
          }
          .modelContainer(sharedModelContainer)
      }
  }
  ```

  Note: `OnboardingView(llmService:)` is defined in Task 3. The build will fail until then — that's expected.

- [ ] **Step 3: Commit**

  ```bash
  git add JobSearchApp/App/OnboardingCoordinator.swift \
          JobSearchApp/App/JobSearchApp.swift
  git commit -m "feat: OnboardingCoordinator — first-launch routing"
  ```

---

## Task 3: OnboardingViewModel + WelcomeView

**Files:**
- Create: `JobSearchApp/Views/Onboarding/OnboardingView.swift`
- Create: `JobSearchApp/Views/Onboarding/WelcomeView.swift`

`OnboardingViewModel` is the step machine for the entire onboarding flow. It holds accumulated parsed data for all five profile sections and orchestrates calls to `ProfileParseService`. `OnboardingView` routes to the per-step views based on `vm.currentStep`. Both are created here; the step views are stubs until Task 4.

- [ ] **Step 1: Create `JobSearchApp/Views/Onboarding/WelcomeView.swift`**

  ```swift
  import SwiftUI

  struct WelcomeView: View {
      let onStart: () -> Void

      var body: some View {
          VStack(spacing: 32) {
              Spacer()
              Image(systemName: "briefcase.fill")
                  .font(.system(size: 80))
                  .foregroundStyle(.blue)
              VStack(spacing: 12) {
                  Text("Welcome to JobSearch")
                      .font(.largeTitle.bold())
                  Text("Let's build your career profile so we can tailor every resume and cover letter to each job you apply to.")
                      .font(.body)
                      .foregroundStyle(.secondary)
                      .multilineTextAlignment(.center)
                      .padding(.horizontal, 24)
              }
              Spacer()
              Button(action: onStart) {
                  Text("Build My Profile")
                      .font(.headline)
                      .frame(maxWidth: .infinity)
                      .padding()
                      .background(Color.accentColor)
                      .foregroundStyle(.white)
                      .clipShape(RoundedRectangle(cornerRadius: 14))
              }
              .padding(.horizontal, 24)
              .padding(.bottom, 40)
          }
      }
  }
  ```

- [ ] **Step 2: Create `JobSearchApp/Views/Onboarding/OnboardingView.swift`**

  This file contains `OnboardingViewModel` (complete) and `OnboardingView` (with stub step views until Task 4 creates them):

  ```swift
  import SwiftUI
  import SwiftData

  // MARK: - ViewModel

  @MainActor
  final class OnboardingViewModel: ObservableObject {
      enum Step: Int, CaseIterable {
          case welcome, basics, workHistory, education, skills, projects, theme
      }

      @Published var currentStep: Step = .welcome
      @Published var isLoading = false
      @Published var errorMessage: String?

      // Text inputs — one per section
      @Published var basicsInput = ""
      @Published var workInput = ""
      @Published var educationInput = ""
      @Published var skillsInput = ""
      @Published var projectsInput = ""

      // Parsed results
      @Published var parsedBasics: ParsedBasics?
      @Published var parsedWork: [ParsedWorkExperience] = []
      @Published var parsedEducation: [ParsedEducation] = []
      @Published var parsedSkills: [String] = []
      @Published var parsedProjects: [ParsedProject] = []
      @Published var selectedTheme: ThemeName = .modern

      private let parseService: ProfileParseService

      init(parseService: ProfileParseService) {
          self.parseService = parseService
      }

      func advance() {
          guard let next = Step(rawValue: currentStep.rawValue + 1) else { return }
          errorMessage = nil
          currentStep = next
      }

      func parseBasics() async {
          await run { [self] in parsedBasics = try await parseService.parseBasics(from: basicsInput) }
      }

      func parseWork() async {
          await run { [self] in parsedWork = try await parseService.parseWorkExperiences(from: workInput) }
      }

      func parseEducation() async {
          await run { [self] in parsedEducation = try await parseService.parseEducation(from: educationInput) }
      }

      func parseSkills() async {
          await run { [self] in parsedSkills = try await parseService.parseSkills(from: skillsInput) }
      }

      func parseProjects() async {
          await run { [self] in parsedProjects = try await parseService.parseProjects(from: projectsInput) }
      }

      func saveProfile(context: ModelContext, coordinator: OnboardingCoordinator) {
          guard let basics = parsedBasics else { return }

          let theme = ResumeTheme(name: selectedTheme, accentColor: "#1E3A5F", bodyFontSize: 11.0)
          let profile = UserProfile(basics: basics, resumeTheme: theme)
          profile.skills = parsedSkills
          context.insert(profile)

          for p in parsedWork {
              let exp = WorkExperience(
                  company: p.company,
                  title: p.title,
                  startDate: yearMonth(p.startDate) ?? Date(),
                  endDate: p.endDate.flatMap { yearMonth($0) },
                  isCurrent: p.isCurrent,
                  bullets: p.bullets
              )
              exp.profile = profile
              profile.workHistory.append(exp)
              context.insert(exp)
          }

          for p in parsedEducation {
              let edu = Education(
                  institution: p.institution,
                  degree: p.degree,
                  field: p.field,
                  graduationDate: p.graduationDate.flatMap { yearMonth($0) }
              )
              edu.profile = profile
              profile.education.append(edu)
              context.insert(edu)
          }

          for p in parsedProjects {
              let proj = Project(
                  name: p.name,
                  projectDescription: p.description,
                  url: p.url,
                  bullets: p.bullets
              )
              proj.profile = profile
              profile.projects.append(proj)
              context.insert(proj)
          }

          try? context.save()
          coordinator.completeOnboarding()
      }

      // MARK: - Private helpers

      private func run(_ block: @escaping () async throws -> Void) async {
          isLoading = true
          errorMessage = nil
          do { try await block() } catch { errorMessage = error.localizedDescription }
          isLoading = false
      }

      /// Converts "YYYY-MM" to a Date at the first of that month.
      private func yearMonth(_ string: String) -> Date? {
          let f = DateFormatter()
          f.dateFormat = "yyyy-MM"
          f.locale = Locale(identifier: "en_US_POSIX")
          return f.date(from: string)
      }
  }

  // MARK: - View

  struct OnboardingView: View {
      @StateObject private var vm: OnboardingViewModel
      @EnvironmentObject private var coordinator: OnboardingCoordinator
      @Environment(\.modelContext) private var modelContext

      init(llmService: any LLMService) {
          _vm = StateObject(wrappedValue: OnboardingViewModel(
              parseService: ProfileParseService(llm: llmService)
          ))
      }

      var body: some View {
          NavigationStack {
              stepContent
          }
      }

      @ViewBuilder
      private var stepContent: some View {
          switch vm.currentStep {
          case .welcome:
              WelcomeView(onStart: { vm.advance() })
          case .basics:
              Text("Basics — coming in Task 4") // replaced in Task 4
          case .workHistory:
              Text("Work — coming in Task 4")
          case .education:
              Text("Education — coming in Task 4")
          case .skills:
              Text("Skills — coming in Task 4")
          case .projects:
              Text("Projects — coming in Task 4")
          case .theme:
              Text("Theme — coming in Task 5")
          }
      }
  }
  ```

- [ ] **Step 3: Build to verify it compiles**

  ```bash
  xcodebuild build \
    -scheme JobSearchApp \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    > /tmp/build_out.txt 2>&1; tail -5 /tmp/build_out.txt
  ```
  Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

  ```bash
  git add JobSearchApp/Views/Onboarding/WelcomeView.swift \
          JobSearchApp/Views/Onboarding/OnboardingView.swift
  git commit -m "feat: OnboardingViewModel + WelcomeView"
  ```

---

## Task 4: Onboarding Step Views

**Files:**
- Create: `JobSearchApp/Views/Onboarding/OnboardingHelpers.swift`
- Create: `JobSearchApp/Views/Onboarding/BasicsStepView.swift`
- Create: `JobSearchApp/Views/Onboarding/WorkHistoryStepView.swift`
- Create: `JobSearchApp/Views/Onboarding/EducationStepView.swift`
- Create: `JobSearchApp/Views/Onboarding/SkillsStepView.swift`
- Create: `JobSearchApp/Views/Onboarding/ProjectsStepView.swift`
- Modify: `JobSearchApp/Views/Onboarding/OnboardingView.swift` (replace stub cases)

Each step view shows a prompt, a text editor, an "Extract with AI" button, and a confirmation section that appears after parsing. They all receive `vm: OnboardingViewModel` as an `@ObservedObject`.

- [ ] **Step 1: Create `JobSearchApp/Views/Onboarding/OnboardingHelpers.swift`**

  Shared UI components used across all step views:

  ```swift
  import SwiftUI

  struct StepHeader: View {
      let step: String
      let title: String
      let prompt: String

      var body: some View {
          VStack(alignment: .leading, spacing: 8) {
              Text(step).font(.caption).foregroundStyle(.secondary)
              Text(title).font(.title2.bold())
              Text(prompt).font(.body).foregroundStyle(.secondary)
          }
      }
  }

  struct LabeledTextField: View {
      let label: String
      @Binding var text: String

      init(_ label: String, text: Binding<String>) {
          self.label = label
          self._text = text
      }

      var body: some View {
          VStack(alignment: .leading, spacing: 2) {
              Text(label).font(.caption).foregroundStyle(.secondary)
              TextField(label, text: $text).textFieldStyle(.roundedBorder)
          }
      }
  }

  struct LabeledOptionalTextField: View {
      let label: String
      @Binding var text: String?

      init(_ label: String, text: Binding<String?>) {
          self.label = label
          self._text = text
      }

      var body: some View {
          VStack(alignment: .leading, spacing: 2) {
              Text(label).font(.caption).foregroundStyle(.secondary)
              TextField(label, text: Binding(
                  get: { text ?? "" },
                  set: { text = $0.isEmpty ? nil : $0 }
              )).textFieldStyle(.roundedBorder)
          }
      }
  }

  struct SkillsChipsView: View {
      @Binding var skills: [String]

      var body: some View {
          FlowLayout(spacing: 8) {
              ForEach(skills.indices, id: \.self) { i in
                  HStack(spacing: 4) {
                      Text(skills[i]).font(.caption)
                      Button { skills.remove(at: i) } label: {
                          Image(systemName: "xmark").font(.caption2)
                      }
                  }
                  .padding(.horizontal, 10)
                  .padding(.vertical, 5)
                  .background(Color.accentColor.opacity(0.15))
                  .clipShape(Capsule())
              }
          }
      }
  }

  struct FlowLayout: Layout {
      var spacing: CGFloat = 8

      func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
          let width = proposal.width ?? 0
          var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0
          for sub in subviews {
              let size = sub.sizeThatFits(.unspecified)
              if x + size.width > width, x > 0 { y += lineH + spacing; x = 0; lineH = 0 }
              x += size.width + spacing
              lineH = max(lineH, size.height)
          }
          return CGSize(width: width, height: y + lineH)
      }

      func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
          var x = bounds.minX, y = bounds.minY, lineH: CGFloat = 0
          for sub in subviews {
              let size = sub.sizeThatFits(.unspecified)
              if x + size.width > bounds.maxX, x > bounds.minX { y += lineH + spacing; x = bounds.minX; lineH = 0 }
              sub.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
              x += size.width + spacing
              lineH = max(lineH, size.height)
          }
      }
  }
  ```

- [ ] **Step 2: Create `JobSearchApp/Views/Onboarding/BasicsStepView.swift`**

  ```swift
  import SwiftUI

  struct BasicsStepView: View {
      @ObservedObject var vm: OnboardingViewModel

      var body: some View {
          ScrollView {
              VStack(alignment: .leading, spacing: 24) {
                  StepHeader(
                      step: "1 of 5",
                      title: "Contact Info",
                      prompt: "Tell me your name, email, phone number, location, and any relevant links (LinkedIn, GitHub, portfolio)."
                  )

                  TextEditor(text: $vm.basicsInput)
                      .frame(minHeight: 120)
                      .padding(8)
                      .background(Color(.secondarySystemBackground))
                      .clipShape(RoundedRectangle(cornerRadius: 10))

                  if vm.isLoading {
                      ProgressView("Extracting info…").frame(maxWidth: .infinity)
                  } else if let error = vm.errorMessage {
                      Text(error).foregroundStyle(.red).font(.caption)
                  }

                  Button("Extract with AI") { Task { await vm.parseBasics() } }
                      .buttonStyle(.borderedProminent)
                      .disabled(vm.basicsInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isLoading)

                  if var basics = vm.parsedBasics {
                      VStack(alignment: .leading, spacing: 12) {
                          Text("Confirm your info").font(.headline)
                          LabeledTextField("Name", text: Binding(
                              get: { vm.parsedBasics?.name ?? "" },
                              set: { vm.parsedBasics?.name = $0 }
                          ))
                          LabeledTextField("Email", text: Binding(
                              get: { vm.parsedBasics?.email ?? "" },
                              set: { vm.parsedBasics?.email = $0 }
                          ))
                          LabeledOptionalTextField("Phone", text: Binding(
                              get: { vm.parsedBasics?.phone },
                              set: { vm.parsedBasics?.phone = $0 }
                          ))
                          LabeledTextField("Location", text: Binding(
                              get: { vm.parsedBasics?.location ?? "" },
                              set: { vm.parsedBasics?.location = $0 }
                          ))
                          LabeledOptionalTextField("LinkedIn", text: Binding(
                              get: { vm.parsedBasics?.linkedIn },
                              set: { vm.parsedBasics?.linkedIn = $0 }
                          ))
                          LabeledOptionalTextField("GitHub", text: Binding(
                              get: { vm.parsedBasics?.github },
                              set: { vm.parsedBasics?.github = $0 }
                          ))
                          LabeledOptionalTextField("Website", text: Binding(
                              get: { vm.parsedBasics?.website },
                              set: { vm.parsedBasics?.website = $0 }
                          ))
                      }
                      .padding()
                      .background(Color(.secondarySystemBackground))
                      .clipShape(RoundedRectangle(cornerRadius: 10))

                      Button("Next →") { vm.advance() }
                          .buttonStyle(.borderedProminent)
                          .frame(maxWidth: .infinity)
                  }
              }
              .padding()
          }
          .navigationTitle("About You")
      }
  }
  ```

- [ ] **Step 3: Create `JobSearchApp/Views/Onboarding/WorkHistoryStepView.swift`**

  ```swift
  import SwiftUI

  struct WorkHistoryStepView: View {
      @ObservedObject var vm: OnboardingViewModel

      var body: some View {
          ScrollView {
              VStack(alignment: .leading, spacing: 24) {
                  StepHeader(
                      step: "2 of 5",
                      title: "Work History",
                      prompt: "Describe your work experience. Include company names, titles, dates, and what you accomplished in each role."
                  )

                  TextEditor(text: $vm.workInput)
                      .frame(minHeight: 120)
                      .padding(8)
                      .background(Color(.secondarySystemBackground))
                      .clipShape(RoundedRectangle(cornerRadius: 10))

                  if vm.isLoading {
                      ProgressView("Extracting work history…").frame(maxWidth: .infinity)
                  } else if let error = vm.errorMessage {
                      Text(error).foregroundStyle(.red).font(.caption)
                  }

                  Button("Extract with AI") { Task { await vm.parseWork() } }
                      .buttonStyle(.borderedProminent)
                      .disabled(vm.workInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isLoading)

                  if !vm.parsedWork.isEmpty {
                      VStack(alignment: .leading, spacing: 8) {
                          Text("Extracted \(vm.parsedWork.count) role(s)").font(.headline)
                          ForEach(vm.parsedWork.indices, id: \.self) { i in
                              VStack(alignment: .leading, spacing: 2) {
                                  Text("\(vm.parsedWork[i].title) at \(vm.parsedWork[i].company)")
                                      .font(.subheadline.bold())
                                  Text(vm.parsedWork[i].startDate + " – " + (vm.parsedWork[i].endDate ?? "Present"))
                                      .font(.caption).foregroundStyle(.secondary)
                              }
                              .padding(8)
                              .frame(maxWidth: .infinity, alignment: .leading)
                              .background(Color(.secondarySystemBackground))
                              .clipShape(RoundedRectangle(cornerRadius: 8))
                          }
                      }
                      Button("Next →") { vm.advance() }
                          .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                  }

                  Button("Skip") { vm.advance() }
                      .foregroundStyle(.secondary).frame(maxWidth: .infinity)
              }
              .padding()
          }
          .navigationTitle("Work History")
      }
  }
  ```

- [ ] **Step 4: Create `JobSearchApp/Views/Onboarding/EducationStepView.swift`**

  ```swift
  import SwiftUI

  struct EducationStepView: View {
      @ObservedObject var vm: OnboardingViewModel

      var body: some View {
          ScrollView {
              VStack(alignment: .leading, spacing: 24) {
                  StepHeader(
                      step: "3 of 5",
                      title: "Education",
                      prompt: "Tell me about your education — institutions, degrees, fields of study, and graduation dates."
                  )

                  TextEditor(text: $vm.educationInput)
                      .frame(minHeight: 100)
                      .padding(8)
                      .background(Color(.secondarySystemBackground))
                      .clipShape(RoundedRectangle(cornerRadius: 10))

                  if vm.isLoading {
                      ProgressView("Extracting education…").frame(maxWidth: .infinity)
                  } else if let error = vm.errorMessage {
                      Text(error).foregroundStyle(.red).font(.caption)
                  }

                  Button("Extract with AI") { Task { await vm.parseEducation() } }
                      .buttonStyle(.borderedProminent)
                      .disabled(vm.educationInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isLoading)

                  if !vm.parsedEducation.isEmpty {
                      VStack(alignment: .leading, spacing: 8) {
                          Text("Extracted \(vm.parsedEducation.count) entry(s)").font(.headline)
                          ForEach(vm.parsedEducation.indices, id: \.self) { i in
                              VStack(alignment: .leading, spacing: 2) {
                                  Text(vm.parsedEducation[i].institution).font(.subheadline.bold())
                                  Text("\(vm.parsedEducation[i].degree) in \(vm.parsedEducation[i].field)")
                                      .font(.caption).foregroundStyle(.secondary)
                              }
                              .padding(8)
                              .frame(maxWidth: .infinity, alignment: .leading)
                              .background(Color(.secondarySystemBackground))
                              .clipShape(RoundedRectangle(cornerRadius: 8))
                          }
                      }
                      Button("Next →") { vm.advance() }
                          .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                  }

                  Button("Skip") { vm.advance() }
                      .foregroundStyle(.secondary).frame(maxWidth: .infinity)
              }
              .padding()
          }
          .navigationTitle("Education")
      }
  }
  ```

- [ ] **Step 5: Create `JobSearchApp/Views/Onboarding/SkillsStepView.swift`**

  ```swift
  import SwiftUI

  struct SkillsStepView: View {
      @ObservedObject var vm: OnboardingViewModel

      var body: some View {
          ScrollView {
              VStack(alignment: .leading, spacing: 24) {
                  StepHeader(
                      step: "4 of 5",
                      title: "Skills",
                      prompt: "List your technical skills, tools, languages, and frameworks."
                  )

                  TextEditor(text: $vm.skillsInput)
                      .frame(minHeight: 100)
                      .padding(8)
                      .background(Color(.secondarySystemBackground))
                      .clipShape(RoundedRectangle(cornerRadius: 10))

                  if vm.isLoading {
                      ProgressView("Extracting skills…").frame(maxWidth: .infinity)
                  } else if let error = vm.errorMessage {
                      Text(error).foregroundStyle(.red).font(.caption)
                  }

                  Button("Extract with AI") { Task { await vm.parseSkills() } }
                      .buttonStyle(.borderedProminent)
                      .disabled(vm.skillsInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isLoading)

                  if !vm.parsedSkills.isEmpty {
                      VStack(alignment: .leading, spacing: 8) {
                          Text("Extracted \(vm.parsedSkills.count) skill(s)").font(.headline)
                          SkillsChipsView(skills: $vm.parsedSkills)
                      }
                      Button("Next →") { vm.advance() }
                          .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                  }

                  Button("Skip") { vm.advance() }
                      .foregroundStyle(.secondary).frame(maxWidth: .infinity)
              }
              .padding()
          }
          .navigationTitle("Skills")
      }
  }
  ```

- [ ] **Step 6: Create `JobSearchApp/Views/Onboarding/ProjectsStepView.swift`**

  ```swift
  import SwiftUI

  struct ProjectsStepView: View {
      @ObservedObject var vm: OnboardingViewModel

      var body: some View {
          ScrollView {
              VStack(alignment: .leading, spacing: 24) {
                  StepHeader(
                      step: "5 of 5",
                      title: "Projects",
                      prompt: "Tell me about any personal or professional projects. Include the name, what it does, and technologies used."
                  )

                  TextEditor(text: $vm.projectsInput)
                      .frame(minHeight: 100)
                      .padding(8)
                      .background(Color(.secondarySystemBackground))
                      .clipShape(RoundedRectangle(cornerRadius: 10))

                  if vm.isLoading {
                      ProgressView("Extracting projects…").frame(maxWidth: .infinity)
                  } else if let error = vm.errorMessage {
                      Text(error).foregroundStyle(.red).font(.caption)
                  }

                  Button("Extract with AI") { Task { await vm.parseProjects() } }
                      .buttonStyle(.borderedProminent)
                      .disabled(vm.projectsInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isLoading)

                  if !vm.parsedProjects.isEmpty {
                      VStack(alignment: .leading, spacing: 8) {
                          Text("Extracted \(vm.parsedProjects.count) project(s)").font(.headline)
                          ForEach(vm.parsedProjects.indices, id: \.self) { i in
                              VStack(alignment: .leading, spacing: 2) {
                                  Text(vm.parsedProjects[i].name).font(.subheadline.bold())
                                  Text(vm.parsedProjects[i].description)
                                      .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                              }
                              .padding(8)
                              .frame(maxWidth: .infinity, alignment: .leading)
                              .background(Color(.secondarySystemBackground))
                              .clipShape(RoundedRectangle(cornerRadius: 8))
                          }
                      }
                      Button("Next →") { vm.advance() }
                          .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
                  }

                  Button("Skip") { vm.advance() }
                      .foregroundStyle(.secondary).frame(maxWidth: .infinity)
              }
              .padding()
          }
          .navigationTitle("Projects")
      }
  }
  ```

- [ ] **Step 7: Update `OnboardingView.swift` — replace stub step cases with real views**

  In `OnboardingView.swift`, replace the `stepContent` computed property body (the switch statement with `Text("... coming in Task 4")` placeholders) with:

  ```swift
      @ViewBuilder
      private var stepContent: some View {
          switch vm.currentStep {
          case .welcome:
              WelcomeView(onStart: { vm.advance() })
          case .basics:
              BasicsStepView(vm: vm)
          case .workHistory:
              WorkHistoryStepView(vm: vm)
          case .education:
              EducationStepView(vm: vm)
          case .skills:
              SkillsStepView(vm: vm)
          case .projects:
              ProjectsStepView(vm: vm)
          case .theme:
              Text("Theme — coming in Task 5")   // replaced in Task 5
          }
      }
  ```

- [ ] **Step 8: Build to verify it compiles**

  ```bash
  xcodebuild build \
    -scheme JobSearchApp \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    > /tmp/build_out.txt 2>&1; tail -5 /tmp/build_out.txt
  ```
  Expected: `BUILD SUCCEEDED`

- [ ] **Step 9: Commit**

  ```bash
  git add JobSearchApp/Views/Onboarding/
  git commit -m "feat: onboarding conversational steps — basics, work, education, skills, projects"
  ```

---

## Task 5: ThemePickerView + Full Onboarding Wiring

**Files:**
- Create: `JobSearchApp/Views/Onboarding/ThemePickerView.swift`
- Modify: `JobSearchApp/Views/Onboarding/OnboardingView.swift` (replace final stub case)

- [ ] **Step 1: Create `JobSearchApp/Views/Onboarding/ThemePickerView.swift`**

  ```swift
  import SwiftUI

  struct ThemePickerView: View {
      @ObservedObject var vm: OnboardingViewModel
      @EnvironmentObject private var coordinator: OnboardingCoordinator
      @Environment(\.modelContext) private var modelContext

      private let themes: [(ThemeName, String, Color)] = [
          (.classic,  "Classic",  .gray),
          (.modern,   "Modern",   .blue),
          (.creative, "Creative", .purple),
          (.minimal,  "Minimal",  .black)
      ]

      var body: some View {
          ScrollView {
              VStack(spacing: 32) {
                  VStack(spacing: 8) {
                      Text("Choose a Theme")
                          .font(.title2.bold())
                      Text("You can change this anytime in Settings.")
                          .font(.subheadline).foregroundStyle(.secondary)
                  }
                  .padding(.top)

                  LazyVGrid(columns: [.init(), .init()], spacing: 16) {
                      ForEach(themes, id: \.0) { name, label, color in
                          ThemeCard(label: label, color: color, isSelected: vm.selectedTheme == name) {
                              vm.selectedTheme = name
                          }
                      }
                  }
                  .padding(.horizontal)

                  Button("Finish & Start Job Searching") {
                      vm.saveProfile(context: modelContext, coordinator: coordinator)
                  }
                  .buttonStyle(.borderedProminent)
                  .controlSize(.large)
                  .frame(maxWidth: .infinity)
                  .padding(.horizontal)
              }
          }
          .navigationTitle("Pick a Theme")
      }
  }

  private struct ThemeCard: View {
      let label: String
      let color: Color
      let isSelected: Bool
      let onTap: () -> Void

      var body: some View {
          Button(action: onTap) {
              VStack(spacing: 8) {
                  RoundedRectangle(cornerRadius: 8)
                      .fill(color.opacity(0.15))
                      .frame(height: 80)
                      .overlay(
                          RoundedRectangle(cornerRadius: 8)
                              .strokeBorder(isSelected ? color : .clear, lineWidth: 2)
                      )
                  Text(label)
                      .font(.caption.bold())
                      .foregroundStyle(isSelected ? color : .primary)
              }
          }
          .buttonStyle(.plain)
      }
  }
  ```

- [ ] **Step 2: Update `OnboardingView.swift` — replace the final stub case**

  In `stepContent`, replace:
  ```swift
          case .theme:
              Text("Theme — coming in Task 5")
  ```
  with:
  ```swift
          case .theme:
              ThemePickerView(vm: vm)
  ```

- [ ] **Step 3: Build and run in simulator**

  ```bash
  xcodebuild build \
    -scheme JobSearchApp \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    > /tmp/build_out.txt 2>&1; tail -5 /tmp/build_out.txt
  ```
  Expected: `BUILD SUCCEEDED`

  Then run in simulator (⌘R in Xcode). Walk through all steps. Tap "Finish & Start Job Searching". Expected: app transitions to the 4-tab `MainTabView` on the Discover tab.

- [ ] **Step 4: Commit**

  ```bash
  git add JobSearchApp/Views/Onboarding/ThemePickerView.swift \
          JobSearchApp/Views/Onboarding/OnboardingView.swift
  git commit -m "feat: ThemePickerView + complete onboarding flow wired end-to-end"
  ```

---

## Task 6: ProfileViewModel

**Files:**
- Create: `JobSearchApp/Views/Profile/ProfileViewModel.swift`

`ProfileViewModel` fetches the single `UserProfile` from SwiftData and exposes helpers for mutations. Views call `load(context:)` in `.onAppear` and after any sheet dismissal.

- [ ] **Step 1: Create `JobSearchApp/Views/Profile/ProfileViewModel.swift`**

  ```swift
  import Foundation
  import SwiftData

  @MainActor
  final class ProfileViewModel: ObservableObject {
      @Published var profile: UserProfile?

      func load(context: ModelContext) {
          profile = try? context.fetch(FetchDescriptor<UserProfile>()).first
      }

      func deleteWorkExperience(_ exp: WorkExperience, context: ModelContext) {
          context.delete(exp)
          try? context.save()
          load(context: context)
      }

      func deleteEducation(_ edu: Education, context: ModelContext) {
          context.delete(edu)
          try? context.save()
          load(context: context)
      }

      func deleteProject(_ proj: Project, context: ModelContext) {
          context.delete(proj)
          try? context.save()
          load(context: context)
      }
  }
  ```

- [ ] **Step 2: Commit**

  ```bash
  git add JobSearchApp/Views/Profile/ProfileViewModel.swift
  git commit -m "feat: ProfileViewModel — SwiftData fetch + CRUD helpers"
  ```

---

## Task 7: Full ProfileView

**Files:**
- Modify: `JobSearchApp/Views/Profile/ProfileView.swift`

Replaces the placeholder. Shows all profile sections in a `List`. Edit/Add buttons open sheets for each section (forms created in Task 8).

- [ ] **Step 1: Replace `JobSearchApp/Views/Profile/ProfileView.swift`**

  ```swift
  import SwiftUI
  import SwiftData

  struct ProfileView: View {
      @StateObject private var vm = ProfileViewModel()
      @Environment(\.modelContext) private var modelContext

      @State private var showEditBasics = false
      @State private var showAddWork = false
      @State private var showAddEducation = false
      @State private var showAddProject = false
      @State private var showSkillsEditor = false
      @State private var selectedWork: WorkExperience?
      @State private var selectedEducation: Education?
      @State private var selectedProject: Project?

      var body: some View {
          NavigationStack {
              Group {
                  if let profile = vm.profile {
                      profileList(profile)
                  } else {
                      ContentUnavailableView(
                          "No Profile",
                          systemImage: "person.crop.circle.badge.exclamationmark",
                          description: Text("Complete onboarding to build your profile.")
                      )
                  }
              }
              .navigationTitle("Profile")
              .toolbar {
                  ToolbarItem(placement: .topBarTrailing) {
                      NavigationLink(destination: SettingsView()) {
                          Image(systemName: "gear")
                      }
                  }
              }
          }
          .onAppear { vm.load(context: modelContext) }
          .sheet(isPresented: $showEditBasics, onDismiss: reload) {
              if let p = vm.profile { EditBasicsView(profile: p) }
          }
          .sheet(isPresented: $showAddWork, onDismiss: reload) {
              if let p = vm.profile { WorkExperienceFormView(profile: p, existing: nil) }
          }
          .sheet(item: $selectedWork, onDismiss: reload) { exp in
              WorkExperienceFormView(profile: vm.profile!, existing: exp)
          }
          .sheet(isPresented: $showAddEducation, onDismiss: reload) {
              if let p = vm.profile { EducationFormView(profile: p, existing: nil) }
          }
          .sheet(item: $selectedEducation, onDismiss: reload) { edu in
              EducationFormView(profile: vm.profile!, existing: edu)
          }
          .sheet(isPresented: $showAddProject, onDismiss: reload) {
              if let p = vm.profile { ProjectFormView(profile: p, existing: nil) }
          }
          .sheet(item: $selectedProject, onDismiss: reload) { proj in
              ProjectFormView(profile: vm.profile!, existing: proj)
          }
          .sheet(isPresented: $showSkillsEditor, onDismiss: reload) {
              if let p = vm.profile { SkillsEditorView(profile: p) }
          }
      }

      private func reload() { vm.load(context: modelContext) }

      @ViewBuilder
      private func profileList(_ profile: UserProfile) -> some View {
          List {
              Section {
                  VStack(alignment: .leading, spacing: 4) {
                      Text(profile.basics.name).font(.title2.bold())
                      Text(profile.basics.email).foregroundStyle(.secondary)
                      if let phone = profile.basics.phone {
                          Text(phone).foregroundStyle(.secondary)
                      }
                      Text(profile.basics.location).foregroundStyle(.secondary)
                      if let li = profile.basics.linkedIn { Text(li).foregroundStyle(.blue) }
                      if let gh = profile.basics.github  { Text(gh).foregroundStyle(.blue) }
                  }
              } header: { sectionHeader("Contact", action: { showEditBasics = true }, label: "Edit") }

              Section {
                  ForEach(profile.workHistory.sorted(by: { $0.startDate > $1.startDate })) { exp in
                      WorkRow(exp: exp).contentShape(Rectangle())
                          .onTapGesture { selectedWork = exp }
                  }
                  .onDelete { offsets in
                      let sorted = profile.workHistory.sorted(by: { $0.startDate > $1.startDate })
                      offsets.forEach { vm.deleteWorkExperience(sorted[$0], context: modelContext) }
                  }
              } header: { sectionHeader("Work History", action: { showAddWork = true }, label: "Add") }

              Section {
                  ForEach(profile.education) { edu in
                      EduRow(edu: edu).contentShape(Rectangle())
                          .onTapGesture { selectedEducation = edu }
                  }
                  .onDelete { offsets in
                      offsets.forEach { vm.deleteEducation(profile.education[$0], context: modelContext) }
                  }
              } header: { sectionHeader("Education", action: { showAddEducation = true }, label: "Add") }

              Section {
                  if profile.skills.isEmpty {
                      Text("No skills added").foregroundStyle(.secondary)
                  } else {
                      Text(profile.skills.joined(separator: " · ")).font(.subheadline)
                  }
              } header: { sectionHeader("Skills", action: { showSkillsEditor = true }, label: "Edit") }

              Section {
                  ForEach(profile.projects) { proj in
                      ProjRow(proj: proj).contentShape(Rectangle())
                          .onTapGesture { selectedProject = proj }
                  }
                  .onDelete { offsets in
                      offsets.forEach { vm.deleteProject(profile.projects[$0], context: modelContext) }
                  }
              } header: { sectionHeader("Projects", action: { showAddProject = true }, label: "Add") }
          }
      }

      private func sectionHeader(_ title: String, action: @escaping () -> Void, label: String) -> some View {
          HStack {
              Text(title)
              Spacer()
              Button(label, action: action).font(.caption)
          }
      }
  }

  // MARK: - Row views

  private struct WorkRow: View {
      let exp: WorkExperience
      var body: some View {
          VStack(alignment: .leading, spacing: 2) {
              Text("\(exp.title) at \(exp.company)").font(.subheadline.bold())
              Text(exp.isCurrent ? "Current" : dateLabel(exp.endDate))
                  .font(.caption).foregroundStyle(.secondary)
              if !exp.bullets.isEmpty {
                  Text(exp.bullets.prefix(2).map { "• \($0)" }.joined(separator: "\n"))
                      .font(.caption).foregroundStyle(.secondary).lineLimit(3)
              }
          }
          .padding(.vertical, 2)
      }

      private func dateLabel(_ date: Date?) -> String {
          guard let date else { return "" }
          let f = DateFormatter(); f.dateFormat = "MMM yyyy"
          return f.string(from: date)
      }
  }

  private struct EduRow: View {
      let edu: Education
      var body: some View {
          VStack(alignment: .leading, spacing: 2) {
              Text(edu.institution).font(.subheadline.bold())
              Text("\(edu.degree) in \(edu.field)").font(.caption).foregroundStyle(.secondary)
          }
          .padding(.vertical, 2)
      }
  }

  private struct ProjRow: View {
      let proj: Project
      var body: some View {
          VStack(alignment: .leading, spacing: 2) {
              Text(proj.name).font(.subheadline.bold())
              Text(proj.projectDescription).font(.caption).foregroundStyle(.secondary).lineLimit(2)
          }
          .padding(.vertical, 2)
      }
  }
  ```

  Note: SwiftData `@Model` classes conform to `Identifiable` via `persistentModelID`, so `sheet(item: $selectedWork)` works without any additional conformance.

- [ ] **Step 2: Build to verify (will fail until Task 8 forms exist)**

  Expected: Build error on `EditBasicsView`, `WorkExperienceFormView` etc. not found. Proceed to Task 8.

---

## Task 8: Profile Editing Forms

**Files:**
- Create: `JobSearchApp/Views/Profile/EditBasicsView.swift`
- Create: `JobSearchApp/Views/Profile/WorkExperienceFormView.swift`
- Create: `JobSearchApp/Views/Profile/EducationFormView.swift`
- Create: `JobSearchApp/Views/Profile/ProjectFormView.swift`
- Create: `JobSearchApp/Views/Profile/SkillsEditorView.swift`

All form views use `@Environment(\.dismiss)` to close the sheet and accept a `UserProfile` + optional existing model for add vs. edit mode.

- [ ] **Step 1: Create `JobSearchApp/Views/Profile/EditBasicsView.swift`**

  ```swift
  import SwiftUI

  struct EditBasicsView: View {
      let profile: UserProfile
      @Environment(\.modelContext) private var modelContext
      @Environment(\.dismiss) private var dismiss

      @State private var name: String
      @State private var email: String
      @State private var phone: String
      @State private var location: String
      @State private var linkedIn: String
      @State private var github: String
      @State private var website: String

      init(profile: UserProfile) {
          self.profile = profile
          _name     = State(initialValue: profile.basics.name)
          _email    = State(initialValue: profile.basics.email)
          _phone    = State(initialValue: profile.basics.phone ?? "")
          _location = State(initialValue: profile.basics.location)
          _linkedIn = State(initialValue: profile.basics.linkedIn ?? "")
          _github   = State(initialValue: profile.basics.github ?? "")
          _website  = State(initialValue: profile.basics.website ?? "")
      }

      var body: some View {
          NavigationStack {
              Form {
                  Section("Contact") {
                      TextField("Name", text: $name)
                      TextField("Email", text: $email).keyboardType(.emailAddress)
                      TextField("Phone", text: $phone).keyboardType(.phonePad)
                      TextField("Location", text: $location)
                  }
                  Section("Links") {
                      TextField("LinkedIn URL", text: $linkedIn)
                      TextField("GitHub URL", text: $github)
                      TextField("Website URL", text: $website)
                  }
              }
              .navigationTitle("Edit Contact Info")
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
                  ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                  ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
              }
          }
      }

      private func save() {
          profile.basics = ProfileBasics(
              name: name,
              email: email,
              phone: phone.isEmpty ? nil : phone,
              location: location,
              linkedIn: linkedIn.isEmpty ? nil : linkedIn,
              github: github.isEmpty ? nil : github,
              website: website.isEmpty ? nil : website
          )
          try? modelContext.save()
          dismiss()
      }
  }
  ```

- [ ] **Step 2: Create `JobSearchApp/Views/Profile/WorkExperienceFormView.swift`**

  ```swift
  import SwiftUI

  struct WorkExperienceFormView: View {
      let profile: UserProfile
      let existing: WorkExperience?
      @Environment(\.modelContext) private var modelContext
      @Environment(\.dismiss) private var dismiss

      @State private var company: String
      @State private var title: String
      @State private var startDate: Date
      @State private var endDate: Date
      @State private var isCurrent: Bool
      @State private var bulletsText: String  // one bullet per line

      init(profile: UserProfile, existing: WorkExperience?) {
          self.profile = profile
          self.existing = existing
          _company     = State(initialValue: existing?.company ?? "")
          _title       = State(initialValue: existing?.title ?? "")
          _startDate   = State(initialValue: existing?.startDate ?? Date())
          _endDate     = State(initialValue: existing?.endDate ?? Date())
          _isCurrent   = State(initialValue: existing?.isCurrent ?? false)
          _bulletsText = State(initialValue: existing?.bullets.joined(separator: "\n") ?? "")
      }

      var body: some View {
          NavigationStack {
              Form {
                  Section("Role") {
                      TextField("Company", text: $company)
                      TextField("Job Title", text: $title)
                  }
                  Section("Dates") {
                      DatePicker("Start", selection: $startDate, displayedComponents: .date)
                      Toggle("Current Role", isOn: $isCurrent)
                      if !isCurrent {
                          DatePicker("End", selection: $endDate, displayedComponents: .date)
                      }
                  }
                  Section {
                      TextEditor(text: $bulletsText).frame(minHeight: 100)
                  } header: { Text("Bullet Points") } footer: { Text("One bullet per line.") }
              }
              .navigationTitle(existing == nil ? "Add Experience" : "Edit Experience")
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
                  ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                  ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
              }
          }
      }

      private func save() {
          let bullets = bulletsText
              .components(separatedBy: "\n")
              .map { $0.trimmingCharacters(in: .whitespaces) }
              .filter { !$0.isEmpty }

          if let exp = existing {
              exp.company   = company
              exp.title     = title
              exp.startDate = startDate
              exp.endDate   = isCurrent ? nil : endDate
              exp.isCurrent = isCurrent
              exp.bullets   = bullets
          } else {
              let exp = WorkExperience(
                  company: company, title: title, startDate: startDate,
                  endDate: isCurrent ? nil : endDate, isCurrent: isCurrent, bullets: bullets
              )
              exp.profile = profile
              profile.workHistory.append(exp)
              modelContext.insert(exp)
          }
          try? modelContext.save()
          dismiss()
      }
  }
  ```

- [ ] **Step 3: Create `JobSearchApp/Views/Profile/EducationFormView.swift`**

  ```swift
  import SwiftUI

  struct EducationFormView: View {
      let profile: UserProfile
      let existing: Education?
      @Environment(\.modelContext) private var modelContext
      @Environment(\.dismiss) private var dismiss

      @State private var institution: String
      @State private var degree: String
      @State private var field: String
      @State private var graduationDate: Date
      @State private var hasGradDate: Bool

      init(profile: UserProfile, existing: Education?) {
          self.profile = profile
          self.existing = existing
          _institution    = State(initialValue: existing?.institution ?? "")
          _degree         = State(initialValue: existing?.degree ?? "")
          _field          = State(initialValue: existing?.field ?? "")
          _graduationDate = State(initialValue: existing?.graduationDate ?? Date())
          _hasGradDate    = State(initialValue: existing?.graduationDate != nil)
      }

      var body: some View {
          NavigationStack {
              Form {
                  Section("School") {
                      TextField("Institution", text: $institution)
                      TextField("Degree (e.g. Bachelor of Science)", text: $degree)
                      TextField("Field of Study", text: $field)
                  }
                  Section("Graduation") {
                      Toggle("Has graduation date", isOn: $hasGradDate)
                      if hasGradDate {
                          DatePicker("Date", selection: $graduationDate, displayedComponents: .date)
                      }
                  }
              }
              .navigationTitle(existing == nil ? "Add Education" : "Edit Education")
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
                  ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                  ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
              }
          }
      }

      private func save() {
          if let edu = existing {
              edu.institution    = institution
              edu.degree         = degree
              edu.field          = field
              edu.graduationDate = hasGradDate ? graduationDate : nil
          } else {
              let edu = Education(
                  institution: institution, degree: degree, field: field,
                  graduationDate: hasGradDate ? graduationDate : nil
              )
              edu.profile = profile
              profile.education.append(edu)
              modelContext.insert(edu)
          }
          try? modelContext.save()
          dismiss()
      }
  }
  ```

- [ ] **Step 4: Create `JobSearchApp/Views/Profile/ProjectFormView.swift`**

  ```swift
  import SwiftUI

  struct ProjectFormView: View {
      let profile: UserProfile
      let existing: Project?
      @Environment(\.modelContext) private var modelContext
      @Environment(\.dismiss) private var dismiss

      @State private var name: String
      @State private var projectDescription: String
      @State private var url: String
      @State private var bulletsText: String

      init(profile: UserProfile, existing: Project?) {
          self.profile = profile
          self.existing = existing
          _name               = State(initialValue: existing?.name ?? "")
          _projectDescription = State(initialValue: existing?.projectDescription ?? "")
          _url                = State(initialValue: existing?.url ?? "")
          _bulletsText        = State(initialValue: existing?.bullets.joined(separator: "\n") ?? "")
      }

      var body: some View {
          NavigationStack {
              Form {
                  Section("Project") {
                      TextField("Name", text: $name)
                      TextField("URL (optional)", text: $url)
                  }
                  Section("Description") {
                      TextEditor(text: $projectDescription).frame(minHeight: 80)
                  }
                  Section {
                      TextEditor(text: $bulletsText).frame(minHeight: 80)
                  } header: { Text("Highlights") } footer: { Text("One bullet per line.") }
              }
              .navigationTitle(existing == nil ? "Add Project" : "Edit Project")
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
                  ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                  ToolbarItem(placement: .confirmationAction) { Button("Save") { save() } }
              }
          }
      }

      private func save() {
          let bullets = bulletsText
              .components(separatedBy: "\n")
              .map { $0.trimmingCharacters(in: .whitespaces) }
              .filter { !$0.isEmpty }

          if let proj = existing {
              proj.name               = name
              proj.projectDescription = projectDescription
              proj.url                = url.isEmpty ? nil : url
              proj.bullets            = bullets
          } else {
              let proj = Project(
                  name: name, projectDescription: projectDescription,
                  url: url.isEmpty ? nil : url, bullets: bullets
              )
              proj.profile = profile
              profile.projects.append(proj)
              modelContext.insert(proj)
          }
          try? modelContext.save()
          dismiss()
      }
  }
  ```

- [ ] **Step 5: Create `JobSearchApp/Views/Profile/SkillsEditorView.swift`**

  ```swift
  import SwiftUI

  struct SkillsEditorView: View {
      let profile: UserProfile
      @Environment(\.modelContext) private var modelContext
      @Environment(\.dismiss) private var dismiss
      @State private var newSkill = ""

      var body: some View {
          NavigationStack {
              List {
                  Section {
                      HStack {
                          TextField("Add skill…", text: $newSkill).onSubmit { addSkill() }
                          Button(action: addSkill) {
                              Image(systemName: "plus.circle.fill")
                          }
                          .disabled(newSkill.trimmingCharacters(in: .whitespaces).isEmpty)
                      }
                  }
                  Section("Skills") {
                      ForEach(profile.skills.indices, id: \.self) { i in
                          Text(profile.skills[i])
                      }
                      .onDelete { offsets in
                          profile.skills.remove(atOffsets: offsets)
                          try? modelContext.save()
                      }
                      .onMove { from, to in
                          profile.skills.move(fromOffsets: from, toOffset: to)
                          try? modelContext.save()
                      }
                  }
              }
              .navigationTitle("Edit Skills")
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
                  ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                  ToolbarItem(placement: .navigationBarLeading) { EditButton() }
              }
          }
      }

      private func addSkill() {
          let trimmed = newSkill.trimmingCharacters(in: .whitespaces)
          guard !trimmed.isEmpty else { return }
          profile.skills.append(trimmed)
          try? modelContext.save()
          newSkill = ""
      }
  }
  ```

- [ ] **Step 6: Build to verify no errors**

  ```bash
  xcodebuild build \
    -scheme JobSearchApp \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    > /tmp/build_out.txt 2>&1; tail -5 /tmp/build_out.txt
  ```
  Expected: `BUILD SUCCEEDED`

- [ ] **Step 7: Run all tests**

  ```bash
  xcodebuild test \
    -scheme JobSearchApp \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    > /tmp/test_out.txt 2>&1; tail -20 /tmp/test_out.txt
  ```
  Expected: `Test Suite 'All tests' passed` (19 tests: 12 from Foundation + 7 from ProfileParseService)

- [ ] **Step 8: Commit**

  ```bash
  git add JobSearchApp/Views/Profile/ JobSearchApp/Views/Onboarding/
  git commit -m "feat: full Profile tab — display + editing forms for all sections"
  ```

---

## What's Next

With Profile & Onboarding complete:

- **Plan 3 — Job Discovery:** `docs/superpowers/plans/2026-04-07-job-discovery.md`
- **Plan 4 — Documents:** `docs/superpowers/plans/2026-04-07-documents.md`
