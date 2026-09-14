import SwiftUI

/// Sections de reglages accessibles depuis la colonne de gauche.
enum SettingsSection: String, CaseIterable, Identifiable {
    case aim, thresholds, advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aim: return "Visee (Stick vers souris)"
        case .thresholds: return "Seuils"
        case .advanced: return "Avance"
        }
    }

    var shortTitle: String {
        switch self {
        case .aim: return "Visee"
        case .thresholds: return "Seuils"
        case .advanced: return "Avance"
        }
    }

    var icon: String {
        switch self {
        case .aim: return "scope"
        case .thresholds: return "slider.horizontal.3"
        case .advanced: return "gearshape"
        }
    }
}

struct Sidebar: View {
    @ObservedObject var state: AppState
    @Binding var section: SettingsSection
    var onNewProfile: () -> Void
    var onRenameProfile: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    profiles
                    controllers
                    settings
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 14)
            }
            Spacer(minLength: 0)
            hint
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.bgSidebar)
    }

    // MARK: - En-tete

    private var header: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(LinearGradient(colors: [Theme.accentHover, Theme.accent],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 0) {
                Text("PadKey")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("v\(AppInfo.version)")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 16)
    }

    // MARK: - Profils

    private var profiles: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Profils") {
                Button(action: onNewProfile) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 20, height: 20)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                }
                .buttonStyle(.plain)
                .help("Nouveau profil")
            }
            .padding(.horizontal, 4)

            VStack(spacing: 2) {
                ForEach(state.profiles, id: \.name) { profile in
                    SidebarRow(icon: profile.symbol,
                               title: profile.name,
                               selected: profile.name == state.selectedProfileName) {
                        state.select(profileNamed: profile.name)
                    }
                }
                SidebarRow(icon: "plus.circle", title: "Nouveau profil", selected: false,
                           action: onNewProfile)
            }
        }
    }

    // MARK: - Manettes

    private var controllers: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Manettes detectees") {
                Button { state.refreshControllers() } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 20, height: 20)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.bgSurface))
                }
                .buttonStyle(.plain)
                .help("Rafraichir")
            }
            .padding(.horizontal, 4)

            if state.availableControllers.isEmpty {
                Panel(padding: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Aucune manette detectee")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                        Text("Connectez une manette en USB ou en Bluetooth.")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                VStack(spacing: 4) {
                    ForEach(state.availableControllers) { controller in
                        ControllerCard(controller: controller,
                                       selected: controller.isActive) {
                            state.choose(controller: controller.id)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Reglages

    private var settings: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel("Reglages du profil")
                .padding(.horizontal, 4)
            VStack(spacing: 2) {
                ForEach(SettingsSection.allCases) { item in
                    SidebarRow(icon: item.icon,
                               title: item.title,
                               selected: section == item) {
                        section = item
                    }
                }
            }
        }
    }

    private var hint: some View {
        Panel(padding: 12) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "lightbulb")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Astuce")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("Cliquez un bouton sur la manette pour modifier ce qu'il envoie.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
}

/// Carte d'une manette detectee.
private struct ControllerCard: View {
    let controller: ControllerInfo
    let selected: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(selected ? Theme.accent : Theme.textSecondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(shortName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(controller.isUsable ? Theme.success : Theme.textTertiary)
                            .frame(width: 5, height: 5)
                        Text(controller.isUsable ? "Connectee, profil \(controller.kind)"
                                                 : "Non exploitable")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .fill(selected ? Theme.accentSoft : (hovering ? Theme.bgSurfaceHover : Theme.bgSurface))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .strokeBorder(selected ? Theme.accentBorder : Theme.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.hover, value: hovering)
        .disabled(!controller.isUsable)
    }

    /// « DualSense Wireless Controller » est trop long pour la colonne.
    private var shortName: String {
        controller.name
            .replacingOccurrences(of: " Wireless Controller", with: "")
            .replacingOccurrences(of: " Controller", with: "")
    }
}
