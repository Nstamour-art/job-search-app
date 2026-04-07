import SwiftUI

struct ClaudeKeyStepView: View {
    @ObservedObject var vm: OnboardingViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                StepHeader(
                    step: "Step 3 of 5",
                    title: "Connect Claude AI",
                    prompt: "Claude writes your resumes and cover letters. Add your API key to enable AI-powered document generation."
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Claude API Key").font(.caption.bold()).foregroundStyle(.secondary)
                    SecureField("sk-ant-...", text: $vm.claudeKey)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button {
                        openURL(URL(string: "https://console.anthropic.com/keys")!)
                    } label: {
                        Label("Get a key at console.anthropic.com", systemImage: "arrow.up.right.square")
                            .font(.caption)
                    }
                }

                VStack(spacing: 12) {
                    Button("Next") { vm.advance() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                        .disabled(vm.claudeKey.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button("Skip for now") { vm.advance() }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .navigationTitle("AI Setup")
        .navigationBarBackButtonHidden(true)
    }
}
