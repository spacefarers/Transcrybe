//
//  AccessibilityManager.swift
//  Transcrybe
//
//  Inserts text by synthesizing Unicode key events (Strategy 2 only).
//

import Cocoa
import os
import Combine
import ApplicationServices

final class AccessibilityManager: NSObject, ObservableObject {
    private let logger = Logger(subsystem: "com.transcryb.accessibility", category: "manager")

    // Public API
    func insertTextAtCursor(_ text: String) {
        // Small delay so focus can settle after UI actions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) { [weak self] in
            guard let self = self else { return }

            // Check if a text input field is actually focused
            guard self.isTextInputFieldFocused() else {
                self.logger.info("No text input field focused, skipping insertion")
                return
            }

            self.requestAXTrustIfNeeded()

            if self.typeUnicode(text) {
                self.logger.info("Inserted via Unicode typing")
            } else {
                self.logger.error("Unicode typing failed")
            }
        }
    }

    /// Check if a text input field is currently focused
    private func isTextInputFieldFocused() -> Bool {
        guard let systemWideAE = AXUIElementCreateSystemWide() as AXUIElement? else {
            return false
        }

        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemWideAE,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard result == .success else {
            return false
        }

        let element = focusedElement as! AXUIElement

        // Check if the focused element is editable
        var isEditable: AnyObject?
        let editResult = AXUIElementCopyAttributeValue(
            element,
            kAXEditableAncestorAttribute as CFString,
            &isEditable
        )

        // If element has an editable ancestor, it's likely editable
        if editResult == .success && isEditable != nil {
            return true
        }

        // Also check the role of the focused element
        var role: AnyObject?
        let roleResult = AXUIElementCopyAttributeValue(
            element,
            kAXRoleAttribute as CFString,
            &role
        )

        if roleResult == .success, let roleString = role as? NSString {
            let editableRoles: [String] = [
                kAXTextFieldRole as String,
                kAXTextAreaRole as String,
                kAXComboBoxRole as String
            ]

            for editableRole in editableRoles {
                if roleString.isEqual(to: editableRole) {
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Unicode typing

    /// Types the full string by sending Unicode payload key events.
    /// Splits into UTF-16 chunks to avoid IOHID payload and IME edge cases.
    private func typeUnicode(_ text: String) -> Bool {
        guard let src = CGEventSource(stateID: .combinedSessionState) else { return false }

        // Use a conservative chunk size. 120–200 UTF-16 units is typically safe.
        // This avoids very large event payloads that some apps ignore.
        let utf16 = Array(text.utf16)
        let chunkSize = 160
        var ok = true

        var i = 0
        while i < utf16.count {
            let end = min(i + chunkSize, utf16.count)
            let slice = utf16[i..<end]
            // Ensure we do not split surrogate pairs
            let safeEnd = adjustForSurrogateSplit(utf16: utf16, start: i, proposedEnd: end)
            let finalSlice = utf16[i..<safeEnd]

            if !sendUnicodeChunk(src: src, utf16Chunk: Array(finalSlice)) {
                ok = false
                break
            }
            i = safeEnd
            // Tiny pause can improve reliability in some apps
            usleep(1_000)
        }

        return ok
    }

    /// Prevent splitting a surrogate pair at the boundary.
    private func adjustForSurrogateSplit(utf16: [UInt16], start: Int, proposedEnd: Int) -> Int {
        guard proposedEnd < utf16.count else { return proposedEnd }
        let last = utf16[proposedEnd - 1]
        let next = utf16[proposedEnd]
        // High surrogate range D800–DBFF, low surrogate DC00–DFFF
        let isHighSurrogate = 0xD800...0xDBFF ~= last
        let isLowSurrogate = 0xDC00...0xDFFF ~= next
        if isHighSurrogate && isLowSurrogate {
            return proposedEnd + 1
        }
        return proposedEnd
    }

    /// Sends a single keyDown+keyUp pair carrying the Unicode payload.
    private func sendUnicodeChunk(src: CGEventSource, utf16Chunk: [UInt16]) -> Bool {
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true),
              let up   = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false) else {
            return false
        }

        // Attach Unicode payload
        var chunkCopy = utf16Chunk
        down.keyboardSetUnicodeString(stringLength: chunkCopy.count, unicodeString: &chunkCopy)
        up.keyboardSetUnicodeString(stringLength: 0, unicodeString: nil)

        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }

    // MARK: - Permissions

    /// CGEvent posting requires Accessibility permission.
    private func requestAXTrustIfNeeded() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }
}
