import Foundation
import SwiftData

enum JobStatus: String, Codable {
    case saved, applied, archived
}

enum DocumentType: String, Codable {
    case resume, coverLetter
}

@Model
final class JobPosting {
    var id: UUID
    var url: String
    var title: String
    var company: String
    var location: String
    var scrapedDescription: String
    var priorityScore: Int
    var priorityReasoning: String
    var status: JobStatus
    var dateFound: Date
    @Relationship(deleteRule: .cascade) var documents: [GeneratedDocument] = []

    init(url: String, title: String, company: String, location: String,
         scrapedDescription: String, priorityScore: Int, priorityReasoning: String,
         status: JobStatus, dateFound: Date) {
        self.id = UUID()
        self.url = url
        self.title = title
        self.company = company
        self.location = location
        self.scrapedDescription = scrapedDescription
        self.priorityScore = priorityScore
        self.priorityReasoning = priorityReasoning
        self.status = status
        self.dateFound = dateFound
    }
}

@Model
final class GeneratedDocument {
    var type: DocumentType
    var richContent: Data
    var lastModified: Date
    var linkedJob: JobPosting

    init(type: DocumentType, richContent: Data, linkedJob: JobPosting) {
        self.type = type
        self.richContent = richContent
        self.lastModified = Date()
        self.linkedJob = linkedJob
    }
}
