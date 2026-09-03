import SwiftUI

enum SERPyVisual {
    enum ColorToken {
        static let canvas = Color(red: 0.035, green: 0.039, blue: 0.047)
        static let surface = Color(red: 0.075, green: 0.082, blue: 0.094)
        static let raised = Color(red: 0.105, green: 0.115, blue: 0.132)
        static let hover = Color(red: 0.14, green: 0.155, blue: 0.18)
        static let border = Color.white.opacity(0.09)
        static let primaryText = Color.white.opacity(0.94)
        static let secondaryText = Color.white.opacity(0.62)
        static let tertiaryText = Color.white.opacity(0.38)
        static let accent = Color(red: 0.22, green: 0.49, blue: 0.98)
        static let accentSoft = accent.opacity(0.16)
        static let success = Color(red: 0.22, green: 0.82, blue: 0.53)
        static let warning = Color(red: 1.0, green: 0.66, blue: 0.24)
        static let danger = Color(red: 1.0, green: 0.34, blue: 0.38)
    }

    enum Space {
        static let compact: CGFloat = 6
        static let small: CGFloat = 10
        static let regular: CGFloat = 14
        static let large: CGFloat = 20
        static let section: CGFloat = 28
    }

    enum Radius {
        static let control: CGFloat = 10
        static let card: CGFloat = 14
        static let window: CGFloat = 22
    }
}

struct SERPyCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .background(SERPyVisual.ColorToken.surface)
        .clipShape(RoundedRectangle(cornerRadius: SERPyVisual.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: SERPyVisual.Radius.card, style: .continuous)
                .stroke(SERPyVisual.ColorToken.border, lineWidth: 1)
        }
    }
}

struct SERPySectionTitle: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(0.8)
            .foregroundStyle(SERPyVisual.ColorToken.tertiaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

struct SERPyArrowMark: View {
    var color: Color = .white

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            Path { path in
                path.move(to: CGPoint(x: width * 0.12, y: height * 0.48))
                path.addLine(to: CGPoint(x: width * 0.50, y: height * 0.12))
                path.addLine(to: CGPoint(x: width * 0.88, y: height * 0.48))
                path.addLine(to: CGPoint(x: width * 0.88, y: height * 0.78))
                path.addLine(to: CGPoint(x: width * 0.50, y: height * 0.43))
                path.addLine(to: CGPoint(x: width * 0.12, y: height * 0.78))
                path.closeSubpath()
            }
            .fill(color)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct SERPyHoverButtonStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: SERPyVisual.Radius.control, style: .continuous)
                    .fill(background(isPressed: configuration.isPressed))
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.12), value: isHovered)
            .onHover { isHovered = $0 }
    }

    private func background(isPressed: Bool) -> Color {
        if isPressed { return SERPyVisual.ColorToken.accentSoft }
        if isHovered { return SERPyVisual.ColorToken.hover }
        return .clear
    }
}
