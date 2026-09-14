import SwiftUI
import AppKit
import CoreGraphics

struct SettingsView: View {
    @ObservedObject var state: AppState

    @State private var capturing: PadInput?
    @State private var selectedZone: String? = "leftStick"
    @State private var mode: Mode
    @State private var renaming = false
    @State private var draftName = ""

    enum Mode: String, CaseIterable {
        case board = "Manette"
        case list = "Liste"
    }

    init(state: AppState, initialMode: Mode = .board) {
        self.state = state
        _mode = State(initialValue: initialMode)
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(state: state)
            Divider()
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 242)
                    .background(Color(nsColor: .windowBackgroundColor))
                Divider()
                content
            }
        }
        .frame(minWidth: 1060, minHeight: 700)
        .onAppear { state.setLiveMonitoring(true) }
        .onDisappear { state.setLiveMonitoring(false) }
        .sheet(item: $capturing) { input in
            KeyCaptureSheet(input: input) { binding in
                apply(binding, to: input)
                capturing = nil
            } onCancel: {
                capturing = nil
            }
        }
        .alert("Renommer le profil", isPresented: $renaming) {
            TextField("Nom", text: $draftName)
            Button("Annuler", role: .cancel) {}
            Button("Renommer") { state.renameSelected(to: draftName) }
        }
    }

    // MARK: - Contenu principal

    private var content: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 190)

                Text(state.selectedProfileName)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.leading, 4)

                Spacer()

                if mode == .board {
                    Text("Cliquez un controle sur la manette pour le regler")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            Group {
                if mode == .board {
                    ControllerBoard(profile: state.selectedProfile,
                                    snapshot: state.liveSnapshot,
                                    selectedZone: $selectedZone) { capturing = $0 }
                } else {
                    BindingsTable(profile: state.selectedProfile,
                                  pressed: state.liveSnapshot?.pressed ?? [],
                                  onCapture: { capturing = $0 },
                                  onApply: apply)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            Inspector(state: state,
                      zoneID: selectedZone,
                      compact: mode == .list,
                      onCapture: { capturing = $0 },
                      onApply: apply)
                .frame(height: mode == .list ? 128 : 196)
        }
        .background(boardBackground)
    }

    /// Un fond legerement plus clair au centre donne du relief au dessin.
    private var boardBackground: some View {
        ZStack {
            Color(nsColor: .textBackgroundColor).opacity(0.35)
            RadialGradient(colors: [Color.primary.opacity(0.05), .clear],
                           center: .center, startRadius: 10, endRadius: 520)
        }
    }

    private func apply(_ binding: PadBinding?, to input: PadInput) {
        var profile = state.selectedProfile
        if let binding, !binding.isEmpty {
            profile.bindings[input] = binding
        } else {
            profile.bindings[input] = nil
        }
        state.update(profile)
    }

    // MARK: - Colonne de gauche

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                profileSection
                controllerSection
                aimSection
                thresholdSection
                appSection
                credits
            }
            .padding(16)
        }
    }

    private var appSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Theme.sectionTitle("Application")
            Toggle("Afficher dans le Dock", isOn: Binding(
                get: { state.showInDock },
                set: { state.showInDock = $0 }))
                .font(.system(size: 11))
                .controlSize(.small)
            Text(state.showInDock
                 ? "PadKey apparait dans le Dock et dans Commande+Tab."
                 : "PadKey vit seulement dans la barre de menus. Si son icone y est masquee, rouvrez cette fenetre en double-cliquant l'application.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var credits: some View {
        VStack(alignment: .leading, spacing: 3) {
            Divider().padding(.vertical, 4)
            Text("Visuels de manette : Gamepad Asset Pack d'AL2009man, licence MIT.")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Theme.sectionTitle("Profils")
            VStack(spacing: 3) {
                ForEach(state.profiles, id: \.name) { profile in
                    let active = profile.name == state.selectedProfileName
                    Button {
                        state.select(profileNamed: profile.name)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: active ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 12))
                                .foregroundStyle(active ? Theme.accent : Color.secondary.opacity(0.5))
                            Text(profile.name)
                                .font(.system(size: 12, weight: active ? .semibold : .regular))
                            Spacer()
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(active ? Theme.accentSoft : .clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 6) {
                Button("Nouveau profil") { state.duplicateSelected() }
                    .controlSize(.small)
                Spacer()
                Menu {
                    Button("Renommer...") {
                        draftName = state.selectedProfileName
                        renaming = true
                    }
                    Button("Supprimer") { state.deleteSelected() }
                        .disabled(state.profiles.count <= 1)
                    Divider()
                    Button("Ouvrir le dossier") { state.revealProfilesFolder() }
                    Button("Recharger depuis les fichiers") { state.reload() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 30)
            }
            .font(.system(size: 11))
        }
    }

    private var controllerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Theme.sectionTitle("Manettes detectees")
                Spacer()
                Button { state.refreshControllers() } label: {
                    Image(systemName: "arrow.clockwise").font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .help("Rafraichir")
            }

            if state.availableControllers.isEmpty {
                Text("Aucune manette. Connectez la DualSense en Bluetooth ou en USB.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 3) {
                    ForEach(state.availableControllers) { controller in
                        Button {
                            state.choose(controller: controller.id)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: controller.isActive ? "largecircle.fill.circle" : "circle")
                                    .font(.system(size: 12))
                                    .foregroundStyle(controller.isActive ? Theme.accent : Color.secondary.opacity(0.5))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(controller.name)
                                        .font(.system(size: 12))
                                        .lineLimit(1)
                                    Text(controller.isUsable ? controller.kind : "\(controller.kind), inutilisable")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .contentShape(Rectangle())
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(controller.isActive ? Theme.accentSoft : .clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!controller.isUsable)
                    }
                }
                if state.availableControllers.count > 1 {
                    Text("Choisissez celle marquee DualSense : les autres sont des manettes virtuelles creees par Steam.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var aimSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Theme.sectionTitle("Visee")
            Picker("", selection: mouseBinding(\.source)) {
                ForEach([MouseSource.rightStick, .leftStick, .none], id: \.self) { source in
                    Text(source.label).tag(source)
                }
            }
            .labelsHidden()
            .controlSize(.small)

            slider("Vitesse", value: mouseBinding(\.speed), range: 200...4000, step: 50) { "\(Int($0)) px/s" }
            slider("Zone morte", value: mouseBinding(\.deadzone), range: 0...0.4, step: 0.01) {
                String(format: "%.0f %%", $0 * 100)
            }
            slider("Courbe", value: mouseBinding(\.curve), range: 1...4, step: 0.1) {
                String(format: "%.1f", $0)
            }
            slider("Axe vertical", value: mouseBinding(\.verticalScale), range: 0.2...1.5, step: 0.05) {
                String(format: "%.2f x", $0)
            }
            Toggle("Inverser l'axe vertical", isOn: mouseBinding(\.invertY))
                .font(.system(size: 11))
                .controlSize(.small)
        }
    }

    private var thresholdSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Theme.sectionTitle("Seuils")
            slider("Direction stick", value: profileBinding(\.stickDeadzone), range: 0.2...0.8, step: 0.05) {
                String(format: "%.0f %%", $0 * 100)
            }
            slider("Gachettes", value: profileBinding(\.triggerThreshold), range: 0.05...0.9, step: 0.05) {
                String(format: "%.0f %%", $0 * 100)
            }
            slider("Cadence molette", value: profileBinding(\.scrollInterval), range: 0.03...0.4, step: 0.01) {
                String(format: "%.0f ms", $0 * 1000)
            }
        }
    }

    private func slider(_ title: String,
                        value: Binding<Double>,
                        range: ClosedRange<Double>,
                        step: Double,
                        format: @escaping (Double) -> String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack {
                Text(title).font(.system(size: 11))
                Spacer()
                Text(format(value.wrappedValue))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
                .controlSize(.small)
        }
    }

    private func mouseBinding<T>(_ keyPath: WritableKeyPath<MouseConfig, T>) -> Binding<T> {
        Binding(
            get: { state.selectedProfile.mouse[keyPath: keyPath] },
            set: { newValue in
                var profile = state.selectedProfile
                profile.mouse[keyPath: keyPath] = newValue
                state.update(profile)
            }
        )
    }

    private func profileBinding<T>(_ keyPath: WritableKeyPath<Profile, T>) -> Binding<T> {
        Binding(
            get: { state.selectedProfile[keyPath: keyPath] },
            set: { newValue in
                var profile = state.selectedProfile
                profile[keyPath: keyPath] = newValue
                state.update(profile)
            }
        )
    }
}

extension PadInput: Identifiable {
    var id: String { rawValue }
}
