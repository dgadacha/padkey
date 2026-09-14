import Foundation
import CoreGraphics
import AppKit

/// Fabrique et poste les evenements clavier / souris vus par le systeme.
/// Necessite l'autorisation Accessibilite.
final class OutputSynth {

    private let source: CGEventSource?
    private var activeFlags: CGEventFlags = []
    private var heldModifiers: Set<CGKeyCode> = []
    private var heldMouseButtons: Set<MouseButtonKind> = []

    init() {
        source = CGEventSource(stateID: .hidSystemState)
        // Sans cela, macOS filtre nos evenements pendant quelques instants apres
        // chaque vraie action de l'utilisateur.
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalKeyboardEvents, .permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )
        source?.localEventsSuppressionInterval = 0
    }

    // MARK: - Clavier

    func keyDown(_ code: CGKeyCode) {
        if KeyCodes.modifierCodes.contains(code) {
            heldModifiers.insert(code)
            if let flag = KeyCodes.flag(for: code) { activeFlags.insert(flag) }
            postFlagsChanged(code)
            return
        }
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true) else { return }
        event.flags = activeFlags
        event.post(tap: .cghidEventTap)
    }

    func keyUp(_ code: CGKeyCode) {
        if KeyCodes.modifierCodes.contains(code) {
            heldModifiers.remove(code)
            if let flag = KeyCodes.flag(for: code), !heldModifiers.contains(where: { KeyCodes.flag(for: $0) == flag }) {
                activeFlags.remove(flag)
            }
            postFlagsChanged(code)
            return
        }
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false) else { return }
        event.flags = activeFlags
        event.post(tap: .cghidEventTap)
    }

    /// Frappe supplementaire pendant que la touche reste enfoncee, marquee comme
    /// repetition automatique, exactement comme le fait un clavier physique.
    func keyRepeat(_ code: CGKeyCode) {
        guard !KeyCodes.modifierCodes.contains(code),
              let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)
        else { return }
        event.setIntegerValueField(.keyboardEventAutorepeat, value: 1)
        event.flags = activeFlags
        event.post(tap: .cghidEventTap)
    }

    /// Un modificateur maintenu ne se simule pas avec keyDown : le systeme attend
    /// un evenement flagsChanged portant l'etat complet des modificateurs.
    private func postFlagsChanged(_ code: CGKeyCode) {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true) else { return }
        event.type = .flagsChanged
        event.flags = activeFlags
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Souris

    private func cursorLocation() -> CGPoint {
        CGEvent(source: nil)?.location ?? CGPoint(x: 0, y: 0)
    }

    private static func desktopBounds() -> CGRect {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        guard count > 0 else { return CGDisplayBounds(CGMainDisplayID()) }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        return ids.reduce(CGRect.null) { $0.union(CGDisplayBounds($1)) }
    }

    private lazy var bounds: CGRect = OutputSynth.desktopBounds()

    func refreshDisplayBounds() {
        bounds = OutputSynth.desktopBounds()
    }

    /// Deplacement relatif. Les deltas sont ce que lisent les jeux qui capturent la souris ;
    /// la position absolue ne sert qu'a garder le curseur a l'ecran hors capture.
    func moveMouse(dx: Double, dy: Double) {
        let deltaX = Int64(dx.rounded())
        let deltaY = Int64(dy.rounded())
        guard deltaX != 0 || deltaY != 0 else { return }

        let current = cursorLocation()
        let target = CGPoint(
            x: min(max(current.x + Double(deltaX), bounds.minX), bounds.maxX - 1),
            y: min(max(current.y + Double(deltaY), bounds.minY), bounds.maxY - 1)
        )

        let type: CGEventType
        let button: CGMouseButton
        if heldMouseButtons.contains(.left) {
            type = .leftMouseDragged; button = .left
        } else if heldMouseButtons.contains(.right) {
            type = .rightMouseDragged; button = .right
        } else if heldMouseButtons.contains(.middle) {
            type = .otherMouseDragged; button = .center
        } else {
            type = .mouseMoved; button = .left
        }

        guard let event = CGEvent(mouseEventSource: source, mouseType: type,
                                  mouseCursorPosition: target, mouseButton: button) else { return }
        event.setIntegerValueField(.mouseEventDeltaX, value: deltaX)
        event.setIntegerValueField(.mouseEventDeltaY, value: deltaY)
        event.flags = activeFlags
        event.post(tap: .cghidEventTap)
    }

    func mouseDown(_ kind: MouseButtonKind) {
        heldMouseButtons.insert(kind)
        postMouse(kind, down: true)
    }

    func mouseUp(_ kind: MouseButtonKind) {
        heldMouseButtons.remove(kind)
        postMouse(kind, down: false)
    }

    private func postMouse(_ kind: MouseButtonKind, down: Bool) {
        let type: CGEventType
        let button: CGMouseButton
        switch kind {
        case .left:
            type = down ? .leftMouseDown : .leftMouseUp; button = .left
        case .right:
            type = down ? .rightMouseDown : .rightMouseUp; button = .right
        case .middle:
            type = down ? .otherMouseDown : .otherMouseUp; button = .center
        }
        guard let event = CGEvent(mouseEventSource: source, mouseType: type,
                                  mouseCursorPosition: cursorLocation(), mouseButton: button) else { return }
        event.setIntegerValueField(.mouseEventClickState, value: 1)
        event.flags = activeFlags
        event.post(tap: .cghidEventTap)
    }

    func scroll(_ direction: ScrollDirection) {
        let vertical: Int32
        let horizontal: Int32
        switch direction {
        case .up: vertical = 1; horizontal = 0
        case .down: vertical = -1; horizontal = 0
        case .left: vertical = 0; horizontal = 1
        case .right: vertical = 0; horizontal = -1
        }
        guard let event = CGEvent(scrollWheelEvent2Source: source, units: .line,
                                  wheelCount: 2, wheel1: vertical, wheel2: horizontal, wheel3: 0) else { return }
        event.flags = activeFlags
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Securite

    /// Relache tout ce qui est encore enfonce : indispensable quand on desactive
    /// le mapping ou quand la manette se deconnecte au milieu d'une action.
    func releaseEverything(keys: Set<CGKeyCode>) {
        for code in keys where !KeyCodes.modifierCodes.contains(code) {
            if let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: false) {
                event.flags = activeFlags
                event.post(tap: .cghidEventTap)
            }
        }
        for code in heldModifiers {
            heldModifiers.remove(code)
            if let flag = KeyCodes.flag(for: code) { activeFlags.remove(flag) }
            postFlagsChanged(code)
        }
        activeFlags = []
        for button in heldMouseButtons {
            postMouse(button, down: false)
        }
        heldMouseButtons.removeAll()
    }
}
