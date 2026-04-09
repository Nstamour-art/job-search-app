import SwiftUI

struct TavilyKeyStepView: View {
    @Bindable var vm: OnboardingViewModel
    let onFinish: () -> Void
    @Environment(\.openURL) private var openURL

    private var keyIsValid: Bool {
        !vm.tavilyKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                StepHeader(
                    step: "Step 5 of 5",
                    title: "AI Job Search",
                    prompt: "Tavily finds job postings from across the web. Add your API key to search for jobs directly in the app."
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tavily API Key").font(.caption.bold()).foregroundStyle(.secondary)
                    SecureField("tvly-...", text: $vm.tavilyKey)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.done)
                        .onSubmit { if keyIsValid { onFinish() } }

                    Button {
                        openURL(URL(string: "https://app.tavily.com/home")!)
                    } label: {
                        Label("Get a free key at tavily.com", systemImage: "arrow.up.right.square")
                            .font(.caption)
                    }
                }

                VStack(spacing: 12) {
                    Button("Finish & Start Job Searching") {
                        onFinish()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(!keyIsValid)

                    Button("Skip for now") {
                        onFinish()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .navigationTitle("Job Search")
        .navigationBarBackButtonHidden(true)
    }
}
