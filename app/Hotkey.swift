import Foundation

struct Hotkey: Codable, Equatable {
    let key: String?
    let cmd: Bool
    let opt: Bool
    let ctrl: Bool
    let shift: Bool

    init(key: String? = nil, cmd: Bool = false, opt: Bool = false, ctrl: Bool = false, shift: Bool = false) {
        self.key = key
        self.cmd = cmd
        self.opt = opt
        self.ctrl = ctrl
        self.shift = shift
    }

    func serialize() -> String {
        var components: [String] = []

        if cmd { components.append("cmd") }
        if opt { components.append("opt") }
        if ctrl { components.append("ctrl") }
        if shift { components.append("shift") }

        if let key = key {
            components.append(key)
        }

        return components.joined(separator: "+")
    }

    static func deserialize(_ hotkeyString: String) -> Hotkey? {
        let components = hotkeyString.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }

        guard !components.isEmpty else { return nil }

        var cmd = false
        var opt = false
        var ctrl = false
        var shift = false
        var key: String?

        // Check if last component is a modifier or a key
        let lastComponent = components.last!
        let isLastModifier = ["cmd", "opt", "ctrl", "shift"].contains(lastComponent.lowercased())

        let componentsToProcess = isLastModifier ? components : components.dropLast()
        if !isLastModifier {
            key = String(lastComponent)
        }

        for component in componentsToProcess {
            switch component.lowercased() {
            case "cmd":
                cmd = true
            case "opt":
                opt = true
            case "ctrl":
                ctrl = true
            case "shift":
                shift = true
            default:
                break
            }
        }

        return Hotkey(key: key, cmd: cmd, opt: opt, ctrl: ctrl, shift: shift)
    }

    static func == (lhs: Hotkey, rhs: Hotkey) -> Bool {
        return lhs.key == rhs.key &&
               lhs.cmd == rhs.cmd &&
               lhs.opt == rhs.opt &&
               lhs.ctrl == rhs.ctrl &&
               lhs.shift == rhs.shift
    }
}