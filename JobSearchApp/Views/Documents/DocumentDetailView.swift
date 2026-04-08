import SwiftUI
import UIKit

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
        // A4 in points (72 pts/inch): 8.27" × 11.69"
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

// MARK: - UIKit share sheet wrapper

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Document picker for saving to Files

struct DocumentPickerView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [url])
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}

// MARK: - Shared document row (used by JobDetailView and DocumentsView)

struct DocumentRow: View {
    let document: GeneratedDocument

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: document.type == .resume ? "doc.text" : "envelope")
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(document.type == .resume ? "Resume" : "Cover Letter")
                    .font(.subheadline.bold())
                Text(document.linkedJob.company)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
