import SwiftUI

/// Vue tableau : toutes les correspondances du profil, groupees par famille.
struct MappingList: View {
    @ObservedObject var state: AppState
    let pressed: Set<PadInput>
    @Binding var selectedZone: String?
    var onApply: (PadBinding?, PadInput) -> Void

    @State private var search = ""

    private struct Group: Identifiable {
        let id: String
        let inputs: [PadInput]
    }

    private let groups: [Group] = [
        Group(id: "Stick gauche", inputs: [.leftStickUp, .leftStickDown, .leftStickLeft, .leftStickRight, .l3]),
        Group(id: "Stick droit", inputs: [.rightStickUp, .rightStickDown, .rightStickLeft, .rightStickRight, .r3]),
        Group(id: "Boutons", inputs: [.triangle, .circle, .cross, .square]),
        Group(id: "Gachettes", inputs: [.l1, .r1, .l2, .r2]),
        Group(id: "Croix directionnelle", inputs: [.dpadUp, .dpadDown, .dpadLeft, .dpadRight]),
        Group(id: "Systeme", inputs: [.options, .create, .touchpad, .ps]),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Correspondances")
                    .font(Theme.screenTitle())
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                    TextField("Rechercher", text: $search)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .frame(width: 150)
                }
                .padding(.horizontal, 9)
                .frame(height: 28)
                .background(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous)
                    .fill(Theme.bgSurface))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous)
                    .strokeBorder(Theme.borderSubtle, lineWidth: 1))
            }
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(visibleGroups) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            SectionLabel(group.id).padding(.horizontal, 4)
                            Panel(padding: 8) {
                                VStack(spacing: 3) {
                                    ForEach(filtered(group.inputs)) { input in
                                        MappingRow(input: input,
                                                   binding: state.selectedProfile.bindings[input],
                                                   disabled: isMouseStick(input),
                                                   pressed: pressed.contains(input),
                                                   onApply: { onApply($0, input) })
                                            .onTapGesture {
                                                selectedZone = PadArtwork.zone(for: input)?.id
                                            }
                                    }
                                }
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }

    private var visibleGroups: [Group] {
        groups.filter { !filtered($0.inputs).isEmpty }
    }

    private func filtered(_ inputs: [PadInput]) -> [PadInput] {
        guard !search.isEmpty else { return inputs }
        let needle = search.lowercased()
        return inputs.filter { input in
            input.label.lowercased().contains(needle)
                || (state.selectedProfile.bindings[input]?.summary.lowercased().contains(needle) ?? false)
        }
    }

    private func isMouseStick(_ input: PadInput) -> Bool {
        let profile = state.selectedProfile
        return (profile.mouse.source == .rightStick && input.rawValue.hasPrefix("rightStick"))
            || (profile.mouse.source == .leftStick && input.rawValue.hasPrefix("leftStick"))
    }
}
