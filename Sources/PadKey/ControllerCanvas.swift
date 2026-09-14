import SwiftUI

/// Le coeur de l'ecran : la manette, ses zones cliquables et les etiquettes de
/// mapping reliees par des traits discrets.
struct ControllerCanvas: View {
    let profile: Profile
    let snapshot: PadSnapshot?
    @Binding var selectedZone: String?
    @Binding var hoveredZone: String?

    private var pressed: Set<PadInput> { snapshot?.pressed ?? [] }

    var body: some View {
        GeometryReader { geo in
            // La manette domine sans ecraser : environ trois cinquiemes de la
            // largeur, le reste revient aux etiquettes.
            let margin = PadArtwork.chipWidth + 30
            let available = max(geo.size.width - margin * 2, 260)
            let width = min(available, geo.size.width * 0.60, (geo.size.height - 36) * PadArtwork.aspect)
            let height = width / PadArtwork.aspect

            ZStack {
                dotGrid
                RadialGradient(colors: [Color.white.opacity(0.05), .clear],
                               center: .center, startRadius: 4, endRadius: width * 0.62)
                    .frame(width: width * 1.5, height: height * 1.6)
                    .allowsHitTesting(false)
                board(width: width, height: height)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    /// Grille de points presque invisible, pour que le fond ne soit pas plat.
    private var dotGrid: some View {
        Canvas { context, size in
            let step: CGFloat = 22
            let color = Color.white.opacity(0.022)
            var y: CGFloat = step
            while y < size.height {
                var x: CGFloat = step
                while x < size.width {
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.5, height: 1.5)),
                                 with: .color(color))
                    x += step
                }
                y += step
            }
        }
        .allowsHitTesting(false)
    }

    private func board(width: CGFloat, height: CGFloat) -> some View {
        bodyImage
            .resizable()
            .interpolation(.high)
            .frame(width: width, height: height)
            .overlay { sticks(width: width, height: height) }
            .overlay { highlights(width: width, height: height) }
            .overlay { hotspots(width: width, height: height) }
            .overlay { leaders(width: width, height: height) }
            .overlay { chips(width: width, height: height) }
    }

    private var bodyImage: Image {
        if let nsImage = PadArtwork.image(named: "dualsense-body-dark") {
            return Image(nsImage: nsImage)
        }
        return Image(systemName: "gamecontroller")
    }

    // MARK: - Capuchons de sticks

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
        .allowsHitTesting(false)
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

    // MARK: - Etats des controles

    private func highlights(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(PadArtwork.zones) { zone in
                let triggers = zone.litBy.isEmpty ? zone.inputs : zone.litBy
                let lit = triggers.contains { pressed.contains($0) }
                let selected = selectedZone == zone.id
                let hovered = hoveredZone == zone.id

                shape(for: zone)
                    .fill(Theme.accent.opacity(lit ? 0.5 : (hovered ? 0.10 : 0)))
                    .blur(radius: lit ? width * 0.010 : 0)
                    .overlay {
                        shape(for: zone)
                            .stroke(selected ? Theme.accent : .clear, lineWidth: 2)
                            .shadow(color: selected ? Theme.accent.opacity(0.55) : .clear, radius: 6)
                    }
                    .frame(width: zone.rect.width * width, height: zone.rect.height * height)
                    .offset(x: zone.rect.minX * width, y: zone.rect.minY * height)
                    .animation(Theme.hover, value: lit)
                    .animation(Theme.selection, value: selected)
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

    private func hotspots(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(PadArtwork.zones) { zone in
                Rectangle()
                    .fill(Color.white.opacity(0.001))
                    .frame(width: max(zone.rect.width * width, 26),
                           height: max(zone.rect.height * height, 26))
                    .offset(x: zone.rect.minX * width, y: zone.rect.minY * height)
                    .onTapGesture { selectedZone = zone.id }
                    .onHover { inside in
                        if inside { hoveredZone = zone.id }
                        else if hoveredZone == zone.id { hoveredZone = nil }
                    }
                    .help(zone.title)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }

    // MARK: - Traits de rappel

    private func leaders(width: CGFloat, height: CGFloat) -> some View {
        Canvas { context, _ in
            for chip in PadArtwork.chips where label(for: chip) != nil {
                guard let zone = PadArtwork.zone(id: chip.zoneID) else { continue }
                let target = CGPoint(x: zone.rect.midX * width, y: zone.rect.midY * height)
                let start: CGPoint
                switch chip.side {
                case .left: start = CGPoint(x: PadArtwork.leftRail * width + 6, y: chip.y * height)
                case .right: start = CGPoint(x: PadArtwork.rightRail * width - 6, y: chip.y * height)
                case .center: start = CGPoint(x: 0.5 * width, y: chip.y * height - 12)
                }

                // Un coude horizontal puis une diagonale : le trait longe le badge
                // avant de rejoindre le controle, ce qui evite les croisements.
                let elbow = CGPoint(x: start.x + (chip.side == .left ? 18 : -18), y: start.y)
                var path = Path()
                path.move(to: start)
                if chip.side != .center { path.addLine(to: elbow) }
                path.addLine(to: target)

                let active = selectedZone == chip.zoneID || hoveredZone == chip.zoneID
                context.stroke(path,
                               with: .color(active ? Theme.accent.opacity(0.9)
                                                   : Color.white.opacity(0.22)),
                               lineWidth: 1)
            }
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }

    // MARK: - Etiquettes

    private func chips(width: CGFloat, height: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(PadArtwork.chips) { chip in
                if let text = label(for: chip) {
                    MappingBadge(symbol: PadArtwork.badge(for: chip.zoneID),
                                 value: text,
                                 pressed: chip.inputs.contains { pressed.contains($0) },
                                 selected: selectedZone == chip.zoneID,
                                 hovered: hoveredZone == chip.zoneID,
                                 alignment: alignment(for: chip.side))
                        .frame(width: PadArtwork.chipWidth, alignment: alignment(for: chip.side))
                        .contentShape(Rectangle())
                        .onTapGesture { selectedZone = chip.zoneID }
                        .onHover { inside in
                            if inside { hoveredZone = chip.zoneID }
                            else if hoveredZone == chip.zoneID { hoveredZone = nil }
                        }
                        .position(x: centerX(chip, width: width), y: chip.y * height)
                }
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }

    private func centerX(_ chip: PadArtwork.Chip, width: CGFloat) -> CGFloat {
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

    /// Seules les entrees reellement assignees portent une etiquette : le reste
    /// se selectionne en cliquant le controle sur la manette.
    private func label(for chip: PadArtwork.Chip) -> String? {
        if chip.grouped {
            let isMouse = (chip.zoneID == "leftStick" && profile.mouse.source == .leftStick)
                || (chip.zoneID == "rightStick" && profile.mouse.source == .rightStick)
            if isMouse { return "Souris" }
            let directions = chip.inputs.dropLast().compactMap { profile.bindings[$0]?.summary }
            let click = chip.inputs.last.flatMap { profile.bindings[$0]?.summary }
            var parts: [String] = []
            if !directions.isEmpty { parts.append(directions.joined(separator: " ")) }
            if let click { parts.append(click) }
            let joined = parts.joined(separator: "  ")
            return joined.isEmpty ? nil : (joined.count <= 16 ? joined : "\(directions.count + (click == nil ? 0 : 1)) touches")
        }
        guard let binding = profile.bindings[chip.inputs[0]], !binding.isEmpty else { return nil }
        return binding.summary
    }
}

/// Etiquette en deux segments : le controle, puis ce qu'il envoie.
struct MappingBadge: View {
    let symbol: String
    let value: String
    let pressed: Bool
    let selected: Bool
    let hovered: Bool
    let alignment: Alignment

    var body: some View {
        HStack(spacing: 0) {
            Text(symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(pressed || selected ? Color.white : Theme.textSecondary)
                .frame(minWidth: 30)
                .padding(.horizontal, 6)
                .frame(height: 26)
                .background(pressed ? Theme.accentHover : Color.white.opacity(0.05))

            Text(value)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(pressed ? Color.white : Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.horizontal, 8)
                .frame(height: 26)
        }
        .fixedSize()
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                .fill(pressed ? Theme.accent : Theme.bgSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusControl, style: .continuous)
                .strokeBorder(selected ? Theme.accent
                                       : (hovered ? Theme.borderMedium : Theme.borderSubtle),
                              lineWidth: selected ? 1.5 : 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
        .opacity(pressed || selected || hovered ? 1 : 0.92)
        .animation(Theme.hover, value: pressed)
        .animation(Theme.selection, value: selected)
    }
}
