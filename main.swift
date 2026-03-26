// MIT License
// Copyright (c) 2026 Ihor Udod
// See LICENSE.md for full terms.

import Cocoa
import ApplicationServices
import Carbon
import ServiceManagement

// ───────────────────────────────────────────────────────────────
//  Constants
// ───────────────────────────────────────────────────────────────
private let kAppVersion    = "1.1.0"
private let kAppDeveloper  = "Ihor Udod"
private let kBundleId      = "com.winshrink.app"

// Default key codes (hardware, layout-independent)
private let kDefaultFullscreen: UInt16 = 3    // F
private let kDefaultLeft:       UInt16 = 123  // Left Arrow
private let kDefaultRight:      UInt16 = 124  // Right Arrow
private let kDefaultTop:        UInt16 = 126  // Up Arrow
private let kDefaultBottom:     UInt16 = 125  // Down Arrow

// UserDefaults keys
private let kPrefKeyFullscreen = "shortcut_fullscreen"
private let kPrefKeyLeft       = "shortcut_left"
private let kPrefKeyRight      = "shortcut_right"
private let kPrefKeyTop        = "shortcut_top"
private let kPrefKeyBottom     = "shortcut_bottom"
private let kPrefKeyLaunch     = "launch_at_login"
private let kPrefKeyShowRes    = "show_resolution"

// ───────────────────────────────────────────────────────────────
//  Shortcut recording field – captures a single key press
// ───────────────────────────────────────────────────────────────
class ShortcutField: NSTextField {

    var onKeyRecorded: ((UInt16) -> Void)?
    private var isRecording = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    private func setup() {
        isEditable   = false
        isSelectable = false
        alignment    = .center
        font         = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        wantsLayer   = true
        layer?.cornerRadius = 6
        layer?.borderWidth  = 1
        layer?.borderColor  = NSColor.separatorColor.cgColor
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        isRecording = true
        stringValue = "Press a key..."
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }
        isRecording = false
        layer?.borderColor = NSColor.separatorColor.cgColor
        let code = event.keyCode
        stringValue = "⌘ ⇧ " + ShortcutField.keyName(code)
        onKeyRecorded?(code)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        layer?.borderColor = NSColor.separatorColor.cgColor
        return super.resignFirstResponder()
    }

    static func keyName(_ code: UInt16) -> String {
        switch code {
        case 123: return "←"
        case 124: return "→"
        case 126: return "↑"
        case 125: return "↓"
        case 3:   return "F"
        case 0:   return "A";  case 1:  return "S";  case 2:  return "D"
        case 4:   return "H";  case 5:  return "G";  case 6:  return "Z"
        case 7:   return "X";  case 8:  return "C";  case 9:  return "V"
        case 11:  return "B";  case 12: return "Q";  case 13: return "W"
        case 14:  return "E";  case 15: return "R";  case 16: return "Y"
        case 17:  return "T";  case 31: return "O";  case 32: return "U"
        case 34:  return "I";  case 35: return "P";  case 37: return "L"
        case 38:  return "J";  case 40: return "K";  case 45: return "N"
        case 46:  return "M"
        case 18:  return "1";  case 19: return "2";  case 20: return "3"
        case 21:  return "4";  case 23: return "5";  case 22: return "6"
        case 26:  return "7";  case 28: return "8";  case 25: return "9"
        case 29:  return "0"
        case 36:  return "↩";  case 48: return "⇥";  case 49: return "Space"
        case 51:  return "⌫";  case 53: return "⎋"
        case 76:  return "⌅"
        case 96:  return "F5"; case 97: return "F6"; case 98: return "F7"
        case 99: return "F3"; case 100: return "F8"; case 101: return "F9"
        case 109: return "F10"; case 103: return "F11"; case 111: return "F12"
        case 105: return "F13"; case 107: return "F14"; case 113: return "F15"
        case 118: return "F4"; case 120: return "F2"; case 122: return "F1"
        default:  return String(format: "Key(%d)", code)
        }
    }
}

// ───────────────────────────────────────────────────────────────
//  Settings Window Controller
// ───────────────────────────────────────────────────────────────
class SettingsWindowController: NSWindowController {

    private var fullscreenField: ShortcutField!
    private var leftField:       ShortcutField!
    private var rightField:      ShortcutField!
    private var topField:        ShortcutField!
    private var bottomField:     ShortcutField!
    private var launchCheckbox:  NSButton!
    private var showResCheckbox: NSButton!
    private weak var appDelegate: AppDelegate?

    convenience init(appDelegate: AppDelegate) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
            styleMask:   [.titled, .closable],
            backing:     .buffered,
            defer:       false
        )
        window.title = "Winshrink Settings"
        window.center()
        window.isReleasedWhenClosed = false

        self.init(window: window)
        self.appDelegate = appDelegate
        buildUI()
    }

    private func buildUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true

        let scroll = NSScrollView(frame: contentView.bounds)
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false

        let flip = FlippedView(frame: NSRect(x: 0, y: 0,
                                              width: contentView.bounds.width,
                                              height: 500))
        scroll.documentView = flip
        contentView.addSubview(scroll)

        let m: CGFloat = 20   // margin
        let w = contentView.bounds.width - m * 2
        var y: CGFloat = m

        // ── About section ─────────────────────────────────────────
        let aboutTitle = makeLabel("About", bold: true, size: 14)
        aboutTitle.frame = NSRect(x: m, y: y, width: w, height: 20)
        flip.addSubview(aboutTitle)
        y += 26

        let versionLabel = makeLabel("Version:  \(kAppVersion)")
        versionLabel.frame = NSRect(x: m + 10, y: y, width: w, height: 18)
        flip.addSubview(versionLabel)
        y += 22

        let devLabel = makeLabel("Developer:  \(kAppDeveloper)")
        devLabel.frame = NSRect(x: m + 10, y: y, width: w, height: 18)
        flip.addSubview(devLabel)
        y += 34

        // ── Separator ─────────────────────────────────────────────
        let sep1 = NSBox(frame: NSRect(x: m, y: y, width: w, height: 1))
        sep1.boxType = .separator
        flip.addSubview(sep1)
        y += 14

        // ── Shortcuts section ─────────────────────────────────────
        let shortcutsTitle = makeLabel("Keyboard Shortcuts", bold: true, size: 14)
        shortcutsTitle.frame = NSRect(x: m, y: y, width: w, height: 20)
        flip.addSubview(shortcutsTitle)
        y += 8

        let note = makeLabel("All shortcuts use ⌘ ⇧ + the key shown below. Click a field, then press a new key to change it.", size: 11)
        note.frame = NSRect(x: m, y: y + 18, width: w, height: 30)
        note.textColor = .secondaryLabelColor
        flip.addSubview(note)
        y += 52

        let defs = UserDefaults.standard
        func code(forKey key: String, fallback: UInt16) -> UInt16 {
            defs.object(forKey: key) != nil ? UInt16(defs.integer(forKey: key)) : fallback
        }

        let pairs: [(String, String, UInt16, (ShortcutField) -> Void)] = [
            ("Full Screen", kPrefKeyFullscreen, code(forKey: kPrefKeyFullscreen, fallback: kDefaultFullscreen),
             { [weak self] f in self?.fullscreenField = f }),
            ("Left Half",   kPrefKeyLeft,       code(forKey: kPrefKeyLeft, fallback: kDefaultLeft),
             { [weak self] f in self?.leftField = f }),
            ("Right Half",  kPrefKeyRight,      code(forKey: kPrefKeyRight, fallback: kDefaultRight),
             { [weak self] f in self?.rightField = f }),
            ("Top Half",    kPrefKeyTop,        code(forKey: kPrefKeyTop, fallback: kDefaultTop),
             { [weak self] f in self?.topField = f }),
            ("Bottom Half", kPrefKeyBottom,     code(forKey: kPrefKeyBottom, fallback: kDefaultBottom),
             { [weak self] f in self?.bottomField = f }),
        ]

        for (label, prefKey, currentCode, assign) in pairs {
            let lb = makeLabel(label)
            lb.frame = NSRect(x: m + 10, y: y, width: 120, height: 28)
            flip.addSubview(lb)

            let field = ShortcutField(frame: NSRect(x: m + 140, y: y, width: 180, height: 28))
            field.stringValue = "⌘ ⇧ " + ShortcutField.keyName(currentCode)
            field.onKeyRecorded = { [weak self] newCode in
                UserDefaults.standard.set(Int(newCode), forKey: prefKey)
                self?.appDelegate?.reloadShortcuts()
                self?.appDelegate?.rebuildMenu()
            }
            flip.addSubview(field)
            assign(field)
            y += 36
        }

        y += 10
        // ── Separator ─────────────────────────────────────────────
        let sep2 = NSBox(frame: NSRect(x: m, y: y, width: w, height: 1))
        sep2.boxType = .separator
        flip.addSubview(sep2)
        y += 14

        // ── Startup toggle ────────────────────────────────────────
        let startupTitle = makeLabel("Startup", bold: true, size: 14)
        startupTitle.frame = NSRect(x: m, y: y, width: w, height: 20)
        flip.addSubview(startupTitle)
        y += 28

        launchCheckbox = NSButton(checkboxWithTitle: "Launch Winshrink at login",
                                   target: self,
                                   action: #selector(toggleLaunchAtLogin))
        launchCheckbox.frame = NSRect(x: m + 10, y: y, width: 280, height: 22)
        launchCheckbox.state = UserDefaults.standard.bool(forKey: kPrefKeyLaunch) ? .on : .off
        flip.addSubview(launchCheckbox)
        y += 34

        // ── Separator ─────────────────────────────────────────────
        let sep3 = NSBox(frame: NSRect(x: m, y: y, width: w, height: 1))
        sep3.boxType = .separator
        flip.addSubview(sep3)
        y += 14

        // ── Display section ───────────────────────────────────────
        let displayTitle = makeLabel("Display", bold: true, size: 14)
        displayTitle.frame = NSRect(x: m, y: y, width: w, height: 20)
        flip.addSubview(displayTitle)
        y += 28

        showResCheckbox = NSButton(checkboxWithTitle: "Show screen resolution in menu bar",
                                    target: self,
                                    action: #selector(toggleShowResolution))
        showResCheckbox.frame = NSRect(x: m + 10, y: y, width: 340, height: 22)
        showResCheckbox.state = UserDefaults.standard.bool(forKey: kPrefKeyShowRes) ? .on : .off
        flip.addSubview(showResCheckbox)
        y += 24

        let resNote = makeLabel("Shows the native pixel resolution of the screen under your cursor next to the 🪴 icon.", size: 11)
        resNote.frame = NSRect(x: m + 10, y: y, width: w - 20, height: 30)
        resNote.textColor = .secondaryLabelColor
        flip.addSubview(resNote)
        y += 40

        flip.frame = NSRect(x: 0, y: 0, width: contentView.bounds.width, height: y)
    }

    @objc private func toggleShowResolution() {
        let enabled = (showResCheckbox.state == .on)
        UserDefaults.standard.set(enabled, forKey: kPrefKeyShowRes)
        appDelegate?.applyResolutionDisplay()
    }

    @objc private func toggleLaunchAtLogin() {
        let enabled = (launchCheckbox.state == .on)
        UserDefaults.standard.set(enabled, forKey: kPrefKeyLaunch)
        appDelegate?.setLaunchAtLogin(enabled)
    }

    private func makeLabel(_ text: String, bold: Bool = false, size: CGFloat = 13) -> NSTextField {
        let lbl = NSTextField(labelWithString: text)
        lbl.font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        lbl.lineBreakMode = .byWordWrapping
        return lbl
    }
}

// Helper: top-left origin view for easier layout
class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

// ───────────────────────────────────────────────────────────────
//  Screen info helpers
// ───────────────────────────────────────────────────────────────
struct ScreenInfo {
    let resolution: String       // e.g. "3840 × 2160"
    let nativePixels: String     // e.g. "3840 × 2160 px"
    let scaleFactor: String      // e.g. "2x Retina"
    let colorProfile: String     // e.g. "Display P3"
    let format: String           // e.g. "16:9"
    let screenName: String       // e.g. "Built-in Retina Display"
    let refreshRate: String      // e.g. "60 Hz"
}

private func gcd(_ a: Int, _ b: Int) -> Int {
    b == 0 ? a : gcd(b, a % b)
}

private func screenFormat(width: Int, height: Int) -> String {
    let d = gcd(width, height)
    let rw = width / d
    let rh = height / d
    // Common aspect ratios – normalise oddities
    let ratio = Double(width) / Double(height)
    if abs(ratio - 16.0/9.0) < 0.02  { return "16:9" }
    if abs(ratio - 16.0/10.0) < 0.02 { return "16:10" }
    if abs(ratio - 21.0/9.0) < 0.04  { return "21:9" }
    if abs(ratio - 32.0/9.0) < 0.04  { return "32:9" }
    if abs(ratio - 4.0/3.0) < 0.02   { return "4:3" }
    if abs(ratio - 3.0/2.0) < 0.02   { return "3:2" }
    if abs(ratio - 5.0/4.0) < 0.02   { return "5:4" }
    return "\(rw):\(rh)"
}

private func getScreenInfo(_ screen: NSScreen) -> ScreenInfo {
    let frame = screen.frame
    let backing = screen.backingScaleFactor

    // Logical (point) resolution
    let logW = Int(frame.width)
    let logH = Int(frame.height)

    // Native (pixel) resolution
    let pixW = Int(frame.width * backing)
    let pixH = Int(frame.height * backing)

    let scaleStr: String
    if backing >= 2 {
        scaleStr = "\(Int(backing))x Retina"
    } else {
        scaleStr = "1x"
    }

    // Color profile
    var colorProfile = "Unknown"
    if let space = screen.colorSpace {
        colorProfile = space.localizedName ?? "Unknown"
    }

    // Screen name
    var name = "Display"
    if #available(macOS 10.15, *) {
        name = screen.localizedName
    }

    // Refresh rate (if available via CGDisplayMode)
    var refreshStr = ""
    let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    if let did = displayID, let mode = CGDisplayCopyDisplayMode(did) {
        let hz = Int(mode.refreshRate)
        refreshStr = hz > 0 ? "\(hz) Hz" : "Variable"
    }

    let format = screenFormat(width: pixW, height: pixH)

    return ScreenInfo(
        resolution:   "\(logW) × \(logH) pt",
        nativePixels: "\(pixW) × \(pixH) px",
        scaleFactor:  scaleStr,
        colorProfile: colorProfile,
        format:       format,
        screenName:   name,
        refreshRate:  refreshStr
    )
}

/// Returns the screen that currently contains the mouse cursor.
private func screenUnderMouse() -> NSScreen {
    let mouseLocation = NSEvent.mouseLocation
    for screen in NSScreen.screens {
        if screen.frame.contains(mouseLocation) {
            return screen
        }
    }
    return NSScreen.main ?? NSScreen.screens[0]
}

// ───────────────────────────────────────────────────────────────
//  AppDelegate
// ───────────────────────────────────────────────────────────────
class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem:     NSStatusItem!
    private var eventTap:       CFMachPort?
    private var settingsWC:     SettingsWindowController?
    private var resolutionTimer: Timer?
    private var showingResolution = false

    // Current shortcut key codes (loaded from UserDefaults)
    private var keyFullscreen: UInt16 = kDefaultFullscreen
    private var keyLeft:       UInt16 = kDefaultLeft
    private var keyRight:      UInt16 = kDefaultRight
    private var keyTop:        UInt16 = kDefaultTop
    private var keyBottom:     UInt16 = kDefaultBottom

    // MARK: - App lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        reloadShortcuts()
        setupMenuBar()
        syncLaunchAgentState()
        applyResolutionDisplay()
        // Listen for screen configuration changes (plugging monitors, resolution changes)
        NotificationCenter.default.addObserver(self,
            selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil)
        if AXIsProcessTrusted() {
            installEventTap()
        } else {
            promptAccessibilityOnce()
            pollForAccessibility()
        }
    }

    @objc private func screensChanged() {
        applyResolutionDisplay()
        rebuildMenu()
    }

    // MARK: - Shortcut persistence

    func reloadShortcuts() {
        let d = UserDefaults.standard
        func val(_ key: String, _ fallback: UInt16) -> UInt16 {
            d.object(forKey: key) != nil ? UInt16(d.integer(forKey: key)) : fallback
        }
        keyFullscreen = val(kPrefKeyFullscreen, kDefaultFullscreen)
        keyLeft       = val(kPrefKeyLeft,       kDefaultLeft)
        keyRight      = val(kPrefKeyRight,      kDefaultRight)
        keyTop        = val(kPrefKeyTop,        kDefaultTop)
        keyBottom     = val(kPrefKeyBottom,      kDefaultBottom)
    }

    // MARK: - Menu bar

    private func emojiImage(_ emoji: String, size: CGFloat = 16) -> NSImage {
        let font  = NSFont.systemFont(ofSize: size)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let str   = NSAttributedString(string: emoji, attributes: attrs)
        let dim   = str.size()
        let img   = NSImage(size: NSSize(width: dim.width, height: dim.height + 2))
        img.lockFocus()
        str.draw(at: NSPoint(x: 0, y: 1))
        img.unlockFocus()
        img.isTemplate = false
        return img
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMenuBarTitle()
        rebuildMenu()
    }

    private func updateMenuBarTitle() {
        guard let btn = statusItem.button else { return }
        if showingResolution {
            let screen = screenUnderMouse()
            let info = getScreenInfo(screen)
            let title = "🪴 \(info.nativePixels)"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            ]
            btn.attributedTitle = NSAttributedString(string: title, attributes: attrs)
            btn.image = nil
        } else {
            btn.attributedTitle = NSAttributedString(string: "")
            btn.image = emojiImage("🪴", size: 16)
            btn.imageScaling = .scaleProportionallyDown
        }
    }

    /// Start or stop the resolution display timer based on UserDefaults.
    func applyResolutionDisplay() {
        let enabled = UserDefaults.standard.bool(forKey: kPrefKeyShowRes)
        showingResolution = enabled
        resolutionTimer?.invalidate()
        resolutionTimer = nil
        if enabled {
            // Update every 2 seconds to track screen under mouse
            resolutionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.updateMenuBarTitle()
            }
        }
        updateMenuBarTitle()
    }

    func rebuildMenu() {
        let menu = NSMenu()

        menu.addItem(header("Winshrink v\(kAppVersion)"))
        menu.addItem(.separator())

        // ── Screen info for each connected display ────────────
        for (idx, screen) in NSScreen.screens.enumerated() {
            let si = getScreenInfo(screen)
            let isCurrent = (screen == screenUnderMouse())
            let prefix = isCurrent ? "▸ " : "  "
            menu.addItem(header("\(prefix)\(si.screenName)"))
            menu.addItem(info("    Resolution:     \(si.nativePixels)  (\(si.scaleFactor))"))
            menu.addItem(info("    Color Profile:  \(si.colorProfile)"))
            menu.addItem(info("    Format:           \(si.format)\(si.refreshRate.isEmpty ? "" : "  •  \(si.refreshRate)")"))
            if idx < NSScreen.screens.count - 1 {
                menu.addItem(.separator())
            }
        }

        menu.addItem(.separator())

        // ── Keyboard shortcuts ────────────────────────────────
        menu.addItem(header("  Keyboard Shortcuts"))
        menu.addItem(info("  ⌘ ⇧ \(ShortcutField.keyName(keyFullscreen))     Full screen"))
        menu.addItem(info("  ⌘ ⇧ \(ShortcutField.keyName(keyLeft))    Left half"))
        menu.addItem(info("  ⌘ ⇧ \(ShortcutField.keyName(keyRight))    Right half"))
        menu.addItem(info("  ⌘ ⇧ \(ShortcutField.keyName(keyTop))    Top half"))
        menu.addItem(info("  ⌘ ⇧ \(ShortcutField.keyName(keyBottom))    Bottom half"))

        menu.addItem(.separator())

        // ── Settings ──────────────────────────────────────────
        let settingsItem = NSMenuItem(title: "Settings...",
                                       action: #selector(openSettings),
                                       keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Winshrink",
                              action: #selector(NSApplication.terminate(_:)),
                              keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    private func header(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func info(_ text: String) -> NSMenuItem {
        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    // MARK: - Settings

    @objc func openSettings() {
        if settingsWC == nil {
            settingsWC = SettingsWindowController(appDelegate: self)
        }
        settingsWC?.showWindow(nil)
        settingsWC?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Launch at login

    func setLaunchAtLogin(_ enabled: Bool) {
        let agentDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
        let plistPath = agentDir.appendingPathComponent("com.winshrink.app.plist")

        if enabled {
            // Write the LaunchAgent plist
            let appPath = Bundle.main.bundlePath + "/Contents/MacOS/Winshrink"
            let plist: [String: Any] = [
                "Label": kBundleId,
                "ProgramArguments": [appPath],
                "RunAtLoad": true,
                "KeepAlive": ["SuccessfulExit": false]
            ]
            try? FileManager.default.createDirectory(at: agentDir,
                                                      withIntermediateDirectories: true)
            (plist as NSDictionary).write(to: plistPath, atomically: true)

            // Load the agent
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            task.arguments = ["load", "-w", plistPath.path]
            try? task.run()
        } else {
            // Unload and remove
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            task.arguments = ["unload", plistPath.path]
            try? task.run()
            task.waitUntilExit()
            try? FileManager.default.removeItem(at: plistPath)
        }
    }

    private func syncLaunchAgentState() {
        let d = UserDefaults.standard
        // On first launch, default to enabled
        if d.object(forKey: kPrefKeyLaunch) == nil {
            d.set(true, forKey: kPrefKeyLaunch)
        }
    }

    // MARK: - Accessibility

    private func promptAccessibilityOnce() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            )
        }
    }

    private func pollForAccessibility() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            if AXIsProcessTrusted() {
                NSLog("Winshrink: Accessibility granted — activating shortcuts")
                self.installEventTap()
            } else {
                self.pollForAccessibility()
            }
        }
    }

    // MARK: - CGEventTap (global hotkeys)

    private func installEventTap() {
        // Remove existing tap if re-installing
        if let old = eventTap {
            CGEvent.tapEnable(tap: old, enable: false)
            eventTap = nil
        }

        let mask    = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let selfPtr = Unmanaged.passRetained(self).toOpaque()

        let tap = CGEvent.tapCreate(
            tap:              .cgSessionEventTap,
            place:            .headInsertEventTap,
            options:          .defaultTap,
            eventsOfInterest: mask,
            callback:         AppDelegate.eventTapCallback,
            userInfo:         selfPtr
        )
        guard let tap = tap else {
            NSLog("Winshrink: failed to create event tap – Accessibility permission missing?")
            return
        }
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.eventTap = tap
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, refcon in
        guard type != .tapDisabledByTimeout,
              type != .tapDisabledByUserInput else {
            return Unmanaged.passRetained(event)
        }
        guard let refcon = refcon else { return Unmanaged.passRetained(event) }
        let me = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
        return me.handleKey(event: event)
    }

    private func handleKey(event: CGEvent) -> Unmanaged<CGEvent>? {
        let flags   = event.flags
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

        let required: CGEventFlags = [.maskCommand, .maskShift]
        let others:   CGEventFlags = [.maskControl, .maskAlternate]
        guard flags.intersection(required) == required,
              flags.intersection(others).isEmpty else {
            return Unmanaged.passRetained(event)
        }

        switch keyCode {
        case keyFullscreen: DispatchQueue.main.async { self.maximizeWindow() }; return nil
        case keyLeft:       DispatchQueue.main.async { self.leftHalf() };       return nil
        case keyRight:      DispatchQueue.main.async { self.rightHalf() };      return nil
        case keyTop:        DispatchQueue.main.async { self.topHalf() };        return nil
        case keyBottom:     DispatchQueue.main.async { self.bottomHalf() };     return nil
        default:            return Unmanaged.passRetained(event)
        }
    }

    // MARK: - Window helpers

    private func focusedWindow() -> AXUIElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var win: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &win) == .success,
              CFGetTypeID(win!) == AXUIElementGetTypeID() else { return nil }
        return (win as! AXUIElement)
    }

    /// Convert an NSScreen's visible frame (Cocoa: bottom-left origin) to
    /// AX coordinates (top-left origin, Y grows downward).
    ///
    /// The key insight for multi-monitor: the Accessibility coordinate space
    /// puts (0,0) at the top-left of the PRIMARY screen. Other screens extend
    /// in whatever direction they're arranged in System Settings.
    private func visibleAXFrame(for screen: NSScreen) -> CGRect {
        // The primary screen (menu bar screen) has its origin at Cocoa (0,0),
        // so primaryHeight is also the global Y-flip pivot.
        guard let primaryScreen = NSScreen.screens.first else {
            return .zero
        }
        let primaryHeight = primaryScreen.frame.height
        let vf = screen.visibleFrame
        let axY = primaryHeight - vf.origin.y - vf.height
        return CGRect(x: vf.origin.x, y: axY, width: vf.width, height: vf.height)
    }

    private func setFrame(_ frame: CGRect, on window: AXUIElement) {
        var origin = frame.origin
        var size   = frame.size
        // Set position first, then size (some apps constrain max size based on position)
        if let pv = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pv)
        }
        if let sv = AXValueCreate(.cgSize, &size) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sv)
        }
        // Set position again in case the size change moved the window
        if let pv = AXValueCreate(.cgPoint, &origin) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pv)
        }
    }

    /// Determine which screen the focused window currently lives on.
    /// Uses the window's center point for accurate detection on multi-monitor setups.
    private func owningScreen() -> NSScreen {
        guard let win = focusedWindow() else {
            return NSScreen.main ?? NSScreen.screens[0]
        }

        // Get window position (AX coords: top-left origin)
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(win, kAXPositionAttribute as CFString, &posRef) == .success,
              AXUIElementCopyAttributeValue(win, kAXSizeAttribute as CFString, &sizeRef) == .success,
              CFGetTypeID(posRef!) == AXValueGetTypeID(),
              CFGetTypeID(sizeRef!) == AXValueGetTypeID() else {
            return NSScreen.main ?? NSScreen.screens[0]
        }

        var pos  = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posRef as! AXValue, .cgPoint, &pos)
        AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)

        // Convert AX center point to Cocoa coordinates
        guard let primaryScreen = NSScreen.screens.first else {
            return NSScreen.main ?? NSScreen.screens[0]
        }
        let primaryHeight = primaryScreen.frame.height
        let centerAX = CGPoint(x: pos.x + size.width / 2, y: pos.y + size.height / 2)
        let centerCocoa = CGPoint(x: centerAX.x, y: primaryHeight - centerAX.y)

        // Find which screen contains the center point
        for screen in NSScreen.screens {
            if screen.frame.contains(centerCocoa) {
                return screen
            }
        }

        // Fallback: find the screen with the most overlap
        let winRectCocoa = CGRect(x: pos.x, y: primaryHeight - pos.y - size.height,
                                   width: size.width, height: size.height)
        var bestScreen = NSScreen.main ?? NSScreen.screens[0]
        var bestArea: CGFloat = 0
        for screen in NSScreen.screens {
            let overlap = screen.frame.intersection(winRectCocoa)
            if !overlap.isNull {
                let area = overlap.width * overlap.height
                if area > bestArea {
                    bestArea = area
                    bestScreen = screen
                }
            }
        }
        return bestScreen
    }

    // MARK: - Snap actions

    func maximizeWindow() {
        guard let win = focusedWindow() else { return }
        setFrame(visibleAXFrame(for: owningScreen()), on: win)
    }

    func leftHalf() {
        guard let win = focusedWindow() else { return }
        var frame = visibleAXFrame(for: owningScreen())
        frame.size.width /= 2
        setFrame(frame, on: win)
    }

    func rightHalf() {
        guard let win = focusedWindow() else { return }
        var frame = visibleAXFrame(for: owningScreen())
        frame.origin.x   += frame.size.width / 2
        frame.size.width /= 2
        setFrame(frame, on: win)
    }

    func topHalf() {
        guard let win = focusedWindow() else { return }
        var frame = visibleAXFrame(for: owningScreen())
        frame.size.height /= 2
        setFrame(frame, on: win)
    }

    func bottomHalf() {
        guard let win = focusedWindow() else { return }
        var frame = visibleAXFrame(for: owningScreen())
        frame.origin.y    += frame.size.height / 2
        frame.size.height /= 2
        setFrame(frame, on: win)
    }
}

// ───────────────────────────────────────────────────────────────
//  Entry point
// ───────────────────────────────────────────────────────────────
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
