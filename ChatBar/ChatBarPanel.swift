//
//  ChatBar.swift
//  GeminiDesktop
//
//  Created by alexcding on 2025-12-13.
//

import SwiftUI
import AppKit

class ChatBarPanel: NSPanel, NSWindowDelegate {

    private var positionSaveWork: DispatchWorkItem?
    private var clickOutsideMonitor: Any?

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Constants.defaultSize.width, height: Constants.defaultSize.height),
            styleMask: [
                .nonactivatingPanel,
                .borderless
            ],
            backing: .buffered,
            defer: false
        )

        self.contentView = contentView
        self.delegate = self

        configureWindow()
        configureAppearance()
    }

    private func configureWindow() {
        isFloatingPanel = true
        level = .floating
        isMovable = true
        isMovableByWindowBackground = false

        collectionBehavior.insert(.fullScreenAuxiliary)
        collectionBehavior.insert(.canJoinAllSpaces)

        minSize = Constants.defaultSize
        maxSize = Constants.defaultSize

        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            guard let self, self.isVisible else { return }
            self.orderOut(nil)
        }
    }

    private func configureAppearance() {
        hasShadow = true
        backgroundColor = .clear
        isOpaque = false

        if let contentView = contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = Constants.cornerRadius
            contentView.layer?.masksToBounds = true
            contentView.layer?.borderWidth = Constants.borderWidth
            contentView.layer?.borderColor = NSColor.separatorColor.cgColor
        }
    }

    deinit {
        positionSaveWork?.cancel()
        if let monitor = clickOutsideMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        positionSaveWork?.cancel()
        let origin = frame.origin
        let work = DispatchWorkItem {
            UserDefaults.standard.set(origin.x, forKey: UserDefaultsKeys.panelX.rawValue)
            UserDefaults.standard.set(origin.y, forKey: UserDefaultsKeys.panelY.rawValue)
        }
        positionSaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.positionSaveDebounce, execute: work)
    }

    // MARK: - Event Handling

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown, event.modifierFlags.contains(.command) {
            NSCursor.closedHand.set()
            performDrag(with: event)
            NSCursor.arrow.set()
            return
        }
        super.sendEvent(event)
    }

    override func cancelOperation(_ sender: Any?) {
        orderOut(nil)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}


extension ChatBarPanel {

    struct Constants {
        static let defaultSize = NSSize(width: 560, height: 60)
        static let cornerRadius: CGFloat = 30
        static let borderWidth: CGFloat = 0.5
        static let positionSaveDebounce: TimeInterval = 0.3
    }
}
