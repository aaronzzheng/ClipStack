import AppKit
import Carbon.HIToolbox

/// System-wide hotkeys via the Carbon Event Manager.
///
/// `RegisterEventHotKey` needs no privacy permission at all — unlike a
/// `CGEventTap`, which would require Input Monitoring. Only synthesising the
/// paste keystroke afterwards needs Accessibility, and that is requested
/// lazily, the first time it is actually used.
final class HotKeyManager {

    struct Shortcut {
        let keyCode: UInt32
        let modifiers: UInt32
        /// How it reads in the UI, e.g. "⌘⇧V".
        let display: String

        static let pasteAsPlainText = Shortcut(keyCode: UInt32(kVK_ANSI_V),
                                              modifiers: UInt32(cmdKey | shiftKey),
                                              display: "⌘⇧V")
        static let showHistory = Shortcut(keyCode: UInt32(kVK_ANSI_V),
                                         modifiers: UInt32(cmdKey | optionKey),
                                         display: "⌥⌘V")
    }

    private var actions: [UInt32: () -> Void] = [:]
    private var registered: [EventHotKeyRef?] = []
    private var handler: EventHandlerRef?
    private var nextID: UInt32 = 1

    func start() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(),
                            hotKeyEventHandler,
                            1,
                            &spec,
                            Unmanaged.passUnretained(self).toOpaque(),
                            &handler)
    }

    /// Returns false when the combination is already claimed by another app;
    /// the rest of the app keeps working without it.
    @discardableResult
    func register(_ shortcut: Shortcut, action: @escaping () -> Void) -> Bool {
        let id = nextID
        nextID += 1

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x43535448), id: id)  // 'CSTH'
        let status = RegisterEventHotKey(shortcut.keyCode,
                                        shortcut.modifiers,
                                        hotKeyID,
                                        GetApplicationEventTarget(),
                                        0,
                                        &ref)
        guard status == noErr else { return false }
        actions[id] = action
        registered.append(ref)
        return true
    }

    fileprivate func fire(_ id: UInt32) {
        actions[id]?()
    }

    func stop() {
        for ref in registered where ref != nil { UnregisterEventHotKey(ref) }
        registered.removeAll()
        actions.removeAll()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }

    deinit { stop() }
}

/// Carbon needs a C function pointer, so the manager arrives via userData.
private let hotKeyEventHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(event,
                                  EventParamName(kEventParamDirectObject),
                                  EventParamType(typeEventHotKeyID),
                                  nil,
                                  MemoryLayout<EventHotKeyID>.size,
                                  nil,
                                  &hotKeyID)
    guard status == noErr else { return status }
    Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue().fire(hotKeyID.id)
    return noErr
}
