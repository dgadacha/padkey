import Foundation
import AppKit
import GameController

/// Mode console : `PadKey --diagnostic` affiche ce que le systeme lit de la manette.
/// Sert a verifier le materiel independamment de l'autorisation Accessibilite.
enum Diagnostic {

    static func run(duration: TimeInterval = 8) {
        GCController.shouldMonitorBackgroundEvents = true
        print("PadKey \(AppInfo.full) - diagnostic, lecture pendant \(Int(duration)) s")

        if SteamWatch.isRunning() {
            print("")
            print("ATTENTION : Steam est ouvert.")
            print("Si Steam Input est actif, il capte la DualSense et la remplace par une")
            print("manette virtuelle : les valeurs ci-dessous resteront alors figees a zero.")
            print("Pour un jeu Steam, ne fermez pas Steam : desactivez Steam Input pour ce")
            print("jeu (Bibliotheque, clic droit, Proprietes, Manette). Bougez les sticks")
            print("pendant ce test pour savoir si la manette est reellement lue.")
            print("")
        }

        print("Accessibilite : \(Permissions.hasAccessibility ? "accordee" : "MANQUANTE")")
        print("Controle des entrees : \(Permissions.inputMonitoringLabel)")
        print("")

        let deadline = Date().addingTimeInterval(duration)
        var announced = false
        var lastLine = ""

        while Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))

            guard let controller = MappingEngine.pick(from: GCController.controllers(), preferring: nil),
                  let pad = controller.extendedGamepad else {
                if !announced {
                    print("Aucune manette vue par macOS. Verifiez l'appairage Bluetooth.")
                    announced = true
                }
                continue
            }

            if !announced {
                for (index, candidate) in GCController.controllers().enumerated() {
                    let kind: String
                    switch candidate.extendedGamepad {
                    case is GCDualSenseGamepad: kind = "DualSense"
                    case is GCDualShockGamepad: kind = "DualShock 4"
                    case is GCXboxGamepad: kind = "Xbox"
                    default: kind = "generique"
                    }
                    print("[\(index)] \(candidate.vendorName ?? "?") - profil \(kind)")
                }
                print("Manette lue : \(controller.vendorName ?? "?")")
                if !(pad is GCDualSenseGamepad) {
                    print("Le profil n'est pas DualSense : un autre logiciel s'est probablement")
                    print("intercale entre la manette et macOS (Steam Input le plus souvent).")
                }
                print("Bougez les sticks et appuyez sur les boutons.")
                announced = true
            }

            var pressed: [String] = []
            let buttons: [(String, GCControllerButtonInput?)] = [
                ("Croix", pad.buttonA), ("Rond", pad.buttonB), ("Carre", pad.buttonX), ("Triangle", pad.buttonY),
                ("L1", pad.leftShoulder), ("R1", pad.rightShoulder),
                ("L3", pad.leftThumbstickButton), ("R3", pad.rightThumbstickButton),
                ("Options", pad.buttonMenu), ("Create", pad.buttonOptions), ("PS", pad.buttonHome),
                ("Haut", pad.dpad.up), ("Bas", pad.dpad.down), ("Gauche", pad.dpad.left), ("Droite", pad.dpad.right),
            ]
            for (name, button) in buttons where button?.isPressed == true { pressed.append(name) }
            if let dualSense = pad as? GCDualSenseGamepad, dualSense.touchpadButton.isPressed {
                pressed.append("Pave")
            }

            let line = String(
                format: "SG %+.2f %+.2f   SD %+.2f %+.2f   L2 %.2f  R2 %.2f   %@",
                pad.leftThumbstick.xAxis.value, pad.leftThumbstick.yAxis.value,
                pad.rightThumbstick.xAxis.value, pad.rightThumbstick.yAxis.value,
                pad.leftTrigger.value, pad.rightTrigger.value,
                pressed.isEmpty ? "-" : pressed.joined(separator: " ")
            )
            if line != lastLine {
                print(line)
                lastLine = line
            }
        }
        print("Fin du diagnostic.")
    }

    /// Verifie qu'une touche envoyee par PadKey reste bien enfoncee tant que
    /// l'entree est maintenue. Dans un editeur de texte, un seul caractere
    /// s'affiche parce que l'auto-repetition du systeme ne s'applique qu'aux vraies
    /// frappes ; les jeux, eux, lisent l'etat de la touche, pas les repetitions.
    static func testKeyHold() {
        guard Permissions.hasAccessibility else {
            print("Accessibilite MANQUANTE : aucun evenement ne peut sortir.")
            return
        }

        // F13 n'ecrit rien et n'est mappee nulle part : le test ne laisse aucune
        // trace dans l'application au premier plan.
        let code: CGKeyCode = 105
        let synth = OutputSynth()

        func state() -> String {
            CGEventSource.keyState(.hidSystemState, key: code) ? "ENFONCEE" : "relachee"
        }

        print("Test du maintien de touche, sur F13 pour n'ecrire nulle part.")
        print("avant        : \(state())")
        synth.keyDown(code)
        for step in 1...6 {
            usleep(250_000)
            print(String(format: "apres %.1f s : %@", Double(step) * 0.25, state()))
        }
        synth.keyUp(code)
        usleep(150_000)
        print("apres relache: \(state())")
        print("")

        measureRepeats(code: code, synth: synth)
        if CGEventSource.keyState(.hidSystemState, key: code) {
            print("La touche est restee enfoncee apres le relachement : c'est un bug.")
        } else {
            print("Conclusion : la touche reste enfoncee tout le temps voulu, puis se")
            print("relache. C'est exactement ce qu'un jeu attend pour un deplacement.")
        }
    }

    private nonisolated(unsafe) static var tapCount = 0
    private nonisolated(unsafe) static var tapKey: CGKeyCode = 0

    /// Ecoute reellement le flux d'evenements pour compter ce qui en sort.
    /// Le compteur systeme ignore les repetitions, il ne prouve donc rien ici.
    private static func measureRepeats(code: CGKeyCode, synth: OutputSynth) {
        tapCount = 0
        tapKey = code
        let mask = (1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                          place: .headInsertEventTap,
                                          options: .listenOnly,
                                          eventsOfInterest: CGEventMask(mask),
                                          callback: { _, _, event, _ in
                                              let key = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
                                              if key == Diagnostic.tapKey { Diagnostic.tapCount += 1 }
                                              return Unmanaged.passUnretained(event)
                                          },
                                          userInfo: nil) else {
            print("Ecoute des evenements impossible.")
            return
        }
        let loop = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), loop, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        synth.keyDown(code)
        for _ in 0..<10 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.045))
            synth.keyRepeat(code)
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        synth.keyUp(code)
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))

        CGEvent.tapEnable(tap: tap, enable: false)
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), loop, .commonModes)

        print("Repetition : \(tapCount) frappes vues pour 1 appui et 10 repetitions.")
        print(tapCount >= 11 ? "Les repetitions sortent correctement."
                             : "Les repetitions n'atteignent pas le systeme.")
        print("")
    }

    /// Verifie que les evenements de synthese sortent vraiment : deplace le curseur,
    /// mesure le resultat, puis le remet ou il etait.
    static func testMouseInjection() {
        guard Permissions.hasAccessibility else {
            print("Accessibilite MANQUANTE : aucun evenement ne peut sortir.")
            print("Reglages Systeme > Confidentialite et securite > Accessibilite > PadKey")
            return
        }

        let synth = OutputSynth()
        let start = CGEvent(source: nil)?.location ?? .zero
        print(String(format: "Curseur au depart : %.0f, %.0f", start.x, start.y))

        for _ in 0..<20 {
            synth.moveMouse(dx: 4, dy: 0)
            usleep(4000)
        }
        let after = CGEvent(source: nil)?.location ?? .zero
        print(String(format: "Curseur apres 80 px vers la droite : %.0f, %.0f", after.x, after.y))

        for _ in 0..<20 {
            synth.moveMouse(dx: -4, dy: 0)
            usleep(4000)
        }
        let back = CGEvent(source: nil)?.location ?? .zero
        print(String(format: "Curseur remis : %.0f, %.0f", back.x, back.y))

        let moved = abs(after.x - start.x)
        if moved >= 60 {
            print("Injection souris fonctionnelle (\(Int(moved)) px mesures).")
        } else {
            print("Le curseur n'a pas bouge : l'autorisation Accessibilite n'est pas active")
            print("pour cette application, ou elle date d'une version precedente du binaire.")
        }
    }
}
