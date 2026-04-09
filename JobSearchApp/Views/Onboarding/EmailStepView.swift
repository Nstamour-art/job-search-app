import SwiftUI

struct EmailStepView: View {
    @Bindable var vm: OnboardingViewModel
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case email, location, phone }

    /// Display-formatted phone string derived from raw digits.
    private var phoneDisplay: Binding<String> {
        Binding(
            get: {
                let digits = InputValidator.phoneDigits(vm.phone)
                return digits.isEmpty ? "" : InputValidator.formattedPhone(digits)
            },
            set: { newValue in
                vm.phone = InputValidator.phoneDigits(newValue)
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                StepHeader(
                    step: "Step 2 of 5",
                    title: "Contact Info",
                    prompt: "Your email and location appear on your resume."
                )

                VStack(spacing: 16) {
                    ValidatedField(
                        label: "Email",
                        error: vm.didAttemptSubmit ? vm.emailError : nil
                    ) {
                        TextField("jane@example.com", text: $vm.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .focused($focusedField, equals: .email)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .location }
                    }

                    ValidatedField(
                        label: "Location",
                        error: vm.didAttemptSubmit ? vm.locationError : nil
                    ) {
                        TextField("Toronto, ON", text: $vm.location)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .location)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .phone }
                    }

                    ValidatedField(
                        label: "Phone (optional)",
                        error: vm.didAttemptSubmit ? vm.phoneError : nil
                    ) {
                        TextField("(416) 555-0100", text: phoneDisplay)
                            .textContentType(.telephoneNumber)
                            .keyboardType(.phonePad)
                            .focused($focusedField, equals: .phone)
                    }
                }

                Button("Next") { attemptAdvance() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .navigationTitle("Contact Info")
        .navigationBarBackButtonHidden(true)
        .onChange(of: vm.email) { if vm.didAttemptSubmit { vm.validateContact() } }
        .onChange(of: vm.phone) { if vm.didAttemptSubmit { vm.validateContact() } }
        .onChange(of: vm.location) { if vm.didAttemptSubmit { vm.validateContact() } }
    }

    private func attemptAdvance() {
        if !vm.tryAdvance() {
            if vm.emailError != nil { focusedField = .email }
            else if vm.locationError != nil { focusedField = .location }
            else if vm.phoneError != nil { focusedField = .phone }
        }
    }
}
