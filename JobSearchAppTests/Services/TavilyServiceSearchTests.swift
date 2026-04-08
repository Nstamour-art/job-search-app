import XCTest
@testable import JobSearchApp

final class TavilyServiceSearchTests: XCTestCase {

    func test_search_decodesResults() async throws {
        let json = """
        {"results":[
          {"title":"iOS Engineer at Acme","url":"https://acme.com/jobs/1","content":"We need Swift engineers"},
          {"title":"Mobile Dev at Beta","url":"https://beta.com/jobs/2","content":"SwiftUI experience required"}
        ]}
        """
        let session = MockURLSession(data: json.data(using: .utf8)!, statusCode: 200)
        let service = TavilyService(apiKey: "test-key", session: session)
        let results = try await service.search(query: "iOS engineer Toronto")
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].title, "iOS Engineer at Acme")
        XCTAssertEqual(results[0].url, "https://acme.com/jobs/1")
        XCTAssertEqual(results[0].content, "We need Swift engineers")
    }

    func test_search_throwsOnHTTPError() async {
        let session = MockURLSession(data: Data(), statusCode: 401)
        let service = TavilyService(apiKey: "bad-key", session: session)
        do {
            _ = try await service.search(query: "iOS")
            XCTFail("Expected error")
        } catch TavilyError.httpError(let code) {
            XCTAssertEqual(code, 401)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func test_search_throwsNoResultsOnEmptyArray() async throws {
        let json = "{\"results\":[]}"
        let session = MockURLSession(data: json.data(using: .utf8)!, statusCode: 200)
        let service = TavilyService(apiKey: "test-key", session: session)
        do {
            _ = try await service.search(query: "obscure query")
            XCTFail("Expected noResults")
        } catch TavilyError.noResults {
            // expected
        }
    }
}
