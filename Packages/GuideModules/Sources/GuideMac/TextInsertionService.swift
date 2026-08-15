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
    fileprivate let element: AXUIElement?

    fileprivate init(processIdentifier: pid_t, element: AXUIElement?) {
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

        let element: AXUIElement?
        if result == .success,
           let value,
           CFGetTypeID(value) == AXUIElementGetTypeID() {
            element = unsafeDowncast(value, to: AXUIElement.self)
        } else {
            element = nil
        }

        if let element {
            let focusedRole = stringAttribute(kAXRoleAttribute as CFString, of: element) ?? "unknown"
            insertionLogger.notice("Focused AX role=\(focusedRole, privacy: .public)")
        } else {
            insertionLogger.notice("Focused AX element unavailable; paste-only target captured")
        }

        guard frontmostPID > 0 else {
            throw insertionFailure(
                "The focused application could not be identified.",
                recovery: "Click in the destination field and try again."
            )
        }
        return FocusedTextTarget(processIdentifier: frontmostPID, element: element)
    }

    public func insert(_ text: String, into target: FocusedTextTarget) async throws -> TextInsertionMethod {
        guard !text.isEmpty else {
            throw insertionFailure("The transcript was empty.", recovery: "Try dictating again.")
        }

        do {
            try await paste(text, into: target)
            return .paste
        } catch {
            insertionLogger.notice("Session paste did not verify; trying Accessibility fallbacks")
        }

        guard let element = target.element, isEditableTextTarget(element) else {
            throw insertionFailure(
                "The destination did not accept the transcript.",
                recovery: "Your transcript is preserved in Guide Companion. Focus a text field and use Retry or Copy."
            )
        }

        if let selectedTextMethod = await replaceSelectedText(text, on: element) {
            return selectedTextMethod
        }
        if let replacementMethod = try await replaceAccessibilityValue(text, on: element) {
            return replacementMethod
        }

        throw insertionFailure(
            "The destination did not accept the transcript.",
            recovery: "Your transcript is preserved in Guide Companion. Focus a text field and use Retry or Copy."
        )
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

    private func replaceSelectedText(
        _ text: String,
        on element: AXUIElement
    ) async -> TextInsertionMethod? {
        let valueBefore = stringValue(of: element)
        let result = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFString
        )
        insertionLogger.notice("AX selected-text write result=\(result.rawValue)")
        guard result == .success else { return nil }
        try? await Task.sleep(for: .milliseconds(120))
        guard let valueBefore,
              let valueAfter = stringValue(of: element),
              valueAfter != valueBefore else {
            insertionLogger.notice("AX selected-text write returned success without an observable change")
            return nil
        }
        return .accessibility
    }

    private func replaceAccessibilityValue(
        _ text: String,
        on element: AXUIElement
    ) async throws -> TextInsertionMethod? {
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
        try? await Task.sleep(for: .milliseconds(120))
        guard stringValue(of: element) == replacement.value else {
            insertionLogger.notice("AX value replacement returned success without an observable change")
            return nil
        }

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
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier else {
            throw insertionFailure(
                "The destination app changed before insertion.",
                recovery: "Your transcript is preserved. Focus the intended field and use Retry."
            )
        }
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        let valueBeforePaste = target.element.flatMap(stringValue)

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
        keyDown.post(tap: .cghidEventTap)
        try await Task.sleep(for: .milliseconds(30))
        keyUp.post(tap: .cghidEventTap)

        try await Task.sleep(for: .milliseconds(550))
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier else {
            if pasteboard.changeCount == injectedChangeCount {
                snapshot.restore(to: pasteboard)
            }
            throw insertionFailure(
                "The destination app changed during insertion.",
                recovery: "Your transcript is preserved. Focus the intended field and use Retry."
            )
        }
        if let valueBeforePaste,
           let element = target.element,
           let valueAfterPaste = stringValue(of: element),
           valueAfterPaste == valueBeforePaste {
            snapshot.restore(to: pasteboard)
            throw insertionFailure(
                "The destination did not accept the transcript.",
                recovery: "Your transcript is preserved in Guide Companion. Focus a text field and use Retry or Copy."
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
