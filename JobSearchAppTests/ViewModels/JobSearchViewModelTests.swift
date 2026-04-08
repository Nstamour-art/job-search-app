import XCTest
import SwiftData
@testable import JobSearchApp

@MainActor
final class JobSearchViewModelTests: XCTestCase {
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
        profile.skills = ["Swift"]
        container.mainContext.insert(profile)
        return profile
    }

    func test_search_insertsJobPostings() async throws {
        let searchJSON = """
        {"results":[{"title":"iOS Dev","url":"https://co.com/1","content":"Build iOS apps with Swift"}]}
        """
        let analysisJSON = """
        {"title":"iOS Dev","company":"Co","location":"Remote","priorityScore":4,"priorityReasoning":"Good fit"}
        """
        let session = MockURLSession(data: searchJSON.data(using: .utf8)!, statusCode: 200)
        let llm = MockLLMService(response: analysisJSON)
        let vm = JobSearchViewModel()

        await vm.search(
            query: "iOS engineer",
            tavilyKey: "test",
            llmService: llm,
            profile: makeProfile(),
            context: container.mainContext,
            sessionOverride: session
        )

        let postings = try container.mainContext.fetch(FetchDescriptor<JobPosting>())
        XCTAssertEqual(postings.count, 1)
        XCTAssertEqual(postings[0].title, "iOS Dev")
        XCTAssertEqual(postings[0].company, "Co")
        XCTAssertEqual(postings[0].status, .saved)
    }

    func test_search_setsErrorOnMissingTavilyKey() async {
        let vm = JobSearchViewModel()
        await vm.search(
            query: "iOS engineer",
            tavilyKey: "",
            llmService: MockLLMService(response: ""),
            profile: makeProfile(),
            context: container.mainContext,
            sessionOverride: nil
        )
        XCTAssertNotNil(vm.errorMessage)
        XCTAssertTrue(vm.errorMessage!.contains("Tavily"))
    }

    func test_search_setsIsSearchingDuringWork() async {
        let vm = JobSearchViewModel()
        XCTAssertFalse(vm.isSearching)
        let json = "{\"results\":[{\"title\":\"T\",\"url\":\"https://x.com\",\"content\":\"c\"}]}"
        let session = MockURLSession(data: json.data(using: .utf8)!, statusCode: 200)
        let llm = MockLLMService(response: "{\"title\":\"T\",\"company\":\"X\",\"location\":\"R\",\"priorityScore\":3,\"priorityReasoning\":\"ok\"}")
        await vm.search(
            query: "q",
            tavilyKey: "key",
            llmService: llm,
            profile: makeProfile(),
            context: container.mainContext,
            sessionOverride: session
        )
        XCTAssertFalse(vm.isSearching)
    }
}
