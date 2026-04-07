import Foundation

enum TavilyError: LocalizedError {
    case noResults
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .noResults:    return "Tavily returned no content for this URL."
        case .httpError(let code): return "Tavily request failed with status \(code)."
        }
    }
}

final class TavilyService {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func fetchContent(url: String) async throws -> String {
        let endpoint = URL(string: "https://api.tavily.com/extract")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["urls": [url], "api_key": apiKey]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw TavilyError.httpError(http.statusCode)
        }

        struct TavilyResponse: Decodable {
            struct Result: Decodable { let raw_content: String }
            let results: [Result]
        }
        let decoded = try JSONDecoder().decode(TavilyResponse.self, from: data)
        guard let first = decoded.results.first else { throw TavilyError.noResults }
        return first.raw_content
    }
}
