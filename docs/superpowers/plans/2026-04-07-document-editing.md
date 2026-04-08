# Document Editing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users edit the plain-text content of a generated document directly in the app, with "Edit" / "Cancel" / "Done" toolbar controls and changes persisted back to `GeneratedDocument.richContent`.

**Architecture:** `DocumentDetailView` gains an edit mode toggle. In edit mode, the `ScrollView + Text` is replaced by a `TextEditor`. "Done" writes `Data(editContent.utf8)` back to the model and updates `lastModified`. "Cancel" discards changes. The toolbar reconfigures itself based on `isEditing` state — read/edit modes have mutually exclusive toolbar items to avoid multiple boolean flags.

**Tech Stack:** SwiftUI, SwiftData

**SwiftUI patterns applied (from swiftui-ui-patterns skill):**
- State ownership: `@State private var isEditing` and `@State private var editContent` are local UI state owned by one view — correct placement
- Toolbar: uses `isEditing` as a single source of truth for which items appear; no multiple boolean flags for mutually exclusive states
- No view model needed — saving is a one-liner against the model

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Modify | `JobSearchApp/Views/Documents/DocumentDetailView.swift` | Add edit mode with TextEditor, toolbar, and save/cancel logic |

---

## Task 1: Add Inline Editing to DocumentDetailView

**Files:**
- Modify: `JobSearchApp/Views/Documents/DocumentDetailView.swift`

This is a single-file change. No new files, no new tests (editing state transitions are visual — test via build and manual verification in the simulator).

- [ ] **Step 1: Read the current file to understand its structure**

Read `JobSearchApp/Views/Documents/DocumentDetailView.swift`. Confirm:
- `struct DocumentDetailView: View` with `let document: GeneratedDocument`
- `@State private var showSharePDF`, `@State private var pdfData`
- Toolbar `Menu` with "Share as Text", "Export as PDF", (possibly "Export as DOCX", "Save to Files…")
- `private func exportPDF()`, `private func makePDF(from text: String)`
- `struct ActivityViewController`, `struct DocumentRow`

- [ ] **Step 2: Update DocumentDetailView.swift**

Replace `struct DocumentDetailView: View` entirely with the version below. Keep `ActivityViewController`, `DocumentPickerView` (if present from Plan 7), and `DocumentRow` unchanged at the bottom of the file.

```swift
struct DocumentDetailView: View {
    let document: GeneratedDocument
    @Environment(\.modelContext) private var modelContext

    @State private var isEditing = false
    @State private var editContent = ""
    @State private var showSharePDF = false
    @State private var pdfData: Data?
    @State private var docxData: Data?
    @State private var showShareDOCX = false
    @State private var docxFileURL: URL?
    @State private var showFilePicker = false

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
        Group {
            if isEditing {
                TextEditor(text: $editContent)
                    .font(.body)
                    .padding()
            } else {
                ScrollView {
                    Text(textContent)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .navigationTitle(documentTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isEditing)
        .toolbar {
            if isEditing {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isEditing = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        saveEdits()
                        isEditing = false
                    }
                    .fontWeight(.semibold)
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button("Edit") {
                            editContent = textContent
                            isEditing = true
                        }
                        Menu {
                            ShareLink("Share as Text", item: textContent)
                            Button("Export as PDF") { exportPDF() }
                            Button("Export as DOCX") { exportDOCX() }
                            Button("Save to Files…") { saveToFiles() }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showSharePDF) {
            if let data = pdfData {
                ActivityViewController(activityItems: [data])
            }
        }
        .sheet(isPresented: $showShareDOCX) {
            if let data = docxData {
                ActivityViewController(activityItems: [data])
            }
        }
        .sheet(isPresented: $showFilePicker) {
            if let url = docxFileURL {
                DocumentPickerView(url: url)
            }
        }
    }

    // MARK: - Actions

    private func saveEdits() {
        document.richContent = Data(editContent.utf8)
        document.lastModified = Date()
        try? modelContext.save()
    }

    private func exportPDF() {
        pdfData = makePDF(from: textContent)
        showSharePDF = true
    }

    private func exportDOCX() {
        docxData = DOCXExporter.export(textContent)
        showShareDOCX = true
    }

    private func saveToFiles() {
        let filename = "\(documentTitle)_\(filenameSafeDate()).docx"
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = dir.appendingPathComponent(filename)
        let data = DOCXExporter.export(textContent)
        do {
            try data.write(to: fileURL)
            docxFileURL = fileURL
            showFilePicker = true
        } catch {
            docxData = data
            showShareDOCX = true
        }
    }

    private func filenameSafeDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private func makePDF(from text: String) -> Data {
        let formatter = UISimpleTextPrintFormatter(text: text)
        let renderer = UIPrintPageRenderer()
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
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
```

**Note:** If Plan 7 (DOCX Export + Sync) has not been executed yet, `DOCXExporter` won't exist and the `exportDOCX()` and `saveToFiles()` actions will cause compile errors. Either:
1. Execute Plan 7 before this plan (recommended), or
2. Remove `exportDOCX()` and `saveToFiles()` temporarily and add them back after Plan 7.

The `struct ActivityViewController`, `struct DocumentPickerView` (if Plan 7 done), and `struct DocumentRow` at the bottom of the file remain unchanged.

- [ ] **Step 3: Build and run all tests**

```bash
xcodebuild test \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|FAILED|passed|failed|Test Suite"
```

Expected: All tests pass, `BUILD SUCCEEDED`.

- [ ] **Step 4: Manual smoke test in simulator**

Boot the iPhone 16 simulator, run the app, navigate to a generated document, and verify:
- "Edit" button appears in read mode alongside the share menu
- Tapping "Edit" shows `TextEditor` with the full text, "Cancel" and "Done" in toolbar, and back button hidden
- Editing text and tapping "Done" updates the displayed text and persists (visible after leaving and returning)
- Tapping "Cancel" discards changes

- [ ] **Step 5: Commit**

```bash
git add JobSearchApp/Views/Documents/DocumentDetailView.swift
git commit -m "feat: inline text editing for generated documents in DocumentDetailView"
```

---

## Self-Review Checklist

**Spec coverage:**
- [x] `isEditing` is the single source of truth for toolbar configuration — no multiple boolean flags — consistent with SwiftUI patterns skill
- [x] Edit mode replaces `ScrollView + Text` with `TextEditor` — correct swap, no layout artifacts
- [x] "Cancel" discards changes (doesn't touch `editContent`, which just stays stale until next edit) — correct
- [x] "Done" calls `saveEdits()` which sets `richContent` and `lastModified` — correct
- [x] `.navigationBarBackButtonHidden(isEditing)` — prevents accidental navigation away while editing
- [x] All existing export actions (PDF, DOCX, Save to Files) preserved in read mode — correct
- [x] `@Environment(\.modelContext)` added — required for `try? modelContext.save()` in `saveEdits()`

**Type consistency:**
- `saveEdits()` writes `Data(editContent.utf8)` — same encoding as the initial save in `GenerateDocumentsView.generateAndSave`
- `document.lastModified = Date()` — updates the sort key used in `DocumentsView`'s `@Query`, so edited documents correctly bubble up to the top

**Dependency note:**
- This plan integrates `DOCXExporter` and `DocumentPickerView` from Plan 7. If running this plan standalone (before Plan 7), remove the `exportDOCX()` and `saveToFiles()` methods and the two related state vars (`docxData`, `showShareDOCX`, `docxFileURL`, `showFilePicker`). Add them back after Plan 7.
