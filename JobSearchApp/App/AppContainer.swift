import Foundation
import Observation

@Observable
@MainActor
final class AppContainer {
    var llmService: any LLMService

    init() {
        llmService = AppContainer.buildLLMService()
    }

    func refreshLLMService() {
        llmService = AppContainer.buildLLMService()
    }

    private static func buildLLMService() -> any LLMService {
        if let key = try? KeychainManager.shared.retrieve(forKey: KeychainKeys.anthropicAPIKey),
           !key.isEmpty {
            return AnthropicLLMService(apiKey: key)
        }
        return MockLLMService(response: "")
    }
}

enum KeychainKeys {
    static let anthropicAPIKey = "com.jobsearch.anthropic.apikey"
    static let tavilyAPIKey    = "com.jobsearch.tavily.apikey"
}
