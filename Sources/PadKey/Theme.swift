import SwiftUI

/// Jetons de style de l'interface. L'application assume un theme sombre unique,
/// legerement violet, qui fait partie de son identite.
enum Theme {

    // MARK: - Surfaces

    static let bgApp = Color(hex: 0x0D0E14)
    static let bgSidebar = Color(hex: 0x11121A)
    static let bgSurface = Color(hex: 0x151720)
    static let bgSurfaceHover = Color(hex: 0x1B1E29)
    static let bgSurfaceActive = Color(hex: 0x202536)

    static let borderSubtle = Color.white.opacity(0.07)
    static let borderMedium = Color.white.opacity(0.11)

    // MARK: - Texte

    static let textPrimary = Color.white.opacity(0.94)
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.38)

    // MARK: - Accent et etats

    static let accent = Color(hex: 0x2878FF)
    static let accentHover = Color(hex: 0x4389FF)
    static let accentSoft = Color(hex: 0x2878FF).opacity(0.14)
    static let accentBorder = Color(hex: 0x2878FF).opacity(0.45)

    static let success = Color(hex: 0x30D158)
    static let warning = Color(hex: 0xFF9F0A)
    static let danger = Color(hex: 0xFF453A)

    // MARK: - Rayons

    static let radiusControl: CGFloat = 7
    static let radiusInput: CGFloat = 8
    static let radiusCard: CGFloat = 11
    static let radiusPanel: CGFloat = 13

    // MARK: - Animations

    static let hover = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.12)
    static let selection = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.16)

    // MARK: - Typographie

    static func screenTitle() -> Font { .system(size: 18, weight: .semibold) }
    static func cardTitle() -> Font { .system(size: 13, weight: .semibold) }
    static func body() -> Font { .system(size: 13, weight: .regular) }
    static func secondary() -> Font { .system(size: 12) }
    static func sectionLabel() -> Font { .system(size: 11, weight: .semibold) }
    static func technical() -> Font { .system(size: 12, weight: .medium, design: .monospaced) }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

// MARK: - Briques reutilisables

/// Titre de section, en petites capitales espacees.
struct SectionLabel: View {
    let text: String
    var trailing: AnyView?

    init(_ text: String) {
        self.text = text
        self.trailing = nil
    }

    init<T: View>(_ text: String, @ViewBuilder trailing: () -> T) {
        self.text = text
        self.trailing = AnyView(trailing())
    }

    var body: some View {
        HStack {
            Text(text.uppercased())
                .font(Theme.sectionLabel())
                .tracking(0.7)
                .foregroundStyle(Theme.textTertiary)
            Spacer()
            trailing
        }
    }
}

/// Panneau de contenu : surface sombre, bord fin, coins arrondis.
struct Panel<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .fill(Theme.bgSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .strokeBorder(Theme.borderSubtle, lineWidth: 1)
            )
    }
}

/// Ligne de navigation de la colonne de gauche.
struct SidebarRow: View {
    let icon: String
    let title: String
    var subtitle: String?
    let selected: Bool
    var trailing: AnyView?
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 16)
                    .foregroundStyle(selected ? Theme.accent : Theme.textSecondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: selected ? .medium : .regular))
                        .foregroundStyle(selected ? Theme.textPrimary : Theme.textSecondary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                Spacer(minLength: 4)
                trailing
            }
            .padding(.horizontal, 10)
            .frame(height: subtitle == nil ? 34 : 42)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                    .fill(selected ? Theme.accentSoft : (hovering ? Theme.bgSurfaceHover : .clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                    .strokeBorder(selected ? Theme.accentBorder : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
    }
}

/// Bouton discret de la barre d'outils.
struct ToolbarButton: View {
    let title: String
    var icon: String?
    var primary = false
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 11, weight: .medium))
                }
                if !title.isEmpty {
                    Text(title).font(.system(size: 12, weight: primary ? .semibold : .medium))
                }
            }
            .foregroundStyle(primary ? Color.white : Theme.textSecondary)
            .padding(.horizontal, title.isEmpty ? 9 : 11)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                    .fill(primary ? (hovering ? Theme.accentHover : Theme.accent)
                                  : (hovering ? Theme.bgSurfaceHover : Theme.bgSurface))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                    .strokeBorder(primary ? .clear : Theme.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
    }
}

/// Touche de clavier stylisee, pour afficher une action.
struct KeyCap: View {
    let text: String
    var active = false

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(active ? Color.white : Theme.textPrimary)
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(active ? Theme.accent : Theme.bgSurfaceActive)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(active ? .clear : Theme.borderMedium, lineWidth: 1)
            )
    }
}
