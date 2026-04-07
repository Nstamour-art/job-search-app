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
    @Attribute(.transformable(by: "ProfileBasicsTransformer"))
    var basics: ProfileBasics
    @Relationship(deleteRule: .cascade) var workHistory: [WorkExperience] = []
    @Relationship(deleteRule: .cascade) var education: [Education] = []
    var skills: [String] = []
    @Relationship(deleteRule: .cascade) var projects: [Project] = []
    @Relationship(deleteRule: .cascade, inverse: \ResumeTheme.profile)
    var resumeTheme: ResumeTheme?

    init(basics: ProfileBasics, resumeTheme: ResumeTheme? = nil) {
        self.basics = basics
        self.resumeTheme = resumeTheme
    }
}

final class ProfileBasicsTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass { NSData.self }
    override class func allowsReverseTransformation() -> Bool { true }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let basics = value as? ProfileBasics else { return nil }
        return try? JSONEncoder().encode(basics) as NSData
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        return try? JSONDecoder().decode(ProfileBasics.self, from: data)
    }

    static func register() {
        ValueTransformer.setValueTransformer(
            ProfileBasicsTransformer(),
            forName: NSValueTransformerName("ProfileBasicsTransformer")
        )
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
