import SwiftUI
import AppKit

// MARK: - Slider sobre

/// Rail fin, pastille discrete, valeur a droite du libelle.
struct SliderField: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    @State private var dragging = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(format(value))
                    .font(Theme.technical())
                    .foregroundStyle(Theme.textPrimary)
            }
            GeometryReader { geo in
                let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
                let x = max(0, min(geo.size.width, geo.size.width * fraction))
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10)).frame(height: 4)
                    Capsule().fill(Theme.accent).frame(width: x, height: 4)
                    Circle()
                        .fill(Color.white)
                        .frame(width: dragging ? 13 : 11, height: dragging ? 13 : 11)
                        .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                        .offset(x: x - (dragging ? 6.5 : 5.5))
                }
                .frame(height: 14)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            dragging = true
                            let ratio = max(0, min(1, drag.location.x / geo.size.width))
                            let raw = range.lowerBound + ratio * (range.upperBound - range.lowerBound)
                            value = (raw / step).rounded() * step
                        }
                        .onEnded { _ in dragging = false }
                )
            }
            .frame(height: 14)
        }
    }
}

/// Case a cocher discrete, au style de l'application.
struct CheckboxField: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isOn ? Theme.accent : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(isOn ? .clear : Theme.borderMedium, lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .opacity(isOn ? 1 : 0)
                    )
                    .frame(width: 15, height: 15)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Panneau de reglages

struct SettingsPanel: View {
    @ObservedObject var state: AppState
    @Binding var section: SettingsSection

    var body: some View {
        Panel(padding: 12) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    Image(systemName: section.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.accent)
                    Text(section.shortTitle)
                        .font(Theme.cardTitle())
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                }
                .padding(.bottom, 9)

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        switch section {
                        case .aim: aim
                        case .thresholds: thresholds
                        case .advanced: advanced
                        }
                    }
                    .padding(.trailing, 2)
                }
            }
        }
    }

    private var aim: some View {
        Group {
            HStack(spacing: 6) {
                ForEach([MouseSource.rightStick, .leftStick, .none], id: \.self) { source in
                    SegmentButton(title: source.shortLabel,
                                  selected: state.selectedProfile.mouse.source == source) {
                        var profile = state.selectedProfile
                        profile.mouse.source = source
                        state.update(profile)
                    }
                }
            }
            if state.selectedProfile.mouse.source != .none {
                SliderField(title: "Vitesse", value: mouse(\.speed),
                            range: 200...4000, step: 50) { "\(Int($0)) px/s" }
                SliderField(title: "Zone morte", value: mouse(\.deadzone),
                            range: 0...0.4, step: 0.01) { String(format: "%.0f %%", $0 * 100) }
                SliderField(title: "Courbe", value: mouse(\.curve),
                            range: 1...4, step: 0.1) { String(format: "%.1f", $0) }
                SliderField(title: "Axe vertical", value: mouse(\.verticalScale),
                            range: 0.2...1.5, step: 0.05) { String(format: "%.2f x", $0) }
                CheckboxField(title: "Inverser l'axe vertical", isOn: mouseBool(\.invertY))
            } else {
                Text("Aucun stick ne pilote la souris. Leurs directions peuvent alors etre assignees a des touches.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var thresholds: some View {
        Group {
            SliderField(title: "Direction du stick", value: profileValue(\.stickDeadzone),
                        range: 0.2...0.8, step: 0.05) { String(format: "%.0f %%", $0 * 100) }
            Text("Poussee a partir de laquelle une direction compte comme pressee.")
                .font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            SliderField(title: "Gachettes", value: profileValue(\.triggerThreshold),
                        range: 0.05...0.9, step: 0.05) { String(format: "%.0f %%", $0 * 100) }
            SliderField(title: "Cadence de la molette", value: profileValue(\.scrollInterval),
                        range: 0.03...0.4, step: 0.01) { String(format: "%.0f ms", $0 * 1000) }
        }
    }

    private var advanced: some View {
        Group {
            CheckboxField(title: "Afficher PadKey dans le Dock",
                          isOn: Binding(get: { state.showInDock },
                                        set: { state.showInDock = $0 }))
            Text("Sans cela, PadKey ne vit que dans la barre de menus, ou macOS peut masquer son icone si la barre est pleine.")
                .font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Divider().overlay(Theme.borderSubtle)

            HStack(spacing: 8) {
                ToolbarButton(title: "Dossier des profils", icon: "folder") {
                    state.revealProfilesFolder()
                }
                ToolbarButton(title: "Recharger", icon: "arrow.clockwise") { state.reload() }
            }
            ToolbarButton(title: "Restaurer les profils livres", icon: "arrow.counterclockwise") {
                state.restoreDefaults()
            }

            if !state.hasAccessibility {
                Divider().overlay(Theme.borderSubtle)
                Text("PadKey doit pouvoir controler votre Mac pour envoyer les touches et les mouvements de souris configures.")
                    .font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                ToolbarButton(title: "Ouvrir Reglages Systeme", icon: "lock.open", primary: true) {
                    state.requestAccessibility()
                }
            }
        }
    }

    private func mouse(_ path: WritableKeyPath<MouseConfig, Double>) -> Binding<Double> {
        Binding(get: { state.selectedProfile.mouse[keyPath: path] },
                set: { value in
                    var profile = state.selectedProfile
                    profile.mouse[keyPath: path] = value
                    state.update(profile)
                })
    }

    private func mouseBool(_ path: WritableKeyPath<MouseConfig, Bool>) -> Binding<Bool> {
        Binding(get: { state.selectedProfile.mouse[keyPath: path] },
                set: { value in
                    var profile = state.selectedProfile
                    profile.mouse[keyPath: path] = value
                    state.update(profile)
                })
    }

    private func profileValue(_ path: WritableKeyPath<Profile, Double>) -> Binding<Double> {
        Binding(get: { state.selectedProfile[keyPath: path] },
                set: { value in
                    var profile = state.selectedProfile
                    profile[keyPath: path] = value
                    state.update(profile)
                })
    }
}

/// Bouton d'un groupe segmente.
struct SegmentButton: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: selected ? .semibold : .regular))
                .foregroundStyle(selected ? Color.white : Theme.textSecondary)
                .padding(.horizontal, 9)
                .frame(height: 26)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selected ? Theme.accent : Color.white.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
    }
}
