import SwiftUI

struct EmailStepView: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                StepHeader(
                    step: "Step 2 of 5",
                    title: "Contact Info",
                    prompt: "Your email and location appear on your resume. Phone is optional."
                )

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Email").font(.caption.bold()).foregroundStyle(.secondary)
                        TextField("jane@example.com", text: $vm.email)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location").font(.caption.bold()).foregroundStyle(.secondary)
                        TextField("Toronto, ON", text: $vm.location)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Phone (optional)").font(.caption.bold()).foregroundStyle(.secondary)
                        TextField("+1 416 555 0100", text: $vm.phone)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)
                    }
                }

                Button("Next") { vm.advance() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(!vm.canAdvanceFromEmail)
            }
            .padding()
        }
        .navigationTitle("Contact Info")
        .navigationBarBackButtonHidden(true)
    }
}
