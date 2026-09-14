import SwiftUI

/// L'illustration interactive de la manette : chaque controle est cliquable,
/// s'allume quand il est presse, et porte l'etiquette de la touche assignee.
struct ControllerBoard: View {
    let profile: Profile
    let snapshot: PadSnapshot?
    @Binding var selectedZone: String?
    var onEdit: (PadInput) -> Void

    @Environment(\.colorScheme) private var scheme
    @State private var hovered: String?

    private var pressed: Set<PadInput> { snapshot?.pressed ?? [] }

    var body: some View {
        GeometryReader { geo in
            let side: CGFloat = PadArtwork.chipWidth + 10
            let available = max(geo.size.width - side * 2, 240)
            let width = min(available, (geo.size.height - 56) * PadArtwork.aspect)
            let height = width / PadArtwork.aspect

            board(width: width, height: height)
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func board(width: CGFloat, height: CGFloat) -> some View {
        bodyImage
            .resizable()
            .interpolation(.high)
            .frame(width: width, height: height)
            .overlay { sticks(width: width, height: height) }
            .overlay { highlights(width: width, height: height) }
            .overlay { hotspots(width: width, height: height) }
            .overlay { chips(width: width, height: height) }
    }

    private var bodyImage: Image {
        let name = scheme == .dark ? "dualsense-body-dark" : "dualsense-body-light"
        if let nsImage = PadArtwork.image(named: name) {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "gamecontroller")
    }

    // MARK: - Capuchons de sticks

    /// Les capuchons suivent les sticks physiques, ce qui rend la zone morte
    /// et la derive visibles d'un coup d'oeil.
    private func sticks(width: CGFloat, height: CGFloat) -> some View {
        let travel = width * 0.022
        return ZStack(alignment: .topLeading) {
            stickCap(name: "dualsense-stick-left",
                     rect: PadArtwork.zone(id: "leftStick")!.rect,
                     value: snapshot?.leftStick ?? .zero,
                     width: width, height: height, travel: travel)
            stickCap(name: "dualsense-stick-right",
                     rect: PadArtwork.zone(id: "rightStick")!.rect,
                     value: snapshot?.rightStick ?? .zero,
                     width: width, height: height, travel: travel)
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }

    private func stickCap(name: String, rect: CGRect, value: CGPoint,
                          width: CGFloat, height: CGFloat, travel: CGFloat) -> some View {
        Group {
            if let nsImage = PadArtwork.image(named: name) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: rect.width * width, height: rect.height * height)
                    .offset(x: rect.minX * width + value.x * travel,
                            y: rect.minY * height - value.y * travel)
            }
        }
    }

    // MARK: - Halos

    private func highlights(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(PadArtwork.zones) { zone in
                let triggers = zone.litBy.isEmpty ? zone.inputs : zone.litBy
                let isLit = triggers.contains { pressed.contains($0) }
                let isSelected = selectedZone == zone.id
                let isHovered = hovered == zone.id

                shape(for: zone)
                    .fill(Theme.accent.opacity(isLit ? 0.55 : 0))
                    .blur(radius: isLit ? width * 0.012 : 0)
                    .overlay {
                        shape(for: zone)
                            .stroke(
                                isSelected ? Theme.accent : (isHovered ? Theme.accent.opacity(0.55) : .clear),
                                lineWidth: isSelected ? 2 : 1.5)
                    }
                    .frame(width: zone.rect.width * width, height: zone.rect.height * height)
                    .offset(x: zone.rect.minX * width, y: zone.rect.minY * height)
                    .animation(.easeOut(duration: 0.09), value: isLit)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func shape(for zone: PadArtwork.Zone) -> AnyShape {
        zone.round
            ? AnyShape(Circle())
            : AnyShape(RoundedRectangle(cornerRadius: zone.corner, style: .continuous))
    }

    // MARK: - Zones cliquables

    private func hotspots(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(PadArtwork.zones) { zone in
                Rectangle()
                    .fill(Color.white.opacity(0.001))
                    .frame(width: zone.rect.width * width, height: zone.rect.height * height)
                    .offset(x: zone.rect.minX * width, y: zone.rect.minY * height)
                    .onTapGesture { selectedZone = zone.id }
                    .onHover { inside in hovered = inside ? zone.id : (hovered == zone.id ? nil : hovered) }
                    .help(zone.title)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }

    // MARK: - Etiquettes et traits de rappel

    private func chips(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            leaders(width: width, height: height)
            ForEach(PadArtwork.chips) { chip in
                let zoneSelected = selectedZone == chip.zoneID
                ChipLabel(text: text(for: chip) ?? "—",
                          assigned: text(for: chip) != nil,
                          highlighted: chip.inputs.contains { pressed.contains($0) },
                          selected: zoneSelected,
                          alignment: alignment(for: chip.side))
                    .frame(width: PadArtwork.chipWidth, alignment: alignment(for: chip.side))
                    .contentShape(Rectangle())
                    .onTapGesture { selectedZone = chip.zoneID }
                    .onHover { inside in
                        hovered = inside ? chip.zoneID : (hovered == chip.zoneID ? nil : hovered)
                    }
                    .position(x: chipCenterX(chip, width: width), y: chip.y * height)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }

    /// Abscisse du centre de l'etiquette : les rails alignent les etiquettes
    /// par leur bord interieur, pour qu'elles n'empietent pas sur le dessin.
    private func chipCenterX(_ chip: PadArtwork.Chip, width: CGFloat) -> CGFloat {
        switch chip.side {
        case .left: return PadArtwork.leftRail * width - PadArtwork.chipWidth / 2
        case .right: return PadArtwork.rightRail * width + PadArtwork.chipWidth / 2
        case .center: return 0.5 * width
        }
    }

    private func alignment(for side: PadArtwork.Chip.Side) -> Alignment {
        switch side {
        case .left: return .trailing
        case .right: return .leading
        case .center: return .center
        }
    }

    /// Trait fin entre l'etiquette et le controle qu'elle decrit.
    private func leaders(width: CGFloat, height: CGFloat) -> some View {
        Canvas { context, _ in
            for chip in PadArtwork.chips {
                guard let zone = PadArtwork.zone(id: chip.zoneID) else { continue }
                let target = CGPoint(x: zone.rect.midX * width, y: zone.rect.midY * height)
                let start: CGPoint
                switch chip.side {
                case .left: start = CGPoint(x: PadArtwork.leftRail * width + 4, y: chip.y * height)
                case .right: start = CGPoint(x: PadArtwork.rightRail * width - 4, y: chip.y * height)
                case .center: start = CGPoint(x: 0.5 * width, y: chip.y * height - 10)
                }
                var path = Path()
                path.move(to: start)
                path.addLine(to: target)
                let active = selectedZone == chip.zoneID || hovered == chip.zoneID
                context.stroke(path,
                               with: .color(active ? Theme.accent.opacity(0.85)
                                                   : Color.primary.opacity(0.16)),
                               lineWidth: active ? 1.4 : 1)
            }
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }

    /// Libelle a afficher : le binding, ou nil quand l'entree est libre.
    private func text(for chip: PadArtwork.Chip) -> String? {
        if chip.grouped {
            let isMouse = (chip.zoneID == "leftStick" && profile.mouse.source == .leftStick)
                || (chip.zoneID == "rightStick" && profile.mouse.source == .rightStick)
            if isMouse { return "Visee souris" }
            let parts = chip.inputs.compactMap { profile.bindings[$0]?.summary }
            guard !parts.isEmpty else { return nil }
            let joined = parts.joined(separator: " ")
            // Quatre libelles longs ne tiennent pas : on annonce le nombre.
            return joined.count <= 13 ? joined : "\(parts.count) touches"
        }
        guard let binding = profile.bindings[chip.inputs[0]], !binding.isEmpty else { return nil }
        return binding.summary
    }
}

/// Etiquette de touche posee sur un rail lateral.
private struct ChipLabel: View {
    let text: String
    let assigned: Bool
    let highlighted: Bool
    let selected: Bool
    let alignment: Alignment

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: assigned ? .semibold : .regular))
            .lineLimit(1)
            .truncationMode(.tail)
            .foregroundStyle(highlighted ? Color.white : (assigned ? .primary : .secondary))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(highlighted ? Theme.accent
                                      : Color(nsColor: .controlBackgroundColor).opacity(assigned ? 0.98 : 0.7))
                    .shadow(color: .black.opacity(0.16), radius: 3, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(selected ? Theme.accent : Color.primary.opacity(assigned ? 0.14 : 0.07),
                                  lineWidth: selected ? 1.5 : 1)
            )
            .animation(.easeOut(duration: 0.09), value: highlighted)
    }
}
