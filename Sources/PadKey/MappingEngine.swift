import Foundation
import GameController
import CoreGraphics

/// Une manette vue par macOS, telle qu'affichee dans les reglages.
struct ControllerInfo: Identifiable, Equatable {
    let id: String
    let name: String
    let kind: String
    let isActive: Bool
    let isUsable: Bool
}

/// Etat brut de la manette a un instant donne.
struct PadSnapshot {
    var pressed: Set<PadInput> = []
    var leftStick: CGPoint = .zero
    var rightStick: CGPoint = .zero
    var leftTrigger: Double = 0
    var rightTrigger: Double = 0
    var psHeld: Bool = false
}

/// Lit la manette a intervalle regulier, compare avec l'etat precedent et
/// traduit les changements en evenements clavier / souris.
final class MappingEngine {

    private static let tickRate: Double = 125.0

    private let synth = OutputSynth()
    private let queue = DispatchQueue(label: "com.tealforge.padkey.engine", qos: .userInteractive)
    private var timer: DispatchSourceTimer?

    private var profile: Profile
    private var resolved: [PadInput: ResolvedBinding] = [:]
    private var enabled = false

    private var previousInputs: Set<PadInput> = []
    private var heldKeys: [CGKeyCode: Int] = [:]
    private var heldMouse: [MouseButtonKind: Int] = [:]
    private var scrollAccumulator: [PadInput: Double] = [:]
    private var mouseRemainder = CGPoint.zero
    private var psHeldSince: Date?
    private var lastTick = Date()
    /// Nom de la manette choisie par l'utilisateur. Vide = choix automatique.
    private var preferredName: String?

    /// Appele sur la file principale quand la liste des manettes change.
    var onControllerChange: ((String?) -> Void)?
    /// Appele sur la file principale quand le moteur s'active ou se desactive tout seul.
    var onEnabledChange: ((Bool) -> Void)?
    /// Flux d'etat brut, alimente uniquement quand quelqu'un l'ecoute.
    var onSnapshot: ((PadSnapshot) -> Void)?
    private var lastSnapshotSent = Date.distantPast

    init(profile: Profile) {
        self.profile = profile
        self.resolved = MappingEngine.resolve(profile)
        NotificationCenter.default.addObserver(self, selector: #selector(controllersChanged),
                                               name: .GCControllerDidConnect, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(controllersChanged),
                                               name: .GCControllerDidDisconnect, object: nil)
        // Sans ceci, la manette n'envoie plus rien des que le jeu passe au premier plan.
        GCController.shouldMonitorBackgroundEvents = true
    }

    // MARK: - Cycle de vie

    func start() {
        queue.async { [weak self] in
            guard let self, self.timer == nil else { return }
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now(), repeating: 1.0 / MappingEngine.tickRate, leeway: .milliseconds(1))
            timer.setEventHandler { [weak self] in self?.tick() }
            self.timer = timer
            self.lastTick = Date()
            timer.resume()
        }
        notifyControllerName()
    }

    func setEnabled(_ value: Bool) {
        queue.async { [weak self] in
            guard let self, self.enabled != value else { return }
            self.enabled = value
            if !value { self.releaseAll() }
        }
    }

    func update(profile newProfile: Profile) {
        queue.async { [weak self] in
            guard let self else { return }
            self.releaseAll()
            self.profile = newProfile
            self.resolved = MappingEngine.resolve(newProfile)
            self.previousInputs = []
        }
    }

    func refreshDisplays() {
        queue.async { [weak self] in self?.synth.refreshDisplayBounds() }
    }

    private static func resolve(_ profile: Profile) -> [PadInput: ResolvedBinding] {
        var map: [PadInput: ResolvedBinding] = [:]
        for (input, binding) in profile.bindings where !binding.isEmpty {
            map[input] = binding.resolve()
        }
        // Le stick qui pilote la souris ne doit pas aussi envoyer des touches.
        switch profile.mouse.source {
        case .rightStick:
            [PadInput.rightStickUp, .rightStickDown, .rightStickLeft, .rightStickRight].forEach { map[$0] = nil }
        case .leftStick:
            [PadInput.leftStickUp, .leftStickDown, .leftStickLeft, .leftStickRight].forEach { map[$0] = nil }
        case .none:
            break
        }
        return map
    }

    // MARK: - Lecture manette

    /// Deux manettes peuvent porter le meme nom : l'identifiant inclut le rang.
    static func identifier(_ controller: GCController, index: Int) -> String {
        "\(controller.vendorName ?? "Manette")#\(index)"
    }

    static func kindLabel(_ controller: GCController) -> String {
        switch controller.extendedGamepad {
        case is GCDualSenseGamepad: return "DualSense"
        case is GCDualShockGamepad: return "DualShock 4"
        case is GCXboxGamepad: return "Xbox"
        case .some: return "Generique"
        case .none: return "Non compatible"
        }
    }

    /// Quand Steam Input tourne, macOS expose deux manettes : la vraie DualSense et
    /// une manette virtuelle creee par Steam. On vise la vraie par defaut.
    static func pick(from controllers: [GCController], preferring id: String?) -> GCController? {
        if let id {
            for (index, controller) in controllers.enumerated()
            where identifier(controller, index: index) == id {
                return controller
            }
            // La manette a pu changer de rang entre deux connexions.
            if let name = id.split(separator: "#").first.map(String.init),
               let match = controllers.first(where: { $0.vendorName == name }) {
                return match
            }
        }
        return controllers.first(where: { $0.extendedGamepad is GCDualSenseGamepad })
            ?? controllers.first(where: { $0.extendedGamepad is GCDualShockGamepad })
            ?? controllers.first(where: { $0.extendedGamepad != nil })
    }

    var activeController: GCController? {
        MappingEngine.pick(from: GCController.controllers(), preferring: preferredName)
    }

    var connectedControllerName: String? {
        activeController?.vendorName
    }

    /// Instantane de ce que macOS expose, pour la liste affichee dans les reglages.
    var detectedControllers: [ControllerInfo] {
        let all = GCController.controllers()
        let active = MappingEngine.pick(from: all, preferring: preferredName)
        return all.enumerated().map { index, controller in
            ControllerInfo(
                id: MappingEngine.identifier(controller, index: index),
                name: controller.vendorName ?? "Manette",
                kind: MappingEngine.kindLabel(controller),
                isActive: controller === active,
                isUsable: controller.extendedGamepad != nil
            )
        }
    }

    func setPreferredController(_ id: String?) {
        queue.async { [weak self] in
            guard let self else { return }
            self.releaseAll()
            self.previousInputs = []
            self.preferredName = id
        }
        notifyControllerName()
    }

    @objc private func controllersChanged() {
        queue.async { [weak self] in
            guard let self else { return }
            // Une manette qui se deconnecte au milieu d'un appui laisserait une touche bloquee.
            self.releaseAll()
            self.previousInputs = []
        }
        notifyControllerName()
    }

    private func notifyControllerName() {
        let name = activeController?.vendorName
        DispatchQueue.main.async { [weak self] in self?.onControllerChange?(name) }
    }

    private func readPad() -> PadSnapshot? {
        guard let controller = MappingEngine.pick(from: GCController.controllers(), preferring: preferredName),
              let pad = controller.extendedGamepad else { return nil }
        let snap = pad.capture()

        var state = PadSnapshot()
        func set(_ input: PadInput, _ on: Bool) { if on { state.pressed.insert(input) } }

        set(.cross, snap.buttonA.isPressed)
        set(.circle, snap.buttonB.isPressed)
        set(.square, snap.buttonX.isPressed)
        set(.triangle, snap.buttonY.isPressed)
        set(.l1, snap.leftShoulder.isPressed)
        set(.r1, snap.rightShoulder.isPressed)
        set(.l2, Double(snap.leftTrigger.value) >= profile.triggerThreshold)
        set(.r2, Double(snap.rightTrigger.value) >= profile.triggerThreshold)
        set(.l3, snap.leftThumbstickButton?.isPressed ?? false)
        set(.r3, snap.rightThumbstickButton?.isPressed ?? false)
        set(.dpadUp, snap.dpad.up.isPressed)
        set(.dpadDown, snap.dpad.down.isPressed)
        set(.dpadLeft, snap.dpad.left.isPressed)
        set(.dpadRight, snap.dpad.right.isPressed)
        set(.options, snap.buttonMenu.isPressed)
        set(.create, snap.buttonOptions?.isPressed ?? false)

        let home = snap.buttonHome?.isPressed ?? false
        set(.ps, home)
        state.psHeld = home

        if let dualSense = snap as? GCDualSenseGamepad {
            set(.touchpad, dualSense.touchpadButton.isPressed)
        }

        state.leftTrigger = Double(snap.leftTrigger.value)
        state.rightTrigger = Double(snap.rightTrigger.value)

        let lx = Double(snap.leftThumbstick.xAxis.value)
        let ly = Double(snap.leftThumbstick.yAxis.value)
        let rx = Double(snap.rightThumbstick.xAxis.value)
        let ry = Double(snap.rightThumbstick.yAxis.value)
        state.leftStick = CGPoint(x: lx, y: ly)
        state.rightStick = CGPoint(x: rx, y: ry)

        let threshold = profile.stickDeadzone
        set(.leftStickUp, ly >= threshold)
        set(.leftStickDown, ly <= -threshold)
        set(.leftStickLeft, lx <= -threshold)
        set(.leftStickRight, lx >= threshold)
        set(.rightStickUp, ry >= threshold)
        set(.rightStickDown, ry <= -threshold)
        set(.rightStickLeft, rx <= -threshold)
        set(.rightStickRight, rx >= threshold)

        return state
    }

    // MARK: - Boucle

    private func tick() {
        let now = Date()
        let dt = min(max(now.timeIntervalSince(lastTick), 0.001), 0.1)
        lastTick = now

        guard let pad = readPad() else {
            if !previousInputs.isEmpty { releaseAll(); previousInputs = [] }
            return
        }

        if onSnapshot != nil, now.timeIntervalSince(lastSnapshotSent) >= 1.0 / 30.0 {
            lastSnapshotSent = now
            DispatchQueue.main.async { [weak self] in self?.onSnapshot?(pad) }
        }

        handlePanicShortcut(pad: pad, now: now)
        guard enabled else { return }

        let active = pad.pressed.filter { resolved[$0] != nil }

        for input in active.subtracting(previousInputs) {
            press(input)
        }
        for input in previousInputs.subtracting(active) {
            release(input)
        }
        previousInputs = active

        repeatScrolls(active: active, dt: dt)
        moveMouse(pad: pad, dt: dt)
    }

    /// Maintenir le bouton PS pendant une seconde coupe ou relance le mapping,
    /// pour reprendre la main sans quitter le jeu. Inactif si PS est mappe.
    private func handlePanicShortcut(pad: PadSnapshot, now: Date) {
        guard resolved[.ps] == nil else { psHeldSince = nil; return }
        guard pad.psHeld else { psHeldSince = nil; return }
        if let since = psHeldSince {
            if now.timeIntervalSince(since) >= 1.0 {
                psHeldSince = nil
                enabled.toggle()
                if !enabled { releaseAll() }
                let value = enabled
                DispatchQueue.main.async { [weak self] in self?.onEnabledChange?(value) }
            }
        } else {
            psHeldSince = now
        }
    }

    private func press(_ input: PadInput) {
        guard let action = resolved[input] else { return }
        for code in action.keyCodes {
            let count = (heldKeys[code] ?? 0) + 1
            heldKeys[code] = count
            if count == 1 { synth.keyDown(code) }
        }
        if let button = action.mouse {
            let count = (heldMouse[button] ?? 0) + 1
            heldMouse[button] = count
            if count == 1 { synth.mouseDown(button) }
        }
        if let scroll = action.scroll {
            synth.scroll(scroll)
            scrollAccumulator[input] = 0
        }
    }

    private func release(_ input: PadInput) {
        guard let action = resolved[input] else { return }
        // Les modificateurs partent en dernier pour que "Maj + W" ne se termine pas
        // par un W tout seul.
        for code in action.keyCodes.sorted(by: { !KeyCodes.modifierCodes.contains($0) && KeyCodes.modifierCodes.contains($1) }) {
            guard let count = heldKeys[code] else { continue }
            if count <= 1 {
                heldKeys[code] = nil
                synth.keyUp(code)
            } else {
                heldKeys[code] = count - 1
            }
        }
        if let button = action.mouse, let count = heldMouse[button] {
            if count <= 1 {
                heldMouse[button] = nil
                synth.mouseUp(button)
            } else {
                heldMouse[button] = count - 1
            }
        }
        scrollAccumulator[input] = nil
    }

    private func repeatScrolls(active: Set<PadInput>, dt: Double) {
        let interval = max(profile.scrollInterval, 0.02)
        for input in active {
            guard let scroll = resolved[input]?.scroll else { continue }
            var elapsed = (scrollAccumulator[input] ?? 0) + dt
            while elapsed >= interval {
                synth.scroll(scroll)
                elapsed -= interval
            }
            scrollAccumulator[input] = elapsed
        }
    }

    private func moveMouse(pad: PadSnapshot, dt: Double) {
        let config = profile.mouse
        let stick: CGPoint
        switch config.source {
        case .rightStick: stick = pad.rightStick
        case .leftStick: stick = pad.leftStick
        case .none: return
        }

        let magnitude = (stick.x * stick.x + stick.y * stick.y).squareRoot()
        guard magnitude > config.deadzone else {
            mouseRemainder = .zero
            return
        }

        // La zone morte est retiree puis la course restante est re-etalee sur 0...1,
        // sinon le curseur saute des que le stick quitte le centre.
        let normalized = min((magnitude - config.deadzone) / (1.0 - config.deadzone), 1.0)
        let shaped = pow(normalized, max(config.curve, 0.2))
        let scale = config.speed * shaped * dt / magnitude

        let dx = stick.x * scale + mouseRemainder.x
        // L'axe Y de la manette pointe vers le haut, celui de l'ecran vers le bas.
        let rawY = config.invertY ? stick.y : -stick.y
        let dy = rawY * scale * config.verticalScale + mouseRemainder.y

        let stepX = dx.rounded(.towardZero)
        let stepY = dy.rounded(.towardZero)
        mouseRemainder = CGPoint(x: dx - stepX, y: dy - stepY)

        synth.moveMouse(dx: stepX, dy: stepY)
    }

    private func releaseAll() {
        synth.releaseEverything(keys: Set(heldKeys.keys))
        heldKeys.removeAll()
        heldMouse.removeAll()
        scrollAccumulator.removeAll()
        mouseRemainder = .zero
    }
}
