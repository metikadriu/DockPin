import AppKit
import ApplicationServices

final class DockPinner {
    // MARK: - Persisted settings

    private static let defaults = UserDefaults.standard
    private static let kEnabled = "active"
    private static let kLockedUUID = "lockedDisplayUUID"

    static var isEnabled: Bool {
        get { defaults.object(forKey: kEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: kEnabled) }
    }

    static var lockedDisplayUUID: String {
        get { defaults.string(forKey: kLockedUUID) ?? "" }
        set { defaults.set(newValue, forKey: kLockedUUID) }
    }

    // MARK: - Tunables

    private let triggerDepth: CGFloat = 7
    private let adjacencyTolerance: CGFloat = 2

    // MARK: - State

    private struct Zone { let rect: CGRect; let nudge: CGVector }
    private var zones: [Zone] = []
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init() {
        if Self.lockedDisplayUUID.isEmpty,
           let main = NSScreen.main,
           let uuid = DisplayUtils.uuid(for: main) {
            Self.lockedDisplayUUID = uuid
        }
        refresh()
    }

    deinit { teardownTap() }

    func refresh() {
        teardownTap()
        guard Self.isEnabled else { return }
        zones = computeZones()
        guard !zones.isEmpty else { return }
        installTap()
    }

    // MARK: - Geometry

    private func dockPosition() -> String {
        UserDefaults(suiteName: "com.apple.dock")?.string(forKey: "orientation") ?? "bottom"
    }

    /// NSScreen frames are bottom-left origin relative to the primary screen.
    /// CGEvent.location uses top-left global coordinates. Convert here.
    private func cgFrame(_ s: NSScreen) -> CGRect {
        let primaryH = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(
            x: s.frame.minX,
            y: primaryH - s.frame.minY - s.frame.height,
            width: s.frame.width,
            height: s.frame.height
        )
    }

    private func computeZones() -> [Zone] {
        let screens = NSScreen.screens
        guard screens.count > 1 else { return [] }
        let lockedUUID = Self.lockedDisplayUUID
        guard let lockedIdx = screens.firstIndex(where: { DisplayUtils.uuid(for: $0) == lockedUUID })
        else { return [] }

        let frames = screens.map(cgFrame)
        let pos = dockPosition()
        var result: [Zone] = []

        for (i, f) in frames.enumerated() where i != lockedIdx {
            let edgeCoord: CGFloat
            let edgeStart: CGFloat
            let edgeEnd: CGFloat
            switch pos {
            case "left":  (edgeCoord, edgeStart, edgeEnd) = (f.minX, f.minY, f.maxY)
            case "right": (edgeCoord, edgeStart, edgeEnd) = (f.maxX, f.minY, f.maxY)
            default:      (edgeCoord, edgeStart, edgeEnd) = (f.maxY, f.minX, f.maxX)
            }

            // Subtract intervals where another display is flush against this edge,
            // so the cursor can still cross between stacked monitors.
            var occluded: [(CGFloat, CGFloat)] = []
            for other in frames where other != f {
                let isAdjacent: Bool
                switch pos {
                case "left":  isAdjacent = abs(other.maxX - edgeCoord) <= adjacencyTolerance
                case "right": isAdjacent = abs(other.minX - edgeCoord) <= adjacencyTolerance
                default:      isAdjacent = abs(other.minY - edgeCoord) <= adjacencyTolerance
                }
                guard isAdjacent else { continue }
                let (oS, oE): (CGFloat, CGFloat) = (pos == "left" || pos == "right")
                    ? (other.minY, other.maxY) : (other.minX, other.maxX)
                let s = max(edgeStart, oS), e = min(edgeEnd, oE)
                if e - s > 0.5 { occluded.append((s, e)) }
            }
            occluded.sort { $0.0 < $1.0 }

            var exposed: [(CGFloat, CGFloat)] = []
            var cursor = edgeStart
            for (s, e) in occluded {
                if s > cursor { exposed.append((cursor, min(s, edgeEnd))) }
                cursor = max(cursor, e)
            }
            if cursor < edgeEnd { exposed.append((cursor, edgeEnd)) }

            for (s, e) in exposed where e - s > 0.5 {
                let depth = triggerDepth
                let zone: Zone
                switch pos {
                case "left":
                    zone = Zone(
                        rect: CGRect(x: f.minX, y: s, width: depth, height: e - s),
                        nudge: CGVector(dx: depth, dy: 0))
                case "right":
                    zone = Zone(
                        rect: CGRect(x: f.maxX - depth, y: s, width: depth, height: e - s),
                        nudge: CGVector(dx: -depth, dy: 0))
                default:
                    zone = Zone(
                        rect: CGRect(x: s, y: f.maxY - depth, width: e - s, height: depth),
                        nudge: CGVector(dx: 0, dy: -depth))
                }
                result.append(zone)
            }
        }
        return result
    }

    // MARK: - Event tap

    private func installTap() {
        let mask: CGEventMask = (1 << CGEventType.mouseMoved.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, refcon in
            let self_ = Unmanaged<DockPinner>.fromOpaque(refcon!).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let t = self_.tap { CGEvent.tapEnable(tap: t, enable: true) }
                return Unmanaged.passUnretained(event)
            }

            // Hold Option to bypass — lets you drag the Dock to the other screen
            // intentionally without disabling the app.
            let flags = event.flags.union(CGEventSource.flagsState(.combinedSessionState))
            if flags.contains(.maskAlternate) { return Unmanaged.passUnretained(event) }

            let p = event.location
            for z in self_.zones where z.rect.contains(p) {
                event.location = CGPoint(x: p.x + z.nudge.dx, y: p.y + z.nudge.dy)
                break
            }
            return Unmanaged.passUnretained(event)
        }

        guard let t = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }

        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
        tap = t
        runLoopSource = src
    }

    private func teardownTap() {
        if let t = tap {
            CGEvent.tapEnable(tap: t, enable: false)
            if let src = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes)
            }
            CFMachPortInvalidate(t)
        }
        tap = nil
        runLoopSource = nil
    }
}
