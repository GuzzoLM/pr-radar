# PR Monitor

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

## Install

```bash
cd pr-monitor
bash install.sh
```

This builds a release binary and creates an app bundle at `/Applications/pr-monitor.app`.

## First Launch

1. Open **PR Monitor** from Spotlight or `/Applications`
2. Click the PR icon in the menu bar
3. Go to **Settings** and enter your GitHub organization and one or more comma-separated team slugs
4. Click **Save** — the app starts fetching your PRs automatically

## Auto-start

To launch on login: **System Settings → General → Login Items → add PR Monitor**.
