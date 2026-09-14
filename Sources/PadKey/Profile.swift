import Foundation
import CoreGraphics

/// Toutes les entrees d'une DualSense exploitables comme un bouton on/off.
enum PadInput: String, CaseIterable, Codable {
    case cross, circle, square, triangle
    case l1, r1, l2, r2, l3, r3
    case dpadUp, dpadDown, dpadLeft, dpadRight
    case options, create, ps, touchpad
    case leftStickUp, leftStickDown, leftStickLeft, leftStickRight
    case rightStickUp, rightStickDown, rightStickLeft, rightStickRight

    var label: String {
        switch self {
        case .cross: return "Croix"
        case .circle: return "Rond"
        case .square: return "Carre"
        case .triangle: return "Triangle"
        case .l1: return "L1"
        case .r1: return "R1"
        case .l2: return "L2 (gachette)"
        case .r2: return "R2 (gachette)"
        case .l3: return "L3 (clic stick G)"
        case .r3: return "R3 (clic stick D)"
        case .dpadUp: return "Croix dir. haut"
        case .dpadDown: return "Croix dir. bas"
        case .dpadLeft: return "Croix dir. gauche"
        case .dpadRight: return "Croix dir. droite"
        case .options: return "Options"
        case .create: return "Create / Share"
        case .ps: return "Bouton PS"
        case .touchpad: return "Clic pave tactile"
        case .leftStickUp: return "Stick G haut"
        case .leftStickDown: return "Stick G bas"
        case .leftStickLeft: return "Stick G gauche"
        case .leftStickRight: return "Stick G droite"
        case .rightStickUp: return "Stick D haut"
        case .rightStickDown: return "Stick D bas"
        case .rightStickLeft: return "Stick D gauche"
        case .rightStickRight: return "Stick D droite"
        }
    }

    /// Ordre d'affichage dans la fenetre de reglages.
    static let displayOrder: [PadInput] = [
        .leftStickUp, .leftStickDown, .leftStickLeft, .leftStickRight,
        .rightStickUp, .rightStickDown, .rightStickLeft, .rightStickRight,
        .cross, .circle, .square, .triangle,
        .l1, .r1, .l2, .r2, .l3, .r3,
        .dpadUp, .dpadDown, .dpadLeft, .dpadRight,
        .options, .create, .touchpad, .ps,
    ]
}

enum MouseButtonKind: String, Codable {
    case left, right, middle

    var label: String {
        switch self {
        case .left: return "Clic gauche"
        case .right: return "Clic droit"
        case .middle: return "Clic milieu"
        }
    }
}

enum ScrollDirection: String, Codable {
    case up, down, left, right

    var label: String {
        switch self {
        case .up: return "Molette haut"
        case .down: return "Molette bas"
        case .left: return "Molette gauche"
        case .right: return "Molette droite"
        }
    }
}

/// Ce que declenche une entree. Tous les champs sont optionnels pour que le JSON
/// reste court a ecrire a la main : {"keys": ["Shift", "W"]} ou {"mouse": "left"}.
struct PadBinding: Codable, Equatable {
    var keys: [String]?
    var chars: [String]?
    var keycodes: [Int]?
    var mouse: MouseButtonKind?
    var scroll: ScrollDirection?

    var isEmpty: Bool {
        (keys?.isEmpty ?? true) && (chars?.isEmpty ?? true) && (keycodes?.isEmpty ?? true)
            && mouse == nil && scroll == nil
    }

    static func key(_ names: String...) -> PadBinding { PadBinding(keys: names) }
    static func click(_ button: MouseButtonKind) -> PadBinding { PadBinding(mouse: button) }
    static func wheel(_ direction: ScrollDirection) -> PadBinding { PadBinding(scroll: direction) }

    /// Traduit le binding en codes concrets, en tenant compte de la disposition clavier
    /// pour les entrees exprimees en caracteres.
    func resolve() -> ResolvedBinding {
        var codes: [CGKeyCode] = []
        for name in keys ?? [] {
            if let code = KeyCodes.code(forName: name) { codes.append(code) }
        }
        for character in chars ?? [] {
            if let code = KeyCodes.code(forCharacter: character) { codes.append(code) }
        }
        for raw in keycodes ?? [] where raw >= 0 && raw <= 127 {
            codes.append(CGKeyCode(raw))
        }
        return ResolvedBinding(keyCodes: codes, mouse: mouse, scroll: scroll)
    }

    /// Libelle lisible, du genre "Maj + W" ou "Clic gauche".
    var summary: String {
        var parts: [String] = []
        parts.append(contentsOf: (keys ?? []).map { KeyCodes.code(forName: $0).map(KeyCodes.label) ?? $0 })
        parts.append(contentsOf: (chars ?? []).map { $0.uppercased() })
        parts.append(contentsOf: (keycodes ?? []).map { KeyCodes.label(for: CGKeyCode($0)) })
        if let mouse { parts.append(mouse.label) }
        if let scroll { parts.append(scroll.label) }
        return parts.isEmpty ? "Aucune" : parts.joined(separator: " + ")
    }
}

struct ResolvedBinding {
    var keyCodes: [CGKeyCode]
    var mouse: MouseButtonKind?
    var scroll: ScrollDirection?
}

enum MouseSource: String, Codable {
    case rightStick, leftStick, none

    var label: String {
        switch self {
        case .rightStick: return "Stick droit"
        case .leftStick: return "Stick gauche"
        case .none: return "Desactive"
        }
    }
}

struct MouseConfig: Codable, Equatable {
    /// Quel stick pilote le curseur.
    var source: MouseSource = .rightStick
    /// Vitesse maximale, en pixels par seconde, stick pousse a fond.
    var speed: Double = 1400
    /// Zone morte du stick, en fraction de sa course.
    var deadzone: Double = 0.10
    /// Exposant applique a la poussee : 1 = lineaire, 2 a 3 = plus de precision au centre.
    var curve: Double = 2.0
    /// Facteur applique a l'axe vertical (les jeux sont souvent plus sensibles en Y).
    var verticalScale: Double = 0.75
    var invertY: Bool = false
}

struct Profile: Codable, Equatable {
    var name: String
    var notes: String?
    /// Poussee a partir de laquelle un stick compte comme une direction pressee.
    var stickDeadzone: Double = 0.45
    /// Enfoncement a partir duquel L2 / R2 comptent comme presses.
    var triggerThreshold: Double = 0.30
    /// Delai entre deux crans de molette quand l'entree est maintenue.
    var scrollInterval: Double = 0.07
    var mouse: MouseConfig = MouseConfig()
    var bindings: [PadInput: PadBinding] = [:]

    enum CodingKeys: String, CodingKey {
        case name, notes, stickDeadzone, triggerThreshold, scrollInterval, mouse, bindings
    }

    init(name: String,
         notes: String? = nil,
         stickDeadzone: Double = 0.45,
         triggerThreshold: Double = 0.30,
         scrollInterval: Double = 0.07,
         mouse: MouseConfig = MouseConfig(),
         bindings: [PadInput: PadBinding] = [:]) {
        self.name = name
        self.notes = notes
        self.stickDeadzone = stickDeadzone
        self.triggerThreshold = triggerThreshold
        self.scrollInterval = scrollInterval
        self.mouse = mouse
        self.bindings = bindings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        stickDeadzone = try container.decodeIfPresent(Double.self, forKey: .stickDeadzone) ?? 0.45
        triggerThreshold = try container.decodeIfPresent(Double.self, forKey: .triggerThreshold) ?? 0.30
        scrollInterval = try container.decodeIfPresent(Double.self, forKey: .scrollInterval) ?? 0.07
        mouse = try container.decodeIfPresent(MouseConfig.self, forKey: .mouse) ?? MouseConfig()

        // Les cles inconnues sont ignorees plutot que de faire echouer tout le fichier.
        let raw = try container.decodeIfPresent([String: PadBinding].self, forKey: .bindings) ?? [:]
        var parsed: [PadInput: PadBinding] = [:]
        for (key, value) in raw {
            guard let input = PadInput(rawValue: key) ?? PadInput.alias(for: key) else { continue }
            parsed[input] = value
        }
        bindings = parsed
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(stickDeadzone, forKey: .stickDeadzone)
        try container.encode(triggerThreshold, forKey: .triggerThreshold)
        try container.encode(scrollInterval, forKey: .scrollInterval)
        try container.encode(mouse, forKey: .mouse)
        var raw: [String: PadBinding] = [:]
        for (input, binding) in bindings where !binding.isEmpty {
            raw[input.rawValue] = binding
        }
        try container.encode(raw, forKey: .bindings)
    }

    var fileName: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let slug = name.lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
            .map { character -> Character in
                String(character).rangeOfCharacter(from: allowed) == nil ? "-" : character
            }
        return String(slug).replacingOccurrences(of: "--", with: "-") + ".json"
    }
}

extension PadInput {
    /// Noms alternatifs acceptes dans les fichiers JSON ecrits a la main.
    static func alias(for key: String) -> PadInput? {
        switch key.lowercased() {
        case "x", "buttona", "a": return .cross
        case "o", "buttonb", "b": return .circle
        case "buttonx": return .square
        case "buttony": return .triangle
        case "leftshoulder", "lb": return .l1
        case "rightshoulder", "rb": return .r1
        case "lefttrigger", "lt": return .l2
        case "righttrigger", "rt": return .r2
        case "leftthumbstickbutton", "leftstickbutton": return .l3
        case "rightthumbstickbutton", "rightstickbutton": return .r3
        case "menu", "start": return .options
        case "share", "select": return .create
        case "home", "guide": return .ps
        case "touchpadbutton": return .touchpad
        default: return nil
        }
    }
}
