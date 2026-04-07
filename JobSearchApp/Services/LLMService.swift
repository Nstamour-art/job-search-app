import Foundation

protocol LLMService {
    func complete(prompt: String, system: String) async throws -> String
    func stream(prompt: String, system: String) -> AsyncThrowingStream<String, Error>
}

final class MockLLMService: LLMService {
    private let response: String
    private let error: Error?

    init(response: String = "", error: Error? = nil) {
        self.response = response
        self.error = error
    }

    func complete(prompt: String, system: String) async throws -> String {
        if let error { throw error }
        return response
    }

    func stream(prompt: String, system: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            if let error = self.error {
                continuation.finish(throwing: error)
            } else {
                continuation.yield(self.response)
                continuation.finish()
            }
        }
    }
}
