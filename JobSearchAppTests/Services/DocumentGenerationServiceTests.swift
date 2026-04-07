import XCTest
import SwiftData
@testable import JobSearchApp

@MainActor
final class DocumentGenerationServiceTests: XCTestCase {
    var container: ModelContainer!

    override func setUp() {
        super.setUp()
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
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

    private func makeProfile() -> UserProfile {
        let basics = ProfileBasics(
            name: "Jane Doe", email: "jane@example.com", phone: nil,
            location: "Toronto, ON", linkedIn: nil, github: nil, website: nil
        )
        let profile = UserProfile(basics: basics)
        profile.skills = ["Swift", "SwiftUI"]
        container.mainContext.insert(profile)
        return profile
    }

    private func makeJob() -> JobPosting {
        let job = JobPosting(
            url: "", title: "iOS Engineer", company: "TechCo", location: "Remote",
            scrapedDescription: "We build iOS apps.",
            priorityScore: 4, priorityReasoning: "Good fit",
            status: .saved, dateFound: Date()
        )
        container.mainContext.insert(job)
        return job
    }

    func test_generateResume_returnsLLMOutput() async throws {
        let service = DocumentGenerationService(llm: MockLLMService(response: "Resume content here"))
        let result = try await service.generateResume(profile: makeProfile(), job: makeJob())
        XCTAssertEqual(result, "Resume content here")
    }

    func test_generateCoverLetter_returnsLLMOutput() async throws {
        let service = DocumentGenerationService(llm: MockLLMService(response: "Cover letter content"))
        let result = try await service.generateCoverLetter(profile: makeProfile(), job: makeJob())
        XCTAssertEqual(result, "Cover letter content")
    }

    func test_generateResume_propagatesLLMError() async {
        let service = DocumentGenerationService(llm: MockLLMService(error: URLError(.badServerResponse)))
        do {
            _ = try await service.generateResume(profile: makeProfile(), job: makeJob())
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
        }
    }

    func test_generateCoverLetter_propagatesLLMError() async {
        let service = DocumentGenerationService(llm: MockLLMService(error: URLError(.badServerResponse)))
        do {
            _ = try await service.generateCoverLetter(profile: makeProfile(), job: makeJob())
            XCTFail("Expected error")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
        }
    }

    func test_generateResume_includesProfileAndJobInPrompt() async throws {
        let mock = MockLLMService(response: "ok")
        let service = DocumentGenerationService(llm: mock)
        _ = try await service.generateResume(profile: makeProfile(), job: makeJob())
        let prompt = mock.capturedPrompt ?? ""
        XCTAssertTrue(prompt.contains("Jane Doe"), "prompt should contain candidate name")
        XCTAssertTrue(prompt.contains("TechCo"), "prompt should contain job company")
        XCTAssertTrue(prompt.contains("Swift"), "prompt should contain skills")
    }

    func test_generateCoverLetter_includesProfileAndJobInPrompt() async throws {
        let mock = MockLLMService(response: "ok")
        let service = DocumentGenerationService(llm: mock)
        _ = try await service.generateCoverLetter(profile: makeProfile(), job: makeJob())
        let prompt = mock.capturedPrompt ?? ""
        XCTAssertTrue(prompt.contains("Jane Doe"), "prompt should contain candidate name")
        XCTAssertTrue(prompt.contains("iOS Engineer"), "prompt should contain job title")
    }
}
