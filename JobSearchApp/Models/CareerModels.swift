import Foundation
import SwiftData

@Model
final class WorkExperience {
    var company: String
    var title: String
    var startDate: Date
    var endDate: Date?
    var isCurrent: Bool
    var bullets: [String]
    var profile: UserProfile?

    init(company: String, title: String, startDate: Date,
         endDate: Date? = nil, isCurrent: Bool = false, bullets: [String] = []) {
        self.company = company
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isCurrent = isCurrent
        self.bullets = bullets
    }
}

@Model
final class Education {
    var institution: String
    var degree: String
    var field: String
    var graduationDate: Date?
    var profile: UserProfile?

    init(institution: String, degree: String, field: String, graduationDate: Date? = nil) {
        self.institution = institution
        self.degree = degree
        self.field = field
        self.graduationDate = graduationDate
    }
}

@Model
final class Project {
    var name: String
    var projectDescription: String
    var url: String?
    var bullets: [String]
    var profile: UserProfile?

    init(name: String, projectDescription: String, url: String? = nil, bullets: [String] = []) {
        self.name = name
        self.projectDescription = projectDescription
        self.url = url
        self.bullets = bullets
    }
}
