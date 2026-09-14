import SwiftUI

/// Geometrie de l'illustration de DualSense.
/// Les rectangles sont normalises (0...1) sur l'image du corps de la manette ;
/// ils ont ete releves directement dans le SVG d'origine, calque par calque.
enum PadArtwork {

    static let aspect: CGFloat = 1467.0 / 816.0

    /// Une region interactive du dessin : zone cliquable et zone eclairee.
    struct Zone: Identifiable {
        let id: String
        let title: String
        let inputs: [PadInput]
        let rect: CGRect
        let round: Bool
        /// Rayon des coins du halo, pour epouser la forme dessinee.
        var corner: CGFloat = 6
        /// Entrees dont l'appui allume la zone. Vide = toutes.
        var litBy: [PadInput] = []
    }

    /// Etiquette de touche, posee sur un rail lateral et reliee au controle
    /// par un trait de rappel, comme sur une notice de manette.
    struct Chip: Identifiable {
        enum Side { case left, right, center }
        let id: String
        let inputs: [PadInput]
        let zoneID: String
        let side: Side
        /// Position verticale sur le rail, normalisee sur la hauteur du dessin.
        let y: Double
        /// Les quatre directions d'un stick tiennent sur une seule etiquette.
        var grouped = false
    }

    /// Abscisse des rails, en fraction de la largeur du dessin.
    static let leftRail: Double = -0.035
    static let rightRail: Double = 1.035
    static let chipWidth: CGFloat = 150

    private static func r(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> CGRect {
        CGRect(x: x, y: y, width: w, height: h)
    }

    static let zones: [Zone] = [
        Zone(id: "l2", title: "L2", inputs: [.l2], rect: r(0.128, 0.014, 0.114, 0.078), round: false, corner: 14),
        Zone(id: "r2", title: "R2", inputs: [.r2], rect: r(0.759, 0.014, 0.114, 0.078), round: false, corner: 14),
        Zone(id: "l1", title: "L1", inputs: [.l1], rect: r(0.116, 0.112, 0.126, 0.126), round: false, corner: 16),
        Zone(id: "r1", title: "R1", inputs: [.r1], rect: r(0.759, 0.112, 0.126, 0.126), round: false, corner: 16),

        Zone(id: "dpadUp", title: "Croix directionnelle haut", inputs: [.dpadUp],
             rect: r(0.1482, 0.3928, 0.0587, 0.1207), round: false),
        Zone(id: "dpadDown", title: "Croix directionnelle bas", inputs: [.dpadDown],
             rect: r(0.1487, 0.5406, 0.0587, 0.1167), round: false),
        Zone(id: "dpadLeft", title: "Croix directionnelle gauche", inputs: [.dpadLeft],
             rect: r(0.0916, 0.4779, 0.0722, 0.0975), round: false),
        Zone(id: "dpadRight", title: "Croix directionnelle droite", inputs: [.dpadRight],
             rect: r(0.1921, 0.4782, 0.0722, 0.0975), round: false),

        Zone(id: "triangle", title: "Triangle", inputs: [.triangle],
             rect: r(0.7895, 0.3539, 0.0696, 0.1166), round: true),
        Zone(id: "circle", title: "Rond", inputs: [.circle],
             rect: r(0.8631, 0.4654, 0.0689, 0.1144), round: true),
        Zone(id: "square", title: "Carre", inputs: [.square],
             rect: r(0.7118, 0.4732, 0.0696, 0.1092), round: true),
        Zone(id: "cross", title: "Croix", inputs: [.cross],
             rect: r(0.7854, 0.5854, 0.0693, 0.1033), round: true),

        Zone(id: "create", title: "Create", inputs: [.create],
             rect: r(0.2407, 0.2811, 0.0323, 0.1104), round: false),
        Zone(id: "options", title: "Options", inputs: [.options],
             rect: r(0.7282, 0.2796, 0.0321, 0.1121), round: false),
        Zone(id: "touchpad", title: "Pave tactile", inputs: [.touchpad],
             rect: r(0.2830, 0.2680, 0.4340, 0.3300), round: false, corner: 18),
        Zone(id: "ps", title: "Bouton PS", inputs: [.ps],
             rect: r(0.4697, 0.6707, 0.0656, 0.0626), round: true),

        Zone(id: "leftStick", title: "Stick gauche",
             inputs: [.leftStickUp, .leftStickLeft, .leftStickDown, .leftStickRight, .l3],
             rect: r(0.2767, 0.6868, 0.1193, 0.1813), round: true, litBy: [.l3]),
        Zone(id: "rightStick", title: "Stick droit",
             inputs: [.rightStickUp, .rightStickLeft, .rightStickDown, .rightStickRight, .r3],
             rect: r(0.6050, 0.6876, 0.1193, 0.1813), round: true, litBy: [.r3]),
    ]

    static let chips: [Chip] = [
        Chip(id: "l2", inputs: [.l2], zoneID: "l2", side: .left, y: 0.050),
        Chip(id: "l1", inputs: [.l1], zoneID: "l1", side: .left, y: 0.165),
        Chip(id: "create", inputs: [.create], zoneID: "create", side: .left, y: 0.285),
        Chip(id: "dpadUp", inputs: [.dpadUp], zoneID: "dpadUp", side: .left, y: 0.405),
        Chip(id: "dpadLeft", inputs: [.dpadLeft], zoneID: "dpadLeft", side: .left, y: 0.510),
        Chip(id: "dpadRight", inputs: [.dpadRight], zoneID: "dpadRight", side: .left, y: 0.615),
        Chip(id: "dpadDown", inputs: [.dpadDown], zoneID: "dpadDown", side: .left, y: 0.720),
        Chip(id: "leftStick",
             inputs: [.leftStickUp, .leftStickLeft, .leftStickDown, .leftStickRight, .l3],
             zoneID: "leftStick", side: .left, y: 0.880, grouped: true),

        Chip(id: "r2", inputs: [.r2], zoneID: "r2", side: .right, y: 0.050),
        Chip(id: "r1", inputs: [.r1], zoneID: "r1", side: .right, y: 0.165),
        Chip(id: "options", inputs: [.options], zoneID: "options", side: .right, y: 0.285),
        Chip(id: "touchpad", inputs: [.touchpad], zoneID: "touchpad", side: .right, y: 0.390),
        Chip(id: "triangle", inputs: [.triangle], zoneID: "triangle", side: .right, y: 0.495),
        Chip(id: "square", inputs: [.square], zoneID: "square", side: .right, y: 0.585),
        Chip(id: "circle", inputs: [.circle], zoneID: "circle", side: .right, y: 0.675),
        Chip(id: "cross", inputs: [.cross], zoneID: "cross", side: .right, y: 0.765),
        Chip(id: "rightStick",
             inputs: [.rightStickUp, .rightStickLeft, .rightStickDown, .rightStickRight, .r3],
             zoneID: "rightStick", side: .right, y: 0.880, grouped: true),

        Chip(id: "ps", inputs: [.ps], zoneID: "ps", side: .center, y: 1.010),
    ]

    static func zone(id: String) -> Zone? { zones.first { $0.id == id } }

    /// Etiquette courte du controle, celle imprimee sur la manette.
    static func badge(for zoneID: String) -> String {
        switch zoneID {
        case "l1": return "L1"
        case "l2": return "L2"
        case "r1": return "R1"
        case "r2": return "R2"
        case "triangle": return "\u{25B3}"
        case "circle": return "\u{25CB}"
        case "cross": return "\u{2715}"
        case "square": return "\u{25A1}"
        case "dpadUp": return "\u{2191}"
        case "dpadDown": return "\u{2193}"
        case "dpadLeft": return "\u{2190}"
        case "dpadRight": return "\u{2192}"
        case "create": return "Create"
        case "options": return "Options"
        case "touchpad": return "Pave"
        case "ps": return "PS"
        case "leftStick": return "Stick G"
        case "rightStick": return "Stick D"
        default: return ""
        }
    }

    static func zone(for input: PadInput) -> Zone? { zones.first { $0.inputs.contains(input) } }

    /// Images du pack livre avec l'application. Le repli sur le dossier Resources
    /// du depot sert quand le binaire tourne hors de son bundle, en developpement.
    static func image(named name: String) -> NSImage? {
        if let path = Bundle.main.path(forResource: name, ofType: "png"),
           let image = NSImage(contentsOfFile: path) {
            return image
        }
        let fallback = FileManager.default.currentDirectoryPath + "/Resources/\(name).png"
        return NSImage(contentsOfFile: fallback)
    }
}
