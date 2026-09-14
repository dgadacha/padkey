import Foundation

/// Profils installes au premier lancement. Ils restent modifiables ensuite :
/// les fichiers JSON du dossier de profils font foi.
enum DefaultProfiles {

    static var all: [Profile] { [outlast, fps, desktop] }

    /// Calque sur le menu Controles d'Outlast (clavier / souris).
    static let outlast = Profile(
        name: "Outlast",
        notes: "Stick gauche pour marcher, stick droit pour regarder. L2 sort le camescope, R2 interagit, PS maintenu une seconde coupe le mapping.",
        stickDeadzone: 0.40,
        triggerThreshold: 0.25,
        mouse: MouseConfig(source: .rightStick, speed: 1500, deadzone: 0.09, curve: 2.0, verticalScale: 0.75),
        bindings: [
            .leftStickUp: .key("W"),
            .leftStickDown: .key("S"),
            .leftStickLeft: .key("A"),
            .leftStickRight: .key("D"),
            .l3: .key("Shift"),          // courir
            .circle: .key("Control"),    // s'accroupir
            .cross: .key("Space"),       // sauter
            .triangle: .key("F"),        // vision nocturne
            .square: .key("R"),          // changer les piles
            .l1: .key("Q"),              // se pencher a gauche
            .r1: .key("E"),              // se pencher a droite
            .l2: .click(.right),         // camescope
            .r2: .click(.left),          // utiliser
            .dpadUp: .wheel(.up),        // zoom avant
            .dpadDown: .wheel(.down),    // zoom arriere
            .options: .key("Escape"),
            .touchpad: .key("Tab"),
        ]
    )

    /// Base pour un jeu de tir a la premiere personne.
    static let fps = Profile(
        name: "FPS generique",
        notes: "Schema classique manette vers clavier et souris. A dupliquer et ajuster par jeu.",
        mouse: MouseConfig(source: .rightStick, speed: 1600, deadzone: 0.08, curve: 2.2, verticalScale: 0.8),
        bindings: [
            .leftStickUp: .key("W"),
            .leftStickDown: .key("S"),
            .leftStickLeft: .key("A"),
            .leftStickRight: .key("D"),
            .l3: .key("Shift"),
            .r3: .key("C"),
            .cross: .key("Space"),
            .circle: .key("Control"),
            .square: .key("R"),
            .triangle: .key("E"),
            .l1: .wheel(.up),
            .r1: .wheel(.down),
            .l2: .click(.right),
            .r2: .click(.left),
            .dpadUp: .key("1"),
            .dpadDown: .key("2"),
            .dpadLeft: .key("3"),
            .dpadRight: .key("4"),
            .options: .key("Escape"),
            .create: .key("Tab"),
            .touchpad: .key("M"),
        ]
    )

    /// Pour piloter le Mac depuis le canape, sans clavier.
    static let desktop = Profile(
        name: "Bureau",
        notes: "Le stick droit deplace le curseur, R2 clique. Pratique pour lancer un jeu sans se relever.",
        mouse: MouseConfig(source: .rightStick, speed: 1100, deadzone: 0.12, curve: 2.6, verticalScale: 1.0),
        bindings: [
            .leftStickUp: .repeating("Up"),
            .leftStickDown: .repeating("Down"),
            .leftStickLeft: .repeating("Left"),
            .leftStickRight: .repeating("Right"),
            .cross: .key("Return"),
            .circle: .key("Escape"),
            .square: .key("Space"),
            .triangle: .key("Tab"),
            .r2: .click(.left),
            .l2: .click(.right),
            .r1: .wheel(.down),
            .l1: .wheel(.up),
            .dpadUp: .repeating("Up"),
            .dpadDown: .repeating("Down"),
            .dpadLeft: .repeating("Left"),
            .dpadRight: .repeating("Right"),
            .options: PadBinding(keys: ["Command", "Tab"]),
            .touchpad: PadBinding(keys: ["Command", "Space"]),
        ]
    )
}
