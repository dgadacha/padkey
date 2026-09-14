import AppKit
import SwiftUI
import CoreGraphics

/// Harnais de developpement : rend la fenetre hors ecran dans un PNG.
/// Une vue peut se dessiner elle-meme sans autorisation d'enregistrement d'ecran,
/// ce qui permet de verifier la mise en page sans capture systeme.
enum Snapshot {

    @MainActor
    static func capture(to path: String, dark: Bool, demo: Bool, profile: String?, list: Bool) {
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        app.finishLaunching()

        let state = AppState()
        if let profile, state.profiles.contains(where: { $0.name == profile }) {
            state.select(profileNamed: profile)
        }
        if demo {
            var fake = PadSnapshot()
            fake.pressed = [.cross, .l2, .leftStickUp, .leftStickRight]
            fake.leftStick = CGPoint(x: 0.62, y: 0.78)
            fake.rightStick = CGPoint(x: -0.45, y: -0.30)
            fake.leftTrigger = 0.85
            fake.rightTrigger = 0.12
            state.liveSnapshot = fake
            state.statusItemHidden = true
        }

        let hosting = NSHostingController(rootView: SettingsView(state: state, initialMode: list ? .list : .board, initialZone: demo ? "leftStick" : nil))
        let window = NSWindow(contentViewController: hosting)
        window.styleMask = [.titled, .closable, .resizable]
        window.title = "PadKey"
        window.setContentSize(NSSize(width: 1440, height: 900))
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.setFrameOrigin(NSPoint(x: -4000, y: 0))
        window.orderFront(nil)

        RunLoop.current.run(until: Date().addingTimeInterval(2.0))

        guard let view = window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
            print("capture impossible")
            return
        }
        view.cacheDisplay(in: view.bounds, to: rep)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            print("encodage impossible")
            return
        }
        try? data.write(to: URL(fileURLWithPath: path))
        print("ecrit : \(path) (\(Int(view.bounds.width))x\(Int(view.bounds.height)))")
    }
}
