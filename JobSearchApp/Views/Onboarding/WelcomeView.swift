import SwiftUI

struct WelcomeView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image(systemName: "briefcase.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            VStack(spacing: 12) {
                Text("Welcome to JobSearch")
                    .font(.largeTitle.bold())
                Text("Let's build your career profile so we can tailor every resume and cover letter to each job you apply to.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Spacer()
            Button(action: onStart) {
                Text("Build My Profile")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }
}
