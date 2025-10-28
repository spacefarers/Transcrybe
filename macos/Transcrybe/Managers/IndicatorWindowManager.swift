//
//  IndicatorWindowManager.swift
//  Transcrybe
//
//  Created by Michael Yang on 10/27/25.
//

import SwiftUI
import AppKit
import Combine

class IndicatorWindowManager: ObservableObject {
    @Published private(set) var isWindowVisible = false

    func updateWindowVisibility(_ shouldBeVisible: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if shouldBeVisible {
                self.showWindowIfAvailable()
            } else {
                self.hideWindowIfNeeded()
            }
        }
    }

    private func showWindowIfAvailable() {
        guard let window = indicatorWindow else { return }

        configure(window)
        resizeToFitContent(window)
        position(window)

        window.alphaValue = 1.0
        window.orderFront(nil)
        isWindowVisible = true
    }

    private func hideWindowIfNeeded() {
        guard let window = indicatorWindow else { return }

        window.orderOut(nil)
        isWindowVisible = false
    }

    private var indicatorWindow: NSWindow? {
        NSApplication.shared.windows.first(where: { $0.title == "Recording Indicator" })
    }

    private func configure(_ window: NSWindow) {
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovable = false
        window.isMovableByWindowBackground = false
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isExcludedFromWindowsMenu = true
        window.level = .statusBar
        window.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle
        ]
        window.styleMask.remove(.resizable)
        window.styleMask.remove(.miniaturizable)
        window.styleMask.remove(.closable)
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.invalidateShadow()
    }

    private func resizeToFitContent(_ window: NSWindow) {
        guard let contentView = window.contentView else { return }

        contentView.layoutSubtreeIfNeeded()
        let fittingSize = contentView.fittingSize

        guard fittingSize.width > 0, fittingSize.height > 0 else { return }

        window.setContentSize(fittingSize)
        window.contentMinSize = fittingSize
        window.contentMaxSize = fittingSize
    }

    private func position(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main else { return }

        let windowFrame = window.frame
        let xOrigin = screen.visibleFrame.midX - (windowFrame.width / 2)
        let yOffset: CGFloat = 52 // distance from bottom of the screen
        let yOrigin = screen.visibleFrame.minY + yOffset

        window.setFrameOrigin(NSPoint(x: xOrigin, y: yOrigin))
    }
}
