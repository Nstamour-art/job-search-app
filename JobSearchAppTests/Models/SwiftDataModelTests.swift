import XCTest
import SwiftData
@testable import JobSearchApp

final class SwiftDataModelTests: XCTestCase {
    var container: ModelContainer!

    override func setUp() {
        super.setUp()
        ProfileBasicsTransformer.register()
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try! ModelContainer(
            for: UserProfile.self, WorkExperience.self,
                 Education.self, Project.self, ResumeTheme.self,
                 JobPosting.self, GeneratedDocument.self,
            configurations: config
        )
    }

    override func tearDown() {
        container = nil
        super.tearDown()
    }

    func test_userProfile_canBeInsertedAndFetched() throws {
        let context = container.mainContext
        let basics = ProfileBasics(
            name: "Jane Doe",
            email: "jane@example.com",
            phone: "+1 416 555 0100",
            location: "Toronto, ON",
            linkedIn: nil,
            github: "github.com/janedoe",
            website: nil
        )
        let theme = ResumeTheme(name: .modern, accentColor: "#1E3A5F", bodyFontSize: 11.0)
        let profile = UserProfile(basics: basics, resumeTheme: theme)
        context.insert(profile)
        try context.save()

        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        XCTAssertEqual(profiles.count, 1)
        XCTAssertEqual(profiles.first?.basics.name, "Jane Doe")
    }

    func test_jobPosting_canBeInsertedWithStatus() throws {
        let context = container.mainContext
        let posting = JobPosting(
            url: "https://example.com/job/123",
            title: "iOS Engineer",
            company: "Acme Corp",
            location: "Toronto, ON",
            scrapedDescription: "We are looking for...",
            priorityScore: 3,
            priorityReasoning: "Strong match on Swift experience",
            status: .saved,
            dateFound: Date()
        )
        context.insert(posting)
        try context.save()

        let postings = try context.fetch(FetchDescriptor<JobPosting>())
        XCTAssertEqual(postings.count, 1)
        XCTAssertEqual(postings.first?.status, .saved)
        XCTAssertEqual(postings.first?.priorityScore, 3)
    }

    func test_generatedDocument_linksToJobPosting() throws {
        let context = container.mainContext
        let posting = JobPosting(
            url: "https://example.com/job/456",
            title: "Swift Developer",
            company: "Beta Inc",
            location: "Remote",
            scrapedDescription: "Remote Swift role...",
            priorityScore: 2,
            priorityReasoning: "Excellent fit",
            status: .saved,
            dateFound: Date()
        )
        context.insert(posting)
        let doc = GeneratedDocument(
            type: .resume,
            richContent: Data("resume content".utf8),
            linkedJob: posting
        )
        context.insert(doc)
        try context.save()

        let docs = try context.fetch(FetchDescriptor<GeneratedDocument>())
        XCTAssertEqual(docs.count, 1)
        XCTAssertEqual(docs.first?.type, .resume)
        XCTAssertEqual(docs.first?.linkedJob.title, "Swift Developer")
    }
}
