import XCTest
import SwiftData
@testable import JobSearchApp

@MainActor
final class JobAnalysisServiceTests: XCTestCase {
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

    private func makeProfile(skills: [String] = ["Swift", "SwiftUI", "iOS"]) -> UserProfile {
        let basics = ProfileBasics(
            name: "Jane Doe", email: "jane@example.com", phone: nil,
            location: "Toronto, ON", linkedIn: nil, github: nil, website: nil
        )
        let profile = UserProfile(basics: basics)
        profile.skills = skills
        container.mainContext.insert(profile)
        return profile
    }

    func test_analyze_extractsStructuredFields() async throws {
        let json = """
        {"title":"iOS Engineer","company":"Acme Corp","location":"Toronto, ON",
         "priorityScore":4,"priorityReasoning":"Strong Swift/SwiftUI match"}
        """
        let service = JobAnalysisService(llm: MockLLMService(response: json))
        let result = try await service.analyze(jobText: "We are hiring an iOS engineer...", profile: makeProfile())
        XCTAssertEqual(result.title, "iOS Engineer")
        XCTAssertEqual(result.company, "Acme Corp")
        XCTAssertEqual(result.location, "Toronto, ON")
        XCTAssertEqual(result.priorityScore, 4)
        XCTAssertFalse(result.priorityReasoning.isEmpty)
    }

    func test_analyze_handlesMarkdownFencedJSON() async throws {
        let response = """
        ```json
        {"title":"Dev","company":"Beta","location":"Remote","priorityScore":3,"priorityReasoning":"Decent fit"}
        ```
        """
        let service = JobAnalysisService(llm: MockLLMService(response: response))
        let result = try await service.analyze(jobText: "Job posting text...", profile: makeProfile())
        XCTAssertEqual(result.title, "Dev")
        XCTAssertEqual(result.priorityScore, 3)
    }

    func test_analyze_throwsOnInvalidJSON() async {
        let service = JobAnalysisService(llm: MockLLMService(response: "not json"))
        do {
            _ = try await service.analyze(jobText: "...", profile: makeProfile())
            XCTFail("Expected DecodingError")
        } catch {
            XCTAssertTrue(error is DecodingError)
        }
    }

    func test_analyze_propagatesLLMError() async {
        let service = JobAnalysisService(llm: MockLLMService(error: URLError(.badServerResponse)))
        do {
            _ = try await service.analyze(jobText: "...", profile: makeProfile())
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is URLError)
        }
    }
}
