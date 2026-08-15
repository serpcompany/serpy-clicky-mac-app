import AppKit
import ApplicationServices
import Foundation
import GuideCore

public final class FocusedTextTarget: @unchecked Sendable {
    fileprivate let processIdentifier: pid_t
    fileprivate let element: AXUIElement

    fileprivate init(processIdentifier: pid_t, element: AXUIElement) {
        self.processIdentifier = processIdentifier
        self.element = element
    }
}

public enum TextInsertionMethod: String, Equatable, Sendable {
    case accessibility
    case paste
}

@MainActor
public final class TextInsertionService {
    public init() {}

    public func captureFocusedTarget() throws -> FocusedTextTarget {
        let systemWide = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &value
        )

        guard result == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            throw insertionFailure(
                "No editable text field is focused.",
                recovery: "Click in a text field before starting dictation."
            )
        }

        let element = unsafeDowncast(value, to: AXUIElement.self)
        var processIdentifier: pid_t = 0
        guard AXUIElementGetPid(element, &processIdentifier) == .success else {
            throw insertionFailure(
                "The focused application could not be identified.",
                recovery: "Click in the destination field and try again."
            )
        }

        return FocusedTextTarget(processIdentifier: processIdentifier, element: element)
    }

    public func insert(_ text: String, into target: FocusedTextTarget) async throws -> TextInsertionMethod {
        guard !text.isEmpty else {
            throw insertionFailure("The transcript was empty.", recovery: "Try dictating again.")
        }

        if canSetSelectedText(on: target.element),
           AXUIElementSetAttributeValue(
               target.element,
               kAXSelectedTextAttribute as CFString,
               text as CFString
           ) == .success {
            return .accessibility
        }

        try await paste(text, into: target.processIdentifier)
        return .paste
    }

    private func canSetSelectedText(on element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        let result = AXUIElementIsAttributeSettable(
            element,
            kAXSelectedTextAttribute as CFString,
            &settable
        )
        return result == .success && settable.boolValue
    }

    private func paste(_ text: String, into processIdentifier: pid_t) async throws {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            throw insertionFailure(
                "The temporary paste operation could not be prepared.",
                recovery: "Copy the transcript from Guide Companion and paste it manually."
            )
        }
        let injectedChangeCount = pasteboard.changeCount

        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            snapshot.restore(to: pasteboard)
            throw insertionFailure(
                "The paste keystroke could not be created.",
                recovery: "Copy the transcript and paste it manually."
            )
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.postToPid(processIdentifier)
        keyUp.postToPid(processIdentifier)

        try await Task.sleep(for: .milliseconds(250))
        if pasteboard.changeCount == injectedChangeCount {
            snapshot.restore(to: pasteboard)
        }
    }

    private func insertionFailure(_ message: String, recovery: String) -> GuideFailure {
        GuideFailure(stage: .insertion, message: message, recovery: recovery)
    }
}

@MainActor
private struct PasteboardSnapshot {
    struct Item {
        let values: [(NSPasteboard.PasteboardType, Data)]
    }

    let items: [Item]

    init(pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            Item(values: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        }
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let restored = items.map { stored -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in stored.values {
                item.setData(data, forType: type)
            }
            return item
        }
        if !restored.isEmpty {
            pasteboard.writeObjects(restored)
        }
    }
}
