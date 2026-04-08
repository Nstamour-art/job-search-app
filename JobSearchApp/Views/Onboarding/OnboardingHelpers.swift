import SwiftUI

struct StepHeader: View {
    let step: String
    let title: String
    let prompt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(step).font(.caption).foregroundStyle(.secondary)
            Text(title).font(.title2.bold())
            Text(prompt).font(.body).foregroundStyle(.secondary)
        }
    }
}

struct LabeledTextField: View {
    let label: String
    @Binding var text: String

    init(_ label: String, text: Binding<String>) {
        self.label = label
        self._text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, text: $text).textFieldStyle(.roundedBorder)
        }
    }
}

struct LabeledOptionalTextField: View {
    let label: String
    @Binding var text: String?

    init(_ label: String, text: Binding<String?>) {
        self.label = label
        self._text = text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, text: Binding(
                get: { text ?? "" },
                set: { text = $0.isEmpty ? nil : $0 }
            )).textFieldStyle(.roundedBorder)
        }
    }
}

struct SkillsChipsView: View {
    @Binding var skills: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(skills, id: \.self) { skill in
                HStack(spacing: 4) {
                    Text(skill).font(.caption)
                    Button { skills.removeAll { $0 == skill } } label: {
                        Image(systemName: "xmark").font(.caption2)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Capsule())
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rawWidth = proposal.width ?? 0
        let width = rawWidth.isFinite ? rawWidth : 0
        var x: CGFloat = 0, y: CGFloat = 0, lineH: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 { y += lineH + spacing; x = 0; lineH = 0 }
            x += size.width + spacing
            lineH = max(lineH, size.height)
        }
        return CGSize(width: width, height: y + lineH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineH: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX { y += lineH + spacing; x = bounds.minX; lineH = 0 }
            sub.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            lineH = max(lineH, size.height)
        }
    }
}
