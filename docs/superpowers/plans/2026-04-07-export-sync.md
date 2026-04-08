# DOCX Export + iCloud Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add DOCX export for generated documents (WordprocessingML format, created with ZIPFoundation), expose generated files in the iOS Files app via the existing `UIFileSharingEnabled` plist key, and enable iCloud CloudKit sync for all SwiftData models.

**Architecture:** `DOCXExporter` builds a minimal DOCX (WordprocessingML XML files packaged into a ZIP via ZIPFoundation). Files are written to the app's Documents directory so the iOS Files app can see them. `DocumentDetailView` gets "Save to Files" and "Export DOCX" menu actions. The CloudKit change is a one-liner in `JobSearchApp.swift`.

**Tech Stack:** SwiftUI, ZIPFoundation (SPM), FileManager, SwiftData CloudKit

**Pre-check:** `UIFileSharingEnabled = true` and CloudKit entitlements are already configured in `project.yml` and `Info.plist` — no Info.plist or entitlement changes needed.

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Modify | `project.yml` | Add ZIPFoundation SPM package |
| Create | `JobSearchApp/Services/DOCXExporter.swift` | DOCX builder (XML + ZIP) |
| Create | `JobSearchAppTests/Services/DOCXExporterTests.swift` | Unit tests |
| Modify | `JobSearchApp/Views/Documents/DocumentDetailView.swift` | Add DOCX and Save to Files menu actions |
| Modify | `JobSearchApp/App/JobSearchApp.swift` | Enable CloudKit in SwiftData config |

---

## Task 1: Add ZIPFoundation via SPM

**Files:**
- Modify: `project.yml`

ZIPFoundation is required to create the DOCX zip archive. xcodegen supports SPM packages through a top-level `packages:` key.

- [ ] **Step 1: Add ZIPFoundation to project.yml**

Add a `packages:` top-level key and a dependency in the `JobSearchApp` target. Find the `targets:` section and add the packages block just before it. Then add the dependency to the `JobSearchApp` target.

Open `project.yml`. After `options:` block, before `targets:`, add:

```yaml
packages:
  ZIPFoundation:
    url: https://github.com/weichsel/ZIPFoundation.git
    minorVersion: "0.9"
```

Inside the `JobSearchApp` target, add under `dependencies:` (create the key if it doesn't exist):

```yaml
    dependencies:
      - package: ZIPFoundation
        product: ZIPFoundation
```

- [ ] **Step 2: Run xcodegen and verify it resolves the package**

```bash
cd /Users/nstamour/Documents/GitHub/job-search-app && xcodegen generate
```

Then open Xcode or run:

```bash
xcodebuild -resolvePackageDependencies \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  2>&1 | grep -E "error:|resolved|ZIPFoundation"
```

Expected: ZIPFoundation resolved successfully.

- [ ] **Step 3: Verify build still succeeds**

```bash
xcodebuild build \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add project.yml
git commit -m "chore: add ZIPFoundation SPM dependency for DOCX export"
```

---

## Task 2: DOCXExporter (TDD)

**Files:**
- Create: `JobSearchApp/Services/DOCXExporter.swift`
- Create: `JobSearchAppTests/Services/DOCXExporterTests.swift`

A valid `.docx` file is a ZIP archive containing these entries:

```
[Content_Types].xml
_rels/.rels
word/document.xml
word/_rels/document.xml.rels
```

`DOCXExporter` takes a plain text string and returns `Data` (a valid DOCX ZIP). Each line of text becomes a `<w:p>` paragraph in `word/document.xml`.

- [ ] **Step 1: Write failing tests**

Create `JobSearchAppTests/Services/DOCXExporterTests.swift`:

```swift
import XCTest
import ZIPFoundation
@testable import JobSearchApp

final class DOCXExporterTests: XCTestCase {

    func test_export_returnsNonEmptyData() {
        let data = DOCXExporter.export("Hello\nWorld")
        XCTAssertFalse(data.isEmpty)
    }

    func test_export_producesValidZIP() throws {
        let data = DOCXExporter.export("Test document")
        let archive = try Archive(data: data, accessMode: .read)
        let entries = archive.map { $0.path }
        XCTAssertTrue(entries.contains("[Content_Types].xml"), "Missing [Content_Types].xml")
        XCTAssertTrue(entries.contains("_rels/.rels"), "Missing _rels/.rels")
        XCTAssertTrue(entries.contains("word/document.xml"), "Missing word/document.xml")
        XCTAssertTrue(entries.contains("word/_rels/document.xml.rels"), "Missing word/_rels/document.xml.rels")
    }

    func test_export_documentXMLContainsText() throws {
        let data = DOCXExporter.export("Swift is great")
        let archive = try Archive(data: data, accessMode: .read)
        guard let entry = archive["word/document.xml"] else {
            XCTFail("word/document.xml missing")
            return
        }
        var xmlData = Data()
        _ = try archive.extract(entry) { chunk in xmlData.append(chunk) }
        let xml = String(data: xmlData, encoding: .utf8) ?? ""
        XCTAssertTrue(xml.contains("Swift is great"), "Text not found in document.xml")
    }

    func test_export_handlesMultipleLines() throws {
        let data = DOCXExporter.export("Line 1\nLine 2\nLine 3")
        let archive = try Archive(data: data, accessMode: .read)
        guard let entry = archive["word/document.xml"] else {
            XCTFail("word/document.xml missing"); return
        }
        var xmlData = Data()
        _ = try archive.extract(entry) { chunk in xmlData.append(chunk) }
        let xml = String(data: xmlData, encoding: .utf8) ?? ""
        // Each line is a <w:p> paragraph
        let paragraphs = xml.components(separatedBy: "<w:p>").count - 1
        XCTAssertEqual(paragraphs, 3)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/nstamour/Documents/GitHub/job-search-app && xcodegen generate && xcodebuild test \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:JobSearchAppTests/DOCXExporterTests \
  2>&1 | grep -E "error:|FAILED|passed|failed|Test Suite"
```

Expected: compile error — `DOCXExporter` not found.

- [ ] **Step 3: Implement DOCXExporter**

Create `JobSearchApp/Services/DOCXExporter.swift`:

```swift
import Foundation
import ZIPFoundation

enum DOCXExporter {
    static func export(_ text: String) -> Data {
        let archive = Archive(accessMode: .create)!
        add(to: archive, path: "[Content_Types].xml",       content: contentTypes)
        add(to: archive, path: "_rels/.rels",               content: relationships)
        add(to: archive, path: "word/document.xml",         content: document(for: text))
        add(to: archive, path: "word/_rels/document.xml.rels", content: wordRelationships)
        return archive.data!
    }

    // MARK: - Private helpers

    private static func add(to archive: Archive, path: String, content: String) {
        let data = Data(content.utf8)
        try? archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count)) { position, size in
            data.subdata(in: position..<position + size)
        }
    }

    private static let contentTypes = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml"  ContentType="application/xml"/>
      <Override PartName="/word/document.xml"
        ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
    </Types>
    """

    private static let relationships = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1"
        Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"
        Target="word/document.xml"/>
    </Relationships>
    """

    private static let wordRelationships = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    </Relationships>
    """

    private static func document(for text: String) -> String {
        let paragraphs = text
            .components(separatedBy: "\n")
            .map { line -> String in
                let escaped = line
                    .replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "<", with: "&lt;")
                    .replacingOccurrences(of: ">", with: "&gt;")
                return "<w:p><w:r><w:t xml:space=\"preserve\">\(escaped)</w:t></w:r></w:p>"
            }
            .joined(separator: "\n")

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"
                    xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
          <w:body>
        \(paragraphs)
          </w:body>
        </w:document>
        """
    }
}
```

- [ ] **Step 4: Run xcodegen and tests**

```bash
cd /Users/nstamour/Documents/GitHub/job-search-app && xcodegen generate && xcodebuild test \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:JobSearchAppTests/DOCXExporterTests \
  2>&1 | grep -E "error:|FAILED|passed|failed|Test Suite"
```

Expected: 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add JobSearchApp/Services/DOCXExporter.swift \
        JobSearchAppTests/Services/DOCXExporterTests.swift
git commit -m "feat: DOCXExporter with WordprocessingML XML and ZIP packaging"
```

---

## Task 3: Add DOCX Export and Save to Files in DocumentDetailView

**Files:**
- Modify: `JobSearchApp/Views/Documents/DocumentDetailView.swift`

Add two menu items to the existing share menu: "Export DOCX" (save to Documents folder + share) and "Save to Files" (PDF or DOCX via UIDocumentPickerViewController).

- [ ] **Step 1: Update DocumentDetailView.swift**

Replace the toolbar `Menu` block:

```swift
.toolbar {
    ToolbarItem(placement: .topBarTrailing) {
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
```

Add state property for DOCX (alongside existing `pdfData`):
```swift
@State private var docxData: Data?
@State private var showShareDOCX = false
```

Add the DOCX share sheet (alongside existing PDF sheet):
```swift
.sheet(isPresented: $showShareDOCX) {
    if let data = docxData {
        ActivityViewController(activityItems: [data])
    }
}
```

Add the three new action functions (place after `exportPDF`):

```swift
private func exportDOCX() {
    docxData = DOCXExporter.export(textContent)
    showShareDOCX = true
}

private func saveToFiles() {
    // Write DOCX to app Documents folder so iOS Files app can see it
    let filename = "\(documentTitle)_\(filenameSafeDate()).docx"
    let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let fileURL = dir.appendingPathComponent(filename)
    let data = DOCXExporter.export(textContent)
    do {
        try data.write(to: fileURL)
        // Present document picker so user can copy to any location
        docxFileURL = fileURL
        showFilePicker = true
    } catch {
        // File write failed — silently fall back to share sheet
        docxData = data
        showShareDOCX = true
    }
}

private func filenameSafeDate() -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: Date())
}
```

Add state for file picker:
```swift
@State private var docxFileURL: URL?
@State private var showFilePicker = false
```

Add file picker sheet:
```swift
.sheet(isPresented: $showFilePicker) {
    if let url = docxFileURL {
        DocumentPickerView(url: url)
    }
}
```

Add `DocumentPickerView` at the bottom of the file (alongside `ActivityViewController`):

```swift
struct DocumentPickerView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [url])
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}
```

- [ ] **Step 2: Build**

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
git add JobSearchApp/Views/Documents/DocumentDetailView.swift
git commit -m "feat: add DOCX export and Save to Files options in DocumentDetailView"
```

---

## Task 4: Enable CloudKit Sync

**Files:**
- Modify: `JobSearchApp/App/JobSearchApp.swift`

CloudKit entitlements, capabilities, and NSUbiquitousContainers are already configured in `project.yml`, `Info.plist`, and the `.entitlements` file. The only code change needed is enabling CloudKit in the SwiftData `ModelConfiguration`.

- [ ] **Step 1: Change cloudKitDatabase from .none to .automatic**

In `JobSearchApp/App/JobSearchApp.swift`, find:

```swift
let config = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
```

Replace with:

```swift
let config = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
```

- [ ] **Step 2: Build and run all tests**

```bash
xcodebuild test \
  -project JobSearchApp.xcodeproj \
  -scheme JobSearchApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | grep -E "error:|FAILED|passed|failed|Test Suite"
```

Expected: All tests pass. Note: CloudKit sync requires a real device with an iCloud-signed-in account to verify end-to-end; simulator tests will pass since SwiftData gracefully degrades when CloudKit is unavailable.

- [ ] **Step 3: Commit**

```bash
git add JobSearchApp/App/JobSearchApp.swift
git commit -m "feat: enable CloudKit sync via SwiftData cloudKitDatabase: .automatic"
```

---

## Self-Review Checklist

**Spec coverage:**
- [x] ZIPFoundation added to project.yml — Task 1
- [x] `DOCXExporter.export(_:)` creates valid ZIP with all 4 required entries — Task 2
- [x] Each line of text becomes a `<w:p>` paragraph — Task 2
- [x] XML special characters (`&`, `<`, `>`) escaped — Task 2
- [x] "Export DOCX" action in `DocumentDetailView` menu — Task 3
- [x] "Save to Files…" writes DOCX to Documents folder + presents `UIDocumentPickerViewController` — Task 3
- [x] `DocumentPickerView` (`UIViewControllerRepresentable`) defined at module scope — Task 3
- [x] CloudKit `.automatic` enabled — Task 4
- [x] No Info.plist or entitlement changes needed (already configured) — confirmed by pre-check

**Type consistency:**
- `DOCXExporter.export(_:)` takes `String`, returns `Data` — consistent usage in both tests and view
- `DocumentPickerView` uses `forExporting:` initializer (iOS 14+, available on iOS 17 target)
