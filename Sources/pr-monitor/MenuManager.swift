import AppKit

final class FocusableTextField: NSTextField {
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
}

enum MenuTab: Int {
    case forYou = 0
    case team = 1
    case others = 2
    case byYou = 3
}

// MARK: - Tab Bar View (custom NSView so clicking doesn't close the menu)

class TabBarView: NSView {
    var onTabSelected: ((MenuTab) -> Void)?
    private var buttons: [NSButton] = []
    private var currentTab: MenuTab = .forYou
    private var counts: (forYou: Int, team: Int, others: Int, byYou: Int) = (0, 0, 0, 0)
    private var unseen: (forYou: Bool, team: Bool, others: Bool, byYou: Bool) = (false, false, false, false)

    override var intrinsicContentSize: NSSize {
        NSSize(width: 720, height: 28)
    }

    func update(tab: MenuTab, counts: (forYou: Int, team: Int, others: Int, byYou: Int),
                unseen: (forYou: Bool, team: Bool, others: Bool, byYou: Bool)) {
        currentTab = tab
        self.counts = counts
        self.unseen = unseen
        rebuildButtons()
    }

    private func rebuildButtons() {
        subviews.forEach { $0.removeFromSuperview() }
        buttons.removeAll()

        let dot = " ●"
        let titles = [
            "You (\(counts.forYou))\(unseen.forYou ? dot : "")",
            "Team (\(counts.team))\(unseen.team ? dot : "")",
            "Other (\(counts.others))\(unseen.others ? dot : "")",
            "By You (\(counts.byYou))\(unseen.byYou ? dot : "")",
        ]

        let tabs: [MenuTab] = [.forYou, .team, .others, .byYou]
        let spacing: CGFloat = 2
        var x: CGFloat = 4

        for (i, title) in titles.enumerated() {
            let font = NSFont.systemFont(ofSize: 10, weight: tabs[i] == currentTab ? .semibold : .regular)
            let textWidth = (title as NSString).size(withAttributes: [.font: font]).width
            let buttonWidth = textWidth + 16

            let btn = NSButton(frame: NSRect(x: x, y: 2, width: buttonWidth, height: 24))
            btn.title = title
            btn.bezelStyle = .recessed
            btn.setButtonType(.pushOnPushOff)
            btn.font = font
            btn.state = tabs[i] == currentTab ? .on : .off
            btn.tag = tabs[i].rawValue
            btn.target = self
            btn.action = #selector(tabClicked(_:))
            addSubview(btn)
            buttons.append(btn)

            x += buttonWidth + spacing
        }
    }

    @objc private func tabClicked(_ sender: NSButton) {
        guard let tab = MenuTab(rawValue: sender.tag) else { return }
        onTabSelected?(tab)
    }
}

// MARK: - Settings View (custom NSView so clicking doesn't close the menu)

class SettingsView: NSView {
    var onSave: ((String, String, TimeInterval, NotificationSoundSettings) -> Void)?
    var onBack: (() -> Void)?

    private let orgField = FocusableTextField()
    private let teamField = FocusableTextField()
    private let intervalField = FocusableTextField()
    private let forYouSoundToggle = NSButton()
    private let teamSoundToggle = NSButton()
    private let othersSoundToggle = NSButton()
    private let feedbackLabel = NSTextField(labelWithString: "")

    private let viewWidth: CGFloat = 420
    private let viewHeight: CGFloat = 300

    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: viewWidth, height: viewHeight)
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    func reload() {
        let config = Config.shared
        orgField.stringValue = config.teamOrg
        teamField.stringValue = config.teamSlugsText
        intervalField.stringValue = "\(Int(config.pollingIntervalSeconds))"
        let sounds = config.notificationSoundSettings
        forYouSoundToggle.state = sounds.forYou ? .on : .off
        teamSoundToggle.state = sounds.team ? .on : .off
        othersSoundToggle.state = sounds.others ? .on : .off
        feedbackLabel.stringValue = ""
    }

    private func setupUI() {
        let pad: CGFloat = 12
        let fieldW = viewWidth - 2 * pad
        var y: CGFloat = 8

        // Back button + title
        let backBtn = NSButton(title: "< Back", target: self, action: #selector(backClicked))
        backBtn.bezelStyle = .recessed
        backBtn.font = NSFont.systemFont(ofSize: 11)
        backBtn.frame = NSRect(x: pad, y: y, width: 55, height: 20)
        addSubview(backBtn)

        let title = NSTextField(labelWithString: "Settings")
        title.font = NSFont.boldSystemFont(ofSize: 13)
        title.alignment = .center
        title.frame = NSRect(x: 70, y: y, width: viewWidth - 140, height: 20)
        addSubview(title)
        y += 28

        // Org
        addLabel("Organization:", x: pad, y: y, width: fieldW)
        y += 18
        orgField.placeholderString = "e.g. PicnicSupermarket"
        orgField.font = NSFont.systemFont(ofSize: 12)
        orgField.frame = NSRect(x: pad, y: y, width: fieldW, height: 22)
        addSubview(orgField)
        y += 28

        // Team
        addLabel("Team slugs (comma-separated):", x: pad, y: y, width: fieldW)
        y += 18
        teamField.placeholderString = "e.g. visits, visits-main, ai-chat-platform"
        teamField.font = NSFont.systemFont(ofSize: 12)
        teamField.frame = NSRect(x: pad, y: y, width: fieldW, height: 22)
        addSubview(teamField)
        y += 28

        // Interval
        addLabel("Refresh interval (seconds):", x: pad, y: y, width: fieldW)
        y += 18
        intervalField.font = NSFont.systemFont(ofSize: 12)
        intervalField.frame = NSRect(x: pad, y: y, width: 60, height: 22)
        addSubview(intervalField)
        y += 32

        // Notification sounds
        addLabel("Play system sound for new PRs:", x: pad, y: y, width: fieldW)
        y += 18
        for (toggle, title) in [
            (forYouSoundToggle, "Assigned directly to you"),
            (teamSoundToggle, "Assigned to your teams"),
            (othersSoundToggle, "Other review activity"),
        ] {
            toggle.title = title
            toggle.setButtonType(.switch)
            toggle.font = NSFont.systemFont(ofSize: 12)
            toggle.frame = NSRect(x: pad, y: y, width: fieldW, height: 22)
            addSubview(toggle)
            y += 24
        }
        y += 2

        // Save button + feedback
        let saveBtn = NSButton(title: "Save", target: self, action: #selector(saveClicked))
        saveBtn.bezelStyle = .rounded
        saveBtn.frame = NSRect(x: viewWidth - pad - 60, y: y, width: 60, height: 24)
        addSubview(saveBtn)

        feedbackLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        feedbackLabel.textColor = .systemGreen
        feedbackLabel.alignment = .right
        feedbackLabel.frame = NSRect(x: viewWidth - pad - 130, y: y + 3, width: 60, height: 18)
        addSubview(feedbackLabel)
    }

    private func addLabel(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat) {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.frame = NSRect(x: x, y: y, width: width, height: 16)
        addSubview(label)
    }

    @objc private func saveClicked() {
        let org = orgField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let team = teamField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawInterval = TimeInterval(intervalField.stringValue) ?? 120
        let interval = max(30, rawInterval)
        intervalField.stringValue = "\(Int(interval))"

        feedbackLabel.stringValue = "Saved ✓"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.feedbackLabel.stringValue = ""
        }

        onSave?(
            org,
            team,
            interval,
            NotificationSoundSettings(
                forYou: forYouSoundToggle.state == .on,
                team: teamSoundToggle.state == .on,
                others: othersSoundToggle.state == .on
            )
        )
    }

    @objc private func backClicked() {
        onBack?()
    }
}

// MARK: - PR Menu Item View (custom NSView with mute button)

class PRMenuItemView: NSView {
    var onPRClicked: (() -> Void)?
    var onMarkRead: (() -> Void)?
    var onMuteToggled: (() -> Void)?

    private let readBtn = NSButton()
    private let muteBtn = NSButton()
    private let textField = NSTextField()
    private let unseenDot = NSTextField(labelWithString: "●")
    private var isHovered = false

    override var isFlipped: Bool { true }

    init(attributedText: NSAttributedString, isMuted: Bool, isUnseen: Bool, width: CGFloat) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 42))

        // Text field
        textField.isEditable = false
        textField.isSelectable = false
        textField.isBordered = false
        textField.drawsBackground = false
        textField.maximumNumberOfLines = 2
        textField.cell?.wraps = true
        textField.cell?.truncatesLastVisibleLine = true
        textField.attributedStringValue = attributedText
        textField.frame = NSRect(x: 16, y: 4, width: width - 96, height: 34)
        addSubview(textField)

        // Unseen green dot
        unseenDot.font = NSFont.systemFont(ofSize: 8)
        unseenDot.textColor = .systemGreen
        unseenDot.frame = NSRect(x: width - 76, y: 16, width: 12, height: 12)
        unseenDot.isHidden = !isUnseen
        addSubview(unseenDot)

        // Mark as read button
        if let image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: "Mark as read") {
            readBtn.image = image
        }
        readBtn.toolTip = "Mark as read"
        readBtn.bezelStyle = .recessed
        readBtn.isBordered = false
        readBtn.imageScaling = .scaleProportionallyDown
        readBtn.frame = NSRect(x: width - 58, y: 11, width: 20, height: 20)
        readBtn.target = self
        readBtn.action = #selector(readBtnClicked)
        readBtn.contentTintColor = .secondaryLabelColor
        readBtn.isHidden = !isUnseen
        addSubview(readBtn)

        // Mute button
        let iconName = isMuted ? "bell.slash" : "bell.fill"
        if let img = NSImage(systemSymbolName: iconName, accessibilityDescription: isMuted ? "Unmute" : "Mute") {
            muteBtn.image = img
        }
        muteBtn.bezelStyle = .recessed
        muteBtn.isBordered = false
        muteBtn.imageScaling = .scaleProportionallyDown
        muteBtn.frame = NSRect(x: width - 32, y: 11, width: 20, height: 20)
        muteBtn.target = self
        muteBtn.action = #selector(muteBtnClicked)
        muteBtn.contentTintColor = .secondaryLabelColor
        addSubview(muteBtn)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: frame.width, height: 42)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        readBtn.contentTintColor = .labelColor
        muteBtn.contentTintColor = .labelColor
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        readBtn.contentTintColor = .secondaryLabelColor
        muteBtn.contentTintColor = .secondaryLabelColor
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        if (!readBtn.isHidden && readBtn.frame.contains(loc)) || muteBtn.frame.contains(loc) { return }
        onPRClicked?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if isHovered {
            NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 4, dy: 1), xRadius: 4, yRadius: 4).fill()
        }
    }

    @objc private func muteBtnClicked() {
        onMuteToggled?()
    }

    @objc private func readBtnClicked() {
        onMarkRead?()
    }
}

// MARK: - Collapsible Section Header View

class CollapsibleSectionHeaderView: NSView {
    var onToggle: (() -> Void)?
    private var isExpanded: Bool
    private let label: String
    private let count: Int

    init(label: String, count: Int, isExpanded: Bool, width: CGFloat) {
        self.label = label
        self.count = count
        self.isExpanded = isExpanded
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 24))
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: frame.width, height: 24)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let chevron = isExpanded ? "▼" : "▶"
        let text = NSAttributedString(
            string: "\(chevron)  \(label) (\(count))",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )
        text.draw(at: NSPoint(x: 16, y: 5))
    }

    override func mouseUp(with event: NSEvent) {
        onToggle?()
    }
}

// MARK: - Menu Manager

class MenuManager: NSObject {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var forYouPRs: [MonitoredPR] = []
    private var teamPRs: [MonitoredPR] = []
    private var otherPRs: [MonitoredPR] = []
    private var byYouPRs: [MonitoredPR] = []
    private var lastChecked: Date?
    private var refreshCallback: (() -> Void)?
    private var currentTab: MenuTab = .forYou
    private var isLoading: Bool = true
    private var tabBarView: TabBarView!
    private var tabMenuItem: NSMenuItem!
    private var tabSeparator: NSMenuItem!
    private var showingSettings: Bool = false
    private var settingsView: SettingsView!
    private var settingsMenuItem: NSMenuItem!
    private var settingsSavedCallback: ((String, String, TimeInterval, NotificationSoundSettings) -> Void)?
    private var isMutedSectionExpanded: Bool = false
    private var isReviewedSectionExpanded: Bool = false
    private var knownIncomingPRIds: Set<Int>?

    private var actionableForYouCount: Int {
        forYouPRs.filter {
            ($0.reviewStatus == .pending || $0.reviewStatus == .reRequested)
            && !Config.shared.isPRMuted($0.id)
        }.count
    }

    private static let reviewedStatuses: Set<ReviewStatus> = [.approved, .commented, .changesRequested]

    private func activeCount(_ prs: [MonitoredPR]) -> Int {
        prs.filter { !Config.shared.isPRMuted($0.id) && !Self.reviewedStatuses.contains($0.reviewStatus) }.count
    }

    private func isPRUnseen(_ pr: MonitoredPR) -> Bool {
        !Config.shared.isPRClicked(pr.id)
        && !Config.shared.isPRMuted(pr.id)
        && !Self.reviewedStatuses.contains(pr.reviewStatus)
    }

    private var hasUnseenForYou: Bool {
        forYouPRs.contains { isPRUnseen($0) }
    }
    private var hasUnseenTeam: Bool {
        teamPRs.contains { isPRUnseen($0) }
    }
    private var hasUnseenOther: Bool {
        otherPRs.contains { isPRUnseen($0) }
    }
    private var hasUnseenByYou: Bool {
        byYouPRs.contains { isPRUnseen($0) }
    }

    func setup(refreshCallback: @escaping () -> Void, settingsSavedCallback: @escaping (String, String, TimeInterval, NotificationSoundSettings) -> Void) {
        self.refreshCallback = refreshCallback
        self.settingsSavedCallback = settingsSavedCallback

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            updateIcon(count: 0)
            button.action = #selector(statusBarButtonClicked(_:))
            button.target = self
        }

        // Create tab bar view
        tabBarView = TabBarView(frame: NSRect(x: 0, y: 0, width: 640, height: 28))
        tabBarView.onTabSelected = { [weak self] tab in
            self?.currentTab = tab
            self?.rebuildContentItems()
        }

        // Persistent tab bar menu item — never removed
        tabMenuItem = NSMenuItem()
        tabMenuItem.view = tabBarView
        tabSeparator = NSMenuItem.separator()

        // Settings view
        settingsView = SettingsView(frame: NSRect(x: 0, y: 0, width: 420, height: 300))
        settingsView.onSave = { [weak self] org, team, interval, soundSettings in
            self?.settingsSavedCallback?(org, team, interval, soundSettings)
        }
        settingsView.onBack = { [weak self] in
            self?.showingSettings = false
            self?.rebuildContentItems()
        }
        settingsMenuItem = NSMenuItem()
        settingsMenuItem.view = settingsView

        menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        // Add persistent tab bar
        menu.addItem(tabMenuItem)
        menu.addItem(tabSeparator)

        rebuildContentItems()
    }

    func setLoading(_ loading: Bool) {
        self.isLoading = loading
        rebuildContentItems()
    }

    func updatePRs(forYou: [MonitoredPR], team: [MonitoredPR], others: [MonitoredPR], byYou: [MonitoredPR], lastChecked: Date) {
        let forYouIds = Set(forYou.map(\.id))
        let teamIds = Set(team.map(\.id))
        let otherIds = Set(others.map(\.id))
        let incomingIds = forYouIds.union(teamIds).union(otherIds)
        if let knownIds = knownIncomingPRIds {
            let newIds = incomingIds.subtracting(knownIds)
            let sounds = Config.shared.notificationSoundSettings
            let shouldPlaySound = (sounds.forYou && !newIds.isDisjoint(with: forYouIds))
                || (sounds.team && !newIds.isDisjoint(with: teamIds))
                || (sounds.others && !newIds.isDisjoint(with: otherIds))
            if shouldPlaySound {
                NSSound.beep()
            }
        }
        knownIncomingPRIds = incomingIds

        self.forYouPRs = forYou
        self.teamPRs = team
        self.otherPRs = others
        self.byYouPRs = byYou
        self.lastChecked = lastChecked
        self.isLoading = false

        // Cleanup stale muted and clicked IDs
        let allIds = Set((forYou + team + others + byYou).map(\.id))
        let staleMuted = Config.shared.mutedPRIds.subtracting(allIds)
        if !staleMuted.isEmpty { Config.shared.mutedPRIds = Config.shared.mutedPRIds.subtracting(staleMuted) }
        let staleClicked = Config.shared.clickedPRIds.subtracting(allIds)
        if !staleClicked.isEmpty { Config.shared.clickedPRIds = Config.shared.clickedPRIds.subtracting(staleClicked) }

        updateIcon(count: actionableForYouCount)
        rebuildContentItems()
    }

    // MARK: - Icon

    private func updateIcon(count: Int) {
        guard let button = statusItem.button else { return }

        let image = drawPRIcon(hasActivity: count > 0)
        image.isTemplate = true
        button.image = image

        if count > 0 && hasUnseenForYou {
            let title = NSMutableAttributedString(
                string: " \(count) ",
                attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)]
            )
            title.append(NSAttributedString(
                string: "●",
                attributes: [.foregroundColor: NSColor.systemGreen, .font: NSFont.systemFont(ofSize: 8)]
            ))
            button.attributedTitle = title
        } else if count > 0 {
            button.attributedTitle = NSAttributedString(string: " \(count)")
        } else {
            button.attributedTitle = NSAttributedString(string: "")
        }
    }

    private func drawPRIcon(hasActivity: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let pad: CGFloat = 2.5
            let r: CGFloat = 2.5
            let lw: CGFloat = 1.5

            let src = NSPoint(x: pad + r, y: pad + r)
            let dst = NSPoint(x: rect.width - pad - r, y: rect.height - pad - r)

            let path = NSBezierPath()
            path.lineWidth = lw
            path.lineCapStyle = .round

            path.move(to: NSPoint(x: src.x, y: src.y + r))
            path.line(to: NSPoint(x: src.x, y: dst.y))

            let cp = NSPoint(x: src.x + (dst.x - src.x) * 0.5, y: dst.y)
            path.curve(to: NSPoint(x: dst.x - r, y: dst.y), controlPoint1: cp, controlPoint2: NSPoint(x: dst.x - r, y: dst.y))

            path.move(to: NSPoint(x: dst.x, y: dst.y - r))
            path.line(to: NSPoint(x: dst.x, y: src.y))

            NSColor.black.setStroke()
            path.stroke()

            NSColor.black.setFill()
            for center in [src, dst, NSPoint(x: dst.x, y: src.y)] {
                NSBezierPath(ovalIn: NSRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)).fill()
            }

            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: - Menu Building

    private func rebuildContentItems() {
        // Remove everything after the persistent tab bar + separator (first 2 items)
        while menu.items.count > 2 {
            menu.removeItem(at: menu.items.count - 1)
        }

        // Settings mode
        if showingSettings {
            tabMenuItem.isHidden = true
            tabSeparator.isHidden = true
            settingsView.reload()
            menu.addItem(settingsMenuItem)
            return
        }

        // Normal mode
        tabMenuItem.isHidden = false
        tabSeparator.isHidden = false

        // Warning if not configured
        if !Config.shared.isConfigured {
            let warning = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            warning.attributedTitle = NSAttributedString(
                string: "Set organization and team in Settings",
                attributes: [.font: NSFont.systemFont(ofSize: 11, weight: .medium), .foregroundColor: NSColor.systemOrange]
            )
            warning.isEnabled = false
            menu.addItem(warning)
        }

        // Update tab bar appearance
        tabBarView.update(
            tab: currentTab,
            counts: (activeCount(forYouPRs), activeCount(teamPRs),activeCount(otherPRs), activeCount(byYouPRs)),
            unseen: (hasUnseenForYou, hasUnseenTeam, hasUnseenOther, hasUnseenByYou)
        )

        // Show PRs for current tab
        if Config.shared.isConfigured {
            let activePRs: [MonitoredPR]
            let emptyText: String
            switch currentTab {
            case .forYou:
                activePRs = forYouPRs
                emptyText = "No PRs directly assigned to you"
            case .team:
                activePRs = teamPRs
                emptyText = "No team-tagged PRs"
            case .others:
                activePRs = otherPRs
                emptyText = "No PRs outside team repos"
            case .byYou:
                activePRs = byYouPRs
                emptyText = "No PRs opened by you"
            }

            let mutedPRs = activePRs.filter { Config.shared.isPRMuted($0.id) }
            let nonMutedPRs = activePRs.filter { !Config.shared.isPRMuted($0.id) }
            let regularPRs = nonMutedPRs.filter { !Self.reviewedStatuses.contains($0.reviewStatus) }
            let reviewedPRs = nonMutedPRs.filter { Self.reviewedStatuses.contains($0.reviewStatus) }

            if activePRs.isEmpty && !isLoading {
                let empty = NSMenuItem(title: emptyText, action: nil, keyEquivalent: "")
                empty.isEnabled = false
                menu.addItem(empty)
            } else if activePRs.isEmpty && isLoading {
                let loadingItem = NSMenuItem(title: "Fetching PRs...", action: nil, keyEquivalent: "")
                loadingItem.isEnabled = false
                loadingItem.attributedTitle = NSAttributedString(
                    string: "Fetching PRs...",
                    attributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.secondaryLabelColor]
                )
                menu.addItem(loadingItem)
            } else if regularPRs.isEmpty && reviewedPRs.isEmpty && !mutedPRs.isEmpty && !isLoading {
                let allMuted = NSMenuItem(title: "All PRs muted", action: nil, keyEquivalent: "")
                allMuted.isEnabled = false
                menu.addItem(allMuted)
            } else {
                for pr in regularPRs {
                    menu.addItem(createPRViewItem(pr: pr, isMuted: false, isUnseen: isPRUnseen(pr)))
                    menu.addItem(NSMenuItem.separator())
                }
            }

            // Reviewed section (above Muted)
            if !reviewedPRs.isEmpty {
                let menuWidth: CGFloat = menu.size.width > 0 ? menu.size.width : 640
                menu.addItem(NSMenuItem.separator())
                let headerView = CollapsibleSectionHeaderView(label: "Reviewed", count: reviewedPRs.count, isExpanded: isReviewedSectionExpanded, width: menuWidth)
                headerView.onToggle = { [weak self] in
                    self?.isReviewedSectionExpanded.toggle()
                    self?.rebuildContentItems()
                }
                let headerItem = NSMenuItem()
                headerItem.view = headerView
                menu.addItem(headerItem)

                if isReviewedSectionExpanded {
                    for pr in reviewedPRs {
                        menu.addItem(createPRViewItem(pr: pr, isMuted: false, isUnseen: isPRUnseen(pr)))
                    }
                }
            }

            // Muted section
            if !mutedPRs.isEmpty {
                let menuWidth: CGFloat = menu.size.width > 0 ? menu.size.width : 640
                menu.addItem(NSMenuItem.separator())
                let headerView = CollapsibleSectionHeaderView(label: "Muted", count: mutedPRs.count, isExpanded: isMutedSectionExpanded, width: menuWidth)
                headerView.onToggle = { [weak self] in
                    self?.isMutedSectionExpanded.toggle()
                    self?.rebuildContentItems()
                }
                let headerItem = NSMenuItem()
                headerItem.view = headerView
                menu.addItem(headerItem)

                if isMutedSectionExpanded {
                    for pr in mutedPRs {
                        menu.addItem(createPRViewItem(pr: pr, isMuted: true, isUnseen: false))
                    }
                }
            }
        }

        // Footer
        menu.addItem(NSMenuItem.separator())

        let statusText = isLoading ? "Refreshing..." : lastCheckedText()
        let lastCheckedItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        lastCheckedItem.isEnabled = false
        lastCheckedItem.attributedTitle = NSAttributedString(
            string: statusText,
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor]
        )
        menu.addItem(lastCheckedItem)

        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshClicked(_:)), keyEquivalent: "")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(settingsClicked(_:)), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitClicked(_:)), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func buildPRAttributedText(pr: MonitoredPR, dimmed: Bool) -> NSAttributedString {
        let alpha: CGFloat = dimmed ? 0.5 : 1.0
        let fullText = NSMutableAttributedString()

        fullText.append(NSAttributedString(
            string: pr.truncatedTitle + "\n",
            attributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.labelColor.withAlphaComponent(alpha)]
        ))

        let detailText = "\(pr.repoShortName) | @\(pr.author) | "
        fullText.append(NSAttributedString(
            string: detailText,
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor.withAlphaComponent(alpha)]
        ))

        let reasonColor: NSColor
        switch pr.reason {
        case .reviewer: reasonColor = .systemBlue
        case .mentioned: reasonColor = .systemOrange
        case .owner: reasonColor = .systemPurple
        }
        fullText.append(NSAttributedString(
            string: pr.reason.rawValue,
            attributes: [.font: NSFont.boldSystemFont(ofSize: 11), .foregroundColor: reasonColor.withAlphaComponent(alpha)]
        ))

        let statusColor: NSColor
        let statusText: String
        if pr.isDraft {
            statusText = " · Draft"
            statusColor = .secondaryLabelColor
        } else if let s = pr.ownerReviewSummary {
            var parts: [String] = []
            if s.approved > 0 { parts.append("\(s.approved) approved") }
            if s.changesRequested > 0 { parts.append("\(s.changesRequested) changes requested") }
            if s.commented > 0 { parts.append("\(s.commented) commented") }
            if parts.isEmpty {
                statusText = " · No reviews yet"
                statusColor = .systemYellow
            } else {
                statusText = " · " + parts.joined(separator: ", ")
                if s.changesRequested > 0 {
                    statusColor = .systemOrange
                } else if s.approved > 0 {
                    statusColor = .systemGreen
                } else {
                    statusColor = .systemBlue
                }
            }
        } else {
            switch pr.reviewStatus {
            case .pending:
                statusColor = .systemYellow
                statusText = " · Pending"
            case .commented:
                statusColor = .systemBlue
                statusText = " · Commented"
            case .approved:
                statusColor = .systemGreen
                statusText = " · Approved"
            case .changesRequested:
                statusColor = .systemOrange
                statusText = " · Changes Requested"
            case .reRequested:
                statusColor = .systemRed
                statusText = " · Re-requested"
            }
        }
        fullText.append(NSAttributedString(
            string: statusText,
            attributes: [.font: NSFont.boldSystemFont(ofSize: 11), .foregroundColor: statusColor.withAlphaComponent(alpha)]
        ))

        return fullText
    }

    private func createPRViewItem(pr: MonitoredPR, isMuted: Bool, isUnseen: Bool) -> NSMenuItem {
        let menuWidth: CGFloat = menu.size.width > 0 ? menu.size.width : 640
        let text = buildPRAttributedText(pr: pr, dimmed: isMuted)
        let prView = PRMenuItemView(attributedText: text, isMuted: isMuted, isUnseen: isUnseen, width: menuWidth)
        prView.toolTip = pr.title

        prView.onPRClicked = { [weak self] in
            Config.shared.markPRClicked(pr.id)
            if let url = URL(string: pr.url) {
                NSWorkspace.shared.open(url)
            }
            self?.updateIcon(count: self?.actionableForYouCount ?? 0)
            self?.reopenMenu()
        }

        prView.onMarkRead = { [weak self] in
            Config.shared.markPRClicked(pr.id)
            self?.updateIcon(count: self?.actionableForYouCount ?? 0)
            self?.rebuildContentItems()
        }

        prView.onMuteToggled = { [weak self] in
            if isMuted {
                Config.shared.unmutePR(pr.id)
            } else {
                Config.shared.mutePR(pr.id)
            }
            self?.updateIcon(count: self?.actionableForYouCount ?? 0)
            self?.rebuildContentItems()
        }

        let item = NSMenuItem()
        item.view = prView
        return item
    }

    private func lastCheckedText() -> String {
        guard let lastChecked = lastChecked else {
            return "Last checked: never"
        }
        let interval = Date().timeIntervalSince(lastChecked)
        if interval < 60 {
            return "Last checked: just now"
        } else {
            let minutes = Int(interval / 60)
            return "Last checked: \(minutes) minute\(minutes == 1 ? "" : "s") ago"
        }
    }

    // MARK: - Actions

    @objc private func statusBarButtonClicked(_ sender: Any?) {}

    @objc private func refreshClicked(_ sender: Any?) {
        refreshCallback?()
        reopenMenu()
    }

    @objc private func settingsClicked(_ sender: Any?) {
        showingSettings = true
        rebuildContentItems()
        reopenMenu()
    }

    private func reopenMenu() {
        DispatchQueue.main.async { [weak self] in
            self?.statusItem.button?.performClick(nil)
        }
    }

    @objc private func quitClicked(_ sender: Any?) {
        NSApplication.shared.terminate(nil)
    }
}

extension MenuManager: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        rebuildContentItems()
    }
}
