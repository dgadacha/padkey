import SwiftUI
import AppKit
import CoreGraphics

// MARK: - Bandeau du haut

struct HeaderBar: View {
    @ObservedObject var state: AppState

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.accent)
                Text("PadKey")
                    .font(.system(size: 14, weight: .semibold))
                Text(AppInfo.version)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .help("Build \(AppInfo.build)")
            }

            PowerToggle(isOn: state.isEnabled) { state.toggleEnabled() }

            HStack(spacing: 6) {
                Circle()
                    .fill(state.controllerName != nil ? Theme.good : Color.secondary.opacity(0.4))
                    .frame(width: 7, height: 7)
                Text(state.controllerName ?? "Aucune manette")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if state.statusItemHidden {
                AlertChip(icon: "menubar.arrow.up.rectangle",
                          text: "Icone masquee, barre de menus pleine",
                          tint: Theme.warning,
                          action: "Details") { state.showMenuBarHelp() }
            }
            if state.steamRunning {
                SteamChip(state: state)
            }
            if !state.hasAccessibility {
                AlertChip(icon: "lock.fill",
                          text: "Accessibilite requise",
                          tint: Theme.warning,
                          action: "Autoriser") { state.requestAccessibility() }
            }
            if !state.hasInputMonitoring {
                AlertChip(icon: "lock.fill",
                          text: "Controle des entrees",
                          tint: Theme.warning,
                          action: "Autoriser") { state.requestInputMonitoring() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

/// Steam n'est pas le probleme en soi : c'est Steam Input. Le distinguer evite
/// de conseiller de fermer Steam a quelqu'un qui lance justement un jeu Steam.
private struct SteamChip: View {
    @ObservedObject var state: AppState
    @State private var showHelp = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10))
            Text("Steam Input peut capter la manette").font(.system(size: 11, weight: .medium))
            Button("Que faire ?") { showHelp = true }
                .controlSize(.small)
                .font(.system(size: 11))
        }
        .foregroundStyle(Theme.warning)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(Theme.warning.opacity(0.12)))
        .popover(isPresented: $showHelp, arrowEdge: .bottom) {
            SteamHelp(state: state)
        }
    }
}

private struct SteamHelp: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Steam est ouvert")
                .font(.system(size: 13, weight: .semibold))

            Text("Quand Steam Input est actif, Steam prend la main sur la DualSense et la remplace par une manette virtuelle. PadKey ne recoit alors plus rien d'utilisable.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("Vous jouez a un jeu Steam")
                    .font(.system(size: 12, weight: .semibold))
                Text("Ne fermez pas Steam, desactivez seulement Steam Input pour ce jeu :\nBibliotheque, clic droit sur le jeu, Proprietes, Manette, puis Desactiver Steam Input.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Pour le couper partout : Steam, Reglages, Manette, puis desactivez la prise en charge des manettes.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Vous jouez a un jeu hors Steam")
                    .font(.system(size: 12, weight: .semibold))
                HStack {
                    Text("Fermer Steam regle le probleme d'un coup.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Button("Quitter Steam") { state.quitSteam() }
                        .controlSize(.small)
                }
            }

            Divider()
            Text("Pour verifier : bougez les sticks et regardez le bandeau du bas. S'il reagit, la manette est bien lue et vous pouvez ignorer cet avertissement.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 380)
    }
}

private struct AlertChip: View {
    let icon: String
    let text: String
    let tint: Color
    let action: String
    let handler: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 10))
            Text(text).font(.system(size: 11, weight: .medium))
            Button(action, action: handler)
                .controlSize(.small)
                .font(.system(size: 11))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(tint.opacity(0.12)))
    }
}

// MARK: - Ligne d'assignation

struct BindingRow: View {
    let input: PadInput
    let binding: PadBinding?
    let isMouseStick: Bool
    let pressed: Bool
    let onCapture: () -> Void
    let onApply: (PadBinding?) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(pressed ? Theme.accent : Color.secondary.opacity(0.22))
                .frame(width: 6, height: 6)

            Text(input.label)
                .font(.system(size: 12))
                .frame(width: 148, alignment: .leading)

            if isMouseStick {
                Text("Pilote la souris")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .italic()
                Spacer()
            } else {
                Text(binding?.summary ?? "Aucune")
                    .font(.system(size: 12, weight: binding == nil ? .regular : .medium))
                    .foregroundStyle(binding == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("Touche", action: onCapture)
                    .controlSize(.small)
                    .font(.system(size: 11))

                Menu {
                    Button("Clic gauche") { onApply(.click(.left)) }
                    Button("Clic droit") { onApply(.click(.right)) }
                    Button("Clic milieu") { onApply(.click(.middle)) }
                    Divider()
                    Button("Molette haut") { onApply(.wheel(.up)) }
                    Button("Molette bas") { onApply(.wheel(.down)) }
                    Divider()
                    Toggle("Repetition automatique", isOn: Binding(
                        get: { binding?.autoRepeat == true },
                        set: { value in
                            guard var updated = binding else { return }
                            updated.autoRepeat = value ? true : nil
                            onApply(updated)
                        }))
                        .disabled(binding == nil || binding?.keys == nil && binding?.keycodes == nil && binding?.chars == nil)
                    Divider()
                    Button("Effacer") { onApply(nil) }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .frame(width: 34)
            }
        }
        .padding(.vertical, 1)
        .opacity(isMouseStick ? 0.6 : 1)
    }
}

// MARK: - Liste complete

struct BindingsTable: View {
    let profile: Profile
    let pressed: Set<PadInput>
    let onCapture: (PadInput) -> Void
    let onApply: (PadBinding?, PadInput) -> Void

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
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 6) {
                        Theme.sectionTitle(group.id)
                        Card(padding: 10) {
                            VStack(spacing: 6) {
                                ForEach(group.inputs) { input in
                                    BindingRow(input: input,
                                               binding: profile.bindings[input],
                                               isMouseStick: isMouseStick(input),
                                               pressed: pressed.contains(input),
                                               onCapture: { onCapture(input) },
                                               onApply: { onApply($0, input) })
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 780)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
    }

    private func isMouseStick(_ input: PadInput) -> Bool {
        (profile.mouse.source == .rightStick && input.rawValue.hasPrefix("rightStick"))
            || (profile.mouse.source == .leftStick && input.rawValue.hasPrefix("leftStick"))
    }
}

// MARK: - Inspecteur du bas

struct Inspector: View {
    @ObservedObject var state: AppState
    let zoneID: String?
    var compact = false
    let onCapture: (PadInput) -> Void
    let onApply: (PadBinding?, PadInput) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            if compact {
                Spacer(minLength: 0)
            } else {
            VStack(alignment: .leading, spacing: 8) {
                if let zone = zoneID.flatMap(PadArtwork.zone(id:)) {
                    Text(zone.title)
                        .font(.system(size: 13, weight: .semibold))
                    ScrollView {
                        VStack(spacing: 5) {
                            ForEach(zone.inputs) { input in
                                BindingRow(input: input,
                                           binding: state.selectedProfile.bindings[input],
                                           isMouseStick: isMouseStick(input),
                                           pressed: state.liveSnapshot?.pressed.contains(input) ?? false,
                                           onCapture: { onCapture(input) },
                                           onApply: { onApply($0, input) })
                            }
                        }
                    }
                } else {
                    Text("Choisissez un controle sur la manette.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .frame(maxWidth: 640, alignment: .leading)

            Spacer(minLength: 12)
            Divider()
            }
            LiveMonitor(snapshot: state.liveSnapshot)
                .frame(width: 300)
        }
        .padding(14)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func isMouseStick(_ input: PadInput) -> Bool {
        let profile = state.selectedProfile
        return (profile.mouse.source == .rightStick && input.rawValue.hasPrefix("rightStick"))
            || (profile.mouse.source == .leftStick && input.rawValue.hasPrefix("leftStick"))
    }
}

// MARK: - Moniteur temps reel

struct LiveMonitor: View {
    let snapshot: PadSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Theme.sectionTitle("Lecture en direct")

            HStack(spacing: 14) {
                stickGauge(title: "Stick G", point: snapshot?.leftStick ?? .zero)
                stickGauge(title: "Stick D", point: snapshot?.rightStick ?? .zero)
                VStack(spacing: 6) {
                    triggerGauge(title: "L2", value: snapshot?.leftTrigger ?? 0)
                    triggerGauge(title: "R2", value: snapshot?.rightTrigger ?? 0)
                }
            }

            Text(activeList)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var activeList: String {
        guard let snapshot, !snapshot.pressed.isEmpty else { return "aucune entree" }
        return PadInput.displayOrder
            .filter { snapshot.pressed.contains($0) }
            .map(\.label)
            .joined(separator: ", ")
    }

    private func stickGauge(title: String, point: CGPoint) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().fill(Color.primary.opacity(0.05))
                Circle().stroke(Color.primary.opacity(0.15), lineWidth: 1)
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 8, height: 8)
                    .offset(x: point.x * 17, y: -point.y * 17)
            }
            .frame(width: 46, height: 46)
            Text(title).font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }

    private func triggerGauge(title: String, value: Double) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: max(2, geo.size.width * value))
                }
            }
            .frame(height: 6)
        }
        .frame(width: 92)
    }
}

// MARK: - Capture de touche

struct KeyCaptureSheet: View {
    let input: PadInput
    let onCapture: (PadBinding) -> Void
    let onCancel: () -> Void

    @State private var monitor: Any?
    @State private var preview = "En attente..."

    var body: some View {
        VStack(spacing: 14) {
            Text("Touche pour \(input.label)")
                .font(.system(size: 14, weight: .semibold))
            Text("Appuyez sur la touche a envoyer. Les modificateurs maintenus sont inclus.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(preview)
                .font(.system(size: 17, weight: .medium, design: .monospaced))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(0.06)))
            Button("Annuler") { stop(); onCancel() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(20)
        .frame(width: 360)
        .onAppear(perform: start)
        .onDisappear(perform: stop)
    }

    private func start() {
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .flagsChanged {
                // Un modificateur seul n'est retenu qu'au moment ou il est enfonce.
                let code = CGKeyCode(event.keyCode)
                guard let flag = KeyCodes.flag(for: code) else { return nil }
                let nsFlag = NSEvent.ModifierFlags(rawValue: UInt(flag.rawValue))
                if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(nsFlag) {
                    preview = KeyCodes.label(for: code)
                    finish(PadBinding(keycodes: [Int(code)]))
                }
                return nil
            }

            var codes: [Int] = []
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.contains(.control) { codes.append(59) }
            if flags.contains(.option) { codes.append(58) }
            if flags.contains(.shift) { codes.append(56) }
            if flags.contains(.command) { codes.append(55) }
            codes.append(Int(event.keyCode))
            preview = codes.map { KeyCodes.label(for: CGKeyCode($0)) }.joined(separator: " + ")
            finish(PadBinding(keycodes: codes))
            return nil
        }
    }

    private func finish(_ binding: PadBinding) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            stop()
            onCapture(binding)
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
