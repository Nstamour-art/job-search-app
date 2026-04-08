import SwiftUI

struct SettingsView: View {
    @Environment(AppContainer.self) private var container
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        Form {
            Section {
                SecureField("Claude API Key", text: $viewModel.anthropicKey)
                    .textContentType(.password)
                    .autocorrectionDisabled()
            } header: {
                Text("AI")
            } footer: {
                Text("Required for document generation. Get your key at console.anthropic.com")
            }

            Section {
                SecureField("Tavily API Key", text: $viewModel.tavilyKey)
                    .textContentType(.password)
                    .autocorrectionDisabled()
            } header: {
                Text("Job Search")
            } footer: {
                Text("Required for AI job discovery. Get your key at tavily.com")
            }

            Section("Documents") {
                Picker("Default Export Format", selection: $viewModel.defaultExportFormat) {
                    ForEach(SettingsViewModel.ExportFormat.allCases) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
            }

            Section {
                Button("Save") {
                    viewModel.saveKeys(container: container)
                }
                .frame(maxWidth: .infinity)
                if let message = viewModel.saveMessage {
                    Text(message)
                        .foregroundStyle(message.hasPrefix("Error") ? .red : .green)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Settings")
        .onAppear { viewModel.loadKeys() }
    }
}
