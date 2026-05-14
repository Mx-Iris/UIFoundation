#if FilterUI

import AppKit
import Carbon

extension NSEvent {
    class CarbonMonitor {
        let handler: (NSEvent) -> Bool
        var carbonHandler: EventHandlerRef?
        init(_ handler: @escaping (NSEvent) -> Bool) { self.handler = handler }
    }

    /// Installs an event monitor that receives copies of Carbon key events posted to this application before they are
    /// dispatched.
    ///
    /// - Parameters:
    ///   - block: The event handler block object. It is passed the event to monitor. Return true if you wish to stop the
    ///    dispatching of the event, otherwise return false.
    ///
    /// - Returns: A Carbon event handler object.
    ///
    /// Unlike ``NSEvent.addLocalMonitorForEvents(matching:handler:)``, your handler will be called for events otherwise
    /// consumed by nested event-tracking loops such as control tracking, menu tracking, or window dragging.
    ///
    static func addCarbonMonitorForKeyEvents(handler block: @escaping (NSEvent) -> Bool) -> Any? {
        var eventHandler: EventHandlerRef?
        let monitor = CarbonMonitor(block)

        let eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventRawKeyDown)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventRawKeyRepeat)),
        ]

        guard InstallEventHandler(
            GetEventDispatcherTarget(),
            { handler, eventRef, monitor in
                guard let eventRef = eventRef else { return noErr }
                guard let event = NSEvent(eventRef: UnsafeRawPointer(eventRef)) else { return noErr }
                guard let monitor = monitor.map({ Unmanaged<CarbonMonitor>.fromOpaque($0).takeUnretainedValue() }) else { return noErr }
                return monitor.handler(event) ? noErr : CallNextEventHandler(handler, eventRef)
            },
            eventTypes.count,
            eventTypes,
            Unmanaged.passUnretained(monitor).toOpaque(),
            &eventHandler
        ) == noErr else {
            return nil
        }

        monitor.carbonHandler = eventHandler

        return monitor
    }

    /// Remove the specified Carbon event monitor.
    ///
    /// - Parameters:
    ///   - monitor: The Carbon event monitor object to remove.
    ///
    /// You must ensure that eventMonitor is removed only once.
    ///
    static func removeCarbonMonitor(_ monitor: Any) {
        guard let monitor = monitor as? CarbonMonitor else { return }
        RemoveEventHandler(monitor.carbonHandler)
    }
}

#endif
