# Winshrink – Window Manager

A lightweight macOS menu bar app that snaps application windows into position using global keyboard shortcuts.

---

## Shortcuts (defaults)

| Shortcut | Action |
|---|---|
| `⌘ ⇧ F` | Full screen — fills the visible work area (below menu bar, above Dock) |
| `⌘ ⇧ ←` | Left half — 50% width, full height, snapped left |
| `⌘ ⇧ →` | Right half — 50% width, full height, snapped right |
| `⌘ ⇧ ↑` | Top half — full width, 50% height, snapped to top |
| `⌘ ⇧ ↓` | Bottom half — full width, 50% height, snapped to bottom |

All shortcuts are customizable in **Settings** (click the 🪴 menu bar icon → Settings).

Shortcuts work across all apps and on any connected display, including external monitors.

---

## Settings

Open from the menu bar: 🪴 → **Settings...** (or `⌘ ,`)

- **Version & Developer** — shows current version and developer info
- **Keyboard Shortcuts** — click any shortcut field, then press a new key to reassign it
- **Launch at Login** — toggle whether Winshrink starts automatically at login

---

## Installation

### Requirements

- macOS 12 Monterey or later
- Xcode Command Line Tools — install with `xcode-select --install`

### Install

1. Right-click `Winshrink-install.command` → **Open**
2. Click **Open** in the Gatekeeper prompt
3. Terminal compiles and installs the app (~20 seconds)
4. Grant **Accessibility** permission when prompted (required for window control)

### Grant Accessibility Access

> System Settings → Privacy & Security → Accessibility → enable **Winshrink**

Without this, the shortcuts register but cannot move or resize windows.

---

## How It Works

Winshrink runs as a background menu bar app (no Dock icon). It installs a `CGEventTap` to intercept global key-down events and uses the macOS Accessibility API (`AXUIElement`) to move and resize the frontmost window.

---

## File Locations

| File | Path |
|---|---|
| App bundle | `/Applications/Winshrink.app` |
| LaunchAgent | `~/Library/LaunchAgents/com.winshrink.app.plist` |
| Preferences | `~/Library/Preferences/com.winshrink.app.plist` |
| Source code | `main.swift` (this folder) |

---

## Uninstall

```bash
# Stop the app
pkill -x Winshrink

# Remove LaunchAgent
launchctl unload ~/Library/LaunchAgents/com.winshrink.app.plist
rm ~/Library/LaunchAgents/com.winshrink.app.plist

# Remove app
sudo rm -rf /Applications/Winshrink.app
```

Then remove Winshrink from **System Settings → Privacy & Security → Accessibility**.

---

## Recompile from Source

If you edit `main.swift`, recompile with:

```bash
xcrun swiftc -O \
    -framework Cocoa \
    -framework ApplicationServices \
    -framework Carbon \
    -framework ServiceManagement \
    main.swift \
    -o /Applications/Winshrink.app/Contents/MacOS/Winshrink

codesign --force --deep --sign - /Applications/Winshrink.app
pkill -x Winshrink && open /Applications/Winshrink.app
```

---

**Version:** 1.1.0
**Developer:** Ihor Udod
