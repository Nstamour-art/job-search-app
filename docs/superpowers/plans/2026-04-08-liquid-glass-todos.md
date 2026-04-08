# Liquid Glass TODOs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the full Liquid Glass overhaul per spec, completing all TODOs with cohesive glass treatments and availability-gated fallbacks.

**Architecture:** Introduce small view-scoped helpers that choose glass vs fallback styles (rect radius 12–14, capsule chips) so logic is testable without UI introspection. Use `GlassEffectContainer` where multiple elements coexist. Keep action buttons non-glass. Gate everything with `#available(iOS 26, *)`.

**Tech Stack:** SwiftUI (iOS), SwiftData, Swift Testing (`Testing`), swift-testing-expert skill for test design.

---

## Task 1: JobDetailView glass surfaces
**Files:**
- Modify: `JobSearchApp/Views/Discover/JobDetailView.swift`
- Create: `JobSearchAppTests/LiquidGlassJobDetailTests.swift`

- [ ] **Step 1: Add testable style helper and failing test (iOS 26 / fallback)**
```swift
// JobDetailView.swift (add near top-level helpers)
enum PriorityCardStyle: Equatable {
    case glass(cornerRadius: CGFloat)
    case material(Material, cornerRadius: CGFloat)
}

func priorityCardStyle() -> PriorityCardStyle {
    if #available(iOS 26, *) {
        .glass(cornerRadius: 12)
    } else {
        .material(.ultraThinMaterial, cornerRadius: 12)
    }
}
```
```swift
// JobSearchAppTests/LiquidGlassJobDetailTests.swift
import Testing
@testable import JobSearchApp

struct LiquidGlassJobDetailTests {
    @Test("priorityCardStyle uses glass on iOS 26", traits: .disabled(unless: #available(iOS 26, *)))
    func priorityCardUsesGlassOn26() throws {
        if #available(iOS 26, *) {
            #expect(priorityCardStyle() == .glass(cornerRadius: 12))
        }
    }

    @Test("priorityCardStyle keeps material fallback pre-26", traits: .disabled(if: #available(iOS 26, *)))
    func priorityCardUsesMaterialFallback() throws {
        #expect(priorityCardStyle() == .material(.ultraThinMaterial, cornerRadius: 12))
    }
}
```
- [ ] **Step 2: Run tests to see failures (glass test will fail until implementation uses helper)**
Run: `xcodebuild test -scheme JobSearchApp -destination "platform=iOS Simulator,name=iPhone 15"`  
Expected: Test `priorityCardUsesGlassOn26` fails (style helper exists but view not wired), fallback test passes.

- [ ] **Step 3: Implement glass treatment with GlassEffectContainer**
```swift
// Inside body, wrap header + priority in GlassEffectContainer and apply helper
GlassEffectContainer(spacing: 12) {
    VStack(alignment: .leading, spacing: 6) { ...header texts... }
        .applyPriorityHeaderGlass()

    HStack(spacing: 10) { ...priority content... }
        .padding()
        .applyPriorityCardGlass()
}
```
```swift
// Add view helpers in JobDetailView.swift
@ViewBuilder
private func applyPriorityHeaderGlass<Content: View>(_ content: Content) -> some View {
    if #available(iOS 26, *) {
        content.glassEffect(.regular, in: .rect(cornerRadius: 14))
    } else {
        content
    }
}

@ViewBuilder
private func applyPriorityCardGlass<Content: View>(_ content: Content) -> some View {
    switch priorityCardStyle() {
    case .glass(let radius):
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: radius))
        }
    case .material(let material, let radius):
        content.background(material, in: .rect(cornerRadius: radius))
    }
}
```

- [ ] **Step 4: Re-run tests**
Run: `xcodebuild test -scheme JobSearchApp -destination "platform=iOS Simulator,name=iPhone 15"`  
Expected: Both tests pass (glass path active on iOS 26 simulator, fallback passes otherwise).

- [ ] **Step 5: Commit**
```bash
git add JobSearchApp/Views/Discover/JobDetailView.swift JobSearchAppTests/LiquidGlassJobDetailTests.swift
git commit -m "feat: add Liquid Glass surfaces to JobDetail priority card"
```

## Task 2: WelcomeView glass CTA
**Files:**
- Modify: `JobSearchApp/Views/Onboarding/WelcomeView.swift`
- Create: `JobSearchAppTests/LiquidGlassWelcomeTests.swift`

- [ ] **Step 1: Add style helper + failing tests**
```swift
// WelcomeView.swift (helper)
enum WelcomeCTAStyle: Equatable {
    case glassProminent
    case fallbackAccent
}

func welcomeCTAStyle() -> WelcomeCTAStyle {
    if #available(iOS 26, *) { .glassProminent } else { .fallbackAccent }
}
```
```swift
// JobSearchAppTests/LiquidGlassWelcomeTests.swift
import Testing
@testable import JobSearchApp

struct LiquidGlassWelcomeTests {
    @Test("Welcome CTA uses glassProminent on iOS 26", traits: .disabled(unless: #available(iOS 26, *)))
    func glassCTAOn26() {
        if #available(iOS 26, *) {
            #expect(welcomeCTAStyle() == .glassProminent)
        }
    }

    @Test("Welcome CTA keeps accent fallback pre-26", traits: .disabled(if: #available(iOS 26, *)))
    func fallbackCTA() {
        #expect(welcomeCTAStyle() == .fallbackAccent)
    }
}
```
- [ ] **Step 2: Run tests to see glass test fail until wired**
Run: `xcodebuild test -scheme JobSearchApp -destination "platform=iOS Simulator,name=iPhone 15"`  
Expected: glass test fails (style helper unused in view), fallback passes.

- [ ] **Step 3: Wire CTA to glass style**
```swift
Button(action: onStart) { ... }
.applyWelcomeCTAStyle() // new helper
```
```swift
// Helper in WelcomeView.swift
private extension View {
    @ViewBuilder
    func applyWelcomeCTAStyle() -> some View {
        switch welcomeCTAStyle() {
        case .glassProminent:
            if #available(iOS 26, *) { self.buttonStyle(.glassProminent) }
        case .fallbackAccent:
            self
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(.rect(cornerRadius: 14))
        }
    }
}
```

- [ ] **Step 4: Re-run tests**
Expected: both tests pass.

- [ ] **Step 5: Commit**
```bash
git add JobSearchApp/Views/Onboarding/WelcomeView.swift JobSearchAppTests/LiquidGlassWelcomeTests.swift
git commit -m "feat: add glass CTA styling to WelcomeView"
```

## Task 3: SkillsChipsView glass chips
**Files:**
- Modify: `JobSearchApp/Views/Onboarding/OnboardingHelpers.swift`
- Create: `JobSearchAppTests/LiquidGlassSkillsChipsTests.swift`

- [ ] **Step 1: Add style helper + failing tests**
```swift
// OnboardingHelpers.swift (helper)
enum SkillChipStyle: Equatable {
    case glass
    case material
}

func skillChipStyle() -> SkillChipStyle {
    if #available(iOS 26, *) { .glass } else { .material }
}
```
```swift
// JobSearchAppTests/LiquidGlassSkillsChipsTests.swift
import Testing
@testable import JobSearchApp

struct LiquidGlassSkillsChipsTests {
    @Test("Skills chips use glass on iOS 26", traits: .disabled(unless: #available(iOS 26, *)))
    func chipsGlassOn26() {
        if #available(iOS 26, *) {
            #expect(skillChipStyle() == .glass)
        }
    }

    @Test("Skills chips use material fallback pre-26", traits: .disabled(if: #available(iOS 26, *)))
    func chipsMaterialFallback() {
        #expect(skillChipStyle() == .material)
    }
}
```
- [ ] **Step 2: Run tests (glass test fails until view uses helper)**

- [ ] **Step 3: Wrap chips in GlassEffectContainer and apply helper**
```swift
GlassEffectContainer(spacing: 8) {
    FlowLayout(spacing: 8) {
        ForEach(skills, id: \.self) { skill in
            chipView(skill)
        }
    }
}
```
```swift
@ViewBuilder
private func chipView(_ skill: String) -> some View {
    let base = HStack(spacing: 4) { ... }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)

    switch skillChipStyle() {
    case .glass:
        if #available(iOS 26, *) {
            base
                .glassEffect(.regular.tint(.accentColor).interactive(), in: .capsule)
        }
    case .material:
        base
            .background(.thinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.tint.opacity(0.3), lineWidth: 1))
    }
}
```

- [ ] **Step 4: Re-run tests**

- [ ] **Step 5: Commit**
```bash
git add JobSearchApp/Views/Onboarding/OnboardingHelpers.swift JobSearchAppTests/LiquidGlassSkillsChipsTests.swift
git commit -m "feat: add glass chips with availability-gated helper"
```

## Task 4: DiscoverView progress/error overlays and cohesion
**Files:**
- Modify: `JobSearchApp/Views/Discover/DiscoverView.swift`
- Create: `JobSearchAppTests/LiquidGlassDiscoverTests.swift`

- [ ] **Step 1: Add style helper + failing tests**
```swift
// DiscoverView.swift (helper)
enum DiscoverOverlayStyle: Equatable {
    case glass(cornerRadius: CGFloat)
    case plain
}

func discoverOverlayStyle() -> DiscoverOverlayStyle {
    if #available(iOS 26, *) { .glass(cornerRadius: 12) } else { .plain }
}
```
```swift
// JobSearchAppTests/LiquidGlassDiscoverTests.swift
import Testing
@testable import JobSearchApp

struct LiquidGlassDiscoverTests {
    @Test("Discover overlay uses glass on iOS 26", traits: .disabled(unless: #available(iOS 26, *)))
    func overlayGlassOn26() {
        if #available(iOS 26, *) {
            #expect(discoverOverlayStyle() == .glass(cornerRadius: 12))
        }
    }

    @Test("Discover overlay plain fallback pre-26", traits: .disabled(if: #available(iOS 26, *)))
    func overlayPlainFallback() {
        #expect(discoverOverlayStyle() == .plain)
    }
}
```
- [ ] **Step 2: Run tests (glass test fails until wired)**

- [ ] **Step 3: Implement overlays + optional container**
```swift
// Extract overlay builders
@ViewBuilder
private var progressOverlay: some View {
    if let progress = searchVM.progress {
        overlayCard {
            HStack(spacing: 12) {
                ProgressView()
                Text(progress).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

@ViewBuilder
private var errorOverlay: some View {
    if let error = searchVM.errorMessage {
        overlayCard {
            Text(error).font(.caption).foregroundStyle(.red)
        }
    }
}

@ViewBuilder
private func overlayCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    switch discoverOverlayStyle() {
    case .glass(let radius):
        if #available(iOS 26, *) {
            content()
                .padding(12)
                .glassEffect(.regular, in: .rect(cornerRadius: radius))
        }
    case .plain:
        content()
            .padding(12)
            .background(.thinMaterial, in: .rect(cornerRadius: 12))
    }
}
```
```swift
// Apply overlays above List, keep rows unchanged; optional subtle background cohesion:
.overlay(alignment: .top) {
    VStack(spacing: 8) {
        progressOverlay
        errorOverlay
    }
    .padding(.top, 8)
    .padding(.horizontal)
}
```

- [ ] **Step 4: Re-run tests**

- [ ] **Step 5: Commit**
```bash
git add JobSearchApp/Views/Discover/DiscoverView.swift JobSearchAppTests/LiquidGlassDiscoverTests.swift
git commit -m "feat: add glass overlays for Discover progress/error"
```

## Task 5: Final verification and lint
**Files:**
- N/A (commands)

- [ ] **Step 1: Run full test suite (Swift Testing) per swift-testing-expert guidance**
Run: `xcodebuild test -scheme JobSearchApp -destination "platform=iOS Simulator,name=iPhone 15"`  
If iOS 26 simulator available, also run: `xcodebuild test -scheme JobSearchApp -destination "platform=iOS Simulator,name=iPhone 16 Pro,OS=18.0"` to execute glass-gated tests.

- [ ] **Step 2: SwiftLint / format (if configured)**
Run: `swiftlint` (if repo uses it) or `swift format` if configured.

- [ ] **Step 3: Commit final batch**
```bash
git status
git add .
git commit -m "feat: complete Liquid Glass TODOs with availability-gated styles"
```

## Self-Review (run before execution)
- Spec coverage: Each view’s TODO handled with helpers + containers; fallbacks unchanged.
- Placeholders: None; concrete code and commands provided.
- Type consistency: Style enums reused per view; corner radii consistent (12–14).

## Execution choice
Plan complete and saved to `docs/superpowers/plans/2026-04-08-liquid-glass-todos.md`. Two execution options:
1. Subagent-Driven (recommended) — superpowers:subagent-driven-development.
2. Inline Execution — superpowers:executing-plans.
Which approach? Remember to apply swift-testing-expert skill when writing and adjusting tests.  
