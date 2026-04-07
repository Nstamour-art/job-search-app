import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var anthropicKey: String = ""
    @Published var tavilyKey: String = ""
    @Published var defaultExportFormat: ExportFormat = .pdf
    @Published var saveMessage: String?

    private let keychain = KeychainManager.shared

    enum ExportFormat: String, CaseIterable, Identifiable {
        case pdf = "PDF"
        case docx = "DOCX"
        case both = "Both"
        var id: String { rawValue }
    }

    func loadKeys() {
        anthropicKey = (try? keychain.retrieve(forKey: KeychainKeys.anthropicAPIKey)) ?? ""
        tavilyKey    = (try? keychain.retrieve(forKey: KeychainKeys.tavilyAPIKey))    ?? ""
        let raw = UserDefaults.standard.string(forKey: "exportFormat") ?? ExportFormat.pdf.rawValue
        defaultExportFormat = ExportFormat(rawValue: raw) ?? .pdf
    }

    func saveKeys(container: AppContainer) {
        do {
            try keychain.save(anthropicKey, forKey: KeychainKeys.anthropicAPIKey)
            try keychain.save(tavilyKey,    forKey: KeychainKeys.tavilyAPIKey)
            UserDefaults.standard.set(defaultExportFormat.rawValue, forKey: "exportFormat")
            container.refreshLLMService()
            saveMessage = "Saved"
        } catch {
            saveMessage = "Error: \(error.localizedDescription)"
        }
    }
}
