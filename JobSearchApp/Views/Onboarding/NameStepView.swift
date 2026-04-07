import SwiftUI

struct NameStepView: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                StepHeader(
                    step: "Step 1 of 5",
                    title: "What's your name?",
                    prompt: "We'll use this on your resume and cover letters."
                )

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("First Name").font(.caption.bold()).foregroundStyle(.secondary)
                        TextField("Jane", text: $vm.firstName)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.givenName)
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Name").font(.caption.bold()).foregroundStyle(.secondary)
                        TextField("Doe", text: $vm.lastName)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.familyName)
                            .autocorrectionDisabled()
                    }
                }

                Button("Next") { vm.advance() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(!vm.canAdvanceFromName)
            }
            .padding()
        }
        .navigationTitle("Your Name")
        .navigationBarBackButtonHidden(true)
    }
}
