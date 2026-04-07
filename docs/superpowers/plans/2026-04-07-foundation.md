# Job Search iOS App — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the Xcode project with SwiftData models, Keychain manager, LLMService protocol, tab navigation shell, and Settings screen — the complete foundation all other plans build on.

**Architecture:** SwiftUI iOS 17+ app using SwiftData for local persistence with CloudKit sync. All Claude API calls route through a `LLMService` protocol backed by `AnthropicLLMService`. API keys are stored in Keychain. Navigation is a 4-tab `TabView` with placeholder screens for tabs implemented in later plans.

**Tech Stack:** Swift 5.10, SwiftUI, SwiftData, CloudKit, XCTest, URLSession

---

## File Structure

```
JobSearchApp/
├── JobSearchApp.xcodeproj
├── JobSearchApp/
│   ├── App/
│   │   ├── JobSearchApp.swift           # @main entry point, ModelContainer setup
│   │   └── AppContainer.swift           # Dependency injection: LLMService, KeychainManager
│   ├── Models/
│   │   ├── UserProfile.swift            # UserProfile, ProfileBasics, ResumeTheme @Model classes
│   │   ├── CareerModels.swift           # WorkExperience, Education, Project @Model classes
│   │   └── JobModels.swift              # JobPosting, GeneratedDocument, all enums
│   ├── Services/
│   │   ├── LLMService.swift             # Protocol + MockLLMService
│   │   ├── AnthropicLLMService.swift    # URLSession impl, retry logic, streaming
│   │   └── KeychainManager.swift        # Keychain read/write/delete
│   └── Views/
│       ├── Navigation/
│       │   └── MainTabView.swift        # 4-tab TabView
│       ├── Settings/
│       │   ├── SettingsView.swift       # API key fields, export defaults
│       │   └── SettingsViewModel.swift  # Reads/writes Keychain + UserDefaults
│       ├── Discover/
│       │   └── DiscoverView.swift       # Placeholder — "Coming soon"
│       ├── Applications/
│       │   └── ApplicationsView.swift   # Placeholder
│       ├── Documents/
│       │   └── DocumentsView.swift      # Placeholder
│       └── Profile/
│           └── ProfileView.swift        # Placeholder
└── JobSearchAppTests/
    ├── Services/
    │   ├── KeychainManagerTests.swift
    │   └── AnthropicLLMServiceTests.swift
    └── Models/
        └── SwiftDataModelTests.swift
```

---

## Task 1: Xcode Project Setup

**Files:**
- Create: `JobSearchApp.xcodeproj` (via Xcode GUI — see steps)
- Modify: `JobSearchApp/Info.plist`

- [ ] **Step 1: Create the Xcode project**

  Open Xcode → File → New → Project → iOS → App.
  - Product Name: `JobSearchApp`
  - Interface: SwiftUI
  - Language: Swift
  - Storage: SwiftData
  - Include Tests: ✓
  - Save to: `C:\Users\nicol\OneDrive\Documents\GitHub\job-search-app\`
  *(Do this on your Mac/cloud Mac with Xcode installed)*

- [ ] **Step 2: Add CloudKit capability**

  In Xcode: Select `JobSearchApp` target → Signing & Capabilities → `+ Capability` → add **iCloud** → check **CloudKit** → create a new container named `iCloud.com.yourname.JobSearchApp`.

  Also add **Background Modes** capability → check **Background fetch**.

- [ ] **Step 3: Enable Files app access**

  In `Info.plist`, add these two keys:
  ```xml
  <key>UIFileSharingEnabled</key>
  <true/>
  <key>LSSupportsOpeningDocumentsInPlace</key>
  <true/>
  ```

- [ ] **Step 4: Add SwiftSoup package dependency**

  File → Add Package Dependencies → enter:
  `https://github.com/scinfu/SwiftSoup`
  → Add to `JobSearchApp` target.

- [ ] **Step 5: Verify the project builds**

  Product → Build (⌘B). Expected: Build Succeeded with 0 errors.

- [ ] **Step 6: Commit**

  ```bash
  git add .
  git commit -m "feat: initial Xcode project scaffold with CloudKit + SwiftData"
  ```

---

## Task 2: SwiftData Models

**Files:**
- Create: `JobSearchApp/Models/UserProfile.swift`
- Create: `JobSearchApp/Models/CareerModels.swift`
- Create: `JobSearchApp/Models/JobModels.swift`
- Modify: `JobSearchApp/App/JobSearchApp.swift`
- Test: `JobSearchAppTests/Models/SwiftDataModelTests.swift`

- [ ] **Step 1: Write the failing model test**

  Create `JobSearchAppTests/Models/SwiftDataModelTests.swift`:

  ```swift
  import XCTest
  import SwiftData
  @testable import JobSearchApp

  final class SwiftDataModelTests: XCTestCase {
      var container: ModelContainer!

      override func setUp() {
          super.setUp()
          let config = ModelConfiguration(isStoredInMemoryOnly: true)
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

      func test_userProfile_canBeInsertedAndFetched() throws {
          let context = container.mainContext
          let basics = ProfileBasics(
              name: "Jane Doe",
              email: "jane@example.com",
              phone: "+1 416 555 0100",
              location: "Toronto, ON",
              linkedIn: nil,
              github: "github.com/janedoe",
              website: nil
          )
          let theme = ResumeTheme(name: .modern, accentColor: "#1E3A5F", bodyFontSize: 11.0)
          let profile = UserProfile(basics: basics, resumeTheme: theme)
          context.insert(profile)
          try context.save()

          let profiles = try context.fetch(FetchDescriptor<UserProfile>())
          XCTAssertEqual(profiles.count, 1)
          XCTAssertEqual(profiles.first?.basics.name, "Jane Doe")
      }

      func test_jobPosting_canBeInsertedWithStatus() throws {
          let context = container.mainContext
          let posting = JobPosting(
              url: "https://example.com/job/123",
              title: "iOS Engineer",
              company: "Acme Corp",
              location: "Toronto, ON",
              scrapedDescription: "We are looking for...",
              priorityScore: 3,
              priorityReasoning: "Strong match on Swift experience",
              status: .saved,
              dateFound: Date()
          )
          context.insert(posting)
          try context.save()

          let postings = try context.fetch(FetchDescriptor<JobPosting>())
          XCTAssertEqual(postings.count, 1)
          XCTAssertEqual(postings.first?.status, .saved)
          XCTAssertEqual(postings.first?.priorityScore, 3)
      }

      func test_generatedDocument_linksToJobPosting() throws {
          let context = container.mainContext
          let posting = JobPosting(
              url: "https://example.com/job/456",
              title: "Swift Developer",
              company: "Beta Inc",
              location: "Remote",
              scrapedDescription: "Remote Swift role...",
              priorityScore: 2,
              priorityReasoning: "Excellent fit",
              status: .saved,
              dateFound: Date()
          )
          context.insert(posting)
          let doc = GeneratedDocument(
              type: .resume,
              richContent: Data("resume content".utf8),
              linkedJob: posting
          )
          context.insert(doc)
          try context.save()

          let docs = try context.fetch(FetchDescriptor<GeneratedDocument>())
          XCTAssertEqual(docs.count, 1)
          XCTAssertEqual(docs.first?.type, .resume)
          XCTAssertEqual(docs.first?.linkedJob.title, "Swift Developer")
      }
  }
  ```

- [ ] **Step 2: Run the test to verify it fails**

  In Xcode: Product → Test (⌘U), or run:
  ```bash
  xcodebuild test \
    -scheme JobSearchApp \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    -only-testing:JobSearchAppTests/SwiftDataModelTests \
    2>&1 | grep -E "(error:|FAILED|passed|failed)"
  ```
  Expected: Build error — `UserProfile`, `JobPosting` etc. not defined.

- [ ] **Step 3: Create `JobSearchApp/Models/UserProfile.swift`**

  ```swift
  import Foundation
  import SwiftData

  struct ProfileBasics: Codable {
      var name: String
      var email: String
      var phone: String?
      var location: String
      var linkedIn: String?
      var github: String?
      var website: String?
  }

  @Model
  final class UserProfile {
      @Attribute(.transformable(by: ProfileBasicsTransformer.self))
      var basics: ProfileBasics
      @Relationship(deleteRule: .cascade) var workHistory: [WorkExperience] = []
      @Relationship(deleteRule: .cascade) var education: [Education] = []
      var skills: [String] = []
      @Relationship(deleteRule: .cascade) var projects: [Project] = []
      @Relationship(deleteRule: .cascade, inverse: \ResumeTheme.profile)
      var resumeTheme: ResumeTheme?

      init(basics: ProfileBasics, resumeTheme: ResumeTheme? = nil) {
          self.basics = basics
          self.resumeTheme = resumeTheme
      }
  }

  // Transformer required for Codable struct in SwiftData
  final class ProfileBasicsTransformer: ValueTransformer {
      override class func transformedValueClass() -> AnyClass { NSData.self }
      override class func allowsReverseTransformation() -> Bool { true }

      override func transformedValue(_ value: Any?) -> Any? {
          guard let basics = value as? ProfileBasics else { return nil }
          return try? JSONEncoder().encode(basics) as NSData
      }

      override func reverseTransformedValue(_ value: Any?) -> Any? {
          guard let data = value as? Data else { return nil }
          return try? JSONDecoder().decode(ProfileBasics.self, from: data)
      }

      static func register() {
          ValueTransformer.setValueTransformer(
              ProfileBasicsTransformer(),
              forName: NSValueTransformerName("ProfileBasicsTransformer")
          )
      }
  }

  @Model
  final class ResumeTheme {
      var name: ThemeName
      var accentColor: String   // hex e.g. "#1E3A5F"
      var bodyFontSize: Double
      var profile: UserProfile?

      init(name: ThemeName, accentColor: String, bodyFontSize: Double) {
          self.name = name
          self.accentColor = accentColor
          self.bodyFontSize = bodyFontSize
      }
  }

  enum ThemeName: String, Codable {
      case classic, modern, creative, minimal
  }
  ```

- [ ] **Step 4: Create `JobSearchApp/Models/CareerModels.swift`**

  ```swift
  import Foundation
  import SwiftData

  @Model
  final class WorkExperience {
      var company: String
      var title: String
      var startDate: Date
      var endDate: Date?
      var isCurrent: Bool
      var bullets: [String]
      var profile: UserProfile?

      init(company: String, title: String, startDate: Date,
           endDate: Date? = nil, isCurrent: Bool = false, bullets: [String] = []) {
          self.company = company
          self.title = title
          self.startDate = startDate
          self.endDate = endDate
          self.isCurrent = isCurrent
          self.bullets = bullets
      }
  }

  @Model
  final class Education {
      var institution: String
      var degree: String
      var field: String
      var graduationDate: Date?
      var profile: UserProfile?

      init(institution: String, degree: String, field: String, graduationDate: Date? = nil) {
          self.institution = institution
          self.degree = degree
          self.field = field
          self.graduationDate = graduationDate
      }
  }

  @Model
  final class Project {
      var name: String
      var projectDescription: String
      var url: String?
      var bullets: [String]
      var profile: UserProfile?

      init(name: String, projectDescription: String, url: String? = nil, bullets: [String] = []) {
          self.name = name
          self.projectDescription = projectDescription
          self.url = url
          self.bullets = bullets
      }
  }
  ```

- [ ] **Step 5: Create `JobSearchApp/Models/JobModels.swift`**

  ```swift
  import Foundation
  import SwiftData

  enum JobStatus: String, Codable {
      case saved, applied, archived
  }

  enum DocumentType: String, Codable {
      case resume, coverLetter
  }

  @Model
  final class JobPosting {
      var id: UUID
      var url: String
      var title: String
      var company: String
      var location: String
      var scrapedDescription: String
      var priorityScore: Int
      var priorityReasoning: String
      var status: JobStatus
      var dateFound: Date
      @Relationship(deleteRule: .cascade) var documents: [GeneratedDocument] = []

      init(url: String, title: String, company: String, location: String,
           scrapedDescription: String, priorityScore: Int, priorityReasoning: String,
           status: JobStatus, dateFound: Date) {
          self.id = UUID()
          self.url = url
          self.title = title
          self.company = company
          self.location = location
          self.scrapedDescription = scrapedDescription
          self.priorityScore = priorityScore
          self.priorityReasoning = priorityReasoning
          self.status = status
          self.dateFound = dateFound
      }
  }

  @Model
  final class GeneratedDocument {
      var type: DocumentType
      var richContent: Data
      var lastModified: Date
      var linkedJob: JobPosting

      init(type: DocumentType, richContent: Data, linkedJob: JobPosting) {
          self.type = type
          self.richContent = richContent
          self.lastModified = Date()
          self.linkedJob = linkedJob
      }
  }
  ```

- [ ] **Step 6: Register the transformer and configure ModelContainer in `JobSearchApp/App/JobSearchApp.swift`**

  ```swift
  import SwiftUI
  import SwiftData

  @main
  struct JobSearchApp: App {
      init() {
          ProfileBasicsTransformer.register()
      }

      var sharedModelContainer: ModelContainer = {
          let schema = Schema([
              UserProfile.self,
              WorkExperience.self,
              Education.self,
              Project.self,
              ResumeTheme.self,
              JobPosting.self,
              GeneratedDocument.self
          ])
          let config = ModelConfiguration(
              schema: schema,
              cloudKitDatabase: .automatic
          )
          return try! ModelContainer(for: schema, configurations: [config])
      }()

      var body: some Scene {
          WindowGroup {
              MainTabView()
          }
          .modelContainer(sharedModelContainer)
      }
  }
  ```

- [ ] **Step 7: Run the tests to verify they pass**

  ```bash
  xcodebuild test \
    -scheme JobSearchApp \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    -only-testing:JobSearchAppTests/SwiftDataModelTests \
    2>&1 | grep -E "(error:|FAILED|Test Suite|passed|failed)"
  ```
  Expected: `Test Suite 'SwiftDataModelTests' passed`

- [ ] **Step 8: Commit**

  ```bash
  git add JobSearchApp/Models/ JobSearchApp/App/JobSearchApp.swift JobSearchAppTests/Models/
  git commit -m "feat: SwiftData models for UserProfile, JobPosting, GeneratedDocument"
  ```

---

## Task 3: KeychainManager

**Files:**
- Create: `JobSearchApp/Services/KeychainManager.swift`
- Test: `JobSearchAppTests/Services/KeychainManagerTests.swift`

- [ ] **Step 1: Write the failing test**

  Create `JobSearchAppTests/Services/KeychainManagerTests.swift`:

  ```swift
  import XCTest
  @testable import JobSearchApp

  final class KeychainManagerTests: XCTestCase {
      let manager = KeychainManager.shared
      let testKey = "test.keychain.key"

      override func tearDown() {
          try? manager.delete(key: testKey)
          super.tearDown()
      }

      func test_save_andRetrieve_value() throws {
          try manager.save("sk-test-api-key-12345", forKey: testKey)
          let retrieved = try manager.retrieve(forKey: testKey)
          XCTAssertEqual(retrieved, "sk-test-api-key-12345")
      }

      func test_retrieve_missingKey_returnsNil() throws {
          let result = try manager.retrieve(forKey: "nonexistent.key.xyz")
          XCTAssertNil(result)
      }

      func test_save_overwrites_existingValue() throws {
          try manager.save("old-value", forKey: testKey)
          try manager.save("new-value", forKey: testKey)
          let retrieved = try manager.retrieve(forKey: testKey)
          XCTAssertEqual(retrieved, "new-value")
      }

      func test_delete_removesValue() throws {
          try manager.save("to-be-deleted", forKey: testKey)
          try manager.delete(key: testKey)
          let result = try manager.retrieve(forKey: testKey)
          XCTAssertNil(result)
      }
  }
  ```

- [ ] **Step 2: Run the test to verify it fails**

  ```bash
  xcodebuild test \
    -scheme JobSearchApp \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    -only-testing:JobSearchAppTests/KeychainManagerTests \
    2>&1 | grep -E "(error:|FAILED|passed|failed)"
  ```
  Expected: Build error — `KeychainManager` not defined.

- [ ] **Step 3: Create `JobSearchApp/Services/KeychainManager.swift`**

  ```swift
  import Foundation
  import Security

  enum KeychainError: LocalizedError {
      case unexpectedStatus(OSStatus)

      var errorDescription: String? {
          switch self {
          case .unexpectedStatus(let status):
              return "Keychain error: \(status)"
          }
      }
  }

  final class KeychainManager {
      static let shared = KeychainManager()
      private init() {}

      func save(_ value: String, forKey key: String) throws {
          let data = Data(value.utf8)
          // Delete any existing item first
          try? delete(key: key)
          let query: [CFString: Any] = [
              kSecClass: kSecClassGenericPassword,
              kSecAttrAccount: key,
              kSecValueData: data
          ]
          let status = SecItemAdd(query as CFDictionary, nil)
          guard status == errSecSuccess else {
              throw KeychainError.unexpectedStatus(status)
          }
      }

      func retrieve(forKey key: String) throws -> String? {
          let query: [CFString: Any] = [
              kSecClass: kSecClassGenericPassword,
              kSecAttrAccount: key,
              kSecReturnData: true,
              kSecMatchLimit: kSecMatchLimitOne
          ]
          var result: AnyObject?
          let status = SecItemCopyMatching(query as CFDictionary, &result)
          if status == errSecItemNotFound { return nil }
          guard status == errSecSuccess, let data = result as? Data else {
              throw KeychainError.unexpectedStatus(status)
          }
          return String(data: data, encoding: .utf8)
      }

      func delete(key: String) throws {
          let query: [CFString: Any] = [
              kSecClass: kSecClassGenericPassword,
              kSecAttrAccount: key
          ]
          let status = SecItemDelete(query as CFDictionary)
          guard status == errSecSuccess || status == errSecItemNotFound else {
              throw KeychainError.unexpectedStatus(status)
          }
      }
  }
  ```

- [ ] **Step 4: Run the tests to verify they pass**

  ```bash
  xcodebuild test \
    -scheme JobSearchApp \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    -only-testing:JobSearchAppTests/KeychainManagerTests \
    2>&1 | grep -E "(error:|FAILED|Test Suite|passed|failed)"
  ```
  Expected: `Test Suite 'KeychainManagerTests' passed`

- [ ] **Step 5: Commit**

  ```bash
  git add JobSearchApp/Services/KeychainManager.swift JobSearchAppTests/Services/KeychainManagerTests.swift
  git commit -m "feat: KeychainManager for secure API key storage"
  ```

---

## Task 4: LLMService Protocol and MockLLMService

**Files:**
- Create: `JobSearchApp/Services/LLMService.swift`
- Test: `JobSearchAppTests/Services/AnthropicLLMServiceTests.swift` (partial — mock only)

- [ ] **Step 1: Write the failing test for MockLLMService**

  Create `JobSearchAppTests/Services/AnthropicLLMServiceTests.swift`:

  ```swift
  import XCTest
  @testable import JobSearchApp

  final class AnthropicLLMServiceTests: XCTestCase {

      func test_mockLLMService_returnsConfiguredResponse() async throws {
          let mock = MockLLMService(response: "Hello from mock")
          let result = try await mock.complete(prompt: "Say hello", system: "You are helpful.")
          XCTAssertEqual(result, "Hello from mock")
      }

      func test_mockLLMService_stream_emitsChunks() async throws {
          let mock = MockLLMService(response: "chunk1 chunk2 chunk3")
          var collected = ""
          for try await chunk in mock.stream(prompt: "stream test", system: "You are helpful.") {
              collected += chunk
          }
          XCTAssertEqual(collected, "chunk1 chunk2 chunk3")
      }

      func test_mockLLMService_canThrow() async {
          let mock = MockLLMService(error: URLError(.notConnectedToInternet))
          do {
              _ = try await mock.complete(prompt: "fail", system: "")
              XCTFail("Expected error to be thrown")
          } catch {
              XCTAssertTrue(error is URLError)
          }
      }
  }
  ```

- [ ] **Step 2: Run the test to verify it fails**

  ```bash
  xcodebuild test \
    -scheme JobSearchApp \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    -only-testing:JobSearchAppTests/AnthropicLLMServiceTests \
    2>&1 | grep -E "(error:|FAILED|passed|failed)"
  ```
  Expected: Build error — `MockLLMService` not defined.

- [ ] **Step 3: Create `JobSearchApp/Services/LLMService.swift`**

  ```swift
  import Foundation

  protocol LLMService {
      func complete(prompt: String, system: String) async throws -> String
      func stream(prompt: String, system: String) -> AsyncThrowingStream<String, Error>
  }

  // Used in all unit tests — swap AnthropicLLMService for this
  final class MockLLMService: LLMService {
      private let response: String
      private let error: Error?

      init(response: String = "", error: Error? = nil) {
          self.response = response
          self.error = error
      }

      func complete(prompt: String, system: String) async throws -> String {
          if let error { throw error }
          return response
      }

      func stream(prompt: String, system: String) -> AsyncThrowingStream<String, Error> {
          AsyncThrowingStream { continuation in
              if let error = self.error {
                  continuation.finish(throwing: error)
              } else {
                  continuation.yield(self.response)
                  continuation.finish()
              }
          }
      }
  }
  ```

- [ ] **Step 4: Run the tests to verify they pass**

  ```bash
  xcodebuild test \
    -scheme JobSearchApp \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    -only-testing:JobSearchAppTests/AnthropicLLMServiceTests \
    2>&1 | grep -E "(error:|FAILED|Test Suite|passed|failed)"
  ```
  Expected: `Test Suite 'AnthropicLLMServiceTests' passed`

- [ ] **Step 5: Commit**

  ```bash
  git add JobSearchApp/Services/LLMService.swift JobSearchAppTests/Services/AnthropicLLMServiceTests.swift
  git commit -m "feat: LLMService protocol and MockLLMService"
  ```

---

## Task 5: AnthropicLLMService

**Files:**
- Create: `JobSearchApp/Services/AnthropicLLMService.swift`
- Modify: `JobSearchAppTests/Services/AnthropicLLMServiceTests.swift`

- [ ] **Step 1: Add integration-style tests to `AnthropicLLMServiceTests.swift`**

  Append to the existing test class:

  ```swift
      // Tests AnthropicLLMService request construction without hitting the real API.
      // Uses a custom URLProtocol to intercept URLSession requests.

      func test_anthropicService_buildsCorrectRequest() async throws {
          MockURLProtocol.requestHandler = { request in
              // Verify headers
              XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "test-key-123")
              XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
              XCTAssertEqual(request.value(forHTTPHeaderField: "content-type"), "application/json")

              // Return a minimal valid Anthropic response
              let body = """
              {"content":[{"type":"text","text":"Hello from Claude"}],"stop_reason":"end_turn"}
              """
              let response = HTTPURLResponse(
                  url: request.url!,
                  statusCode: 200,
                  httpVersion: nil,
                  headerFields: ["Content-Type": "application/json"]
              )!
              return (response, Data(body.utf8))
          }

          let config = URLSessionConfiguration.ephemeral
          config.protocolClasses = [MockURLProtocol.self]
          let session = URLSession(configuration: config)
          let service = AnthropicLLMService(apiKey: "test-key-123", session: session)

          let result = try await service.complete(prompt: "Say hello", system: "You are helpful.")
          XCTAssertEqual(result, "Hello from Claude")
      }

      func test_anthropicService_retries_on429() async throws {
          var callCount = 0
          MockURLProtocol.requestHandler = { request in
              callCount += 1
              if callCount < 2 {
                  let response = HTTPURLResponse(
                      url: request.url!, statusCode: 429,
                      httpVersion: nil, headerFields: nil
                  )!
                  return (response, Data())
              }
              let body = """
              {"content":[{"type":"text","text":"retry worked"}],"stop_reason":"end_turn"}
              """
              let response = HTTPURLResponse(
                  url: request.url!, statusCode: 200,
                  httpVersion: nil, headerFields: ["Content-Type": "application/json"]
              )!
              return (response, Data(body.utf8))
          }

          let config = URLSessionConfiguration.ephemeral
          config.protocolClasses = [MockURLProtocol.self]
          let session = URLSession(configuration: config)
          let service = AnthropicLLMService(apiKey: "test-key-123", session: session, retryDelay: 0)

          let result = try await service.complete(prompt: "test", system: "")
          XCTAssertEqual(result, "retry worked")
          XCTAssertEqual(callCount, 2)
      }
  ```

  Add `MockURLProtocol` at the bottom of the test file (outside the class):

  ```swift
  final class MockURLProtocol: URLProtocol {
      static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

      override class func canInit(with request: URLRequest) -> Bool { true }
      override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

      override func startLoading() {
          guard let handler = MockURLProtocol.requestHandler else {
              client?.urlProtocolDidFinishLoading(self)
              return
          }
          do {
              let (response, data) = try handler(request)
              client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
              client?.urlProtocol(self, didLoad: data)
              client?.urlProtocolDidFinishLoading(self)
          } catch {
              client?.urlProtocol(self, didFailWithError: error)
          }
      }

      override func stopLoading() {}
  }
  ```

- [ ] **Step 2: Run the new tests to verify they fail**

  ```bash
  xcodebuild test \
    -scheme JobSearchApp \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    -only-testing:JobSearchAppTests/AnthropicLLMServiceTests/test_anthropicService_buildsCorrectRequest \
    2>&1 | grep -E "(error:|FAILED|passed|failed)"
  ```
  Expected: Build error — `AnthropicLLMService` not defined.

- [ ] **Step 3: Create `JobSearchApp/Services/AnthropicLLMService.swift`**

  ```swift
  import Foundation

  enum LLMError: LocalizedError {
      case missingAPIKey
      case invalidResponse(Int)
      case decodingFailed(String)
      case maxRetriesExceeded

      var errorDescription: String? {
          switch self {
          case .missingAPIKey: return "Claude API key not configured. Add it in Settings."
          case .invalidResponse(let code): return "Unexpected API response: HTTP \(code)"
          case .decodingFailed(let detail): return "Failed to parse API response: \(detail)"
          case .maxRetriesExceeded: return "Request failed after retries. Please try again."
          }
      }
  }

  final class AnthropicLLMService: LLMService {
      private let apiKey: String
      private let session: URLSession
      private let retryDelay: TimeInterval
      private let maxRetries = 2
      private let model = "claude-sonnet-4-6"
      private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

      init(apiKey: String, session: URLSession = .shared, retryDelay: TimeInterval = 1.0) {
          self.apiKey = apiKey
          self.session = session
          self.retryDelay = retryDelay
      }

      func complete(prompt: String, system: String) async throws -> String {
          var lastError: Error = LLMError.maxRetriesExceeded
          for attempt in 0..<maxRetries {
              do {
                  return try await performRequest(prompt: prompt, system: system)
              } catch LLMError.invalidResponse(let code) where code == 429 || code == 503 {
                  lastError = LLMError.invalidResponse(code)
                  if attempt < maxRetries - 1 {
                      try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                  }
              } catch {
                  throw error
              }
          }
          throw lastError
      }

      func stream(prompt: String, system: String) -> AsyncThrowingStream<String, Error> {
          // Streaming via SSE — delivers text deltas as they arrive
          AsyncThrowingStream { continuation in
              Task {
                  do {
                      var request = self.buildRequest(prompt: prompt, system: system, stream: true)
                      let (bytes, response) = try await self.session.bytes(for: request)
                      guard let httpResponse = response as? HTTPURLResponse,
                            httpResponse.statusCode == 200 else {
                          let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                          continuation.finish(throwing: LLMError.invalidResponse(code))
                          return
                      }
                      for try await line in bytes.lines {
                          guard line.hasPrefix("data: "),
                                let data = line.dropFirst(6).data(using: .utf8),
                                let delta = try? JSONDecoder().decode(StreamDelta.self, from: data),
                                let text = delta.delta?.text else { continue }
                          continuation.yield(text)
                      }
                      continuation.finish()
                  } catch {
                      continuation.finish(throwing: error)
                  }
              }
          }
      }

      // MARK: - Private

      private func performRequest(prompt: String, system: String) async throws -> String {
          let request = buildRequest(prompt: prompt, system: system, stream: false)
          let (data, response) = try await session.data(for: request)
          guard let httpResponse = response as? HTTPURLResponse else {
              throw LLMError.invalidResponse(0)
          }
          guard httpResponse.statusCode == 200 else {
              throw LLMError.invalidResponse(httpResponse.statusCode)
          }
          guard let decoded = try? JSONDecoder().decode(MessagesResponse.self, from: data),
                let text = decoded.content.first?.text else {
              throw LLMError.decodingFailed(String(data: data, encoding: .utf8) ?? "")
          }
          return text
      }

      private func buildRequest(prompt: String, system: String, stream: Bool) -> URLRequest {
          var request = URLRequest(url: endpoint)
          request.httpMethod = "POST"
          request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
          request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
          request.setValue("application/json", forHTTPHeaderField: "content-type")
          let body: [String: Any] = [
              "model": model,
              "max_tokens": 4096,
              "system": system,
              "stream": stream,
              "messages": [["role": "user", "content": prompt]]
          ]
          request.httpBody = try? JSONSerialization.data(withJSONObject: body)
          return request
      }

      // MARK: - Response Types

      private struct MessagesResponse: Decodable {
          let content: [ContentBlock]
          struct ContentBlock: Decodable {
              let type: String
              let text: String?
          }
      }

      private struct StreamDelta: Decodable {
          let delta: Delta?
          struct Delta: Decodable {
              let type: String?
              let text: String?
          }
      }
  }
  ```

- [ ] **Step 4: Run all LLM service tests**

  ```bash
  xcodebuild test \
    -scheme JobSearchApp \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    -only-testing:JobSearchAppTests/AnthropicLLMServiceTests \
    2>&1 | grep -E "(error:|FAILED|Test Suite|passed|failed)"
  ```
  Expected: `Test Suite 'AnthropicLLMServiceTests' passed`

- [ ] **Step 5: Commit**

  ```bash
  git add JobSearchApp/Services/AnthropicLLMService.swift JobSearchAppTests/Services/AnthropicLLMServiceTests.swift
  git commit -m "feat: AnthropicLLMService with retry logic and streaming"
  ```

---

## Task 6: AppContainer (Dependency Injection)

**Files:**
- Create: `JobSearchApp/App/AppContainer.swift`
- Modify: `JobSearchApp/App/JobSearchApp.swift`

- [ ] **Step 1: Create `JobSearchApp/App/AppContainer.swift`**

  No test needed — this is pure wiring with no logic.

  ```swift
  import Foundation

  @MainActor
  final class AppContainer: ObservableObject {
      let keychain = KeychainManager.shared
      lazy var llmService: any LLMService = makeLLMService()

      private func makeLLMService() -> any LLMService {
          if let key = try? keychain.retrieve(forKey: KeychainKeys.anthropicAPIKey),
             !key.isEmpty {
              return AnthropicLLMService(apiKey: key)
          }
          // Returns mock with empty string until user configures API key.
          // SettingsViewModel will recreate llmService after key is saved.
          return MockLLMService(response: "")
      }

      func refreshLLMService() {
          llmService = makeLLMService()
      }
  }

  enum KeychainKeys {
      static let anthropicAPIKey = "com.jobsearch.anthropic.apikey"
      static let tavilyAPIKey    = "com.jobsearch.tavily.apikey"
  }
  ```

- [ ] **Step 2: Inject AppContainer into the SwiftUI environment in `JobSearchApp.swift`**

  Replace the existing `body` in `JobSearchApp.swift`:

  ```swift
  @main
  struct JobSearchApp: App {
      @StateObject private var container = AppContainer()

      init() {
          ProfileBasicsTransformer.register()
      }

      var sharedModelContainer: ModelContainer = {
          let schema = Schema([
              UserProfile.self, WorkExperience.self, Education.self,
              Project.self, ResumeTheme.self, JobPosting.self, GeneratedDocument.self
          ])
          let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
          return try! ModelContainer(for: schema, configurations: [config])
      }()

      var body: some Scene {
          WindowGroup {
              MainTabView()
                  .environmentObject(container)
          }
          .modelContainer(sharedModelContainer)
      }
  }
  ```

- [ ] **Step 3: Build to verify no errors**

  Product → Build (⌘B). Expected: Build Succeeded.

- [ ] **Step 4: Commit**

  ```bash
  git add JobSearchApp/App/AppContainer.swift JobSearchApp/App/JobSearchApp.swift
  git commit -m "feat: AppContainer dependency injection for LLMService"
  ```

---

## Task 7: Navigation Shell

**Files:**
- Create: `JobSearchApp/Views/Navigation/MainTabView.swift`
- Create: `JobSearchApp/Views/Discover/DiscoverView.swift`
- Create: `JobSearchApp/Views/Applications/ApplicationsView.swift`
- Create: `JobSearchApp/Views/Documents/DocumentsView.swift`
- Create: `JobSearchApp/Views/Profile/ProfileView.swift`

- [ ] **Step 1: Create placeholder tab views**

  Create `JobSearchApp/Views/Discover/DiscoverView.swift`:
  ```swift
  import SwiftUI
  struct DiscoverView: View {
      var body: some View {
          NavigationStack {
              ContentUnavailableView("Job Discovery", systemImage: "magnifyingglass",
                  description: Text("Search for jobs coming in Plan 3"))
              .navigationTitle("Discover")
          }
      }
  }
  ```

  Create `JobSearchApp/Views/Applications/ApplicationsView.swift`:
  ```swift
  import SwiftUI
  struct ApplicationsView: View {
      var body: some View {
          NavigationStack {
              ContentUnavailableView("Applications", systemImage: "briefcase",
                  description: Text("Track your applications — coming in Plan 3"))
              .navigationTitle("Applications")
          }
      }
  }
  ```

  Create `JobSearchApp/Views/Documents/DocumentsView.swift`:
  ```swift
  import SwiftUI
  struct DocumentsView: View {
      var body: some View {
          NavigationStack {
              ContentUnavailableView("Documents", systemImage: "doc.text",
                  description: Text("Generated resumes and cover letters — coming in Plan 4"))
              .navigationTitle("Documents")
          }
      }
  }
  ```

  Create `JobSearchApp/Views/Profile/ProfileView.swift`:
  ```swift
  import SwiftUI
  struct ProfileView: View {
      var body: some View {
          NavigationStack {
              ContentUnavailableView("Profile", systemImage: "person.circle",
                  description: Text("Your career profile — coming in Plan 2"))
              .navigationTitle("Profile")
              .toolbar {
                  ToolbarItem(placement: .topBarTrailing) {
                      NavigationLink(destination: SettingsView()) {
                          Image(systemName: "gear")
                      }
                  }
              }
          }
      }
  }
  ```

- [ ] **Step 2: Create `JobSearchApp/Views/Navigation/MainTabView.swift`**

  ```swift
  import SwiftUI

  struct MainTabView: View {
      var body: some View {
          TabView {
              DiscoverView()
                  .tabItem { Label("Discover", systemImage: "magnifyingglass") }
              ApplicationsView()
                  .tabItem { Label("Applications", systemImage: "briefcase") }
              DocumentsView()
                  .tabItem { Label("Documents", systemImage: "doc.text") }
              ProfileView()
                  .tabItem { Label("Profile", systemImage: "person.circle") }
          }
      }
  }
  ```

- [ ] **Step 3: Build and run in simulator**

  Product → Run (⌘R). Expected: App launches showing 4-tab navigation with placeholder screens. Gear icon in Profile tab navigates to Settings (empty for now).

- [ ] **Step 4: Commit**

  ```bash
  git add JobSearchApp/Views/
  git commit -m "feat: 4-tab navigation shell with placeholder screens"
  ```

---

## Task 8: Settings Screen

**Files:**
- Create: `JobSearchApp/Views/Settings/SettingsViewModel.swift`
- Create: `JobSearchApp/Views/Settings/SettingsView.swift`

- [ ] **Step 1: Create `JobSearchApp/Views/Settings/SettingsViewModel.swift`**

  ```swift
  import Foundation
  import Combine

  @MainActor
  final class SettingsViewModel: ObservableObject {
      @Published var anthropicKey: String = ""
      @Published var tavilyKey: String = ""
      @Published var defaultExportFormat: ExportFormat = .pdf
      @Published var saveMessage: String?

      private let keychain = KeychainManager.shared

      enum ExportFormat: String, CaseIterable, Identifiable {
          case pdf = "PDF"
          case docx = "DOCX"
          case both = "Both"
          var id: String { rawValue }
      }

      func loadKeys() {
          anthropicKey = (try? keychain.retrieve(forKey: KeychainKeys.anthropicAPIKey)) ?? ""
          tavilyKey    = (try? keychain.retrieve(forKey: KeychainKeys.tavilyAPIKey))    ?? ""
          let raw = UserDefaults.standard.string(forKey: "exportFormat") ?? ExportFormat.pdf.rawValue
          defaultExportFormat = ExportFormat(rawValue: raw) ?? .pdf
      }

      func saveKeys(container: AppContainer) {
          do {
              try keychain.save(anthropicKey, forKey: KeychainKeys.anthropicAPIKey)
              try keychain.save(tavilyKey,    forKey: KeychainKeys.tavilyAPIKey)
              UserDefaults.standard.set(defaultExportFormat.rawValue, forKey: "exportFormat")
              container.refreshLLMService()
              saveMessage = "Saved"
          } catch {
              saveMessage = "Error: \(error.localizedDescription)"
          }
      }
  }
  ```

- [ ] **Step 2: Create `JobSearchApp/Views/Settings/SettingsView.swift`**

  ```swift
  import SwiftUI

  struct SettingsView: View {
      @EnvironmentObject private var container: AppContainer
      @StateObject private var viewModel = SettingsViewModel()

      var body: some View {
          Form {
              Section {
                  SecureField("Claude API Key", text: $viewModel.anthropicKey)
                      .textContentType(.password)
                      .autocorrectionDisabled()
              } header: {
                  Text("AI")
              } footer: {
                  Text("Required for document generation. Get your key at console.anthropic.com")
              }

              Section {
                  SecureField("Tavily API Key", text: $viewModel.tavilyKey)
                      .textContentType(.password)
                      .autocorrectionDisabled()
              } header: {
                  Text("Job Search")
              } footer: {
                  Text("Required for AI job discovery. Get your key at tavily.com")
              }

              Section("Documents") {
                  Picker("Default Export Format", selection: $viewModel.defaultExportFormat) {
                      ForEach(SettingsViewModel.ExportFormat.allCases) { format in
                          Text(format.rawValue).tag(format)
                      }
                  }
              }

              Section {
                  Button("Save") {
                      viewModel.saveKeys(container: container)
                  }
                  .frame(maxWidth: .infinity)
                  if let message = viewModel.saveMessage {
                      Text(message)
                          .foregroundStyle(message.hasPrefix("Error") ? .red : .green)
                          .frame(maxWidth: .infinity)
                  }
              }
          }
          .navigationTitle("Settings")
          .onAppear { viewModel.loadKeys() }
      }
  }
  ```

- [ ] **Step 3: Build and run in simulator**

  Product → Run (⌘R). Navigate to Profile tab → tap gear → Settings screen. Enter dummy API keys, tap Save. Expected: "Saved" confirmation appears. Keys persist across app restarts.

- [ ] **Step 4: Commit**

  ```bash
  git add JobSearchApp/Views/Settings/
  git commit -m "feat: Settings screen with Keychain-backed API key storage"
  ```

---

## Task 9: Full Test Suite Pass

- [ ] **Step 1: Run all tests**

  ```bash
  xcodebuild test \
    -scheme JobSearchApp \
    -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest' \
    2>&1 | grep -E "(error:|FAILED|Test Suite 'All|passed|failed)"
  ```
  Expected: `Test Suite 'All tests' passed`

- [ ] **Step 2: Commit any final fixes, then tag**

  ```bash
  git add -A
  git commit -m "chore: foundation plan complete — all tests passing"
  git tag foundation-complete
  ```

---

## What's Next

With Foundation complete, the remaining three plans can be worked on in order:

- **Plan 2 — Profile & Onboarding:** `docs/superpowers/plans/2026-04-07-profile-onboarding.md`
- **Plan 3 — Job Discovery:** `docs/superpowers/plans/2026-04-07-job-discovery.md`
- **Plan 4 — Documents:** `docs/superpowers/plans/2026-04-07-documents.md`
