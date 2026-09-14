import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var state: AppState

    @State private var selectedZone: String?
    @State private var hoveredZone: String?
    @State private var section: SettingsSection = .aim
    @State private var mode: Mode
    @State private var renaming = false
    @State private var draftName = ""

    enum Mode: String, CaseIterable {
        case board = "Manette"
        case list = "Liste"
    }

    init(state: AppState, initialMode: Mode = .board, initialZone: String? = nil) {
        self.state = state
        _mode = State(initialValue: initialMode)
        _selectedZone = State(initialValue: initialZone)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Sidebar(state: state, section: $section,
                        onNewProfile: { state.duplicateSelected() },
                        onRenameProfile: startRename)
                    .frame(width: 252)
                Rectangle().fill(Theme.borderSubtle).frame(width: 1)
                content
            }
            Rectangle().fill(Theme.borderSubtle).frame(height: 1)
            StatusBar(state: state)
        }
        .frame(minWidth: 1180, minHeight: 780)
        .background(Theme.bgApp)
        .preferredColorScheme(.dark)
        .onAppear { state.setLiveMonitoring(true) }
        .onDisappear { state.setLiveMonitoring(false) }
        .alert("Renommer le profil", isPresented: $renaming) {
            TextField("Nom", text: $draftName)
            Button("Annuler", role: .cancel) {}
            Button("Renommer") { state.renameSelected(to: draftName) }
        }
    }

    private func startRename() {
        draftName = state.selectedProfileName
        renaming = true
    }

    // MARK: - Zone principale

    private var content: some View {
        VStack(spacing: 0) {
            MainToolbar(state: state, onOpenAdvanced: { section = .advanced })
            Rectangle().fill(Theme.borderSubtle).frame(height: 1)
            viewBar
            Group {
                if mode == .board {
                    ControllerCanvas(profile: state.selectedProfile,
                                     snapshot: state.liveSnapshot,
                                     selectedZone: $selectedZone,
                                     hoveredZone: $hoveredZone)
                } else {
                    MappingList(state: state,
                                pressed: state.liveSnapshot?.pressed ?? [],
                                selectedZone: $selectedZone,
                                onApply: apply)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            panels
        }
        .background(Theme.bgApp)
    }

    private var viewBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 3) {
                ForEach(Mode.allCases, id: \.self) { item in
                    SegmentButton(title: item.rawValue, selected: mode == item) {
                        withAnimation(Theme.selection) { mode = item }
                    }
                    .frame(width: 78)
                }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Theme.bgSurface))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Theme.borderSubtle, lineWidth: 1))

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: state.selectedProfile.symbol)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                Text(state.selectedProfileName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
            }
            .padding(.horizontal, 11)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                .fill(Theme.bgSurface))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                .strokeBorder(Theme.borderSubtle, lineWidth: 1))

            ToolbarButton(title: "", icon: "pencil", action: startRename)
                .help("Renommer le profil")

            Menu {
                Button("Dupliquer") { state.duplicateSelected() }
                Button("Renommer...", action: startRename)
                Divider()
                Button("Supprimer") { state.deleteSelected() }
                    .disabled(state.profiles.count <= 1)
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                .fill(Theme.bgSurface))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                .strokeBorder(Theme.borderSubtle, lineWidth: 1))

            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                Text("Enregistre")
                    .font(.system(size: 11))
            }
            .foregroundStyle(Theme.textTertiary)
            .help("Les modifications sont enregistrees automatiquement")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var panels: some View {
        HStack(spacing: 10) {
            SettingsPanel(state: state, section: $section)
                .frame(width: 268)
            if mode == .board {
                MappingInspector(state: state,
                                 zoneID: selectedZone,
                                 pressed: state.liveSnapshot?.pressed ?? [],
                                 onApply: apply)
                    .frame(maxWidth: .infinity)
            } else {
                Spacer(minLength: 0)
            }
            LivePanel(snapshot: state.liveSnapshot, connected: state.controllerName != nil)
                .frame(width: 300)
        }
        .frame(height: 278)
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
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
}

// MARK: - Barre d'outils

struct MainToolbar: View {
    @ObservedObject var state: AppState
    var onOpenAdvanced: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button { state.toggleEnabled() } label: {
                HStack(spacing: 7) {
                    Circle()
                        .fill(state.isEnabled ? Theme.success : Theme.warning)
                        .frame(width: 7, height: 7)
                        .shadow(color: state.isEnabled ? Theme.success.opacity(0.7) : .clear, radius: 4)
                    Text(state.isEnabled ? "Actif" : "En pause")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.horizontal, 11)
                .frame(height: 30)
                .background(RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                    .fill(state.isEnabled ? Theme.success.opacity(0.12) : Theme.bgSurface))
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                    .strokeBorder(state.isEnabled ? Theme.success.opacity(0.35) : Theme.borderSubtle,
                                  lineWidth: 1))
            }
            .buttonStyle(.plain)
            .help(state.isEnabled ? "Mettre le mapping en pause" : "Activer le mapping")

            HStack(spacing: 6) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(state.controllerName != nil ? Theme.textSecondary : Theme.textTertiary)
                Text(state.controllerName.map { "\($0) connectee" } ?? "Aucune manette detectee")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            if state.steamRunning {
                ToolbarChip(icon: "exclamationmark.triangle.fill",
                            text: "Steam Input", tint: Theme.warning) {
                    state.showSteamHelp()
                }
            }
            if !state.hasAccessibility {
                ToolbarChip(icon: "lock.fill", text: "Autorisation requise", tint: Theme.warning) {
                    state.requestAccessibility()
                }
            }
            if state.statusItemHidden {
                ToolbarChip(icon: "menubar.arrow.up.rectangle",
                            text: "Icone masquee", tint: Theme.textSecondary) {
                    state.showMenuBarHelp()
                }
            }

            ToolbarButton(title: "", icon: "gearshape", action: onOpenAdvanced)
                .help("Reglages avances")
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Theme.bgSidebar)
    }
}

struct ToolbarChip: View {
    let icon: String
    let text: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 10))
                Text(text).font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background(Capsule().fill(tint.opacity(0.12)))
            .overlay(Capsule().strokeBorder(tint.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Barre de statut

struct StatusBar: View {
    @ObservedObject var state: AppState

    var body: some View {
        HStack(spacing: 8) {
            Text("PadKey, pour jouer a la manette aux jeux qui ne gerent que le clavier")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
            Spacer()
            if let name = state.controllerName {
                HStack(spacing: 5) {
                    Circle().fill(Theme.success).frame(width: 6, height: 6)
                    Text("\(state.availableControllers.count) manette\(state.availableControllers.count > 1 ? "s" : "") detectee\(state.availableControllers.count > 1 ? "s" : "")")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                    Text("·").foregroundStyle(Theme.textTertiary)
                    Text(name)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                }
            } else {
                Text("Aucune manette")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 34)
        .background(Theme.bgSidebar)
    }
}

extension PadInput: Identifiable {
    var id: String { rawValue }
}
