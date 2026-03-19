import Cocoa
import Carbon.HIToolbox

class KeyboardMonitor {
    static let shared = KeyboardMonitor()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var buffer: String = ""
    private var isTracking: Bool = false
    private var savedClipboard: String?

    var onBufferUpdate: ((String) -> Void)?
    var onEmojiInserted: (() -> Void)?
    var onTrackingCancelled: (() -> Void)?

    private init() {}

    func start() {
        guard eventTap == nil else { return }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else {
                    return Unmanaged.passRetained(event)
                }
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: refcon
        ) else {
            print("MacMoji: Failed to create event tap. Check Accessibility permissions.")
            return
        }

        self.eventTap = tap

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("MacMoji: Keyboard monitor started")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            eventTap = nil
            runLoopSource = nil
        }
        cancelTracking()
    }

    func cancelTracking() {
        if isTracking {
            isTracking = false
            buffer = ""
            DispatchQueue.main.async {
                self.onTrackingCancelled?()
            }
        }
    }

    func selectEmoji(_ emoji: String, shortcode: String) {
        let deleteCount: Int
        if isTracking {
            // Delete the `:` + buffer content
            deleteCount = buffer.count + 1
        } else {
            deleteCount = 0
        }

        isTracking = false
        buffer = ""

        DispatchQueue.main.async {
            self.onTrackingCancelled?()
        }

        // Perform the replacement after a tiny delay to let the event tap settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.replaceText(deleteCount: deleteCount, replacement: emoji)
        }
    }

    private func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable tap if it gets disabled (macOS can disable taps that take too long)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        guard type == .keyDown else {
            return Unmanaged.passRetained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        // Ignore events with Command modifier (shortcuts like Cmd+C, Cmd+V)
        if flags.contains(.maskCommand) {
            return Unmanaged.passRetained(event)
        }

        // Handle special keys when autocomplete popup is showing
        if isTracking && !buffer.isEmpty {
            let popup = AutocompleteWindowController.shared

            switch Int(keyCode) {
            case kVK_Escape:
                cancelTracking()
                return nil // Consume the event

            case kVK_Return, kVK_Tab:
                if popup.isVisible, let selected = popup.selectedEmoji {
                    selectEmoji(selected.emoji, shortcode: selected.shortcode)
                    return nil // Consume the event
                }
                cancelTracking()
                return Unmanaged.passRetained(event)

            case kVK_UpArrow:
                if popup.isVisible {
                    DispatchQueue.main.async { popup.moveSelectionUp() }
                    return nil
                }
                return Unmanaged.passRetained(event)

            case kVK_DownArrow:
                if popup.isVisible {
                    DispatchQueue.main.async { popup.moveSelectionDown() }
                    return nil
                }
                return Unmanaged.passRetained(event)

            case kVK_Delete: // Backspace
                if !buffer.isEmpty {
                    buffer.removeLast()
                    if buffer.isEmpty {
                        cancelTracking()
                    } else {
                        DispatchQueue.main.async {
                            self.onBufferUpdate?(self.buffer)
                        }
                    }
                } else {
                    cancelTracking()
                }
                return Unmanaged.passRetained(event)

            case kVK_Space:
                cancelTracking()
                return Unmanaged.passRetained(event)

            default:
                break
            }
        } else if Int(keyCode) == kVK_Delete && isTracking && buffer.isEmpty {
            // Backspace when we only have the `:` tracked
            cancelTracking()
            return Unmanaged.passRetained(event)
        }

        // Get the character typed
        if let characters = event.copy()?.keyboardString(), !characters.isEmpty {
            let char = characters

            if char == ":" {
                if isTracking && !buffer.isEmpty {
                    // Closing colon - check if we have a valid shortcode
                    let shortcode = buffer.lowercased()
                    if let emoji = EmojiDatabase.all[shortcode] {
                        // Valid shortcode! Replace :shortcode: with emoji
                        let deleteCount = buffer.count + 1 // +1 for opening `:`
                        isTracking = false
                        buffer = ""
                        DispatchQueue.main.async {
                            self.onTrackingCancelled?()
                        }
                        // Let the closing `:` pass through, then delete everything and insert emoji
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            self.replaceText(deleteCount: deleteCount + 1, replacement: emoji) // +1 for closing `:`
                        }
                        return Unmanaged.passRetained(event)
                    } else {
                        // Not a valid shortcode, start fresh tracking from this `:`
                        buffer = ""
                        isTracking = true
                        DispatchQueue.main.async {
                            self.onBufferUpdate?(self.buffer)
                        }
                        return Unmanaged.passRetained(event)
                    }
                } else {
                    // Start tracking
                    isTracking = true
                    buffer = ""
                    DispatchQueue.main.async {
                        self.onBufferUpdate?(self.buffer)
                    }
                    return Unmanaged.passRetained(event)
                }
            } else if isTracking {
                // Only allow alphanumeric and underscore in shortcodes
                let validChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
                if char.unicodeScalars.allSatisfy({ validChars.contains($0) }) {
                    buffer += char.lowercased()
                    DispatchQueue.main.async {
                        self.onBufferUpdate?(self.buffer)
                    }
                } else {
                    // Invalid character for shortcode, cancel tracking
                    cancelTracking()
                }
            }
        }

        return Unmanaged.passRetained(event)
    }

    private func replaceText(deleteCount: Int, replacement: String) {
        let pasteboard = NSPasteboard.general

        // Save current clipboard content
        let savedString = pasteboard.string(forType: .string)

        // Simulate backspace keys to delete the shortcode
        let src = CGEventSource(stateID: .hidSystemState)
        for _ in 0..<deleteCount {
            let backDown = CGEvent(keyboardEventSource: src, virtualKey: UInt16(kVK_Delete), keyDown: true)
            backDown?.post(tap: .cghidEventTap)
            let backUp = CGEvent(keyboardEventSource: src, virtualKey: UInt16(kVK_Delete), keyDown: false)
            backUp?.post(tap: .cghidEventTap)
            usleep(5000) // 5ms between keystrokes
        }

        // Small delay to let backspaces process
        usleep(30000) // 30ms

        // Put emoji on clipboard
        pasteboard.clearContents()
        pasteboard.setString(replacement, forType: .string)

        // Simulate Cmd+V to paste
        let vDown = CGEvent(keyboardEventSource: src, virtualKey: UInt16(kVK_ANSI_V), keyDown: true)
        vDown?.flags = .maskCommand
        vDown?.post(tap: .cghidEventTap)
        let vUp = CGEvent(keyboardEventSource: src, virtualKey: UInt16(kVK_ANSI_V), keyDown: false)
        vUp?.flags = .maskCommand
        vUp?.post(tap: .cghidEventTap)

        // Restore clipboard after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let savedString = savedString {
                pasteboard.clearContents()
                pasteboard.setString(savedString, forType: .string)
            }
            self.onEmojiInserted?()
        }
    }
}

// Extension to get string from CGEvent
extension CGEvent {
    func keyboardString() -> String? {
        let maxLength = 4
        var length = 0
        var chars = [UniChar](repeating: 0, count: maxLength)
        self.keyboardGetUnicodeString(maxStringLength: maxLength, actualStringLength: &length, unicodeString: &chars)
        guard length > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: length)
    }
}
