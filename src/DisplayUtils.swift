import AppKit

enum DisplayUtils {
    static func uuid(for screen: NSScreen) -> String? {
        guard
            let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
            let cf = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue()
        else { return nil }
        return CFUUIDCreateString(nil, cf) as String?
    }

    static func label(for screen: NSScreen) -> String {
        let w = Int(screen.frame.width)
        let h = Int(screen.frame.height)
        return "\(screen.localizedName) (\(w)×\(h))"
    }
}
