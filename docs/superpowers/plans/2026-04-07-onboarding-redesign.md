# Onboarding Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the LLM-dependent onboarding flow (which can't proceed without a Claude key) with a simple, sequential form-based flow: Welcome → Name → Email → Claude API Key → Profile Details → Tavily API Key. No LLM is required at any point.

**Architecture:** `OnboardingView.swift` is rewritten with a new `OnboardingViewModel` that holds plain text state (no parse service, no async LLM calls). Each step is a focused single-screen form view. The 5 old LLM-powered step views are deleted. `saveProfile()` builds the SwiftData objects directly from form values. `JobSearchApp.swift` is updated since `OnboardingView` no longer takes a `llmService` parameter.

**Tech Stack:** SwiftUI, SwiftData, KeychainManager (existing), `@Environment(\.openURL)` for the Tavily browser link

**Supersedes:** The onboarding portion of `2026-04-07-onboarding-apply.md` (the `ApiKeysStepView` task). The Apply button task in that plan is still valid and unaffected.

---

## New Onboarding Flow

| Step | View | Content |
|------|------|---------|
| — | `WelcomeView` | Existing splash screen, unchanged |
| 1 of 5 | `NameStepView` | First name + Last name TextFields |
| 2 of 5 | `EmailStepView` | Email + Phone (optional) + Location TextFields |
| 3 of 5 | `ClaudeKeyStepView` | Claude API key SecureField + link to console.anthropic.com |
| 4 of 5 | `ProfileDetailsStepView` | Current job title, company, comma-separated skills, education basics |
| 5 of 5 | `TavilyKeyStepView` | Tavily API key SecureField + "Get a free key" browser button |

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Modify | `JobSearchApp/Views/Onboarding/OnboardingView.swift` | Rewrite ViewModel + View + Step enum |
| Create | `JobSearchApp/Views/Onboarding/NameStepView.swift` | Step 1: first + last name |
| Create | `JobSearchApp/Views/Onboarding/EmailStepView.swift` | Step 2: email, phone, location |
| Create | `JobSearchApp/Views/Onboarding/ClaudeKeyStepView.swift` | Step 3: Claude API key |
| Create | `JobSearchApp/Views/Onboarding/ProfileDetailsStepView.swift` | Step 4: role, skills, education |
| Create | `JobSearchApp/Views/Onboarding/TavilyKeyStepView.swift` | Step 5: Tavily key + browser button |
| Delete | `JobSearchApp/Views/Onboarding/BasicsStepView.swift` | Replaced |
| Delete | `JobSearchApp/Views/Onboarding/WorkHistoryStepView.swift` | Replaced |
| Delete | `JobSearchApp/Views/Onboarding/EducationStepView.swift` | Replaced |
| Delete | `JobSearchApp/Views/Onboarding/SkillsStepView.swift` | Replaced |
| Delete | `JobSearchApp/Views/Onboarding/ProjectsStepView.swift` | Replaced |
| Delete | `JobSearchApp/Views/Onboarding/ThemePickerView.swift` | Removed from onboarding (theme is set in Settings) |
| Modify | `JobSearchApp/App/JobSearchApp.swift` | Remove `llmService:` from `OnboardingView` init |

**Note on `ProfileParseService`:** It is no longer called from onboarding but is still tested in isolation by `ProfileParseServiceTests`. Leave `ProfileParseService.swift` and its tests untouched — they will still compile and pass.

---

## Task 1: Rewrite OnboardingView.swift + delete old step views

**Files:**
- Modify: `JobSearchApp/Views/Onboarding/OnboardingView.swift`
- Delete: `BasicsStepView.swift`, `WorkHistoryStepView.swift`, `EducationStepView.swift`, `SkillsStepView.swift`, `ProjectsStepView.swift`, `ThemePickerView.swift`
- Modify: `JobSearchApp/App/JobSearchApp.swift`

- [ ] **Step 1: Delete the old step views**

```bash
cd /Users/nstamour/Documents/GitHub/job-search-app && \
  rm JobSearchApp/Views/Onboarding/BasicsStepView.swift \
     JobSearchApp/Views/Onboarding/WorkHistoryStepView.swift \
     JobSearchApp/Views/Onboarding/EducationStepView.swift \
     JobSearchApp/Views/Onboarding/SkillsStepView.swift \
     JobSearchApp/Views/Onboarding/ProjectsStepView.swift \
     JobSearchApp/Views/Onboarding/ThemePickerView.swift
```

- [ ] **Step 2: Rewrite OnboardingView.swift**

Replace the entire file with:

```swift
import SwiftUI
import SwiftData

// MARK: - ViewModel

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case welcome, name, email, claudeKey, profileDetails, tavilyKey
    }

    @Published var currentStep: Step = .welcome

    // Step 1 — Name
    @Published var firstName = ""
    @Published var lastName = ""

    // Step 2 — Email
    @Published var email = ""
    @Published var phone = ""
    @Published var location = ""

    // Step 3 — Claude API key
    @Published var claudeKey = ""

    // Step 4 — Profile details
    @Published var currentJobTitle = ""
    @Published var currentCompany = ""
    @Published var skillsText = ""          // comma-separated, split on save
    @Published var educationInstitution = ""
    @Published var educationDegree = ""
    @Published var educationField = ""

    // Step 5 — Tavily key
    @Published var tavilyKey = ""

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
        // Persist API keys
        if !claudeKey.trimmingCharacters(in: .whitespaces).isEmpty {
            try? KeychainManager.shared.save(claudeKey, forKey: KeychainKeys.anthropicAPIKey)
        }
        if !tavilyKey.trimmingCharacters(in: .whitespaces).isEmpty {
            try? KeychainManager.shared.save(tavilyKey, forKey: KeychainKeys.tavilyAPIKey)
        }
        container.refreshLLMService()

        // Build profile
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
    @StateObject private var vm = OnboardingViewModel()
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    @EnvironmentObject private var container: AppContainer
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

- [ ] **Step 3: Update JobSearchApp.swift**

In `JobSearchApp/App/JobSearchApp.swift`, find:

```swift
OnboardingView(llmService: container.llmService)
    .environmentObject(container)
    .environmentObject(onboardingCoordinator)
```

Replace with:

```swift
OnboardingView()
    .environmentObject(container)
    .environmentObject(onboardingCoordinator)
```

- [ ] **Step 4: Run xcodegen (to pick up deleted files) and attempt to build**

```bash
cd /Users/nstamour/Documents/GitHub/job-search-app && xcodegen generate && xcodebuild build \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: compile errors because the new step views (`NameStepView`, etc.) don't exist yet. That is fine — proceed to Task 2.

- [ ] **Step 5: Commit the skeleton**

```bash
git add JobSearchApp/Views/Onboarding/OnboardingView.swift \
        JobSearchApp/App/JobSearchApp.swift
git rm JobSearchApp/Views/Onboarding/BasicsStepView.swift \
       JobSearchApp/Views/Onboarding/WorkHistoryStepView.swift \
       JobSearchApp/Views/Onboarding/EducationStepView.swift \
       JobSearchApp/Views/Onboarding/SkillsStepView.swift \
       JobSearchApp/Views/Onboarding/ProjectsStepView.swift \
       JobSearchApp/Views/Onboarding/ThemePickerView.swift
git commit -m "refactor: replace LLM-dependent onboarding steps with form-based flow skeleton"
```

---

## Task 2: NameStepView + EmailStepView

**Files:**
- Create: `JobSearchApp/Views/Onboarding/NameStepView.swift`
- Create: `JobSearchApp/Views/Onboarding/EmailStepView.swift`

- [ ] **Step 1: Create NameStepView.swift**

```swift
import SwiftUI

struct NameStepView: View {
    @ObservedObject var vm: OnboardingViewModel

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

- [ ] **Step 2: Create EmailStepView.swift**

```swift
import SwiftUI

struct EmailStepView: View {
    @ObservedObject var vm: OnboardingViewModel

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
                            .textContentType(.addressCity)
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

- [ ] **Step 3: Run xcodegen and build**

```bash
cd /Users/nstamour/Documents/GitHub/job-search-app && xcodegen generate && xcodebuild build \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: still compile errors for missing `ClaudeKeyStepView`, `ProfileDetailsStepView`, `TavilyKeyStepView`. Fine — continue.

- [ ] **Step 4: Commit**

```bash
git add JobSearchApp/Views/Onboarding/NameStepView.swift \
        JobSearchApp/Views/Onboarding/EmailStepView.swift
git commit -m "feat: NameStepView and EmailStepView for redesigned onboarding"
```

---

## Task 3: ClaudeKeyStepView

**Files:**
- Create: `JobSearchApp/Views/Onboarding/ClaudeKeyStepView.swift`

- [ ] **Step 1: Create ClaudeKeyStepView.swift**

```swift
import SwiftUI

struct ClaudeKeyStepView: View {
    @ObservedObject var vm: OnboardingViewModel
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

- [ ] **Step 2: Run xcodegen and build**

```bash
cd /Users/nstamour/Documents/GitHub/job-search-app && xcodegen generate && xcodebuild build \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: still compile errors for missing views. Fine — continue.

- [ ] **Step 3: Commit**

```bash
git add JobSearchApp/Views/Onboarding/ClaudeKeyStepView.swift
git commit -m "feat: ClaudeKeyStepView with API key entry and link to console.anthropic.com"
```

---

## Task 4: ProfileDetailsStepView

**Files:**
- Create: `JobSearchApp/Views/Onboarding/ProfileDetailsStepView.swift`

This step collects the basics of the user's professional profile. All fields are optional — they can fill in more detail via the Profile tab later.

- [ ] **Step 1: Create ProfileDetailsStepView.swift**

```swift
import SwiftUI

struct ProfileDetailsStepView: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                StepHeader(
                    step: "Step 4 of 5",
                    title: "Your Background",
                    prompt: "Add the basics now. You can fill in work history, education, and projects in full from the Profile tab."
                )

                VStack(alignment: .leading, spacing: 20) {
                    // Current role
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

                    // Skills
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Key Skills").font(.subheadline.bold())
                        Text("Separate with commas").font(.caption).foregroundStyle(.secondary)
                        TextField("Swift, SwiftUI, Python, Git", text: $vm.skillsText)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                    }

                    Divider()

                    // Education
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

- [ ] **Step 2: Run xcodegen and build**

```bash
cd /Users/nstamour/Documents/GitHub/job-search-app && xcodegen generate && xcodebuild build \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: one compile error remaining — `TavilyKeyStepView`. Fine — one more step.

- [ ] **Step 3: Commit**

```bash
git add JobSearchApp/Views/Onboarding/ProfileDetailsStepView.swift
git commit -m "feat: ProfileDetailsStepView for role, skills, and education basics"
```

---

## Task 5: TavilyKeyStepView + full build + tests

**Files:**
- Create: `JobSearchApp/Views/Onboarding/TavilyKeyStepView.swift`

This is the final onboarding step. It presents the Tavily API key field, a button that opens the Tavily website in the system browser (using `@Environment(\.openURL)`), and the "Finish" action.

- [ ] **Step 1: Create TavilyKeyStepView.swift**

```swift
import SwiftUI

struct TavilyKeyStepView: View {
    @ObservedObject var vm: OnboardingViewModel
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

**Why `onFinish: () -> Void`?** `TavilyKeyStepView` is the terminal step and needs to call `vm.saveProfile(context:coordinator:container:)` which requires environment values only the parent has. Passing a closure is cleaner than threading three environment values through the step view.

- [ ] **Step 2: Run xcodegen and verify full build succeeds**

```bash
cd /Users/nstamour/Documents/GitHub/job-search-app && xcodegen generate && xcodebuild build \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Run all tests**

```bash
xcodebuild test \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|FAILED|passed|failed|Test Suite"
```

Expected: All tests pass. `ProfileParseServiceTests` still passes (the service is untouched). `OnboardingCoordinator`-related tests still pass.

- [ ] **Step 4: Commit**

```bash
git add JobSearchApp/Views/Onboarding/TavilyKeyStepView.swift
git commit -m "feat: TavilyKeyStepView with API key entry and Tavily browser link"
```

---

## Self-Review Checklist

**Spec coverage:**
- [x] Name step: first name + last name TextFields — Task 2
- [x] Email step: email (required) + location (required) + phone (optional) — Task 2
- [x] Claude API key step: SecureField + `openURL` link to console.anthropic.com — Task 3
- [x] "Skip for now" on Claude key step — Task 3
- [x] Profile details step: current job title + company + comma-separated skills + education basics — Task 4
- [x] "Skip for now" on profile details step — Task 4
- [x] Tavily key step: SecureField + `openURL` button opening app.tavily.com in system browser — Task 5
- [x] "Skip for now" on Tavily step also calls `onFinish()` — Task 5
- [x] `saveProfile()` saves both API keys to Keychain and calls `container.refreshLLMService()` — Task 1
- [x] `saveProfile()` builds `UserProfile`, optional `WorkExperience`, optional `Education` — Task 1
- [x] `navigationBarBackButtonHidden(true)` on all step views — prevents going backwards — Tasks 2–5
- [x] Old LLM-powered step views deleted — Task 1
- [x] `OnboardingView.init()` takes no parameters — Task 1
- [x] `JobSearchApp.swift` updated — Task 1

**SwiftUI patterns:**
- `@Environment(\.openURL)` used for external links — correct iOS 14+ pattern; avoids `UIApplication.shared.open()` UIKit coupling
- `onFinish: () -> Void` closure on `TavilyKeyStepView` — avoids threading environment values through step view
- `canAdvanceFromName` and `canAdvanceFromEmail` guard button enabled state — input validation at the right layer (VM)
- `navigationBarBackButtonHidden(true)` on all step views — sequential onboarding should not allow back navigation

**Type consistency:**
- `vm.saveProfile(context:coordinator:container:)` signature used in `OnboardingView.stepContent` for `.tavilyKey` case
- `skills` parsed from comma-separated `skillsText` in `saveProfile()` — consistent with `UserProfile.skills: [String]`
- `WorkExperience(company:title:startDate:isCurrent:)` — matches the model's init with defaults for `endDate` and `bullets`
