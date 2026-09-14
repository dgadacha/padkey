import Foundation
import Carbon.HIToolbox
import CoreGraphics

/// Table des touches par position physique (libelles d'un clavier QWERTY/ANSI).
/// Les jeux lisent presque toujours la position physique de la touche : "W" designe
/// donc la touche situee a l'emplacement du W sur un QWERTY, soit le Z d'un AZERTY.
enum KeyCodes {

    static let byName: [String: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9,
        "b": 11, "q": 12, "w": 13, "e": 14, "r": 15, "y": 16, "t": 17,
        "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "9": 25, "7": 26, "8": 28, "0": 29,
        "=": 24, "equal": 24, "-": 27, "minus": 27,
        "]": 30, "rightbracket": 30, "[": 33, "leftbracket": 33,
        "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
        "'": 39, "quote": 39, ";": 41, "semicolon": 41, "\\": 42, "backslash": 42,
        ",": 43, "comma": 43, "/": 44, "slash": 44, ".": 47, "period": 47, "`": 50, "grave": 50,

        "return": 36, "enter": 36, "tab": 48, "space": 49, "spacebar": 49,
        "delete": 51, "backspace": 51, "escape": 53, "esc": 53,
        "forwarddelete": 117, "suppr": 117,

        "command": 55, "cmd": 55, "leftcommand": 55, "rightcommand": 54,
        "shift": 56, "leftshift": 56, "rightshift": 60,
        "capslock": 57,
        "option": 58, "alt": 58, "leftoption": 58, "leftalt": 58, "rightoption": 61, "rightalt": 61,
        "control": 59, "ctrl": 59, "leftcontrol": 59, "leftctrl": 59, "rightcontrol": 62, "rightctrl": 62,
        "function": 63, "fn": 63,

        "keypad0": 82, "keypad1": 83, "keypad2": 84, "keypad3": 85, "keypad4": 86,
        "keypad5": 87, "keypad6": 88, "keypad7": 89, "keypad8": 91, "keypad9": 92,
        "keypadenter": 76, "keypadplus": 69, "keypadminus": 78, "keypadmultiply": 67,
        "keypaddivide": 75, "keypaddecimal": 65, "keypadequals": 81, "keypadclear": 71,

        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97, "f7": 98, "f8": 100,
        "f9": 101, "f10": 109, "f11": 103, "f12": 111, "f13": 105, "f14": 107, "f15": 113,
        "f16": 106, "f17": 64, "f18": 79, "f19": 80, "f20": 90,

        "home": 115, "end": 119, "pageup": 116, "pagedown": 121, "help": 114,
        "left": 123, "right": 124, "down": 125, "up": 126,
        "arrowleft": 123, "arrowright": 124, "arrowdown": 125, "arrowup": 126,
    ]

    private static let nameByCode: [CGKeyCode: String] = {
        // Libelle canonique affiche dans l'interface.
        let preferred: [CGKeyCode: String] = [
            36: "Entree", 48: "Tab", 49: "Espace", 51: "Suppr", 53: "Echap", 117: "Suppr avant",
            55: "Cmd", 54: "Cmd D", 56: "Maj", 60: "Maj D", 57: "Verr Maj",
            58: "Alt", 61: "Alt D", 59: "Ctrl", 62: "Ctrl D", 63: "Fn",
            123: "\u{2190}", 124: "\u{2192}", 125: "\u{2193}", 126: "\u{2191}",
            115: "Debut", 119: "Fin", 116: "Page haut", 121: "Page bas",
            24: "=", 27: "-", 30: "]", 33: "[", 39: "'", 41: ";", 42: "\\",
            43: ",", 44: "/", 47: ".", 50: "`",
        ]
        var map = preferred
        for (name, code) in byName where map[code] == nil {
            if name.count <= 3, name.allSatisfy({ $0.isLetter || $0.isNumber }) {
                map[code] = name.uppercased()
            }
        }
        return map
    }()

    static func code(forName raw: String) -> CGKeyCode? {
        byName[raw.lowercased().replacingOccurrences(of: " ", with: "")]
    }

    static func label(for code: CGKeyCode) -> String {
        nameByCode[code] ?? "Touche \(code)"
    }

    static let modifierCodes: Set<CGKeyCode> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]

    static func flag(for code: CGKeyCode) -> CGEventFlags? {
        switch code {
        case 55, 54: return .maskCommand
        case 56, 60: return .maskShift
        case 58, 61: return .maskAlternate
        case 59, 62: return .maskControl
        case 57: return .maskAlphaShift
        case 63: return .maskSecondaryFn
        default: return nil
        }
    }

    /// Resout un caractere ("z", "&") vers le keycode qui le produit sur la disposition
    /// clavier actuellement active. Utile quand un jeu lit le caractere et non la position.
    static func code(forCharacter character: String) -> CGKeyCode? {
        guard let wanted = character.lowercased().first else { return nil }
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutPtr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutPtr).takeUnretainedValue() as Data

        return layoutData.withUnsafeBytes { raw -> CGKeyCode? in
            guard let base = raw.baseAddress else { return nil }
            let layout = base.assumingMemoryBound(to: UCKeyboardLayout.self)
            for code in CGKeyCode(0)...CGKeyCode(127) {
                var deadKeyState: UInt32 = 0
                var length = 0
                var chars = [UniChar](repeating: 0, count: 4)
                let status = UCKeyTranslate(layout,
                                            UInt16(code),
                                            UInt16(kUCKeyActionDisplay),
                                            0,
                                            UInt32(LMGetKbdType()),
                                            UInt32(kUCKeyTranslateNoDeadKeysBit),
                                            &deadKeyState,
                                            chars.count,
                                            &length,
                                            &chars)
                guard status == noErr, length > 0 else { continue }
                let produced = String(utf16CodeUnits: chars, count: length).lowercased()
                if produced.first == wanted { return code }
            }
            return nil
        }
    }
}
