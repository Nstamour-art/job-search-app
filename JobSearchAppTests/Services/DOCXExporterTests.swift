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
        let paragraphs = xml.components(separatedBy: "<w:p>").count - 1
        XCTAssertEqual(paragraphs, 3)
    }
}
