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
        if terminateIfAnotherInstanceIsRunning() {
            return
        }

        NSApp.setActivationPolicy(.accessory)

        settings = AppSettings()
        let provider = CodexUsageProvider(executablePath: settings.defaultProviderExecutablePath)
        viewModel = UsageViewModel(provider: provider, settings: settings)
        viewModel.onSnapshotChanged = { [weak self] snapshot in
            self?.updateStatusItemTitle(snapshot)
        }

        configureStatusItem()
        configurePanel()
        viewModel.start()

        if settings.launchAtLoginEnabled && !LaunchAgentManager.isInstalled() {
            try? LaunchAgentManager.setEnabled(true)
        }
    }

    private func terminateIfAnotherInstanceIsRunning() -> Bool {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return false
        }

        let currentProcessIdentifier = ProcessInfo.processInfo.processIdentifier
        let hasExistingInstance = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleIdentifier)
            .contains { $0.processIdentifier != currentProcessIdentifier }

        if hasExistingInstance {
            NSApp.terminate(nil)
        }

        return hasExistingInstance
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem

        if let button = statusItem.button {
            button.image = makeStatusItemImage()
            button.imagePosition = .imageLeading
            button.imageScaling = .scaleNone
            button.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
            button.title = statusBarTitle(for: nil)
            button.toolTip = statusBarToolTip(for: nil)
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    private func makeStatusItemImage() -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        guard let image = NSImage(systemSymbolName: "gauge", accessibilityDescription: "Agent Usage")?
            .withSymbolConfiguration(configuration)
        else {
            return nil
        }

        image.isTemplate = true
        image.size = NSSize(width: 16, height: 16)
        image.alignmentRect = NSRect(x: 0, y: -0.5, width: 16, height: 16)
        return image
    }

    private func updateStatusItemTitle(_ snapshot: UsageSnapshot?) {
        guard let button = statusItem?.button else {
            return
        }

        button.title = statusBarTitle(for: snapshot)
        button.toolTip = statusBarToolTip(for: snapshot)
    }

    private func statusBarTitle(for snapshot: UsageSnapshot?) -> String {
        settings.selectedStatusBarMetrics
            .map { $0.menuBarComponent(from: snapshot) }
            .joined(separator: "  ")
    }

    private func statusBarToolTip(for snapshot: UsageSnapshot?) -> String {
        let providerName = snapshot?.provider.displayName ?? viewModel.providerDescriptor.displayName
        let metricSummary = settings.selectedStatusBarMetrics
            .map { $0.tooltipComponent(from: snapshot) }
            .joined(separator: "，")
        guard !metricSummary.isEmpty else {
            return providerName
        }
        return "\(providerName)：\(metricSummary)"
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
            onSetLaunchAtLogin: { [weak self] enabled in
                self?.setLaunchAtLogin(enabled)
            },
            onSetStatusBarMetric: { [weak self] metric, enabled in
                self?.setStatusBarMetric(metric, enabled: enabled)
            },
            onQuit: {
                NSApp.terminate(nil)
            }
        )

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 460),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.delegate = self
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = true
        panel.isMovableByWindowBackground = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = NSHostingView(rootView: content)
        positionPanelBelowStatusItem(panel)

        self.panel = panel
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            popStatusMenu()
            return
        }

        togglePanel()
    }

    private func popStatusMenu() {
        guard let button = statusItem?.button else {
            return
        }

        let menu = NSMenu()
        let openItem = NSMenuItem(title: "打开面板", action: #selector(openPanelFromMenu), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitFromMenu), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY - 2), in: button)
    }

    @objc private func openPanelFromMenu() {
        showPanel()
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    private func togglePanel() {
        guard let panel else {
            return
        }

        if panel.isVisible {
            panel.orderOut(nil)
            return
        }

        showPanel()
    }

    private func showPanel() {
        guard let panel else {
            return
        }

        positionPanelBelowStatusItem(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @discardableResult
    private func setLaunchAtLogin(_ enabled: Bool) -> Bool {
        guard enabled != settings.launchAtLoginEnabled else {
            return true
        }

        do {
            try LaunchAgentManager.setEnabled(enabled)
            settings.launchAtLoginEnabled = enabled
            return true
        } catch {
            NSSound.beep()
            return false
        }
    }

    private func setStatusBarMetric(_ metric: StatusBarMetric, enabled: Bool) {
        settings.setStatusBarMetric(metric, enabled: enabled)
        updateStatusItemTitle(viewModel.snapshot)
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

    func windowDidResignKey(_ notification: Notification) {
        panel?.orderOut(nil)
    }
}
