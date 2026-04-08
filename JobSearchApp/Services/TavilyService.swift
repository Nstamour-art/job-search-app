import Foundation

enum TavilyError: LocalizedError {
    case noResults
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .noResults:               return "Tavily returned no content for this URL."
        case .httpError(let code):     return "Tavily request failed with status \(code)."
        }
    }
}

struct TavilySearchResult {
    let title: String
    let url: String
    let content: String
}

final class TavilyService {
    private let apiKey: String
    private let session: any URLSessionProtocol

    init(apiKey: String, session: any URLSessionProtocol = URLSession.shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // MARK: - Extract (existing)

    func fetchContent(url: String) async throws -> String {
        let endpoint = URL(string: "https://api.tavily.com/extract")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["urls": [url], "api_key": apiKey]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw TavilyError.httpError(http.statusCode)
        }

        struct TavilyExtractResponse: Decodable {
            struct Result: Decodable { let raw_content: String }
            let results: [Result]
        }
        let decoded = try JSONDecoder().decode(TavilyExtractResponse.self, from: data)
        guard let first = decoded.results.first else { throw TavilyError.noResults }
        return first.raw_content
    }

    // MARK: - Search

    func search(query: String, maxResults: Int = 7) async throws -> [TavilySearchResult] {
        let endpoint = URL(string: "https://api.tavily.com/search")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "api_key": apiKey,
            "query": query,
            "max_results": maxResults,
            "search_depth": "basic"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw TavilyError.httpError(http.statusCode)
        }

        struct TavilySearchResponse: Decodable {
            struct Result: Decodable {
                let title: String
                let url: String
                let content: String
            }
            let results: [Result]
        }
        let decoded = try JSONDecoder().decode(TavilySearchResponse.self, from: data)
        guard !decoded.results.isEmpty else { throw TavilyError.noResults }
        return decoded.results.map { TavilySearchResult(title: $0.title, url: $0.url, content: $0.content) }
    }
}
