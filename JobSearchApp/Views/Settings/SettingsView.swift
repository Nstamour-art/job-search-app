import SwiftUI

struct SettingsView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModel = SettingsViewModel()

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
                .disabled(!viewModel.hasChanges)
            }
        }
        .navigationTitle("Settings")
        .onAppear { viewModel.loadKeys() }
        // Brief green "Saved" toast overlay
        .overlay(alignment: .bottom) {
            if viewModel.showSavedConfirmation {
                savedToast
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        // Auto-dismiss after 1.5 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                viewModel.dismissSavedConfirmation()
                            }
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.showSavedConfirmation)
        // Clear stale error on next edit
        .onChange(of: viewModel.anthropicKey) { viewModel.saveMessage = nil }
        .onChange(of: viewModel.tavilyKey) { viewModel.saveMessage = nil }
    }

    private var savedToast: some View {
        Text("Saved")
            .font(.subheadline.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(.green, in: Capsule())
            .padding(.bottom, 24)
    }
}
