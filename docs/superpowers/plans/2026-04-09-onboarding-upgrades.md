# Onboarding & Settings Validation Upgrades Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement onboarding validation/formatting (name/email/phone/location), optional-key skip/enter rules, Edit Contact parity, and Settings save-button polish with fading confirmation.

**Architecture:** Add lightweight validators/formatters (pure helpers) reused by onboarding and settings. Keep view models as owners of validation state, emit inline error flags/messages, and gate navigation/submit actions on validity. Use `@Observable` bindings for view updates. No new external deps.

**Tech Stack:** SwiftUI, SwiftData, Keychain, UserDefaults, Swift Testing (`Testing`) where applicable.

---

### Task 1: Shared validation and formatting helpers
**Files:**
- Create/Modify: `JobSearchApp/Utilities/Validation.swift` (new helper file)
- Test: `JobSearchAppTests/ValidationTests.swift` (new)

- [ ] Add helpers:
```swift
struct InputValidator {
    static func sanitizedName(first: String, last: String) -> (first: String, last: String, full: String)
    static func isValidEmail(_ value: String) -> Bool
    static func normalizePhone(_ value: String) -> (display: String, normalized: String)
    static func isValidPhoneDigits(_ digits: String) -> Bool // 7–15 digits
    static func normalizeLocation(_ value: String) -> String // trim + collapse spaces
    static func isValidLocation(_ value: String) -> Bool // non-empty, at least 2 tokens
}
```
- [ ] Tests: cover name trim/collapse, email valid/invalid, phone normalization/length bounds, location validity.
- [ ] Run tests: `xcodebuild test -scheme JobSearchApp -destination "id=87A36A12-A0A6-449E-9FE0-CEBEBD8A5E91"`

### Task 2: Onboarding view model validation state
**Files:**
- Modify: `JobSearchApp/Views/Onboarding/OnboardingView.swift`
- Test: optionally `JobSearchAppTests/OnboardingValidationTests.swift` (new) for view model logic

- [ ] Add stored error flags/messages in `OnboardingViewModel` (e.g., `nameError`, `emailError`, `phoneError`, `locationError`).
- [ ] Update `canAdvanceFromName` / `canAdvanceFromEmail` to use helpers (sanitized full name, email regex, phone digits optional, location validity).
- [ ] Ensure `advance()` only fires when current step valid; Enter/Submit guarded.
- [ ] Run tests (if added) via same xcodebuild command.

### Task 3: Name step UI wiring
**Files:**
- Modify: `JobSearchApp/Views/Onboarding/NameStepView.swift`

- [ ] On change/end editing: sanitize/collapse spaces; clear error when valid.
- [ ] Show inline error text when invalid on submit; disable Next until valid; no Skip.
- [ ] Hook submit/keyboard return to `vm.advance()` only if valid.

### Task 4: Contact step UI wiring (email/phone/location)
**Files:**
- Modify: `JobSearchApp/Views/Onboarding/EmailStepView.swift`

- [ ] Email: trim/lowercase on change; inline error on invalid; disable Next until valid.
- [ ] Phone: apply display formatting (from helper) while storing normalized digits in vm; inline error if present but invalid; allow empty.
- [ ] Location: trim/collapse; inline error if invalid/empty; required.
- [ ] Enter/Next only when valid; no Skip.

### Task 5: Optional key steps (ClaudeKeyStepView, TavilyKeyStepView)
**Files:**
- Modify: `JobSearchApp/Views/Onboarding/ClaudeKeyStepView.swift`
- Modify: `JobSearchApp/Views/Onboarding/TavilyKeyStepView.swift`

- [ ] Trim whitespace on change; enable Next only when non-empty; Enter submits only when valid.
- [ ] Keep Skip button as secondary; ensure Skip not triggered by Enter.

### Task 6: Edit Contact Info parity
**Files:**
- Modify: `JobSearchApp/Views/Profile/EditBasicsView.swift`

- [ ] Apply same validation/sanitization as onboarding (name/email/phone/location).
- [ ] Block Save until valid and fields differ from stored values; show inline errors matching onboarding copy.
- [ ] Normalize before saving (trim/collapse names, lowercase email, normalized phone digits or nil).

### Task 7: Settings save UX polish
**Files:**
- Modify: `JobSearchApp/Views/Settings/SettingsView.swift`
- Modify: `JobSearchApp/Views/Settings/SettingsViewModel.swift`

- [ ] Track initial vs current values; enable Save only when changed.
- [ ] On successful save: show brief green “Saved” notice (e.g., with `withAnimation` + timed reset) and disable button; re-enable on next edit.
- [ ] Ensure divider/spacing intact; no truncated bar.

### Task 8: Integration testing pass
**Files/Commands:**
- [ ] Run full tests: `xcodebuild test -scheme JobSearchApp -destination "id=87A36A12-A0A6-449E-9FE0-CEBEBD8A5E91"`
- [ ] Manual sanity: onboarding flow (required steps block until valid; optional steps skipable; Enter behavior); Edit Contact Save gating; Settings Save state/notification.

### Task 9: Commit and prep PR
**Files:**
- All touched files

- [ ] `git status`
- [ ] `git add ...`
- [ ] `git commit -m "feat: tighten onboarding validation and settings save UX"`
- [ ] If credentials available: `git push -u origin feature/liquid-glass`

---

## Self-Review Checklist
- Validation matches spec (name trim/collapse; email regex; phone normalized+mask; location structured).
- Required steps have no Skip; optional keys keep Skip; Enter only when valid.
- Edit Contact mirrors onboarding rules; Save gating on valid+changed.
- Settings Save enables on change, shows brief green “Saved”, then disables until next edit.
- Tests for helpers cover edge cases; UI behavior validated manually or via view-model tests.
