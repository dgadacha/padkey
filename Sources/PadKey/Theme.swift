import SwiftUI

/// Palette et mesures communes, pour que l'interface reste coherente
/// en clair comme en sombre.
enum Theme {

    static let accent = Color(red: 0.31, green: 0.60, blue: 1.00)
    static let accentSoft = Color(red: 0.31, green: 0.60, blue: 1.00).opacity(0.16)
    static let warning = Color(red: 0.98, green: 0.62, blue: 0.24)
    static let good = Color(red: 0.26, green: 0.78, blue: 0.48)

    static let corner: CGFloat = 10
    static let cardCorner: CGFloat = 14

    static func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }
}

/// Carte de contenu : fond doux, bord fin, coins arrondis.
struct Card<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardCorner, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }
}

/// Pastille compacte, utilisee pour les touches assignees et les etats.
struct Pill: View {
    let text: String
    var tint: Color = .secondary
    var filled = false

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(filled ? tint.opacity(0.18) : Color.primary.opacity(0.06))
            )
            .foregroundStyle(filled ? tint : Color.secondary)
    }
}

/// Interrupteur principal, plus visible qu'un Toggle standard.
struct PowerToggle: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Circle()
                    .fill(isOn ? Theme.good : Color.secondary.opacity(0.45))
                    .frame(width: 8, height: 8)
                    .shadow(color: isOn ? Theme.good.opacity(0.8) : .clear, radius: 4)
                Text(isOn ? "Mapping actif" : "En pause")
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(isOn ? Theme.good.opacity(0.14) : Color.primary.opacity(0.06))
            )
            .overlay(
                Capsule().strokeBorder(isOn ? Theme.good.opacity(0.35) : Color.primary.opacity(0.10), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
