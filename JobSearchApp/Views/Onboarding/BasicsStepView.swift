import SwiftUI

struct BasicsStepView: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                StepHeader(
                    step: "1 of 5",
                    title: "Contact Info",
                    prompt: "Tell me your name, email, phone number, location, and any relevant links (LinkedIn, GitHub, portfolio)."
                )

                TextEditor(text: $vm.basicsInput)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                if vm.isLoading {
                    ProgressView("Extracting info…").frame(maxWidth: .infinity)
                } else if let error = vm.errorMessage {
                    Text(error).foregroundStyle(.red).font(.caption)
                }

                Button("Extract with AI") { Task { await vm.parseBasics() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(vm.basicsInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || vm.isLoading)

                if var basics = vm.parsedBasics {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Confirm your info").font(.headline)
                        LabeledTextField("Name", text: Binding(
                            get: { vm.parsedBasics?.name ?? "" },
                            set: { vm.parsedBasics?.name = $0 }
                        ))
                        LabeledTextField("Email", text: Binding(
                            get: { vm.parsedBasics?.email ?? "" },
                            set: { vm.parsedBasics?.email = $0 }
                        ))
                        LabeledOptionalTextField("Phone", text: Binding(
                            get: { vm.parsedBasics?.phone },
                            set: { vm.parsedBasics?.phone = $0 }
                        ))
                        LabeledTextField("Location", text: Binding(
                            get: { vm.parsedBasics?.location ?? "" },
                            set: { vm.parsedBasics?.location = $0 }
                        ))
                        LabeledOptionalTextField("LinkedIn", text: Binding(
                            get: { vm.parsedBasics?.linkedIn },
                            set: { vm.parsedBasics?.linkedIn = $0 }
                        ))
                        LabeledOptionalTextField("GitHub", text: Binding(
                            get: { vm.parsedBasics?.github },
                            set: { vm.parsedBasics?.github = $0 }
                        ))
                        LabeledOptionalTextField("Website", text: Binding(
                            get: { vm.parsedBasics?.website },
                            set: { vm.parsedBasics?.website = $0 }
                        ))
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Button("Next →") { vm.advance() }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
        .navigationTitle("About You")
    }
}
