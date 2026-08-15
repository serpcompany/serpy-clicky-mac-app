import AppKit
import ApplicationServices
import Foundation
import GuideCore
import OSLog

private let insertionLogger = Logger(
    subsystem: "com.serpcompany.guidecompanion.internal",
    category: "insertion"
)

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
    case accessibilityValue
    case paste
}

public enum TextValueReplacement {
    public enum Error: Swift.Error, Equatable {
        case invalidRange
    }

    public struct Result {
        public let value: String
        public let caret: CFRange
    }

    public static func inserting(
        _ text: String,
        into existing: String,
        selectedRange: CFRange
    ) throws -> Result {
        let utf16Length = (existing as NSString).length
        guard selectedRange.location >= 0,
              selectedRange.length >= 0,
              selectedRange.location <= utf16Length,
              selectedRange.location + selectedRange.length <= utf16Length else {
            throw Error.invalidRange
        }

        let mutable = NSMutableString(string: existing)
        mutable.replaceCharacters(
            in: NSRange(location: selectedRange.location, length: selectedRange.length),
            with: text
        )
        let caretLocation = selectedRange.location + (text as NSString).length
        return Result(
            value: mutable as String,
            caret: CFRange(location: caretLocation, length: 0)
        )
    }
}

@MainActor
public final class TextInsertionService {
    public init() {}

    public func captureFocusedTarget() throws -> FocusedTextTarget {
        let frontmostApplication = NSWorkspace.shared.frontmostApplication
        let frontmostPID = frontmostApplication?.processIdentifier ?? 0
        insertionLogger.notice(
            "Capturing target; frontmostBundle=\(frontmostApplication?.bundleIdentifier ?? "unknown", privacy: .public) pid=\(frontmostPID)"
        )
        let applicationElement = frontmostPID > 0
            ? AXUIElementCreateApplication(frontmostPID)
            : AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        var result = AXUIElementCopyAttributeValue(
            applicationElement,
            kAXFocusedUIElementAttribute as CFString,
            &value
        )

        if result != .success || value == nil {
            let systemWide = AXUIElementCreateSystemWide()
            result = AXUIElementCopyAttributeValue(
                systemWide,
                kAXFocusedUIElementAttribute as CFString,
                &value
            )
        }

        guard result == .success,
              let value,
              CFGetTypeID(value) == AXUIElementGetTypeID() else {
            throw insertionFailure(
                "No editable text field is focused.",
                recovery: "Click in a text field before starting dictation."
            )
        }

        let element = unsafeDowncast(value, to: AXUIElement.self)
        let focusedRole = stringAttribute(kAXRoleAttribute as CFString, of: element) ?? "unknown"
        insertionLogger.notice("Focused AX role=\(focusedRole, privacy: .public)")
        guard isEditableTextTarget(element) else {
            throw insertionFailure(
                "No editable text field is focused.",
                recovery: "Click directly inside the destination text field and try again."
            )
        }
        var elementPID: pid_t = 0
        guard AXUIElementGetPid(element, &elementPID) == .success else {
            throw insertionFailure(
                "The focused application could not be identified.",
                recovery: "Click in the destination field and try again."
            )
        }

        return FocusedTextTarget(processIdentifier: elementPID, element: element)
    }

    public func insert(_ text: String, into target: FocusedTextTarget) async throws -> TextInsertionMethod {
        guard !text.isEmpty else {
            throw insertionFailure("The transcript was empty.", recovery: "Try dictating again.")
        }

        let selectedTextResult = AXUIElementSetAttributeValue(
               target.element,
               kAXSelectedTextAttribute as CFString,
               text as CFString
           )
        insertionLogger.notice("AX selected-text write result=\(selectedTextResult.rawValue)")
        if selectedTextResult == .success {
            return .accessibility
        }

        if let replacementMethod = try replaceAccessibilityValue(text, on: target.element) {
            return replacementMethod
        }

        try await paste(text, into: target)
        return .paste
    }

    private func canSet(attribute: CFString, on element: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        let result = AXUIElementIsAttributeSettable(
            element,
            attribute,
            &settable
        )
        return result == .success && settable.boolValue
    }

    private func isEditableTextTarget(_ element: AXUIElement) -> Bool {
        let role = stringAttribute(kAXRoleAttribute as CFString, of: element)
        return role == (kAXTextFieldRole as String)
            || role == (kAXTextAreaRole as String)
            || role == (kAXComboBoxRole as String)
            || canSet(attribute: kAXSelectedTextAttribute as CFString, on: element)
            || canSet(attribute: kAXValueAttribute as CFString, on: element)
    }

    private func replaceAccessibilityValue(
        _ text: String,
        on element: AXUIElement
    ) throws -> TextInsertionMethod? {
        guard let existing = stringValue(of: element),
              let selectedRange = selectedTextRange(of: element) else {
            return nil
        }

        let replacement: TextValueReplacement.Result
        do {
            replacement = try TextValueReplacement.inserting(
                text,
                into: existing,
                selectedRange: selectedRange
            )
        } catch {
            return nil
        }

        guard AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            replacement.value as CFString
        ) == .success else {
            insertionLogger.notice("AX value replacement was rejected")
            return nil
        }
        insertionLogger.notice("AX value replacement succeeded")

        var caret = replacement.caret
        if let caretValue = AXValueCreate(.cfRange, &caret) {
            _ = AXUIElementSetAttributeValue(
                element,
                kAXSelectedTextRangeAttribute as CFString,
                caretValue
            )
        }
        return .accessibilityValue
    }

    private func stringValue(of element: AXUIElement) -> String? {
        stringAttribute(kAXValueAttribute as CFString, of: element)
    }

    private func stringAttribute(_ attribute: CFString, of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute,
            &value
        ) == .success else { return nil }
        return value as? String
    }

    private func selectedTextRange(of element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &value
        ) == .success,
              let value,
              CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(unsafeDowncast(value, to: AXValue.self), .cfRange, &range) else {
            return nil
        }
        return range
    }

    private func paste(_ text: String, into target: FocusedTextTarget) async throws {
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        let valueBeforePaste = stringValue(of: target.element)

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
        keyDown.postToPid(target.processIdentifier)
        keyUp.postToPid(target.processIdentifier)

        try await Task.sleep(for: .milliseconds(350))
        if let valueBeforePaste,
           let valueAfterPaste = stringValue(of: target.element),
           valueAfterPaste == valueBeforePaste {
            snapshot.restore(to: pasteboard)
            throw insertionFailure(
                "The destination did not accept the transcript.",
                recovery: "Click directly inside the text field and try again."
            )
        }
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
