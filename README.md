# GitHub Notifications for macOS

**Desktop notifications for your GitHub inbox.** A native menu bar app that tells you the moment someone requests your
review, mentions you, or assigns you something — including in private and organisation repositories.

GitHub's web inbox never raises a desktop notification. This does.

<p align="center">
  <img src="docs/screenshots/panel.png" alt="The menu bar panel, grouped by repository" width="420">
</p>

---

## Why it exists

You find out about a review request by remembering to look. Everything else on your machine can interrupt you; the one
inbox that gates other people's work cannot.

## Features

- **Grouped by repository, ordered by urgency.** Review requests and mentions sort above CI noise, not by timestamp
- **Notifications that respect your attention.** Choose a preset, or pick exactly which of the fifteen GitHub
  notification types are allowed to interrupt you
- **Work hours.** Hold notifications outside your hours and deliver them together when the next working day starts,
  with per-day schedules if your week is not uniform
- **Customisable notifications.** Decide what each banner shows, whether it stacks by repository, and which sound plays
- **Mark read or dismiss** from the panel, or click through to exactly the right page — a pull request opens at the pull
  request, a comment opens at the comment
- **Private and organisation repositories included**, with SAML single sign-on supported

## How it works

There is no push. GitHub has no user-level webhook, no event stream, and no subscription API for the notification
inbox — webhooks are repository-scoped and do not carry inbox semantics.

What GitHub does support is conditional polling, and it is explicit about how: send `If-Modified-Since` with the
previous `Last-Modified`, receive `304 Not Modified` when nothing has changed, and obey the `X-Poll-Interval` header.
A `304` costs nothing against your rate limit.

This app does exactly that. Notifications arrive within about a minute, and an idle inbox consumes effectively none of
your 5,000 requests per hour.

## Security

The app talks to one host: `api.github.com`. There is no backend, no telemetry, and no account to create.

| | |
| --- | --- |
| **Your token** | Stored in the macOS keychain. Never written anywhere else, never logged |
| **Where it goes** | `api.github.com` only, over HTTPS, as a bearer token |
| **What it can do** | Read your notification inbox, mark threads read or done, read your username |
| **What it cannot do** | Anything you do not grant. Revoke it on GitHub at any time and the app stops working immediately |
| **Dependencies** | None. Swift and Apple frameworks only |

GitHub requires a **classic** personal access token here: the notification endpoints are not available to GitHub Apps,
and fine-grained tokens have no notifications permission at all. Fine-grained tokens also need organisation approval,
which classic tokens do not — you authorise your own token for a SAML organisation yourself, without an administrator.

### Scopes, and why each is needed

| Scope | Why |
| --- | --- |
| `notifications` | Read your inbox and mark threads as read |
| `repo` | See notifications from private and organisation repositories |
| `read:user` | Show which account you are signed in as |

Use `public_repo` instead of `repo` if you only care about public repositories.

## Install

Download the latest zip from [Releases](../../releases), unzip it, and move `GitHub Notifications.app` to
`/Applications`.

Releases are ad-hoc signed and **not notarised**, because notarisation requires a paid Apple Developer ID. macOS will
quarantine the download. Open it once with right-click → **Open**, or clear the flag:

```sh
xattr -d com.apple.quarantine "/Applications/GitHub Notifications.app"
```

Building from source avoids this entirely.

## Setup

1. Click the menu bar icon. The sign-in panel links you to GitHub's classic token page with the right scopes and
   *No expiration* already selected
2. Paste the token. If it is already on your clipboard, the field fills itself
3. Allow notifications when macOS asks

If an organisation enforces SAML single sign-on, press **Configure SSO** on the token afterwards and authorise it. No
organisation administrator is involved in that step.

<p align="center">
  <img src="docs/screenshots/settings.png" alt="Notification settings, work hours and customisation" width="720">
</p>

## Build from source

Requires Xcode 26 or newer, on macOS 14 or newer.

```sh
git clone https://github.com/Jean-PierreGassin/github-desktop-notifications.git
cd github-desktop-notifications
./scripts/build.sh release
open "build/Build/Products/Release/GitHub Notifications.app"
```

Run the test suite with `./scripts/test.sh`.

Builds are ad-hoc signed, so each rebuild has a different code signature and macOS asks once per build before reading
your token from the keychain. Choose **Always Allow**, or sign with a stable identity if you are iterating often.

## Contributing

Issues and pull requests are welcome. The codebase is small and deliberately dependency-free:

```
GitHubNotifications/
├── API/      GitHub client, conditional requests, rate-limit handling
├── Alerts/   Notification content, sounds, held-notification queue
├── Auth/     Keychain storage and token validation
├── Core/     Polling loop, grouping, preferences
├── Model/    Decodable models and pure logic (URL derivation, work hours)
└── UI/       SwiftUI menu bar panel and settings
```

Pure logic is covered by unit tests; please keep it that way.

## Licence

MIT. The menu bar glyph and app icon are original artwork. This project is not affiliated with or endorsed by GitHub.
