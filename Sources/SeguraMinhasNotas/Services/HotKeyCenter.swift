import Carbon.HIToolbox
import Foundation

final class HotKeyCenter {
    enum Action: UInt32 {
        case newNote = 1
        case allNotes = 2
        case archive = 3
    }

    var onAction: ((Action) -> Void)?
    private var refs: [EventHotKeyRef?] = []
    private var handler: EventHandlerRef?

    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, pointer in
                guard let event, let pointer else { return noErr }
                let center = Unmanaged<HotKeyCenter>.fromOpaque(pointer).takeUnretainedValue()
                var identifier = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &identifier
                )
                if status == noErr, let action = Action(rawValue: identifier.id) {
                    DispatchQueue.main.async { center.onAction?(action) }
                }
                return noErr
            },
            1,
            &type,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )

        register(.newNote, keyCode: UInt32(kVK_ANSI_N))
        register(.allNotes, keyCode: UInt32(kVK_ANSI_A))
        register(.archive, keyCode: UInt32(kVK_ANSI_L))
    }

    deinit {
        refs.forEach { if let ref = $0 { UnregisterEventHotKey(ref) } }
        if let handler { RemoveEventHandler(handler) }
    }

    private func register(_ action: Action, keyCode: UInt32) {
        var ref: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: OSType(0x534D4E54), id: action.rawValue) // SMNT
        RegisterEventHotKey(keyCode, UInt32(cmdKey | optionKey), identifier, GetApplicationEventTarget(), 0, &ref)
        refs.append(ref)
    }
}
