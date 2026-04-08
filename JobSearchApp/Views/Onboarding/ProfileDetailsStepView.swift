import SwiftUI

struct ProfileDetailsStepView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                StepHeader(
                    step: "Step 4 of 5",
                    title: "Your Background",
                    prompt: "Add the basics now. You can fill in work history, education, and projects in full from the Profile tab."
                )

                VStack(alignment: .leading, spacing: 20) {
                    // Current role
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Role").font(.subheadline.bold())

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Job Title").font(.caption.bold()).foregroundStyle(.secondary)
                            TextField("iOS Engineer", text: $vm.currentJobTitle)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Company").font(.caption.bold()).foregroundStyle(.secondary)
                            TextField("Acme Corp", text: $vm.currentCompany)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                        }
                    }

                    Divider()

                    // Skills
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Key Skills").font(.subheadline.bold())
                        Text("Separate with commas").font(.caption).foregroundStyle(.secondary)
                        TextField("Swift, SwiftUI, Python, Git", text: $vm.skillsText)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                    }

                    Divider()

                    // Education
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Education").font(.subheadline.bold())

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Institution").font(.caption.bold()).foregroundStyle(.secondary)
                            TextField("University of Toronto", text: $vm.educationInstitution)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Degree").font(.caption.bold()).foregroundStyle(.secondary)
                                TextField("Bachelor", text: $vm.educationDegree)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Field").font(.caption.bold()).foregroundStyle(.secondary)
                                TextField("Computer Science", text: $vm.educationField)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                            }
                        }
                    }
                }

                Button("Next") { vm.advance() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)

                Button("Skip for now") { vm.advance() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .navigationTitle("Profile Basics")
        .navigationBarBackButtonHidden(true)
    }
}
