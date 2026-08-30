import SwiftUI

enum SeguraNotasStyle {
    static let ink = Color.black.opacity(0.82)
    static let secondaryInk = Color.black.opacity(0.58)
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let hairline = Color.black.opacity(0.10)
    static let nsInk = NSColor.black.withAlphaComponent(0.82)
}

struct SeguraNotasButtonStyle: ButtonStyle {
    var emphasized = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(emphasized ? Color.white : SeguraNotasStyle.ink)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(
                emphasized ? Color.black.opacity(configuration.isPressed ? 0.42 : 0.32) : Color.white.opacity(configuration.isPressed ? 0.40 : 0.68),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.22, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

struct ColorDot: View {
    let noteColor: NoteColor
    let selected: Bool

    var body: some View {
        Circle()
            .fill(noteColor.color)
            .frame(width: 21, height: 21)
            .overlay(Circle().stroke(Color.black.opacity(selected ? 0.58 : 0.12), lineWidth: selected ? 2 : 1))
            .overlay {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(SeguraNotasStyle.ink)
                }
            }
    }
}

extension Date {
    var seguraNotasRelative: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}
