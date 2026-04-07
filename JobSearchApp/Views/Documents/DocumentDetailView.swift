import SwiftUI
import UIKit

struct DocumentDetailView: View {
    let document: GeneratedDocument
    @State private var showSharePDF = false
    @State private var pdfData: Data?

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
        ScrollView {
            Text(textContent)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(documentTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ShareLink("Share as Text", item: textContent)
                    Button("Export as PDF") { exportPDF() }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .sheet(isPresented: $showSharePDF) {
            if let data = pdfData {
                ActivityViewController(activityItems: [data])
            }
        }
    }

    private func exportPDF() {
        pdfData = makePDF(from: textContent)
        showSharePDF = true
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
