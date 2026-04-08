import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    var anthropicKey: String = ""
    var tavilyKey: String = ""
    var defaultExportFormat: ExportFormat = .pdf
    var saveMessage: String?

    enum ExportFormat: String, CaseIterable, Identifiable {
        case pdf = "PDF"
        case docx = "DOCX"
        case both = "Both"
        var id: String { rawValue }
    }

    func loadKeys() {
        anthropicKey = (try? KeychainManager.shared.retrieve(forKey: KeychainKeys.anthropicAPIKey)) ?? ""
        tavilyKey    = (try? KeychainManager.shared.retrieve(forKey: KeychainKeys.tavilyAPIKey)) ?? ""
        let raw = UserDefaults.standard.string(forKey: "exportFormat") ?? ExportFormat.pdf.rawValue
        defaultExportFormat = ExportFormat(rawValue: raw) ?? .pdf
    }

    func saveKeys(container: AppContainer) {
        do {
            try KeychainManager.shared.save(anthropicKey, forKey: KeychainKeys.anthropicAPIKey)
            try KeychainManager.shared.save(tavilyKey,    forKey: KeychainKeys.tavilyAPIKey)
            UserDefaults.standard.set(defaultExportFormat.rawValue, forKey: "exportFormat")
            container.refreshLLMService()
            saveMessage = "Saved"
        } catch {
            saveMessage = "Error: \(error.localizedDescription)"
        }
    }
}
