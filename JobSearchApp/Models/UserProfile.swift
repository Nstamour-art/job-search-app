import Foundation
import SwiftData

struct ProfileBasics: Codable {
    var name: String
    var email: String
    var phone: String?
    var location: String
    var linkedIn: String?
    var github: String?
    var website: String?
}

@Model
final class UserProfile {
    var basics: ProfileBasics
    @Relationship(deleteRule: .cascade, inverse: \WorkExperience.profile) var workHistory: [WorkExperience] = []
    @Relationship(deleteRule: .cascade, inverse: \Education.profile)      var education: [Education] = []
    var skills: [String] = []
    @Relationship(deleteRule: .cascade, inverse: \Project.profile)        var projects: [Project] = []
    @Relationship(deleteRule: .cascade, inverse: \ResumeTheme.profile)
    var resumeTheme: ResumeTheme?

    init(basics: ProfileBasics, resumeTheme: ResumeTheme? = nil) {
        self.basics = basics
        self.resumeTheme = resumeTheme
    }
}

@Model
final class ResumeTheme {
    var name: ThemeName
    var accentColor: String
    var bodyFontSize: Double
    var profile: UserProfile?

    init(name: ThemeName, accentColor: String, bodyFontSize: Double) {
        self.name = name
        self.accentColor = accentColor
        self.bodyFontSize = bodyFontSize
    }
}

enum ThemeName: String, Codable {
    case classic, modern, creative, minimal
}
