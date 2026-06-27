# DockPin

A tiny macOS menu-bar app that pins your Dock to one specific monitor — even with **"Displays have separate Spaces"** enabled.

> No settings to fiddle with. No Dock restart. No private APIs. Just one job, done well.

---

## Why I built this

I run a multi-monitor setup, and macOS's default behavior drove me up the wall: with **"Displays have separate Spaces"** turned on, the Dock follows the cursor to whichever screen I'm on. I'd push my mouse to the bottom of a screen — even just casually — and the Dock would yank itself across to that monitor, breaking my muscle memory every time.

Apple's only "fix" is to **turn off "Displays have separate Spaces."** But that setting also changes how Spaces and full-screen apps behave across monitors, which I rely on. I just wanted the Dock to stay put on one screen and leave the rest of my setup alone.

There is no preference for this. No `defaults` key. No hidden toggle anywhere in System Settings. So I built one.

## What it does

DockPin lives in your menu bar as a small pin icon. You pick which display the Dock should stay on. From that moment, the Dock never jumps to another monitor — even when your cursor reaches the bottom edge of a different screen.

It does this without:
- ❌ Disabling "Displays have separate Spaces"
- ❌ Restarting the Dock (no flicker, ever)
- ❌ Modifying any system file
- ❌ Running a hidden background daemon
- ❌ Hacking Dock.app internals or using private APIs

## How it works

There is no public *or* undocumented API to lock the Dock to a specific display on modern macOS. When "Displays have separate Spaces" is on, `WindowServer` triggers the Dock to relocate the moment your cursor touches the bottom row of pixels of any display.

DockPin's trick: it installs a session-level `CGEventTap` that watches mouse-moved events. If the cursor is about to enter the "Dock trigger zone" of a display you haven't pinned, DockPin nudges the cursor 7 pixels back into the screen — **before `WindowServer` ever sees the trigger.** The Dock never gets the signal to relocate, so it stays exactly where you put it.

Hold **⌥ Option** while moving to bypass — useful when you actually do want to drag something across to the other screen.

The geometry pass excludes the part of an edge that's flush against another display, so cursor travel between stacked monitors still works normally.

## Features

- 📌 Pins the Dock to a chosen display
- 🖥️ Multi-monitor aware — switch the pinned display from the menu bar at any time
- ⌥ Option-hold bypass for one-off overrides
- 🔁 Auto-reconfigures on display reconnect, sleep/wake, and arrangement changes
- 🚀 Optional "Open at Login" using the modern `SMAppService` API
- 🪶 Universal binary (Apple Silicon + Intel), ~270 KB, near-zero CPU
- 🔐 Public APIs only — no SIMBL, no swizzling, no private symbols
- 🎯 Single purpose — does one thing and gets out of your way

## Requirements

- macOS 13 Ventura or later
- Accessibility permission (macOS will prompt on first launch)

## Install

### Option 1 — Build it yourself (recommended)

```sh
git clone https://github.com/metikadriu/DockPin.git
cd DockPin
./build.sh             # compiles DockPin.app (universal binary, ad-hoc signed)
./tools/install.sh     # copies to /Applications and launches it
```

Requires only the Xcode command-line tools (`xcode-select --install`). No Xcode IDE needed.

### Option 2 — Download a prebuilt release

Grab the latest `DockPin.app` from the [Releases](https://github.com/metikadriu/DockPin/releases) page and drag it into `/Applications`.

### First-launch permission

macOS will ask for **Accessibility** permission on first launch:
*System Settings → Privacy & Security → Accessibility → enable DockPin.*

This is required for the event-tap mechanism that makes the whole thing work. DockPin uses this permission **only** to nudge the cursor by a few pixels at the bottom edge of non-pinned displays. It reads no keystrokes and no data leaves your Mac.

## Use

Click the 📌 pin icon in your menu bar:

| Item | What it does |
|------|--------------|
| **Active** | Toggle DockPin on/off |
| **Lock Dock to ▶** | Pick which display the Dock stays on |
| **Open at Login** | Auto-start on every login (uses `SMAppService`) |
| **Open Accessibility Settings…** | Shortcut to the permission pane |
| **Quit DockPin** | Exit |

That's the entire UI. **Hold ⌥ Option** any time you want to temporarily move the Dock to another monitor on purpose.

## Troubleshooting

**The Dock still follows my cursor after install.**
Open the menu and look at the **status line** at the top — it'll tell you exactly what's wrong:

- *"⚠ Accessibility permission required"* — the most common cause. Click **Open Accessibility Settings to fix…** and toggle DockPin on.
- *"⚠ Pinned display not connected"* — the screen you previously pinned to is no longer attached. Click **Lock Dock to ▶** and pick a current display.
- *"Only one display connected"* — there's nothing to pin against; DockPin idles in this state.

**I moved the app between folders and now permission is "granted" but it doesn't work.**
This is a quirk of ad-hoc-signed apps + macOS's TCC database — the old grant is tied to the old binary path. Fix:

```sh
tccutil reset Accessibility com.meti.dockpin
pkill -f DockPin
open /Applications/DockPin.app
```

…then grant permission again when prompted.

**The menu-bar icon shows a pin with a slash through it.**
That's the visual cue that DockPin can't enforce its lock right now — check the status line for the reason.

## Why this should keep working on future macOS releases

DockPin uses only stable, public Apple APIs:

- `CGEventTap` (Quartz Event Services)
- `NSScreen`, `NSStatusItem` (AppKit)
- `SMAppService` (Service Management — Apple's current login-item API)
- `AXIsProcessTrustedWithOptions` (Accessibility)

It doesn't depend on Dock.app internals or any private framework. As long as macOS continues to trigger Dock relocation from cursor proximity — which is the design pattern underpinning every Apple multi-monitor behavior — DockPin's interception strategy will continue to work.

## Project layout

```
DockPin/
├── src/                      Swift sources
│   ├── main.swift
│   ├── AppDelegate.swift     Menu bar UI
│   ├── DockPinner.swift      Event tap + geometry
│   └── DisplayUtils.swift
├── resources/
│   ├── Info.plist
│   └── AppIcon.icns
├── tools/
│   ├── make_icon.swift       Generates the app icon from code
│   ├── make_icon.sh          Builds .icns from the master PNG
│   └── install.sh            Copies to /Applications + registers
├── build.sh                  Builds DockPin.app
└── README.md
```

No Xcode project, no `Package.swift`, no dependencies. Just `swiftc` and Apple's frameworks.

## Acknowledgements

The cursor-nudge approach was discovered by reading [DockDoor](https://github.com/ejbills/DockDoor) — a much more comprehensive Dock-enhancement app that includes this feature among many others. **If you want hover previews, window switcher, and more, use DockDoor.** DockPin exists as a tiny standalone implementation for people who just want the pinning behavior with nothing else attached.

## License

[MIT](LICENSE)

---

Built by [Meti Kadriu](https://github.com/metikadriu) in Gjilan, Kosovo. PRs and issues welcome.
