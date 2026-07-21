import Foundation

struct FetchResult {
    let forYou: [MonitoredPR]
    let team: [MonitoredPR]
    let others: [MonitoredPR]
    let byYou: [MonitoredPR]
}

actor GitHubService {
    private var token: String
    private let session: URLSession
    private var teamRepos: Set<String> = []
    private var lastModifiedHeader: String?

    init(token: String) {
        self.token = token
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Notifications (lightweight change detection)

    /// Returns true if there are new notifications since last check (or on first call).
    /// Uses If-Modified-Since conditional request — returns 304 with no rate limit cost when unchanged.
    func hasNewActivity() async -> Bool {
        guard let url = URL(string: "https://api.github.com/notifications?per_page=1") else { return true }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("pr-monitor/1.0", forHTTPHeaderField: "User-Agent")

        if let lastModified = lastModifiedHeader {
            request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
        }

        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { return true }

            if let lm = http.value(forHTTPHeaderField: "Last-Modified") {
                lastModifiedHeader = lm
            }

            if http.statusCode == 304 {
                log("[Notifications] No changes (304)")
                return false
            }

            log("[Notifications] New activity detected (\(http.statusCode))")
            return true
        } catch {
            log("[Error] Notification check failed: \(error)")
            return true // fetch on error to be safe
        }
    }

    // MARK: - Public

    func fetchCurrentUser() async -> String? {
        guard let data = await fetchData(path: "/user") else {
            log("[Error] Failed to fetch current user")
            return nil
        }
        if let user = try? JSONDecoder().decode(GitHubUserResponse.self, from: data) {
            log("[User] Detected: \(user.login)")
            return user.login
        }
        return nil
    }

    func resetCache() {
        teamRepos = []
    }

    func fetchTeamRepos() async {
        let path = "/orgs/\(Config.shared.teamOrg)/teams/\(Config.shared.teamSlug)/repos?per_page=100"
        guard let data = await fetchData(path: path) else {
            log("[Error] Failed to fetch team repos")
            return
        }

        if let repos = try? JSONDecoder().decode([GitHubRepo].self, from: data) {
            let active = repos.filter { !$0.archived }
            teamRepos = Set(active.map { $0.fullName })
            log("[Repos] Loaded \(teamRepos.count) team repos (\(repos.count - active.count) archived excluded)")
        }
    }

    func fetchMonitoredPRs() async -> FetchResult {
        // Fetch team repos if not loaded yet
        if teamRepos.isEmpty {
            await fetchTeamRepos()
        }

        // Search for PRs where the user or configured team is review-requested,
        // mentioned, already reviewed, or author.
        async let reviewCandidates = searchPRs(query: "is:pr is:open review-requested:\(Config.shared.currentUser)")
        async let teamReviewCandidates = searchPRs(query: "is:pr is:open team-review-requested:\(Config.shared.teamOrg)/\(Config.shared.teamSlug)")
        async let mentionCandidates = searchPRs(query: "is:pr is:open mentions:\(Config.shared.currentUser) org:\(Config.shared.teamOrg)")
        async let reviewedCandidates = searchPRs(query: "is:pr is:open reviewed-by:\(Config.shared.currentUser)")
        async let authoredCandidates = searchPRs(query: "is:pr is:open author:\(Config.shared.currentUser)")

        let reviewItems = await reviewCandidates
        let teamReviewItems = await teamReviewCandidates
        let mentionItems = await mentionCandidates
        let reviewedItems = await reviewedCandidates
        let authoredItems = await authoredCandidates

        // Merge candidates, dedup by PR number+repo
        // If a PR appears in mentions, mark it as mentioned (personal) even if also found via team review-request
        var candidateMap: [String: (item: GitHubSearchItem, reason: PRReason)] = [:]

        for item in reviewItems {
            let key = "\(item.repoFullName)#\(item.number)"
            if candidateMap[key] == nil {
                candidateMap[key] = (item, .reviewer)
            }
        }
        for item in teamReviewItems {
            let key = "\(item.repoFullName)#\(item.number)"
            if candidateMap[key] == nil {
                candidateMap[key] = (item, .reviewer)
            }
        }
        for item in reviewedItems {
            let key = "\(item.repoFullName)#\(item.number)"
            if candidateMap[key] == nil {
                candidateMap[key] = (item, .reviewer)
            }
        }
        for item in mentionItems {
            let key = "\(item.repoFullName)#\(item.number)"
            if let existing = candidateMap[key] {
                // Upgrade to mentioned if previously only reviewer (ensures personal categorization)
                candidateMap[key] = (existing.item, .mentioned)
            } else {
                candidateMap[key] = (item, .mentioned)
            }
        }

        var candidates = Array(candidateMap.values)

        // Sort all candidates newest first
        candidates.sort { $0.item.createdAt > $1.item.createdAt }

        // Build "By You" list from authored PRs (sorted newest first)
        var byYou: [MonitoredPR] = []
        let sortedAuthored = authoredItems.sorted { $0.createdAt > $1.createdAt }
        for item in sortedAuthored {
            let summary = await fetchOwnerReviewSummary(repo: item.repoFullName, prNumber: item.number)
            byYou.append(MonitoredPR(
                id: item.id,
                number: item.number,
                title: item.title,
                repoFullName: item.repoFullName,
                author: item.user.login,
                url: item.htmlUrl,
                reason: .owner,
                reviewStatus: .pending,
                ownerReviewSummary: summary,
                isDraft: item.draft ?? false
            ))
        }

        // Filter and verify each PR
        var forYou: [MonitoredPR] = []
        var teamTag: [MonitoredPR] = []
        var others: [MonitoredPR] = []

        for entry in candidates {
            let item = entry.item
            let reason = entry.reason

            // Not own PR
            guard item.user.login != Config.shared.currentUser else { continue }

            // Verify direct vs team-tag assignment
            let verification = await verifyDirectAssignment(repo: item.repoFullName, prNumber: item.number)

            let pr = MonitoredPR(
                id: item.id,
                number: item.number,
                title: item.title,
                repoFullName: item.repoFullName,
                author: item.user.login,
                url: item.htmlUrl,
                reason: reason,
                reviewStatus: verification.reviewStatus,
                ownerReviewSummary: nil,
                isDraft: item.draft ?? false
            )

            let isPersonal = verification.isDirect || reason == .mentioned

            if isPersonal {
                forYou.append(pr)
            }
            else if verification.isTeam {
                teamTag.append(pr)
            }
            else {
                others.append(pr)
            }
        }

        log("[Fetch] Done. \(forYou.count) for-you, \(teamTag.count) team, \(others.count) others, \(byYou.count) by-you.")
        return FetchResult(
            forYou: forYou,
            team: teamTag,
            others: others,
            byYou: byYou
        )
    }

    // MARK: - Search

    private func searchPRs(query: String) async -> [GitHubSearchItem] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://api.github.com/search/issues?q=\(encoded)&per_page=100") else { return [] }

        do {
            let data = try await makeRequest(url: url)
            let result = try JSONDecoder().decode(GitHubSearchResult.self, from: data)
            log("[Search] \(query) => \(result.totalCount) results")
            return result.items
        } catch {
            log("[Error] Search failed: \(error)")
            return []
        }
    }

    // MARK: - Verification

    struct VerificationResult {
        let isDirect: Bool
        let isTeam: Bool
        let reviewStatus: ReviewStatus
    }

    private func verifyDirectAssignment(repo: String, prNumber: Int) async -> VerificationResult {
        async let prDetailData = fetchData(path: "/repos/\(repo)/pulls/\(prNumber)")
        async let reviewsData = fetchData(path: "/repos/\(repo)/pulls/\(prNumber)/reviews")

        var isDirectlyRequested = false
        var isTeamRequested = false
        if let data = await prDetailData {
            if let detail = try? JSONDecoder().decode(GitHubPRDetail.self, from: data) {
                isDirectlyRequested = detail.requestedReviewers.contains { $0.login == Config.shared.currentUser }
                isTeamRequested = detail.requestedTeams.contains { $0.slug == Config.shared.teamSlug }
            }
        }

        var latestReviewState: String?
        if let data = await reviewsData {
            if let reviews = try? JSONDecoder().decode([GitHubReview].self, from: data) {
                // Get the latest review by the current user (last one wins)
                latestReviewState = reviews
                    .filter { $0.user.login == Config.shared.currentUser }
                    .last?.state
            }
        }

        let hasReviewed = latestReviewState != nil
        let isDirect = isDirectlyRequested || hasReviewed

        let reviewStatus: ReviewStatus
        if hasReviewed && isDirectlyRequested {
            reviewStatus = .reRequested
        } else if let state = latestReviewState {
            switch state {
            case "APPROVED": reviewStatus = .approved
            case "CHANGES_REQUESTED": reviewStatus = .changesRequested
            default: reviewStatus = .commented
            }
        } else {
            reviewStatus = .pending
        }

        return VerificationResult(isDirect: isDirect, isTeam: isTeamRequested, reviewStatus: reviewStatus)
    }

    // MARK: - Owner Review Summary

    private func fetchOwnerReviewSummary(repo: String, prNumber: Int) async -> OwnerReviewSummary {
        guard let data = await fetchData(path: "/repos/\(repo)/pulls/\(prNumber)/reviews"),
              let reviews = try? JSONDecoder().decode([GitHubReview].self, from: data) else {
            return OwnerReviewSummary(approved: 0, commented: 0, changesRequested: 0)
        }

        // Take latest non-pending/non-dismissed state per reviewer
        var latestByUser: [String: String] = [:]
        for review in reviews {
            if review.state == "PENDING" || review.state == "DISMISSED" { continue }
            latestByUser[review.user.login] = review.state
        }

        var approved = 0, commented = 0, changesRequested = 0
        for state in latestByUser.values {
            switch state {
            case "APPROVED": approved += 1
            case "CHANGES_REQUESTED": changesRequested += 1
            case "COMMENTED": commented += 1
            default: break
            }
        }
        return OwnerReviewSummary(approved: approved, commented: commented, changesRequested: changesRequested)
    }

    // MARK: - HTTP

    private func fetchData(path: String) async -> Data? {
        guard let url = URL(string: "https://api.github.com\(path)") else { return nil }
        do {
            return try await makeRequest(url: url)
        } catch {
            log("[Error] \(path): \(error)")
            return nil
        }
    }

    private func makeRequest(url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("pr-monitor/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw GitHubError.httpError(statusCode: http.statusCode)
        }

        return data
    }
}

enum GitHubError: Error {
    case httpError(statusCode: Int)
}
