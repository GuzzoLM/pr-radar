import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private let menuManager = MenuManager()
    private var githubService: GitHubService?
    private var pollTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        menuManager.setup(
            refreshCallback: { [weak self] in
                self?.triggerRefresh()
            },
            settingsSavedCallback: { [weak self] org, teams, interval in
                self?.handleSettingsSaved(org: org, teams: teams, interval: interval)
            }
        )

        if let token = TokenHelper.loadGhCliToken() {
            log("[PRMonitor] Using token from gh CLI.")
            githubService = GitHubService(token: token)
            autoDetectUser()

            if Config.shared.isConfigured {
                triggerRefresh()
                startPolling()
            }
        } else {
            log("[PRMonitor] Could not load token from gh CLI.")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        pollTimer?.invalidate()
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(
            withTimeInterval: Config.shared.pollingIntervalSeconds,
            repeats: true
        ) { [weak self] _ in
            self?.pollCheck()
        }
        log("[PRMonitor] Polling every \(Int(Config.shared.pollingIntervalSeconds))s.")
    }

    private func pollCheck() {
        guard let service = githubService else { return }
        Task {
            let hasNew = await service.hasNewActivity()
            if hasNew {
                await MainActor.run { self.triggerRefresh() }
            } else {
                log("[PRMonitor] Skipping fetch — no new activity.")
            }
        }
    }

    private func autoDetectUser() {
        guard let service = githubService else { return }
        Task {
            if let login = await service.fetchCurrentUser() {
                Config.shared.currentUser = login
                log("[PRMonitor] Auto-detected user: \(login)")
            }
        }
    }

    private func handleSettingsSaved(org: String, teams: String, interval: TimeInterval) {
        let config = Config.shared
        let parsedTeams = Config.parseTeamSlugs(teams)
        let orgChanged = config.teamOrg != org || config.teamSlugs != parsedTeams

        config.teamOrg = org
        config.teamSlugs = parsedTeams
        config.pollingIntervalSeconds = interval

        log("[Settings] Saved: org=\(org), teams=\(parsedTeams.joined(separator: ",")), interval=\(Int(interval))s")

        if orgChanged, let service = githubService {
            Task { await service.resetCache() }
        }

        if config.isConfigured {
            startPolling()
            triggerRefresh()
        }
    }

    private func triggerRefresh() {
        guard let service = githubService else { return }

        menuManager.setLoading(true)
        Task {
            log("[PRMonitor] Fetching PRs...")
            let result = await service.fetchMonitoredPRs()
            let now = Date()
            log("[PRMonitor] \(result.forYou.count) for-you, \(result.team.count) team, \(result.others.count) other(s), \(result.byYou.count) by-you.")

            await MainActor.run {
                self.menuManager.updatePRs(forYou: result.forYou, team: result.team, others: result.others, byYou: result.byYou, lastChecked: now)
            }
        }
    }
}
