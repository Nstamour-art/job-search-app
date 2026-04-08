# Onboarding API Keys + Apply Button Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an API-key setup step at the end of onboarding so users can configure Claude + Tavily before they need them, and add an Apply button to JobDetailView that opens the job URL in SFSafariViewController.

**Architecture:** The onboarding `Step` enum gains an `.apiKeys` case inserted between `.theme` and completion; `ThemePickerView` advances to that step instead of finishing; a new `ApiKeysStepView` saves keys to Keychain and then calls `saveProfile`. `SafariView` is a thin `UIViewControllerRepresentable` wrapper shared by `JobDetailView`'s Apply button.

**Tech Stack:** SwiftUI, SafariServices, KeychainManager (already exists), AppContainer (already exists)

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Modify | `JobSearchApp/Views/Onboarding/OnboardingView.swift` | Add `.apiKeys` to `Step` enum and route in `stepContent` |
| Modify | `JobSearchApp/Views/Onboarding/ThemePickerView.swift` | Change "Finish" → `vm.advance()` |
| Create | `JobSearchApp/Views/Onboarding/ApiKeysStepView.swift` | API key form + finish action |
| Create | `JobSearchApp/Views/Shared/SafariView.swift` | SFSafariViewController wrapper |
| Modify | `JobSearchApp/Views/Discover/JobDetailView.swift` | Add Apply button + sheet |

---

## Task 1: Add API Keys Step to Onboarding

**Files:**
- Modify: `JobSearchApp/Views/Onboarding/OnboardingView.swift`
- Modify: `JobSearchApp/Views/Onboarding/ThemePickerView.swift`
- Create: `JobSearchApp/Views/Onboarding/ApiKeysStepView.swift`

- [ ] **Step 1: Add `.apiKeys` to the Step enum in OnboardingView.swift**

Find:
```swift
enum Step: Int, CaseIterable {
    case welcome, basics, workHistory, education, skills, projects, theme
}
```

Replace with:
```swift
enum Step: Int, CaseIterable {
    case welcome, basics, workHistory, education, skills, projects, theme, apiKeys
}
```

Then find:
```swift
case .theme:
    ThemePickerView(vm: vm)
```

Replace with:
```swift
case .theme:
    ThemePickerView(vm: vm)
case .apiKeys:
    ApiKeysStepView(vm: vm)
```

- [ ] **Step 2: Change ThemePickerView's "Finish" button to call `vm.advance()`**

In `JobSearchApp/Views/Onboarding/ThemePickerView.swift`, find:
```swift
Button("Finish & Start Job Searching") {
    vm.saveProfile(context: modelContext, coordinator: coordinator)
}
```

Replace with:
```swift
Button("Next: Connect AI Services") {
    vm.advance()
}
```

Also remove `@Environment(\.modelContext) private var modelContext` and `@EnvironmentObject private var coordinator: OnboardingCoordinator` from `ThemePickerView` since they're no longer used there.

- [ ] **Step 3: Create ApiKeysStepView.swift**

```swift
import SwiftUI

struct ApiKeysStepView: View {
    @ObservedObject var vm: OnboardingViewModel
    @EnvironmentObject private var coordinator: OnboardingCoordinator
    @EnvironmentObject private var container: AppContainer
    @Environment(\.modelContext) private var modelContext

    @State private var anthropicKey = ""
    @State private var tavilyKey = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                StepHeader(
                    step: "Step 8 of 8",
                    title: "Connect AI Services",
                    prompt: "Add your API keys to enable document generation and job discovery. You can update these any time in Settings."
                )

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Claude API Key").font(.caption.bold()).foregroundStyle(.secondary)
                        SecureField("sk-ant-...", text: $anthropicKey)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        Text("Required for document generation. Get yours at console.anthropic.com")
                            .font(.caption2).foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tavily API Key").font(.caption.bold()).foregroundStyle(.secondary)
                        SecureField("tvly-...", text: $tavilyKey)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        Text("Optional — enables AI job search. Get yours at tavily.com")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 12) {
                    Button("Finish & Start Job Searching") {
                        saveAndFinish()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                    Button("Skip for now") {
                        vm.saveProfile(context: modelContext, coordinator: coordinator)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .navigationTitle("API Keys")
        .navigationBarBackButtonHidden(true)
    }

    private func saveAndFinish() {
        if !anthropicKey.trimmingCharacters(in: .whitespaces).isEmpty {
            try? KeychainManager.shared.save(anthropicKey, forKey: KeychainKeys.anthropicAPIKey)
        }
        if !tavilyKey.trimmingCharacters(in: .whitespaces).isEmpty {
            try? KeychainManager.shared.save(tavilyKey, forKey: KeychainKeys.tavilyAPIKey)
        }
        container.refreshLLMService()
        vm.saveProfile(context: modelContext, coordinator: coordinator)
    }
}
```

- [ ] **Step 4: Run xcodegen and build**

```bash
cd /Users/nstamour/Documents/GitHub/job-search-app && xcodegen generate && xcodebuild build \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git add JobSearchApp/Views/Onboarding/OnboardingView.swift \
        JobSearchApp/Views/Onboarding/ThemePickerView.swift \
        JobSearchApp/Views/Onboarding/ApiKeysStepView.swift
git commit -m "feat: add API key setup step to onboarding flow"
```

---

## Task 2: Apply Button (SFSafariViewController)

**Files:**
- Create: `JobSearchApp/Views/Shared/SafariView.swift`
- Modify: `JobSearchApp/Views/Discover/JobDetailView.swift`

- [ ] **Step 1: Create SafariView.swift**

```swift
import SwiftUI
import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
```

- [ ] **Step 2: Add Apply button to JobDetailView**

The current `JobDetailView` has `@State private var showGenerateDocs = false`. Add an `applyURL` state property and the Apply button.

In `JobDetailView.swift`, add this state property alongside the existing one:
```swift
@State private var showGenerateDocs = false
@State private var applyItem: ApplyItem?

// Add this nested type at the bottom of the file (outside the struct, at file scope):
private struct ApplyItem: Identifiable {
    let id = UUID()
    let url: URL
}
```

In the `body`, after the "Generate Documents" button block, add the Apply button. It should only appear when `job.url` is a valid URL:

```swift
// Generate documents
Button("Generate Documents") { showGenerateDocs = true }
    .buttonStyle(.bordered)
    .frame(maxWidth: .infinity)

// Apply button — only shown when the posting has a URL
if let url = URL(string: job.url), !job.url.isEmpty {
    Button("Apply") { applyItem = ApplyItem(url: url) }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: .infinity)
}
```

Add the sheet modifier alongside the existing one (chain after the `showGenerateDocs` sheet):
```swift
.sheet(isPresented: $showGenerateDocs) {
    GenerateDocumentsView(job: job)
}
.sheet(item: $applyItem) { item in
    SafariView(url: item.url)
}
```

Note: `ApplyItem` lives at file scope (below the closing brace of `JobDetailView`) since `Identifiable` conformance on a `private struct` inside the view causes issues with `sheet(item:)` in some Xcode versions.

- [ ] **Step 3: Run xcodegen and build**

```bash
cd /Users/nstamour/Documents/GitHub/job-search-app && xcodegen generate && xcodebuild build \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Run all tests to confirm no regressions**

```bash
xcodebuild test \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|FAILED|passed|failed|Test Suite"
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add JobSearchApp/Views/Shared/SafariView.swift \
        JobSearchApp/Views/Discover/JobDetailView.swift
git commit -m "feat: Apply button with SFSafariViewController in JobDetailView"
```

---

## Self-Review Checklist

**Spec coverage:**
- [x] API key step added between theme picker and profile save — Task 1
- [x] Anthropic key saved to Keychain before `refreshLLMService()` is called — Task 1
- [x] Tavily key saved to Keychain — Task 1
- [x] "Skip for now" still completes onboarding without keys — Task 1
- [x] `navigationBarBackButtonHidden(true)` on ApiKeysStepView (prevents going back after theme) — Task 1
- [x] Apply button only shows when `job.url` is non-empty and a valid URL — Task 2
- [x] `.sheet(item: $applyItem)` pattern — no `if let` inside sheet body — Task 2
- [x] `SafariView` uses SFSafariViewController — Task 2

**Type consistency:**
- `vm.advance()` in ThemePickerView increments `Step.theme.rawValue` (= 6) → `Step.apiKeys.rawValue` (= 7). Confirmed by enum ordering.
- `vm.saveProfile(context:coordinator:)` in ApiKeysStepView uses same signature as before in ThemePickerView.
