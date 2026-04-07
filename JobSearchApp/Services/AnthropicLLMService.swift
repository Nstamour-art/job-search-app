import Foundation

enum LLMError: LocalizedError {
    case missingAPIKey
    case invalidResponse(Int)
    case decodingFailed(String)
    case maxRetriesExceeded

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Claude API key not configured. Add it in Settings."
        case .invalidResponse(let code): return "Unexpected API response: HTTP \(code)"
        case .decodingFailed(let detail): return "Failed to parse API response: \(detail)"
        case .maxRetriesExceeded: return "Request failed after retries. Please try again."
        }
    }
}

final class AnthropicLLMService: LLMService {
    private let apiKey: String
    private let session: URLSession
    private let retryDelay: TimeInterval
    private let maxRetries = 2
    private let model = "claude-sonnet-4-6"
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    init(apiKey: String, session: URLSession = .shared, retryDelay: TimeInterval = 1.0) {
        self.apiKey = apiKey
        self.session = session
        self.retryDelay = retryDelay
    }

    func complete(prompt: String, system: String) async throws -> String {
        var lastError: Error = LLMError.maxRetriesExceeded
        for attempt in 0..<maxRetries {
            do {
                return try await performRequest(prompt: prompt, system: system)
            } catch LLMError.invalidResponse(let code) where code == 429 || code == 503 {
                lastError = LLMError.invalidResponse(code)
                if attempt < maxRetries - 1 {
                    try await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                }
            } catch {
                throw error
            }
        }
        throw lastError
    }

    func stream(prompt: String, system: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = self.buildRequest(prompt: prompt, system: system, stream: true)
                    let (bytes, response) = try await self.session.bytes(for: request)
                    guard let httpResponse = response as? HTTPURLResponse,
                          httpResponse.statusCode == 200 else {
                        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                        continuation.finish(throwing: LLMError.invalidResponse(code))
                        return
                    }
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: "),
                              let data = line.dropFirst(6).data(using: .utf8),
                              let delta = try? JSONDecoder().decode(StreamDelta.self, from: data),
                              let text = delta.delta?.text else { continue }
                        continuation.yield(text)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Private

    private func performRequest(prompt: String, system: String) async throws -> String {
        let request = buildRequest(prompt: prompt, system: system, stream: false)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse(0)
        }
        guard httpResponse.statusCode == 200 else {
            throw LLMError.invalidResponse(httpResponse.statusCode)
        }
        guard let decoded = try? JSONDecoder().decode(MessagesResponse.self, from: data),
              let text = decoded.content.first?.text else {
            throw LLMError.decodingFailed(String(data: data, encoding: .utf8) ?? "")
        }
        return text
    }

    private func buildRequest(prompt: String, system: String, stream: Bool) -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": system,
            "stream": stream,
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return request
    }

    // MARK: - Response Types

    private struct MessagesResponse: Decodable {
        let content: [ContentBlock]
        struct ContentBlock: Decodable {
            let type: String
            let text: String?
        }
    }

    private struct StreamDelta: Decodable {
        let delta: Delta?
        struct Delta: Decodable {
            let type: String?
            let text: String?
        }
    }
}
