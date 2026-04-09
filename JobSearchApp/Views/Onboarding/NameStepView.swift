import SwiftUI

struct NameStepView: View {
    @Bindable var vm: OnboardingViewModel
    @FocusState private var focusedField: Field?

    private enum Field: Hashable { case first, last }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                StepHeader(
                    step: "Step 1 of 5",
                    title: "What's your name?",
                    prompt: "We'll use this on your resume and cover letters."
                )

                VStack(spacing: 16) {
                    ValidatedField(
                        label: "First Name",
                        error: vm.didAttemptSubmit ? vm.nameError : nil
                    ) {
                        TextField("Jane", text: $vm.firstName)
                            .textContentType(.givenName)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .first)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .last }
                    }

                    ValidatedField(
                        label: "Last Name",
                        error: vm.didAttemptSubmit ? vm.lastNameError : nil
                    ) {
                        TextField("Doe", text: $vm.lastName)
                            .textContentType(.familyName)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .last)
                            .submitLabel(.done)
                            .onSubmit { attemptAdvance() }
                    }
                }

                Button("Next") { attemptAdvance() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .navigationTitle("Your Name")
        .navigationBarBackButtonHidden(true)
        .onChange(of: vm.firstName) {
            if vm.didAttemptSubmit { vm.validateName() }
        }
        .onChange(of: vm.lastName) {
            if vm.didAttemptSubmit { vm.validateName() }
        }
    }

    private func attemptAdvance() {
        if !vm.tryAdvance() {
            if vm.nameError != nil { focusedField = .first }
            else if vm.lastNameError != nil { focusedField = .last }
        }
    }
}
