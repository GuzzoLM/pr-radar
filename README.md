# PRadar

A lightweight macOS menu bar app that monitors GitHub pull requests assigned to you.

## Features

### 5-tab PR categorization
- **You** — PRs where you're directly assigned as reviewer or mentioned in comments
- **Team** — PRs assigned to your team (via team tag)
- **Other** — PRs assigned to you outside your team's repos

### Review status tracking
- Shows granular status per PR: **Pending**, **Commented**, **Approved**, **Changes Requested**, **Re-requested**
- Reviewed PRs (commented/approved/changes requested) move to a collapsible **Reviewed** section
- Re-requested PRs come back to the regular list

### Unseen PR indicators
- Green dot next to each new PR until you click and open it in the browser
- Green dot on the menu bar icon when there are un-clicked PRs in the You tab
- Menu bar count shows only actionable PRs (pending + re-requested, excluding muted)

### Mute/unmute
- Mute button on each PR to hide stale, blocked, or inaccessible PRs
- Muted PRs go to a collapsible **Muted** section at the bottom
- Mute state persists across restarts

### Smart polling
- Hybrid polling: checks GitHub Notifications API first, only does a full fetch when there's new activity
- Configurable interval (default: 2 minutes)
- Manual refresh available anytime

### Other
- Menu stays open when clicking PRs — open multiple PRs without re-opening the app
- PR title capped at 70 characters with tooltip showing the full title
- DMG packaging script for sharing with colleagues
- Settings configurable from within the app (organization, team, polling interval)

## Prerequisites

- macOS 13+
- [GitHub CLI](https://cli.github.com/) (`gh`) installed and authenticated

The app reads your GitHub token from `gh auth token` — no manual token setup needed.

## Install with Homebrew

```bash
brew install --cask guzzolm/tap/pradar
```

Homebrew also installs the required GitHub CLI. Authenticate it before launching
PRadar for the first time:

```bash
gh auth login
```

Because current releases are not Apple-notarized, macOS may block the first
launch. If it does, open **System Settings → Privacy & Security** and choose
**Open Anyway** for PRadar.

## Install from source

```bash
cd pr-monitor
bash install.sh
```

This builds a release binary and creates an app bundle at `/Applications/PRadar.app`.

## Publishing a release

1. Add a `TAP_GITHUB_TOKEN` Actions secret with `contents: write` access to
   `GuzzoLM/homebrew-tap`.
2. Create and push a version tag, for example `git tag v1.0.0 && git push origin v1.0.0`.

The release workflow builds a universal DMG, publishes it on GitHub, and updates
`Casks/pradar.rb` in the tap. Versions must use a `v`-prefixed numeric tag.

## First Launch

1. Open **PRadar** from Spotlight or `/Applications`
2. Click the PR icon in the menu bar
3. Go to **Settings** and enter your GitHub organization and one or more comma-separated team slugs
4. Click **Save** — the app starts fetching your PRs automatically

## Auto-start

To launch on login: **System Settings → General → Login Items → add PRadar**.
