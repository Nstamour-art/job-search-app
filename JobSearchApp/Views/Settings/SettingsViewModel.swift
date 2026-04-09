import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    var anthropicKey: String = ""
    var tavilyKey: String = ""
    var defaultExportFormat: ExportFormat = .pdf
    var saveMessage: String?

    /// Whether a brief "Saved" confirmation is currently visible.
    var showSavedConfirmation = false

    // Snapshots taken after load for change detection
    private var initialAnthropicKey: String = ""
    private var initialTavilyKey: String = ""
    private var initialExportFormat: ExportFormat = .pdf

    var hasChanges: Bool {
        anthropicKey != initialAnthropicKey ||
        tavilyKey != initialTavilyKey ||
        defaultExportFormat != initialExportFormat
    }

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
        snapshotInitialValues()
    }

    func saveKeys(container: AppContainer) {
        do {
            try KeychainManager.shared.save(anthropicKey, forKey: KeychainKeys.anthropicAPIKey)
            try KeychainManager.shared.save(tavilyKey,    forKey: KeychainKeys.tavilyAPIKey)
            UserDefaults.standard.set(defaultExportFormat.rawValue, forKey: "exportFormat")
            container.refreshLLMService()
            snapshotInitialValues()

            // Brief confirmation then fade
            showSavedConfirmation = true
            saveMessage = nil
        } catch {
            saveMessage = "Error: \(error.localizedDescription)"
        }
    }

    /// Dismiss the "Saved" toast (called after a delay).
    func dismissSavedConfirmation() {
        showSavedConfirmation = false
    }

    private func snapshotInitialValues() {
        initialAnthropicKey = anthropicKey
        initialTavilyKey = tavilyKey
        initialExportFormat = defaultExportFormat
    }
}
