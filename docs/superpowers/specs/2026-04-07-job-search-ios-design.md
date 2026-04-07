# Job Search iOS App — Design Spec
**Date:** 2026-04-07
**Status:** Approved

---

## Overview

A native iOS app where users build a career profile, discover jobs (AI-powered search and manual URL), generate tailored resumes and cover letters with rich in-app editing, export to PDF/DOCX, and apply via Safari — all synced across devices via iCloud.

Reference implementation: [Job-Profiler-Tool](https://github.com/nstamour-art/Job-Profiler-Tool) (Python CLI) — core concepts ported to a mobile-native context.

---

## Target Users

Both career changers (building a profile from scratch) and active job seekers (already have a resume, need to apply efficiently). The app handles the full lifecycle: onboarding → discovery → document generation → application.

---

## Tech Stack

| Concern | Choice |
|---------|--------|
| UI | SwiftUI (iOS 17+) |
| LLM | Anthropic Claude API (`claude-sonnet-4-6`) via `LLMService` protocol |
| Job discovery | Tavily API (REST, URLSession) |
| HTML parsing | SwiftSoup |
| Persistence | SwiftData (on-device) + CloudKit (iCloud sync) |
| Document editing | TextKit 2 / AttributedString |
| PDF export | UIGraphicsPDFRenderer |
| DOCX export | Custom XML template builder (WordprocessingML) |
| Browser | SFSafariViewController |
| Files integration | `UIFileSharingEnabled` — app's `Documents/` exposed to iOS Files app |
| API key storage | Keychain |

---

## LLMService Protocol

All Claude interactions go through a single protocol, keeping the rest of the app provider-agnostic:

```swift
protocol LLMService {
    func complete(prompt: String, system: String) async throws -> String
    func stream(prompt: String, system: String) -> AsyncThrowingStream<String, Error>
}

class AnthropicLLMService: LLMService {
    // API key loaded from Keychain
    // Uses claude-sonnet-4-6
    // Handles retries + rate limit backoff
}
```

**Future path to hosted backend:** Implement `BackendLLMService: LLMService` pointing at a proxy server. No other changes needed.

**Four prompt tasks:**

| Task | Input | Output |
|------|-------|--------|
| `parseProfile` | Free-form user text | Structured `UserProfile` fields |
| `parseJobPosting` | Raw HTML/text | Structured `JobPosting` fields |
| `rankJob` | Profile + job description | Priority score (1–10) + reasoning |
| `generateDocuments` | Profile + job description + theme | Resume + cover letter content |

---

## Navigation

Four-tab structure:

| Tab | Purpose |
|-----|---------|
| **Discover** | AI job search + manual URL paste |
| **Applications** | History of jobs viewed/applied to, status tracking |
| **Documents** | All generated resumes & cover letters — preview, edit, export |
| **Profile** | Career profile — work history, skills, education, etc. |

Settings (API keys, export defaults, theme) accessible via gear icon in Profile tab header.

---

## Onboarding Flow (first launch)

1. Welcome screen → "Build your profile"
2. Conversational AI interview — one section at a time, Claude extracts structured data from free-form input (same approach as Job Profiler resume onboarding)
3. User confirms/edits each extracted section before saving
4. Resume theme picker (Classic / Modern / Creative / Minimal)
5. Settings prompt — enter Claude API key and Tavily API key
6. Land on Discover tab

---

## Core Flows

### Flow 1 — AI Job Discovery
1. User types a query ("Senior iOS engineer, Toronto, remote") in Discover tab
2. App calls Tavily API → list of job URLs
3. App fetches + parses each posting (URLSession + SwiftSoup)
4. Claude ranks each posting against user profile (1–10 score + one-line reasoning)
5. Results shown as scrollable card list: company, title, score badge, reasoning snippet
6. Tap card → Job Detail screen (full description, "Generate Documents" CTA, "Apply" button → SFSafariViewController)

### Flow 2 — Manual URL
1. User pastes a job URL into text field in Discover tab
2. App scrapes posting, Claude parses it → same Job Detail screen

### Flow 3 — Document Generation
1. From Job Detail, tap "Generate Documents"
2. Loading screen with Claude streaming output (animated progress: "Tailoring resume… Writing cover letter…")
3. Rich in-app editor — Resume and Cover Letter as segmented tabs
4. User edits: tap to edit text, drag to reorder sections, theme/font/color picker in toolbar
5. Toolbar: Share | Export PDF | Export DOCX | Save to Files

### Flow 4 — Applying
1. From Job Detail, tap "Apply" → opens job site in SFSafariViewController
2. User attaches resume from iOS Files app (Documents folder exposed by app)
3. Job status updated to `.applied` manually by user in Applications tab

---

## Data Model

```swift
struct ProfileBasics {
    var name: String
    var email: String
    var phone: String?
    var location: String
    var linkedIn: String?
    var github: String?
    var website: String?
}

@Model class UserProfile {
    var basics: ProfileBasics        // name, email, phone, location, links
    var workHistory: [WorkExperience]
    var education: [Education]
    var skills: [String]
    var projects: [Project]
    var resumeTheme: ResumeTheme
}

@Model class WorkExperience {
    var company: String
    var title: String
    var startDate: Date
    var endDate: Date?
    var isCurrent: Bool
    var bullets: [String]
}

@Model class Education {
    var institution: String
    var degree: String
    var field: String
    var graduationDate: Date?
}

@Model class Project {
    var name: String
    var description: String
    var url: String?
    var bullets: [String]
}

@Model class JobPosting {
    var id: UUID
    var url: String
    var title: String
    var company: String
    var location: String
    var scrapedDescription: String
    var priorityScore: Int           // 1–10 (1 = apply immediately)
    var priorityReasoning: String
    var status: JobStatus            // .saved | .applied | .archived
    var dateFound: Date
    var documents: [GeneratedDocument]
}

@Model class GeneratedDocument {
    var type: DocumentType           // .resume | .coverLetter
    var richContent: Data            // AttributedString serialized
    var linkedJob: JobPosting
    var lastModified: Date
}

@Model class ResumeTheme {
    var name: ThemeName              // .classic | .modern | .creative | .minimal
    var accentColor: String          // hex
    var bodyFontSize: Double
}

enum JobStatus { case saved, applied, archived }
enum DocumentType { case resume, coverLetter }
enum ThemeName { case classic, modern, creative, minimal }
```

All models synced to iCloud via CloudKit automatically through SwiftData's CloudKit integration.

---

## Document Export

Both PDF and DOCX are generated from the same `DocumentStyle`, ensuring visual parity:

```swift
struct DocumentStyle {
    // Resolved from ResumeTheme: font family, sizes, colors, spacing
}

struct PDFExporter {
    func export(_ document: GeneratedDocument, style: DocumentStyle) -> Data
    // Uses UIGraphicsPDFRenderer
}

struct DOCXExporter {
    func export(_ document: GeneratedDocument, style: DocumentStyle) -> Data
    // Uses custom WordprocessingML XML builder
}
```

**Output folder structure** (same for both formats):
```
Documents/
└── <Company>_<Role>_<YYYY-MM-DD>/
    ├── Resume.pdf / Resume.docx
    └── Cover Letter.pdf / Cover Letter.docx
```

Folder exposed to iOS Files app via `UIFileSharingEnabled = true` in Info.plist.

---

## Settings

| Section | Fields |
|---------|--------|
| **AI** | Claude API key (Keychain-backed) |
| **Job Search** | Tavily API key (Keychain-backed) |
| **Documents** | Default export format (PDF / DOCX / Both), default resume theme |

Missing API keys surface as inline non-blocking prompts in the relevant tab rather than hard gates.

---

## Error Handling

- All LLM + network calls are `async throws` — errors displayed as inline view banners
- Claude JSON parsing failures retry once with explicit "return valid JSON" instruction appended
- Scraping failures (bot detection, paywalled pages) prompt: "Couldn't read this page — try pasting the job description manually"
- Missing API key shows inline prompt in affected tab

---

## Testing Strategy

- `LLMService` protocol enables trivial mocking — unit tests use `MockLLMService` with canned responses
- `PDFExporter` and `DOCXExporter` tested against snapshot fixtures
- SwiftData models tested with an in-memory store
- No UI tests in v1
