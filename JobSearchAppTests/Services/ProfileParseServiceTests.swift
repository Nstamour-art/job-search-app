import XCTest
@testable import JobSearchApp

final class ProfileParseServiceTests: XCTestCase {

    func test_parseBasics_extractsFields() async throws {
        let json = """
        {"name":"Jane Doe","email":"jane@example.com","phone":"+1 416 555 0100",
         "location":"Toronto, ON","linkedIn":"linkedin.com/in/janedoe","github":null,"website":null}
        """
        let service = ProfileParseService(llm: MockLLMService(response: json))
        let result = try await service.parseBasics(from: "I'm Jane Doe...")
        XCTAssertEqual(result.name, "Jane Doe")
        XCTAssertEqual(result.email, "jane@example.com")
        XCTAssertEqual(result.location, "Toronto, ON")
        XCTAssertNil(result.github)
    }

    func test_parseBasics_handlesMarkdownFencedJSON() async throws {
        let response = """
        ```json
        {"name":"John","email":"john@test.com","phone":null,"location":"NYC","linkedIn":null,"github":null,"website":null}
        ```
        """
        let service = ProfileParseService(llm: MockLLMService(response: response))
        let result = try await service.parseBasics(from: "John from NYC")
        XCTAssertEqual(result.name, "John")
    }

    func test_parseWorkExperiences_extractsList() async throws {
        let json = """
        [{"company":"Acme","title":"iOS Engineer","startDate":"2022-01",
          "endDate":null,"isCurrent":true,"bullets":["Built features","Led team"]}]
        """
        let service = ProfileParseService(llm: MockLLMService(response: json))
        let result = try await service.parseWorkExperiences(from: "I work at Acme...")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].company, "Acme")
        XCTAssertTrue(result[0].isCurrent)
        XCTAssertEqual(result[0].bullets.count, 2)
    }

    func test_parseEducation_extractsList() async throws {
        let json = """
        [{"institution":"U of T","degree":"Bachelor","field":"Computer Science","graduationDate":"2020-06"}]
        """
        let service = ProfileParseService(llm: MockLLMService(response: json))
        let result = try await service.parseEducation(from: "I studied CS at UofT...")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].institution, "U of T")
        XCTAssertEqual(result[0].graduationDate, "2020-06")
    }

    func test_parseSkills_extractsArray() async throws {
        let json = #"["Swift","SwiftUI","Python","Git"]"#
        let service = ProfileParseService(llm: MockLLMService(response: json))
        let result = try await service.parseSkills(from: "I know Swift, SwiftUI...")
        XCTAssertEqual(result, ["Swift", "SwiftUI", "Python", "Git"])
    }

    func test_parseProjects_extractsList() async throws {
        let json = """
        [{"name":"MyApp","description":"An iOS app","url":"github.com/me/myapp","bullets":["SwiftUI"]}]
        """
        let service = ProfileParseService(llm: MockLLMService(response: json))
        let result = try await service.parseProjects(from: "I built MyApp...")
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].name, "MyApp")
    }

    func test_parseBasics_throwsOnInvalidJSON() async {
        let service = ProfileParseService(llm: MockLLMService(response: "not json"))
        do {
            _ = try await service.parseBasics(from: "some text")
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is DecodingError)
        }
    }

    func test_parseBasics_propagatesLLMError() async {
        let service = ProfileParseService(llm: MockLLMService(error: URLError(.badServerResponse)))
        do {
            _ = try await service.parseBasics(from: "some text")
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(error is URLError)
        }
    }
}
