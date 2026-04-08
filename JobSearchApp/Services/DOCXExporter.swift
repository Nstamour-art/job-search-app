import Foundation
import ZIPFoundation

enum DOCXExporter {
    static func export(_ text: String) -> Data {
        guard let archive = Archive(accessMode: .create) else { return Data() }
        add(to: archive, path: "[Content_Types].xml",          content: contentTypes)
        add(to: archive, path: "_rels/.rels",                  content: relationships)
        add(to: archive, path: "word/document.xml",            content: document(for: text))
        add(to: archive, path: "word/_rels/document.xml.rels", content: wordRelationships)
        return archive.data ?? Data()
    }

    // MARK: - Private helpers

    private static func add(to archive: Archive, path: String, content: String) {
        let data = Data(content.utf8)
        guard let uncompressedSize = UInt32(exactly: data.count) else { return }
        try? archive.addEntry(
            with: path,
            type: .file,
            uncompressedSize: uncompressedSize
        ) { position, size in
            let start = Int(position)
            let end = min(data.count, start + size)
            return data.subdata(in: start..<end)
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
