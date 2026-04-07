import XCTest
@testable import JobSearchApp

final class AnthropicLLMServiceTests: XCTestCase {

    func test_mockLLMService_returnsConfiguredResponse() async throws {
        let mock = MockLLMService(response: "Hello from mock")
        let result = try await mock.complete(prompt: "Say hello", system: "You are helpful.")
        XCTAssertEqual(result, "Hello from mock")
    }

    func test_mockLLMService_stream_emitsChunks() async throws {
        let mock = MockLLMService(response: "chunk1 chunk2 chunk3")
        var collected = ""
        for try await chunk in mock.stream(prompt: "stream test", system: "You are helpful.") {
            collected += chunk
        }
        XCTAssertEqual(collected, "chunk1 chunk2 chunk3")
    }

    func test_mockLLMService_canThrow() async {
        let mock = MockLLMService(error: URLError(.notConnectedToInternet))
        do {
            _ = try await mock.complete(prompt: "fail", system: "")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is URLError)
        }
    }
}
