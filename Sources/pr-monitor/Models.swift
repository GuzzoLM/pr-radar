import Foundation

// MARK: - Token Helper

final class TokenHelper {
    static func loadGhCliToken() -> String? {
        let ghPaths = [
            "/opt/homebrew/bin/gh",
            "/usr/local/bin/gh",
            "/usr/bin/gh",
        ]

        guard let ghPath = ghPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else {
            log("[TokenHelper] gh CLI not found")
            return nil
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ghPath)
        process.arguments = ["auth", "token"]
        process.environment = [
            "HOME": NSHomeDirectory(),
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let token = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (token?.isEmpty == false) ? token : nil
        } catch {
            return nil
        }
    }
}

// MARK: - Configuration

final class Config {
    static let shared = Config()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let currentUser = "config.currentUser"
        static let teamOrg = "config.teamOrg"
        static let teamSlug = "config.teamSlug"
        static let pollingInterval = "config.pollingIntervalSeconds"
        static let mutedPRIds = "config.mutedPRIds"
        static let clickedPRIds = "config.clickedPRIds"
    }

    var currentUser: String {
        get { defaults.string(forKey: Keys.currentUser) ?? "" }
        set { defaults.set(newValue, forKey: Keys.currentUser) }
    }

    var teamOrg: String {
        get { defaults.string(forKey: Keys.teamOrg) ?? "" }
        set { defaults.set(newValue, forKey: Keys.teamOrg) }
    }

    var teamSlug: String {
        get { defaults.string(forKey: Keys.teamSlug) ?? "" }
        set { defaults.set(newValue, forKey: Keys.teamSlug) }
    }

    var pollingIntervalSeconds: TimeInterval {
        get {
            let val = defaults.double(forKey: Keys.pollingInterval)
            return val > 0 ? val : 120
        }
        set { defaults.set(max(newValue, 30), forKey: Keys.pollingInterval) }
    }

    var mutedPRIds: Set<Int> {
        get { Set(defaults.array(forKey: Keys.mutedPRIds) as? [Int] ?? []) }
        set { defaults.set(Array(newValue), forKey: Keys.mutedPRIds) }
    }

    func mutePR(_ id: Int) { var ids = mutedPRIds; ids.insert(id); mutedPRIds = ids }
    func unmutePR(_ id: Int) { var ids = mutedPRIds; ids.remove(id); mutedPRIds = ids }
    func isPRMuted(_ id: Int) -> Bool { mutedPRIds.contains(id) }

    var clickedPRIds: Set<Int> {
        get { Set(defaults.array(forKey: Keys.clickedPRIds) as? [Int] ?? []) }
        set { defaults.set(Array(newValue), forKey: Keys.clickedPRIds) }
    }

    func markPRClicked(_ id: Int) { var ids = clickedPRIds; ids.insert(id); clickedPRIds = ids }
    func isPRClicked(_ id: Int) -> Bool { clickedPRIds.contains(id) }

    var isConfigured: Bool {
        !teamOrg.isEmpty && !teamSlug.isEmpty
    }
}

// MARK: - PR Models

enum PRReason: String {
    case reviewer = "Reviewer"
    case mentioned = "Mentioned"
    case owner = "Owner"
}

enum ReviewStatus: String {
    case pending = "Pending"
    case commented = "Commented"
    case approved = "Approved"
    case changesRequested = "Changes Requested"
    case reRequested = "Re-requested"
}

struct OwnerReviewSummary {
    let approved: Int
    let commented: Int
    let changesRequested: Int
}

struct MonitoredPR: Identifiable, Hashable {
    let id: Int
    let number: Int
    let title: String
    let repoFullName: String
    let author: String
    let url: String
    let reason: PRReason
    let reviewStatus: ReviewStatus
    let ownerReviewSummary: OwnerReviewSummary?
    let isDraft: Bool

    var repoShortName: String {
        let parts = repoFullName.split(separator: "/")
        guard parts.count == 2 else { return repoFullName }
        let name = String(parts[1])
        if name.hasPrefix("picnic-") {
            return String(name.dropFirst("picnic-".count))
        }
        return name
    }

    var truncatedTitle: String {
        if title.count > 70 {
            return String(title.prefix(67)) + "..."
        }
        return title
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: MonitoredPR, rhs: MonitoredPR) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - GitHub API Models

struct GitHubSearchResult: Decodable {
    let totalCount: Int
    let items: [GitHubSearchItem]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case items
    }
}

struct GitHubSearchItem: Decodable {
    let id: Int
    let number: Int
    let title: String
    let htmlUrl: String
    let createdAt: String
    let user: GitHubUser
    let labels: [GitHubLabel]?
    let repositoryUrl: String
    let draft: Bool?

    enum CodingKeys: String, CodingKey {
        case id, number, title
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case user
        case labels
        case repositoryUrl = "repository_url"
        case draft
    }

    var repoFullName: String {
        let parts = repositoryUrl.split(separator: "/")
        guard parts.count >= 2 else { return "" }
        return "\(parts[parts.count - 2])/\(parts[parts.count - 1])"
    }
}

struct GitHubUser: Decodable {
    let login: String
}

struct GitHubLabel: Decodable {
    let name: String
}

struct GitHubPRDetail: Decodable {
    let requestedReviewers: [GitHubUser]
    let requestedTeams: [GitHubTeam]

    enum CodingKeys: String, CodingKey {
        case requestedReviewers = "requested_reviewers"
        case requestedTeams = "requested_teams"
    }
}

struct GitHubTeam: Decodable {
    let slug: String
}

struct GitHubReview: Decodable {
    let user: GitHubUser
    let state: String
}

struct GitHubUserResponse: Decodable {
    let login: String
}

struct GitHubRepo: Decodable {
    let fullName: String
    let archived: Bool

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case archived
    }
}
