import AppKit
import AgentUsageCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var settings: AppSettings!
    private var viewModel: UsageViewModel!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        settings = AppSettings()
        let provider = CodexUsageProvider(executablePath: settings.defaultProviderExecutablePath)
        viewModel = UsageViewModel(provider: provider, settings: settings)
        viewModel.onSnapshotChanged = { [weak self] snapshot in
            self?.updateStatusItemTitle(snapshot)
        }

        configureStatusItem()
        configurePanel()
        applyPinState()
        viewModel.start()

        if settings.launchAtLoginEnabled && !LaunchAgentManager.isInstalled() {
            try? LaunchAgentManager.setEnabled(true)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let frame = panel?.frame {
            settings.savePanelFrame(frame)
        }
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "gauge", accessibilityDescription: "Agent Usage")
            button.imagePosition = .imageLeading
            button.title = "P --"
            button.toolTip = "\(viewModel.providerDescriptor.displayName) primary remaining unavailable"
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func updateStatusItemTitle(_ snapshot: UsageSnapshot?) {
        guard let button = statusItem?.button else {
            return
        }

        if let remainingPercent = snapshot?.limits?.primary?.remainingPercent {
            button.title = "P \(remainingPercent)%"
            let providerName = snapshot?.provider.displayName ?? viewModel.providerDescriptor.displayName
            button.toolTip = "\(providerName) primary remaining: \(remainingPercent)%"
        } else {
            button.title = "P --"
            let providerName = snapshot?.provider.displayName ?? viewModel.providerDescriptor.displayName
            button.toolTip = "\(providerName) primary remaining unavailable"
        }
    }

    private func configurePanel() {
        let content = UsagePanelView(
            viewModel: viewModel,
            settings: settings,
            onRefresh: { [weak self] in
                Task { @MainActor in
                    await self?.viewModel.refresh()
                }
            },
            onTogglePin: { [weak self] in
                self?.togglePin()
            },
            onToggleLaunchAtLogin: { [weak self] in
                self?.toggleLaunchAtLogin()
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 440),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.contentView = NSHostingView(rootView: content)

        if let savedFrame = settings.savedPanelFrame() {
            panel.setFrame(savedFrame, display: false)
        } else {
            positionPanelBelowStatusItem(panel)
        }

        self.panel = panel

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(panelMoved(_:)),
            name: NSWindow.didMoveNotification,
            object: panel
        )
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            togglePanel()
            return
        }

        if event.type == .rightMouseUp {
            popStatusMenu()
        } else {
            togglePanel()
        }
    }

    private func togglePanel() {
        guard let panel else {
            return
        }

        if panel.isVisible {
            panel.orderOut(nil)
            return
        }

        if settings.savedPanelFrame() == nil {
            positionPanelBelowStatusItem(panel)
        }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func popStatusMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Refresh", action: #selector(refreshFromMenu), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: settings.isPinned ? "Unpin" : "Pin", action: #selector(togglePinFromMenu), keyEquivalent: "p"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: settings.launchAtLoginEnabled ? "Disable Login Launch" : "Enable Login Launch", action: #selector(toggleLaunchFromMenu), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitFromMenu), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    @objc private func refreshFromMenu() {
        Task {
            await viewModel.refresh()
        }
    }

    @objc private func togglePinFromMenu() {
        togglePin()
    }

    @objc private func toggleLaunchFromMenu() {
        toggleLaunchAtLogin()
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    private func togglePin() {
        settings.isPinned.toggle()
        applyPinState()
    }

    private func applyPinState() {
        panel?.level = settings.isPinned ? .floating : .normal
        panel?.collectionBehavior = settings.isPinned ? [.canJoinAllSpaces, .fullScreenAuxiliary] : []
    }

    private func toggleLaunchAtLogin() {
        let nextValue = !settings.launchAtLoginEnabled
        do {
            try LaunchAgentManager.setEnabled(nextValue)
            settings.launchAtLoginEnabled = nextValue
        } catch {
            NSSound.beep()
        }
    }

    private func positionPanelBelowStatusItem(_ panel: NSPanel) {
        guard
            let button = statusItem?.button,
            let window = button.window,
            let screen = window.screen ?? NSScreen.main
        else {
            panel.center()
            return
        }

        let buttonFrame = button.convert(button.bounds, to: nil)
        let screenFrame = window.convertToScreen(buttonFrame)
        let panelSize = panel.frame.size
        let x = min(max(screenFrame.midX - panelSize.width / 2, screen.visibleFrame.minX + 12), screen.visibleFrame.maxX - panelSize.width - 12)
        let y = screenFrame.minY - panelSize.height - 8
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    @objc private func panelMoved(_ notification: Notification) {
        if let panel = notification.object as? NSPanel {
            settings.savePanelFrame(panel.frame)
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        if !settings.isPinned {
            panel?.orderOut(nil)
        }
    }
}
