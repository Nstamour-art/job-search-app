import Foundation

@MainActor
final class AppContainer: ObservableObject {
    let keychain = KeychainManager.shared
    lazy var llmService: any LLMService = makeLLMService()

    private func makeLLMService() -> any LLMService {
        if let key = try? keychain.retrieve(forKey: KeychainKeys.anthropicAPIKey),
           !key.isEmpty {
            return AnthropicLLMService(apiKey: key)
        }
        // Returns mock with empty string until user configures API key.
        // SettingsViewModel will recreate llmService after key is saved.
        return MockLLMService(response: "")
    }

    func refreshLLMService() {
        llmService = makeLLMService()
    }
}

enum KeychainKeys {
    static let anthropicAPIKey = "com.jobsearch.anthropic.apikey"
    static let tavilyAPIKey    = "com.jobsearch.tavily.apikey"
}
