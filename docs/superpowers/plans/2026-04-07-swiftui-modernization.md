# SwiftUI Modernization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate all six `ObservableObject` classes to `@Observable` (iOS 17+), update injection and consumption patterns (`@EnvironmentObject` → `@Environment`, `@StateObject` → `@State`, `@ObservedObject` → `@Bindable`), fix two deprecated `clipShape(RoundedRectangle(...))` calls, and adopt the iOS 18 `Tab` API with a proper `#available` fallback.

**Architecture:** Each class migration is atomic — the class and every view that consumes it are updated in a single commit so the build never breaks mid-task. No new behavior is introduced; the 40 existing tests serve as the regression suite. `AppContainer` is migrated first because it is consumed by the most views.

**Tech Stack:** SwiftUI, Observation framework (iOS 17+), Swift 5.9 macros

---

## File Map

| Action | Path | Change |
|--------|------|--------|
| Modify | `JobSearchApp/App/AppContainer.swift` | `@Observable`, remove `ObservableObject`/`@Published`, convert `lazy var` to `init` |
| Modify | `JobSearchApp/App/OnboardingCoordinator.swift` | `@Observable`, remove `ObservableObject`/`@Published` |
| Modify | `JobSearchApp/App/JobSearchApp.swift` | `@State` for owned objects, `.environment(x)` instead of `.environmentObject(x)` |
| Modify | `JobSearchApp/Views/Onboarding/OnboardingView.swift` | Update `OnboardingViewModel` to `@Observable`, `@State` for vm, `@Environment` for coordinator + container |
| Modify | `JobSearchApp/Views/Onboarding/NameStepView.swift` | `@ObservedObject` → `@Bindable` |
| Modify | `JobSearchApp/Views/Onboarding/EmailStepView.swift` | `@ObservedObject` → `@Bindable` |
| Modify | `JobSearchApp/Views/Onboarding/ClaudeKeyStepView.swift` | `@ObservedObject` → `@Bindable` |
| Modify | `JobSearchApp/Views/Onboarding/ProfileDetailsStepView.swift` | `@ObservedObject` → `@Bindable` |
| Modify | `JobSearchApp/Views/Onboarding/TavilyKeyStepView.swift` | `@ObservedObject` → `@Bindable` |
| Modify | `JobSearchApp/Views/Discover/DiscoverView.swift` | `@EnvironmentObject` → `@Environment`, `@StateObject` → `@State` (Task 4) |
| Modify | `JobSearchApp/Views/Discover/AddJobView.swift` | `@EnvironmentObject` → `@Environment` |
| Modify | `JobSearchApp/Views/Documents/GenerateDocumentsView.swift` | `@EnvironmentObject` → `@Environment` |
| Modify | `JobSearchApp/Views/Settings/SettingsView.swift` | `@EnvironmentObject` → `@Environment`, `@StateObject` → `@State` |
| Modify | `JobSearchApp/Views/Settings/SettingsViewModel.swift` | `@Observable`, remove `ObservableObject`/`@Published`/`Combine` |
| Modify | `JobSearchApp/Views/Profile/ProfileView.swift` | `@StateObject` → `@State` |
| Modify | `JobSearchApp/Views/Profile/ProfileViewModel.swift` | `@Observable`, remove `ObservableObject`/`@Published` |
| Modify | `JobSearchApp/ViewModels/JobSearchViewModel.swift` | `@Observable`, remove `ObservableObject`/`@Published` |
| Modify | `JobSearchApp/Views/Navigation/MainTabView.swift` | `Tab` API with `#available(iOS 18, *)` fallback |
| Modify | `JobSearchApp/Views/Discover/JobDetailView.swift` | `clipShape(.rect(cornerRadius: 10))` |
| Modify | `JobSearchApp/Views/Onboarding/WelcomeView.swift` | `clipShape(.rect(cornerRadius: 14))` |

---

## Task 1: Migrate AppContainer to @Observable

`AppContainer` is used by 5 views plus the root app. Removing its `ObservableObject` conformance will cause compile errors in every consumer until they are updated. All changes ship in one commit.

**Files:**
- Modify: `JobSearchApp/App/AppContainer.swift`
- Modify: `JobSearchApp/App/JobSearchApp.swift`
- Modify: `JobSearchApp/Views/Discover/DiscoverView.swift`
- Modify: `JobSearchApp/Views/Discover/AddJobView.swift`
- Modify: `JobSearchApp/Views/Documents/GenerateDocumentsView.swift`
- Modify: `JobSearchApp/Views/Settings/SettingsView.swift`
- Modify: `JobSearchApp/Views/Onboarding/OnboardingView.swift`

- [ ] **Step 1: Replace AppContainer.swift**

```swift
import Foundation
import Observation

@Observable
@MainActor
final class AppContainer {
    var llmService: any LLMService

    init() {
        llmService = AppContainer.buildLLMService()
    }

    func refreshLLMService() {
        llmService = AppContainer.buildLLMService()
    }

    private static func buildLLMService() -> any LLMService {
        if let key = try? KeychainManager.shared.retrieve(forKey: KeychainKeys.anthropicAPIKey),
           !key.isEmpty {
            return AnthropicLLMService(apiKey: key)
        }
        return MockLLMService(response: "")
    }
}

enum KeychainKeys {
    static let anthropicAPIKey = "com.jobsearch.anthropic.apikey"
    static let tavilyAPIKey    = "com.jobsearch.tavily.apikey"
}
```

**Why `import Observation`:** `AppContainer` imports only `Foundation`. `@Observable` lives in the `Observation` framework which is not re-exported by `Foundation`. Files that import `SwiftUI` get it automatically.

**Why convert `lazy var` to `init`:** `lazy var` and `@Observable` conflict because the macro rewrites property storage. Moving the initialization to `init()` is the correct pattern.

- [ ] **Step 2: Update JobSearchApp.swift**

Replace both `@StateObject` declarations and both `.environmentObject(...)` calls:

```swift
import SwiftUI
import SwiftData

@main
struct JobSearchApp: App {
    @State private var container = AppContainer()
    @StateObject private var onboardingCoordinator = OnboardingCoordinator()
    let sharedModelContainer: ModelContainer

    init() {
        let schema = Schema([
            UserProfile.self, WorkExperience.self, Education.self,
            Project.self, ResumeTheme.self, JobPosting.self, GeneratedDocument.self
        ])
        if let cloudContainer = try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)]
        ) {
            sharedModelContainer = cloudContainer
        } else {
            sharedModelContainer = try! ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, cloudKitDatabase: .none)]
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingCoordinator.isOnboardingComplete {
                    MainTabView()
                        .environment(container)
                } else {
                    OnboardingView()
                        .environment(container)
                        .environmentObject(onboardingCoordinator)
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
```

**Note:** `onboardingCoordinator` still uses `@StateObject`/`@EnvironmentObject` here — it migrates in Task 2. This is intentional so each task builds cleanly.

- [ ] **Step 3: Update DiscoverView.swift — change @EnvironmentObject to @Environment**

Change line 7 only:
```swift
// Before:
@EnvironmentObject private var container: AppContainer

// After:
@Environment(AppContainer.self) private var container
```

Leave `@StateObject private var searchVM = JobSearchViewModel()` unchanged — it migrates in Task 4.

- [ ] **Step 4: Update AddJobView.swift — change @EnvironmentObject to @Environment**

```swift
// Before:
@EnvironmentObject private var container: AppContainer

// After:
@Environment(AppContainer.self) private var container
```

- [ ] **Step 5: Update GenerateDocumentsView.swift — change @EnvironmentObject to @Environment**

```swift
// Before:
@EnvironmentObject private var container: AppContainer

// After:
@Environment(AppContainer.self) private var container
```

- [ ] **Step 6: Update SettingsView.swift — change @EnvironmentObject to @Environment**

```swift
// Before:
@EnvironmentObject private var container: AppContainer

// After:
@Environment(AppContainer.self) private var container
```

Leave `@StateObject private var viewModel = SettingsViewModel()` unchanged — it migrates in Task 5.

- [ ] **Step 7: Update OnboardingView.swift — change @EnvironmentObject for container to @Environment**

In `OnboardingView` struct, change only the container line:
```swift
// Before:
@EnvironmentObject private var container: AppContainer

// After:
@Environment(AppContainer.self) private var container
```

Leave `@StateObject private var vm = OnboardingViewModel()` and `@EnvironmentObject private var coordinator: OnboardingCoordinator` unchanged.

- [ ] **Step 8: Build and run all tests**

```bash
xcodebuild test \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|FAILED|passed|failed|Test Suite"
```

Expected: All 40 tests pass, `BUILD SUCCEEDED`.

- [ ] **Step 9: Commit**

```bash
git add JobSearchApp/App/AppContainer.swift \
        JobSearchApp/App/JobSearchApp.swift \
        JobSearchApp/Views/Discover/DiscoverView.swift \
        JobSearchApp/Views/Discover/AddJobView.swift \
        JobSearchApp/Views/Documents/GenerateDocumentsView.swift \
        JobSearchApp/Views/Settings/SettingsView.swift \
        JobSearchApp/Views/Onboarding/OnboardingView.swift
git commit -m "refactor: migrate AppContainer to @Observable"
```

---

## Task 2: Migrate OnboardingCoordinator to @Observable

`OnboardingCoordinator` is used by `JobSearchApp.swift` and `OnboardingView.swift`.

**Files:**
- Modify: `JobSearchApp/App/OnboardingCoordinator.swift`
- Modify: `JobSearchApp/App/JobSearchApp.swift`
- Modify: `JobSearchApp/Views/Onboarding/OnboardingView.swift`

- [ ] **Step 1: Replace OnboardingCoordinator.swift**

```swift
import Foundation
import Observation

@Observable
@MainActor
final class OnboardingCoordinator {
    private(set) var isOnboardingComplete: Bool

    private static let key = "com.jobsearch.onboardingComplete"

    init() {
        isOnboardingComplete = UserDefaults.standard.bool(forKey: Self.key)
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.key)
        isOnboardingComplete = true
    }

    func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: Self.key)
        isOnboardingComplete = false
    }
}
```

- [ ] **Step 2: Update JobSearchApp.swift**

Replace `@StateObject` and `.environmentObject` for `onboardingCoordinator`:

```swift
import SwiftUI
import SwiftData

@main
struct JobSearchApp: App {
    @State private var container = AppContainer()
    @State private var onboardingCoordinator = OnboardingCoordinator()
    let sharedModelContainer: ModelContainer

    init() {
        let schema = Schema([
            UserProfile.self, WorkExperience.self, Education.self,
            Project.self, ResumeTheme.self, JobPosting.self, GeneratedDocument.self
        ])
        if let cloudContainer = try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)]
        ) {
            sharedModelContainer = cloudContainer
        } else {
            sharedModelContainer = try! ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, cloudKitDatabase: .none)]
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if onboardingCoordinator.isOnboardingComplete {
                    MainTabView()
                        .environment(container)
                } else {
                    OnboardingView()
                        .environment(container)
                        .environment(onboardingCoordinator)
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
```

- [ ] **Step 3: Update OnboardingView.swift — change @EnvironmentObject for coordinator to @Environment**

In the `OnboardingView` struct, change only the coordinator line:
```swift
// Before:
@EnvironmentObject private var coordinator: OnboardingCoordinator

// After:
@Environment(OnboardingCoordinator.self) private var coordinator
```

Leave `@StateObject private var vm = OnboardingViewModel()` unchanged — it migrates in Task 3.

- [ ] **Step 4: Build and run all tests**

```bash
xcodebuild test \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|FAILED|passed|failed|Test Suite"
```

Expected: All 40 tests pass, `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add JobSearchApp/App/OnboardingCoordinator.swift \
        JobSearchApp/App/JobSearchApp.swift \
        JobSearchApp/Views/Onboarding/OnboardingView.swift
git commit -m "refactor: migrate OnboardingCoordinator to @Observable"
```

---

## Task 3: Migrate OnboardingViewModel to @Observable

`OnboardingViewModel` is defined in `OnboardingView.swift` and consumed by 5 step views via `@ObservedObject`. The step views use `$vm.property` bindings, so they become `@Bindable`.

**Files:**
- Modify: `JobSearchApp/Views/Onboarding/OnboardingView.swift`
- Modify: `JobSearchApp/Views/Onboarding/NameStepView.swift`
- Modify: `JobSearchApp/Views/Onboarding/EmailStepView.swift`
- Modify: `JobSearchApp/Views/Onboarding/ClaudeKeyStepView.swift`
- Modify: `JobSearchApp/Views/Onboarding/ProfileDetailsStepView.swift`
- Modify: `JobSearchApp/Views/Onboarding/TavilyKeyStepView.swift`

- [ ] **Step 1: Replace OnboardingView.swift with the full migrated version**

```swift
import SwiftUI
import SwiftData

// MARK: - ViewModel

@Observable
@MainActor
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case welcome, name, email, claudeKey, profileDetails, tavilyKey
    }

    var currentStep: Step = .welcome

    // Step 1 — Name
    var firstName = ""
    var lastName = ""

    // Step 2 — Contact
    var email = ""
    var phone = ""
    var location = ""

    // Step 3 — Claude API key
    var claudeKey = ""

    // Step 4 — Profile details
    var currentJobTitle = ""
    var currentCompany = ""
    var skillsText = ""
    var educationInstitution = ""
    var educationDegree = ""
    var educationField = ""

    // Step 5 — Tavily key
    var tavilyKey = ""

    var fullName: String {
        "\(firstName.trimmingCharacters(in: .whitespaces)) \(lastName.trimmingCharacters(in: .whitespaces))"
            .trimmingCharacters(in: .whitespaces)
    }

    var canAdvanceFromName: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var canAdvanceFromEmail: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty &&
        !location.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func advance() {
        guard let next = Step(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    func saveProfile(context: ModelContext, coordinator: OnboardingCoordinator, container: AppContainer) {
        if !claudeKey.trimmingCharacters(in: .whitespaces).isEmpty {
            try? KeychainManager.shared.save(claudeKey, forKey: KeychainKeys.anthropicAPIKey)
        }
        if !tavilyKey.trimmingCharacters(in: .whitespaces).isEmpty {
            try? KeychainManager.shared.save(tavilyKey, forKey: KeychainKeys.tavilyAPIKey)
        }
        container.refreshLLMService()

        let basics = ProfileBasics(
            name: fullName.isEmpty ? firstName : fullName,
            email: email.trimmingCharacters(in: .whitespaces),
            phone: phone.trimmingCharacters(in: .whitespaces).isEmpty ? nil
                   : phone.trimmingCharacters(in: .whitespaces),
            location: location.trimmingCharacters(in: .whitespaces),
            linkedIn: nil, github: nil, website: nil
        )
        let profile = UserProfile(basics: basics)

        let parsedSkills = skillsText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        profile.skills = parsedSkills

        context.insert(profile)

        if !currentJobTitle.trimmingCharacters(in: .whitespaces).isEmpty ||
           !currentCompany.trimmingCharacters(in: .whitespaces).isEmpty {
            let exp = WorkExperience(
                company: currentCompany.trimmingCharacters(in: .whitespaces).isEmpty
                    ? "Unknown" : currentCompany.trimmingCharacters(in: .whitespaces),
                title: currentJobTitle.trimmingCharacters(in: .whitespaces).isEmpty
                    ? "Unknown" : currentJobTitle.trimmingCharacters(in: .whitespaces),
                startDate: Date(),
                isCurrent: true
            )
            exp.profile = profile
            profile.workHistory.append(exp)
            context.insert(exp)
        }

        if !educationInstitution.trimmingCharacters(in: .whitespaces).isEmpty {
            let edu = Education(
                institution: educationInstitution.trimmingCharacters(in: .whitespaces),
                degree: educationDegree.trimmingCharacters(in: .whitespaces).isEmpty
                    ? "Degree" : educationDegree.trimmingCharacters(in: .whitespaces),
                field: educationField.trimmingCharacters(in: .whitespaces).isEmpty
                    ? "Unknown" : educationField.trimmingCharacters(in: .whitespaces)
            )
            edu.profile = profile
            profile.education.append(edu)
            context.insert(edu)
        }

        try? context.save()
        coordinator.completeOnboarding()
    }
}

// MARK: - View

struct OnboardingView: View {
    @State private var vm = OnboardingViewModel()
    @Environment(OnboardingCoordinator.self) private var coordinator
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext

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
        case .name:
            NameStepView(vm: vm)
        case .email:
            EmailStepView(vm: vm)
        case .claudeKey:
            ClaudeKeyStepView(vm: vm)
        case .profileDetails:
            ProfileDetailsStepView(vm: vm)
        case .tavilyKey:
            TavilyKeyStepView(vm: vm) {
                vm.saveProfile(context: modelContext, coordinator: coordinator, container: container)
            }
        }
    }
}
```

- [ ] **Step 2: Update NameStepView.swift — @ObservedObject → @Bindable**

```swift
import SwiftUI

struct NameStepView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                StepHeader(
                    step: "Step 1 of 5",
                    title: "What's your name?",
                    prompt: "We'll use this on your resume and cover letters."
                )

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("First Name").font(.caption.bold()).foregroundStyle(.secondary)
                        TextField("Jane", text: $vm.firstName)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.givenName)
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Name").font(.caption.bold()).foregroundStyle(.secondary)
                        TextField("Doe", text: $vm.lastName)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.familyName)
                            .autocorrectionDisabled()
                    }
                }

                Button("Next") { vm.advance() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(!vm.canAdvanceFromName)
            }
            .padding()
        }
        .navigationTitle("Your Name")
        .navigationBarBackButtonHidden(true)
    }
}
```

- [ ] **Step 3: Update EmailStepView.swift — @ObservedObject → @Bindable**

```swift
import SwiftUI

struct EmailStepView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                StepHeader(
                    step: "Step 2 of 5",
                    title: "Contact Info",
                    prompt: "Your email and location appear on your resume. Phone is optional."
                )

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Email").font(.caption.bold()).foregroundStyle(.secondary)
                        TextField("jane@example.com", text: $vm.email)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location").font(.caption.bold()).foregroundStyle(.secondary)
                        TextField("Toronto, ON", text: $vm.location)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Phone (optional)").font(.caption.bold()).foregroundStyle(.secondary)
                        TextField("+1 416 555 0100", text: $vm.phone)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)
                    }
                }

                Button("Next") { vm.advance() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(!vm.canAdvanceFromEmail)
            }
            .padding()
        }
        .navigationTitle("Contact Info")
        .navigationBarBackButtonHidden(true)
    }
}
```

- [ ] **Step 4: Update ClaudeKeyStepView.swift — @ObservedObject → @Bindable**

```swift
import SwiftUI

struct ClaudeKeyStepView: View {
    @Bindable var vm: OnboardingViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                StepHeader(
                    step: "Step 3 of 5",
                    title: "Connect Claude AI",
                    prompt: "Claude writes your resumes and cover letters. Add your API key to enable AI-powered document generation."
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Claude API Key").font(.caption.bold()).foregroundStyle(.secondary)
                    SecureField("sk-ant-...", text: $vm.claudeKey)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button {
                        openURL(URL(string: "https://console.anthropic.com/keys")!)
                    } label: {
                        Label("Get a key at console.anthropic.com", systemImage: "arrow.up.right.square")
                            .font(.caption)
                    }
                }

                VStack(spacing: 12) {
                    Button("Next") { vm.advance() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .disabled(vm.claudeKey.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button("Skip for now") { vm.advance() }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .navigationTitle("AI Setup")
        .navigationBarBackButtonHidden(true)
    }
}
```

- [ ] **Step 5: Update ProfileDetailsStepView.swift — @ObservedObject → @Bindable**

```swift
import SwiftUI

struct ProfileDetailsStepView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                StepHeader(
                    step: "Step 4 of 5",
                    title: "Your Background",
                    prompt: "Add the basics now. You can fill in work history, education, and projects in full from the Profile tab."
                )

                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Role").font(.subheadline.bold())

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Job Title").font(.caption.bold()).foregroundStyle(.secondary)
                            TextField("iOS Engineer", text: $vm.currentJobTitle)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Company").font(.caption.bold()).foregroundStyle(.secondary)
                            TextField("Acme Corp", text: $vm.currentCompany)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Key Skills").font(.subheadline.bold())
                        Text("Separate with commas").font(.caption).foregroundStyle(.secondary)
                        TextField("Swift, SwiftUI, Python, Git", text: $vm.skillsText)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Education").font(.subheadline.bold())

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Institution").font(.caption.bold()).foregroundStyle(.secondary)
                            TextField("University of Toronto", text: $vm.educationInstitution)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Degree").font(.caption.bold()).foregroundStyle(.secondary)
                                TextField("Bachelor", text: $vm.educationDegree)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Field").font(.caption.bold()).foregroundStyle(.secondary)
                                TextField("Computer Science", text: $vm.educationField)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                            }
                        }
                    }
                }

                Button("Next") { vm.advance() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                Button("Skip for now") { vm.advance() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .navigationTitle("Profile Basics")
        .navigationBarBackButtonHidden(true)
    }
}
```

- [ ] **Step 6: Update TavilyKeyStepView.swift — @ObservedObject → @Bindable**

```swift
import SwiftUI

struct TavilyKeyStepView: View {
    @Bindable var vm: OnboardingViewModel
    let onFinish: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                StepHeader(
                    step: "Step 5 of 5",
                    title: "AI Job Search",
                    prompt: "Tavily finds job postings from across the web. Add your API key to search for jobs directly in the app."
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tavily API Key").font(.caption.bold()).foregroundStyle(.secondary)
                    SecureField("tvly-...", text: $vm.tavilyKey)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button {
                        openURL(URL(string: "https://app.tavily.com/home")!)
                    } label: {
                        Label("Get a free key at tavily.com", systemImage: "arrow.up.right.square")
                            .font(.caption)
                    }
                }

                VStack(spacing: 12) {
                    Button("Finish & Start Job Searching") {
                        onFinish()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                    Button("Skip for now") {
                        onFinish()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .navigationTitle("Job Search")
        .navigationBarBackButtonHidden(true)
    }
}
```

- [ ] **Step 7: Build and run all tests**

```bash
xcodebuild test \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|FAILED|passed|failed|Test Suite"
```

Expected: All 40 tests pass, `BUILD SUCCEEDED`.

- [ ] **Step 8: Commit**

```bash
git add JobSearchApp/Views/Onboarding/OnboardingView.swift \
        JobSearchApp/Views/Onboarding/NameStepView.swift \
        JobSearchApp/Views/Onboarding/EmailStepView.swift \
        JobSearchApp/Views/Onboarding/ClaudeKeyStepView.swift \
        JobSearchApp/Views/Onboarding/ProfileDetailsStepView.swift \
        JobSearchApp/Views/Onboarding/TavilyKeyStepView.swift
git commit -m "refactor: migrate OnboardingViewModel to @Observable, step views to @Bindable"
```

---

## Task 4: Migrate JobSearchViewModel to @Observable

**Files:**
- Modify: `JobSearchApp/ViewModels/JobSearchViewModel.swift`
- Modify: `JobSearchApp/Views/Discover/DiscoverView.swift`

- [ ] **Step 1: Replace JobSearchViewModel.swift**

```swift
import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class JobSearchViewModel {
    var isSearching = false
    var progress: String?
    var errorMessage: String?

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

- [ ] **Step 2: Update DiscoverView.swift — @StateObject → @State**

Change line 12 only:
```swift
// Before:
@StateObject private var searchVM = JobSearchViewModel()

// After:
@State private var searchVM = JobSearchViewModel()
```

- [ ] **Step 3: Build and run all tests**

```bash
xcodebuild test \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|FAILED|passed|failed|Test Suite"
```

Expected: All 40 tests pass, `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
git add JobSearchApp/ViewModels/JobSearchViewModel.swift \
        JobSearchApp/Views/Discover/DiscoverView.swift
git commit -m "refactor: migrate JobSearchViewModel to @Observable"
```

---

## Task 5: Migrate SettingsViewModel and ProfileViewModel to @Observable

**Files:**
- Modify: `JobSearchApp/Views/Settings/SettingsViewModel.swift`
- Modify: `JobSearchApp/Views/Settings/SettingsView.swift`
- Modify: `JobSearchApp/Views/Profile/ProfileViewModel.swift`
- Modify: `JobSearchApp/Views/Profile/ProfileView.swift`

- [ ] **Step 1: Replace SettingsViewModel.swift**

```swift
import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    var anthropicKey: String = ""
    var tavilyKey: String = ""
    var defaultExportFormat: ExportFormat = .pdf
    var saveMessage: String?

    enum ExportFormat: String, CaseIterable, Identifiable {
        case pdf = "PDF"
        case docx = "DOCX"
        case both = "Both"
        var id: String { rawValue }
    }

    func loadKeys() {
        anthropicKey = (try? KeychainManager.shared.retrieve(forKey: KeychainKeys.anthropicAPIKey)) ?? ""
        tavilyKey    = (try? KeychainManager.shared.retrieve(forKey: KeychainKeys.tavilyAPIKey)) ?? ""
        let raw = UserDefaults.standard.string(forKey: "exportFormat") ?? ExportFormat.pdf.rawValue
        defaultExportFormat = ExportFormat(rawValue: raw) ?? .pdf
    }

    func saveKeys(container: AppContainer) {
        do {
            try KeychainManager.shared.save(anthropicKey, forKey: KeychainKeys.anthropicAPIKey)
            try KeychainManager.shared.save(tavilyKey,    forKey: KeychainKeys.tavilyAPIKey)
            UserDefaults.standard.set(defaultExportFormat.rawValue, forKey: "exportFormat")
            container.refreshLLMService()
            saveMessage = "Saved"
        } catch {
            saveMessage = "Error: \(error.localizedDescription)"
        }
    }
}
```

**What changed:** Removed `import Combine`, removed `ObservableObject` conformance, removed all `@Published` prefixes, replaced `private let keychain = KeychainManager.shared` property with direct `KeychainManager.shared` calls.

- [ ] **Step 2: Update SettingsView.swift — @StateObject → @State**

Change line 5 only:
```swift
// Before:
@StateObject private var viewModel = SettingsViewModel()

// After:
@State private var viewModel = SettingsViewModel()
```

The `@Environment(AppContainer.self) private var container` line is already correct from Task 1. No other changes needed. `$viewModel.anthropicKey` bindings continue to work because `@State` with an `@Observable` object provides bindings directly.

- [ ] **Step 3: Replace ProfileViewModel.swift**

```swift
import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class ProfileViewModel {
    var profile: UserProfile?

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

- [ ] **Step 4: Update ProfileView.swift — @StateObject → @State**

Change line 5 only:
```swift
// Before:
@StateObject private var vm = ProfileViewModel()

// After:
@State private var vm = ProfileViewModel()
```

- [ ] **Step 5: Build and run all tests**

```bash
xcodebuild test \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|FAILED|passed|failed|Test Suite"
```

Expected: All 40 tests pass, `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit**

```bash
git add JobSearchApp/Views/Settings/SettingsViewModel.swift \
        JobSearchApp/Views/Settings/SettingsView.swift \
        JobSearchApp/Views/Profile/ProfileViewModel.swift \
        JobSearchApp/Views/Profile/ProfileView.swift
git commit -m "refactor: migrate SettingsViewModel and ProfileViewModel to @Observable"
```

---

## Task 6: Fix clipShape + Tab API with iOS 18 Gating

**Files:**
- Modify: `JobSearchApp/Views/Discover/JobDetailView.swift`
- Modify: `JobSearchApp/Views/Onboarding/WelcomeView.swift`
- Modify: `JobSearchApp/Views/Navigation/MainTabView.swift`

- [ ] **Step 1: Fix JobDetailView.swift — deprecated clipShape**

In `JobDetailView.swift`, find the priority badge block and change:
```swift
// Before:
.clipShape(RoundedRectangle(cornerRadius: 10))

// After:
.clipShape(.rect(cornerRadius: 10))
```

- [ ] **Step 2: Fix WelcomeView.swift — deprecated clipShape**

In `WelcomeView.swift`, find the button styling and change:
```swift
// Before:
.clipShape(RoundedRectangle(cornerRadius: 14))

// After:
.clipShape(.rect(cornerRadius: 14))
```

- [ ] **Step 3: Replace MainTabView.swift with iOS 18 Tab API + fallback**

The deployment target is iOS 17. The `Tab` API requires iOS 18. Use `#available` to adopt it on iOS 18+ while keeping `tabItem` as the iOS 17 fallback. Both branches must list all four tabs.

```swift
import SwiftUI

struct MainTabView: View {
    var body: some View {
        if #available(iOS 18, *) {
            TabView {
                Tab("Discover", systemImage: "magnifyingglass") {
                    DiscoverView()
                }
                Tab("Applications", systemImage: "briefcase") {
                    ApplicationsView()
                }
                Tab("Documents", systemImage: "doc.text") {
                    DocumentsView()
                }
                Tab("Profile", systemImage: "person.circle") {
                    ProfileView()
                }
            }
        } else {
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
}
```

- [ ] **Step 4: Build and run all tests**

```bash
xcodebuild test \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|FAILED|passed|failed|Test Suite"
```

Expected: All 40 tests pass, `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
git add JobSearchApp/Views/Discover/JobDetailView.swift \
        JobSearchApp/Views/Onboarding/WelcomeView.swift \
        JobSearchApp/Views/Navigation/MainTabView.swift
git commit -m "refactor: fix deprecated clipShape calls and add iOS 18 Tab API with fallback"
```

---

## Self-Review Checklist

**Spec coverage:**
- [x] `AppContainer` migrated to `@Observable` — Task 1
- [x] `OnboardingCoordinator` migrated to `@Observable` — Task 2
- [x] `OnboardingViewModel` migrated to `@Observable` — Task 3
- [x] `JobSearchViewModel` migrated to `@Observable` — Task 4
- [x] `SettingsViewModel` migrated to `@Observable` — Task 5
- [x] `ProfileViewModel` migrated to `@Observable` — Task 5
- [x] All `@EnvironmentObject` → `@Environment(Type.self)` — Tasks 1, 2
- [x] All `@StateObject` (owned objects) → `@State` — Tasks 1, 2, 4, 5
- [x] All `@ObservedObject` with bindings → `@Bindable` — Task 3
- [x] `.environmentObject(x)` → `.environment(x)` at injection sites — Tasks 1, 2
- [x] `clipShape(RoundedRectangle(cornerRadius:))` → `clipShape(.rect(cornerRadius:))` — Task 6 (2 occurrences)
- [x] `tabItem` → `Tab` API with `#available(iOS 18, *)` fallback — Task 6

**Placeholder scan:** No TODOs, no "similar to Task N" references. Every step contains actual code.

**Type consistency:**
- `OnboardingViewModel.saveProfile(context:coordinator:container:)` signature is identical in Task 3's updated view and in the step views that call it
- `SettingsViewModel.saveKeys(container:)` keeps the same signature — `SettingsView` calls it with `container` from `@Environment(AppContainer.self)`
- `JobSearchViewModel.search(query:tavilyKey:llmService:profile:context:sessionOverride:)` signature unchanged — `JobSearchViewModelTests` continues to compile because `@Observable` classes are still reference types usable in tests
- `@Bindable var vm: OnboardingViewModel` in step views: all `$vm.property` bindings reference properties that exist on the migrated `@Observable` class
