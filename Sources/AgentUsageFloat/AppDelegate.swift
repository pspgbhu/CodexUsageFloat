import AppKit
import AgentUsageCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItemPanelGap: CGFloat = 2
    private let statusItemMenuGap: CGFloat = 8
    private let floatingWindowMargin: CGFloat = 16
    private let floatingWindowHorizontalPadding: CGFloat = 12
    private let floatingWindowVerticalPadding: CGFloat = 6

    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var floatingPanel: NSPanel?
    private var floatingTextField: NSTextField?
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
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
            self?.updateMetricDisplays(snapshot)
        }

        configureStatusItem()
        configurePanel()
        configureFloatingPanel()
        updateMetricDisplays(nil)
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
        guard !settings.floatingWindowEnabled else {
            return ""
        }

        return metricsTitle(for: snapshot)
    }

    private func metricsTitle(for snapshot: UsageSnapshot?) -> String {
        settings.selectedStatusBarMetrics
            .map { $0.menuBarComponent(from: snapshot) }
            .joined(separator: "  ")
    }

    private func statusBarToolTip(for snapshot: UsageSnapshot?) -> String {
        let strings = AppStrings(language: settings.language)
        let providerName = snapshot?.provider.displayName ?? viewModel.providerDescriptor.displayName
        let metricSummary = settings.selectedStatusBarMetrics
            .map { $0.tooltipComponent(from: snapshot, language: settings.language) }
            .joined(separator: strings.tooltipItemSeparator)
        guard !metricSummary.isEmpty else {
            return providerName
        }
        return "\(providerName)\(strings.tooltipSeparator)\(metricSummary)"
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
            onSetFloatingWindow: { [weak self] enabled in
                self?.setFloatingWindow(enabled)
            },
            onSetStatusBarMetric: { [weak self] metric, enabled in
                self?.setStatusBarMetric(metric, enabled: enabled)
            }
        )

        let panel = UsagePanel(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 524),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.isOpaque = false
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.moveToActiveSpace, .transient, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentView = NSHostingView(rootView: content)

        self.panel = panel
    }

    private func configureFloatingPanel() {
        let textField = NSTextField(labelWithString: metricsTitle(for: nil))
        textField.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        textField.textColor = .labelColor
        textField.alignment = .center
        textField.lineBreakMode = .byTruncatingTail
        textField.maximumNumberOfLines = 1
        textField.cell?.usesSingleLineMode = true

        let backgroundView = FloatingMetricsContentView(frame: NSRect(x: 0, y: 0, width: 80, height: 30))
        backgroundView.material = .popover
        backgroundView.blendingMode = .behindWindow
        backgroundView.state = .active
        backgroundView.wantsLayer = true
        backgroundView.layer?.cornerRadius = 8
        backgroundView.layer?.cornerCurve = .continuous
        backgroundView.layer?.masksToBounds = true
        backgroundView.onDragEnded = { [weak self] origin in
            self?.saveFloatingWindowOrigin(origin)
        }
        backgroundView.addSubview(textField)

        let panel = FloatingMetricsPanel(
            contentRect: backgroundView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false
        panel.isOpaque = false
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = false
        panel.contentView = backgroundView

        self.floatingTextField = textField
        self.floatingPanel = panel
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            popStatusMenu()
            return
        }

        togglePanel()
    }

    private func popStatusMenu() {
        hideAllPanels()

        let strings = AppStrings(language: settings.language)
        let menu = NSMenu()
        let openItem = NSMenuItem(title: strings.openPanel, action: #selector(openPanelFromMenu), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(NSMenuItem.separator())

        let languageItem = NSMenuItem(title: strings.languageMenuTitle, action: nil, keyEquivalent: "")
        let languageMenu = NSMenu()
        for language in AppLanguage.allCases {
            let item = NSMenuItem(
                title: strings.displayName(for: language),
                action: #selector(languageSelectedFromMenu(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = language.rawValue
            item.state = settings.language == language ? .on : .off
            languageMenu.addItem(item)
        }
        menu.setSubmenu(languageMenu, for: languageItem)
        menu.addItem(languageItem)
        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: strings.quit, action: #selector(quitFromMenu), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        menu.update()
        menu.popUp(positioning: nil, at: statusMenuOrigin(for: menu), in: nil)
    }

    @objc private func openPanelFromMenu() {
        showPanel()
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    @objc private func languageSelectedFromMenu(_ sender: NSMenuItem) {
        guard
            let rawValue = sender.representedObject as? String,
            let language = AppLanguage(rawValue: rawValue),
            language != settings.language
        else {
            return
        }

        settings.language = language
        updateMetricDisplays(viewModel.snapshot)
    }

    private func togglePanel() {
        guard let panel else {
            return
        }

        if panel.isVisible {
            hideAllPanels()
            return
        }

        showPanel()
    }

    private func showPanel() {
        guard let panel else {
            return
        }

        positionPanelBelowStatusItem(panel)
        panel.orderFrontRegardless()
        installOutsideClickMonitors()
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
        updateMetricDisplays(viewModel.snapshot)
    }

    private func setFloatingWindow(_ enabled: Bool) {
        guard enabled != settings.floatingWindowEnabled else {
            return
        }

        settings.floatingWindowEnabled = enabled
        updateMetricDisplays(viewModel.snapshot)
    }

    private func updateMetricDisplays(_ snapshot: UsageSnapshot?) {
        updateStatusItemTitle(snapshot)
        updateFloatingWindow(snapshot)
    }

    private func updateFloatingWindow(_ snapshot: UsageSnapshot?) {
        guard let floatingPanel, let floatingTextField else {
            return
        }

        let title = metricsTitle(for: snapshot)
        floatingTextField.stringValue = title

        guard settings.floatingWindowEnabled, !title.isEmpty else {
            floatingPanel.orderOut(nil)
            return
        }

        let preferredOrigin = settings.floatingWindowOrigin.map { NSPoint(x: CGFloat($0.x), y: CGFloat($0.y)) }
        guard let screen = floatingWindowScreen(for: preferredOrigin, panelSize: floatingPanel.frame.size) else {
            return
        }

        let maxTextWidth = max(
            44,
            screen.visibleFrame.width - floatingWindowMargin * 2 - floatingWindowHorizontalPadding * 2
        )
        let textSize = floatingTextField.intrinsicContentSize
        let textWidth = min(max(ceil(textSize.width), 44), maxTextWidth)
        let textHeight = ceil(textSize.height)
        let panelSize = NSSize(
            width: textWidth + floatingWindowHorizontalPadding * 2,
            height: textHeight + floatingWindowVerticalPadding * 2
        )

        floatingPanel.setContentSize(panelSize)
        floatingPanel.contentView?.frame = NSRect(origin: .zero, size: panelSize)
        floatingTextField.frame = NSRect(
            x: floatingWindowHorizontalPadding,
            y: floor((panelSize.height - textHeight) / 2),
            width: textWidth,
            height: textHeight
        )
        positionFloatingWindow(floatingPanel, on: screen, preferredOrigin: preferredOrigin)
        floatingPanel.orderFrontRegardless()
    }

    private func hideAllPanels() {
        panel?.orderOut(nil)
        removeOutsideClickMonitors()
    }

    private func statusMenuOrigin(for menu: NSMenu) -> NSPoint {
        guard
            let button = statusItem?.button,
            let window = button.window,
            let screen = window.screen ?? NSScreen.main
        else {
            return NSEvent.mouseLocation
        }

        let buttonFrame = button.convert(button.bounds, to: nil)
        let screenFrame = window.convertToScreen(buttonFrame)
        let menuSize = menu.size
        let x = min(max(screenFrame.midX - menuSize.width / 2, screen.visibleFrame.minX + 12), screen.visibleFrame.maxX - menuSize.width - 12)
        let y = screenFrame.minY - statusItemMenuGap
        return NSPoint(x: x, y: y)
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
        let y = screenFrame.minY - panelSize.height - statusItemPanelGap
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func floatingWindowScreen(for origin: NSPoint? = nil, panelSize: NSSize? = nil) -> NSScreen? {
        if let origin, let panelSize {
            let proposedFrame = NSRect(origin: origin, size: panelSize)
            if let screen = screen(containing: proposedFrame) {
                return screen
            }
        }

        return statusItem?.button?.window?.screen ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func positionFloatingWindow(_ panel: NSPanel, on screen: NSScreen, preferredOrigin: NSPoint?) {
        if let preferredOrigin {
            panel.setFrameOrigin(clampedFloatingWindowOrigin(preferredOrigin, size: panel.frame.size, on: screen))
            return
        }

        let frame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = frame.maxX - panelSize.width - floatingWindowMargin
        let y = frame.maxY - panelSize.height - floatingWindowMargin
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func saveFloatingWindowOrigin(_ origin: NSPoint) {
        guard let floatingPanel else {
            return
        }

        let screen = screen(containing: floatingPanel.frame) ?? floatingWindowScreen(panelSize: floatingPanel.frame.size)
        guard let screen else {
            settings.setFloatingWindowOrigin(x: Double(origin.x), y: Double(origin.y))
            return
        }

        let clampedOrigin = clampedFloatingWindowOrigin(origin, size: floatingPanel.frame.size, on: screen)
        if clampedOrigin != origin {
            floatingPanel.setFrameOrigin(clampedOrigin)
        }
        settings.setFloatingWindowOrigin(x: Double(clampedOrigin.x), y: Double(clampedOrigin.y))
    }

    private func screen(containing rect: NSRect) -> NSScreen? {
        NSScreen.screens.first { $0.visibleFrame.intersects(rect) }
            ?? NSScreen.screens.first { $0.frame.intersects(rect) }
    }

    private func clampedFloatingWindowOrigin(_ origin: NSPoint, size: NSSize, on screen: NSScreen) -> NSPoint {
        let frame = screen.visibleFrame
        return NSPoint(
            x: clamped(origin.x, lowerBound: frame.minX, upperBound: frame.maxX - size.width),
            y: clamped(origin.y, lowerBound: frame.minY, upperBound: frame.maxY - size.height)
        )
    }

    private func clamped(_ value: CGFloat, lowerBound: CGFloat, upperBound: CGFloat) -> CGFloat {
        guard lowerBound <= upperBound else {
            return lowerBound
        }

        return min(max(value, lowerBound), upperBound)
    }

    private func installOutsideClickMonitors() {
        removeOutsideClickMonitors()

        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else {
                return event
            }

            if self.isEventInsidePanel(event) || self.isEventInsideStatusItem(event) {
                return event
            }

            self.hideAllPanels()
            return event
        }

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.hideAllPanels()
            }
        }
    }

    private func removeOutsideClickMonitors() {
        if let localEventMonitor {
            NSEvent.removeMonitor(localEventMonitor)
            self.localEventMonitor = nil
        }

        if let globalEventMonitor {
            NSEvent.removeMonitor(globalEventMonitor)
            self.globalEventMonitor = nil
        }
    }

    private func isEventInsidePanel(_ event: NSEvent) -> Bool {
        event.window === panel
    }

    private func isEventInsideStatusItem(_ event: NSEvent) -> Bool {
        guard
            let button = statusItem?.button,
            let buttonWindow = button.window,
            event.window === buttonWindow
        else {
            return false
        }

        let locationInButton = button.convert(event.locationInWindow, from: nil)
        return button.bounds.contains(locationInButton)
    }

    func applicationWillTerminate(_ notification: Notification) {
        removeOutsideClickMonitors()
    }
}

private final class UsagePanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}

private final class FloatingMetricsPanel: NSPanel {
    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}

private final class FloatingMetricsContentView: NSVisualEffectView {
    var onDragEnded: ((NSPoint) -> Void)?

    private var dragOffset: NSPoint?

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        dragOffset = event.locationInWindow
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window, let dragOffset else {
            return
        }

        let mouseLocation = NSEvent.mouseLocation
        window.setFrameOrigin(NSPoint(
            x: mouseLocation.x - dragOffset.x,
            y: mouseLocation.y - dragOffset.y
        ))
    }

    override func mouseUp(with event: NSEvent) {
        defer {
            dragOffset = nil
        }

        guard let window else {
            return
        }

        onDragEnded?(window.frame.origin)
    }
}
