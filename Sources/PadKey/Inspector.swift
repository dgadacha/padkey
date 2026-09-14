import SwiftUI
import AppKit
import CoreGraphics

/// Panneau d'edition du controle selectionne.
struct MappingInspector: View {
    @ObservedObject var state: AppState
    let zoneID: String?
    let pressed: Set<PadInput>
    var onApply: (PadBinding?, PadInput) -> Void

    var body: some View {
        Panel {
            if let zone = zoneID.flatMap(PadArtwork.zone(id:)) {
                VStack(alignment: .leading, spacing: 0) {
                    header(zone)
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(zone.inputs) { input in
                                MappingRow(input: input,
                                           binding: state.selectedProfile.bindings[input],
                                           disabled: isMouseStick(input),
                                           pressed: pressed.contains(input),
                                           onApply: { onApply($0, input) })
                            }
                        }
                        .padding(.trailing, 2)
                    }
                }
            } else {
                emptyState
            }
        }
    }

    private func header(_ zone: PadArtwork.Zone) -> some View {
        HStack(spacing: 9) {
            Text(PadArtwork.badge(for: zone.id))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(minWidth: 26, minHeight: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(Theme.accentSoft))
            VStack(alignment: .leading, spacing: 1) {
                Text(zone.title)
                    .font(Theme.cardTitle())
                    .foregroundStyle(Theme.textPrimary)
                Text(summary(zone))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            ToolbarButton(title: "Effacer", icon: "arrow.counterclockwise") {
                for input in zone.inputs { onApply(nil, input) }
            }
        }
        .padding(.bottom, 10)
    }

    private func summary(_ zone: PadArtwork.Zone) -> String {
        let assigned = zone.inputs.filter { state.selectedProfile.bindings[$0]?.isEmpty == false }.count
        if zone.inputs.count == 1 {
            return assigned == 1 ? "Assigne" : "Aucune action"
        }
        return "\(assigned) entree\(assigned > 1 ? "s" : "") sur \(zone.inputs.count) assignee\(assigned > 1 ? "s" : "")"
    }

    private var emptyState: some View {
        VStack(spacing: 7) {
            Spacer()
            Image(systemName: "hand.tap")
                .font(.system(size: 20))
                .foregroundStyle(Theme.textTertiary)
            Text("Selectionnez un controle")
                .font(Theme.cardTitle())
                .foregroundStyle(Theme.textSecondary)
            Text("Cliquez un bouton ou un stick sur la manette pour modifier ce qu'il envoie.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func isMouseStick(_ input: PadInput) -> Bool {
        let profile = state.selectedProfile
        return (profile.mouse.source == .rightStick && input.rawValue.hasPrefix("rightStick"))
            || (profile.mouse.source == .leftStick && input.rawValue.hasPrefix("leftStick"))
    }
}

/// Une ligne d'edition : entree, action, type, menu.
struct MappingRow: View {
    let input: PadInput
    let binding: PadBinding?
    let disabled: Bool
    let pressed: Bool
    let onApply: (PadBinding?) -> Void

    @State private var capturing = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Text(icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(pressed ? Theme.accent : Theme.textTertiary)
                .frame(width: 26, height: 22)
                .background(RoundedRectangle(cornerRadius: 6)
                    .fill(pressed ? Theme.accentSoft : Color.white.opacity(0.04)))

            Text(shortLabel)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 92, alignment: .leading)

            if disabled {
                Text("Pilote la souris")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                actionField
                typeMenu
                moreMenu
            }
        }
        .frame(height: 34)
        .opacity(disabled ? 0.55 : 1)
        .onDisappear(perform: stopCapture)
    }

    // MARK: - Champ d'action

    private var actionField: some View {
        Button { startCapture() } label: {
            HStack {
                Text(capturing ? "Appuyez sur une touche..." : (binding?.summary ?? "Aucune"))
                    .font(.system(size: 12, weight: binding == nil ? .regular : .medium))
                    .foregroundStyle(capturing ? Theme.accent
                                              : (binding == nil ? Theme.textTertiary : Theme.textPrimary))
                    .lineLimit(1)
                Spacer(minLength: 4)
            }
            .padding(.horizontal, 9)
            .frame(height: 26)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous)
                .fill(Theme.bgSurfaceActive))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous)
                .strokeBorder(capturing ? Theme.accent : Theme.borderSubtle,
                              lineWidth: capturing ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .help("Cliquez puis appuyez sur la touche a envoyer")
    }

    private var typeMenu: some View {
        Menu {
            Button("Touche...") { startCapture() }
            Divider()
            Button("Clic gauche") { onApply(.click(.left)) }
            Button("Clic droit") { onApply(.click(.right)) }
            Button("Clic milieu") { onApply(.click(.middle)) }
            Divider()
            Button("Molette haut") { onApply(.wheel(.up)) }
            Button("Molette bas") { onApply(.wheel(.down)) }
        } label: {
            Text(typeName)
                .font(.system(size: 11))
        }
        .menuStyle(.borderlessButton)
        .frame(width: 84)
        .padding(.horizontal, 6)
        .frame(height: 26)
        .background(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous)
            .fill(Theme.bgSurface))
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusInput, style: .continuous)
            .strokeBorder(Theme.borderSubtle, lineWidth: 1))
    }

    private var moreMenu: some View {
        Menu {
            Toggle("Repeter tant que maintenu", isOn: Binding(
                get: { binding?.autoRepeat == true },
                set: { value in
                    guard var updated = binding else { return }
                    updated.autoRepeat = value ? true : nil
                    onApply(updated)
                }))
                .disabled(binding == nil)
            Divider()
            Button("Supprimer le mapping") { onApply(nil) }
                .disabled(binding == nil)
        } label: {
            Image(systemName: "ellipsis")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 26, height: 26)
    }

    private var typeName: String {
        if binding?.mouse != nil { return "Souris" }
        if binding?.scroll != nil { return "Molette" }
        if binding == nil { return "Aucun" }
        return "Touche"
    }

    private var shortLabel: String {
        input.label
            .replacingOccurrences(of: "Croix directionnelle ", with: "")
            .replacingOccurrences(of: "Stick G ", with: "")
            .replacingOccurrences(of: "Stick D ", with: "")
            .capitalizedFirst
    }

    private var icon: String {
        switch input {
        case .leftStickUp, .rightStickUp, .dpadUp: return "\u{2191}"
        case .leftStickDown, .rightStickDown, .dpadDown: return "\u{2193}"
        case .leftStickLeft, .rightStickLeft, .dpadLeft: return "\u{2190}"
        case .leftStickRight, .rightStickRight, .dpadRight: return "\u{2192}"
        case .l3: return "L3"
        case .r3: return "R3"
        default: return PadArtwork.zone(for: input).map { PadArtwork.badge(for: $0.id) } ?? ""
        }
    }

    // MARK: - Capture

    private func startCapture() {
        guard !disabled, monitor == nil else { return }
        capturing = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            if event.type == .flagsChanged {
                let code = CGKeyCode(event.keyCode)
                guard let flag = KeyCodes.flag(for: code) else { return nil }
                let nsFlag = NSEvent.ModifierFlags(rawValue: UInt(flag.rawValue))
                if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(nsFlag) {
                    finish(PadBinding(keycodes: [Int(code)], autoRepeat: binding?.autoRepeat))
                }
                return nil
            }
            // Echap annule la capture sans rien changer.
            if event.keyCode == 53 {
                stopCapture()
                return nil
            }
            var codes: [Int] = []
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags.contains(.control) { codes.append(59) }
            if flags.contains(.option) { codes.append(58) }
            if flags.contains(.shift) { codes.append(56) }
            if flags.contains(.command) { codes.append(55) }
            codes.append(Int(event.keyCode))
            finish(PadBinding(keycodes: codes, autoRepeat: binding?.autoRepeat))
            return nil
        }
    }

    private func finish(_ value: PadBinding) {
        stopCapture()
        onApply(value)
    }

    private func stopCapture() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        capturing = false
    }
}

extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return String(first).uppercased() + dropFirst()
    }
}

// MARK: - Lecture en direct

struct LivePanel: View {
    let snapshot: PadSnapshot?
    let connected: Bool

    private var pressed: Set<PadInput> { snapshot?.pressed ?? [] }

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(connected ? Theme.success : Theme.textTertiary)
                        .frame(width: 7, height: 7)
                    Text("Lecture en direct")
                        .font(Theme.cardTitle())
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                }
                Text(connected ? "Bougez votre manette pour voir les entrees"
                               : "Aucune manette connectee")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 2)
                    .padding(.bottom, 12)

                HStack(alignment: .top, spacing: 16) {
                    stick(title: "Stick G", point: snapshot?.leftStick ?? .zero,
                          clicked: pressed.contains(.l3))
                    stick(title: "Stick D", point: snapshot?.rightStick ?? .zero,
                          clicked: pressed.contains(.r3))
                    VStack(spacing: 7) {
                        HStack(spacing: 10) {
                            trigger("L2", snapshot?.leftTrigger ?? 0)
                            trigger("R2", snapshot?.rightTrigger ?? 0)
                        }
                        HStack(spacing: 10) {
                            shoulder("L1", pressed.contains(.l1))
                            shoulder("R1", pressed.contains(.r1))
                        }
                    }
                    Spacer(minLength: 0)
                }

                Spacer(minLength: 10)

                HStack(spacing: 8) {
                    faceButton("\u{25B3}", .triangle)
                    faceButton("\u{25CB}", .circle)
                    faceButton("\u{2715}", .cross)
                    faceButton("\u{25A1}", .square)
                    Spacer(minLength: 0)
                    dpadCluster
                }
            }
        }
    }

    private func stick(title: String, point: CGPoint, clicked: Bool) -> some View {
        VStack(spacing: 5) {
            ZStack {
                Circle().fill(Color.white.opacity(0.04))
                Circle().strokeBorder(clicked ? Theme.accent : Theme.borderMedium, lineWidth: 1)
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 9, height: 9)
                    .offset(x: point.x * 17, y: -point.y * 17)
            }
            .frame(width: 52, height: 52)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private func trigger(_ title: String, _ value: Double) -> some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.07))
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.accent)
                    .frame(height: max(2, 38 * value))
            }
            .frame(width: 13, height: 38)
            Text(title)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private func shoulder(_ title: String, _ on: Bool) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(on ? .white : Theme.textTertiary)
            .frame(width: 30, height: 18)
            .background(RoundedRectangle(cornerRadius: 5)
                .fill(on ? Theme.accent : Color.white.opacity(0.05)))
    }

    private func faceButton(_ symbol: String, _ input: PadInput) -> some View {
        let on = pressed.contains(input)
        return Text(symbol)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(on ? .white : Theme.textSecondary)
            .frame(width: 26, height: 26)
            .background(Circle().fill(on ? Theme.accent : Color.white.opacity(0.05)))
            .animation(Theme.hover, value: on)
    }

    private var dpadCluster: some View {
        VStack(spacing: 2) {
            dpadKey("\u{2191}", .dpadUp)
            HStack(spacing: 2) {
                dpadKey("\u{2190}", .dpadLeft)
                dpadKey("\u{2193}", .dpadDown)
                dpadKey("\u{2192}", .dpadRight)
            }
        }
    }

    private func dpadKey(_ symbol: String, _ input: PadInput) -> some View {
        let on = pressed.contains(input)
        return Text(symbol)
            .font(.system(size: 9))
            .foregroundStyle(on ? .white : Theme.textTertiary)
            .frame(width: 18, height: 16)
            .background(RoundedRectangle(cornerRadius: 4)
                .fill(on ? Theme.accent : Color.white.opacity(0.05)))
    }
}
