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

    // Tests AnthropicLLMService request construction without hitting the real API.
    // Uses a custom URLProtocol to intercept URLSession requests.

    func test_anthropicService_buildsCorrectRequest() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "test-key-123")
            XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
            XCTAssertEqual(request.value(forHTTPHeaderField: "content-type"), "application/json")

            let body = """
            {"content":[{"type":"text","text":"Hello from Claude"}],"stop_reason":"end_turn"}
            """
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(body.utf8))
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let service = AnthropicLLMService(apiKey: "test-key-123", session: session)

        let result = try await service.complete(prompt: "Say hello", system: "You are helpful.")
        XCTAssertEqual(result, "Hello from Claude")
    }

    func test_anthropicService_retries_on429() async throws {
        var callCount = 0
        MockURLProtocol.requestHandler = { request in
            callCount += 1
            if callCount < 2 {
                let response = HTTPURLResponse(
                    url: request.url!, statusCode: 429,
                    httpVersion: nil, headerFields: nil
                )!
                return (response, Data())
            }
            let body = """
            {"content":[{"type":"text","text":"retry worked"}],"stop_reason":"end_turn"}
            """
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200,
                httpVersion: nil, headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(body.utf8))
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let service = AnthropicLLMService(apiKey: "test-key-123", session: session, retryDelay: 0)

        let result = try await service.complete(prompt: "test", system: "")
        XCTAssertEqual(result, "retry worked")
        XCTAssertEqual(callCount, 2)
    }
}

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
