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

Requires macOS 26 or newer.

Download the latest DMG from [Releases](../../releases) and drag `GitHub Notifications.app` to `/Applications`. The
zip beside it is what the app's own updater downloads; either works.

Releases are signed with a self-signed certificate and **not notarised**, because notarisation requires a paid Apple
Developer ID. macOS will quarantine the download. Open it once with right-click → **Open**, or clear the flag:

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

Requires Xcode 26 or newer, on macOS 26 or newer.

```sh
git clone https://github.com/Jean-PierreGassin/github-desktop-notifications.git
cd github-desktop-notifications
./scripts/build.sh release
open "build/Build/Products/Release/GitHub Notifications.app"
```

Run the test suite with `./scripts/test.sh`.

A clone builds without any certificate, ad-hoc signed, and the build warns when it does. See below for why that costs
you a keychain prompt per rebuild, and how to stop it.

## Building and signing

### Why the app is signed at all

Not for Gatekeeper. A self-signed certificate does nothing for notarisation, and the quarantine step above still
applies. It is for the keychain.

When the app first reads your token, macOS records an access control list entry naming the program allowed to read it.
The program is identified by its **designated requirement**, not its path. An ad-hoc signature's designated requirement
is a hash of the built code, so it changes on every single build, and macOS treats the next build as a different
program: **Always Allow** is forgotten, and you are asked again. That is merely annoying while developing, and it would
be much worse once the app updates itself, since every update would prompt every user.

A certificate replaces that hash with a stable requirement naming the certificate, which survives rebuilds. Apple's
[TN2206](https://developer.apple.com/library/archive/technotes/tn2206/_index.html) is explicit that the keychain cares
about stability rather than about who issued the certificate, so a self-signed one is enough.

### Creating the certificate

```sh
./scripts/create-signing-certificate.sh
```

It generates a self-signed code signing certificate, imports it into your login keychain, trusts it for code signing,
and prints the private key as base64 for the repository secrets. Then build with it:

```sh
SIGNING_IDENTITY="GitHub Notifications Signing" ./scripts/build.sh release
```

Releases are signed the same way. `.github/workflows/release.yml` imports the certificate from the
`SIGNING_CERTIFICATE_P12` and `SIGNING_CERTIFICATE_PASSWORD` secrets into a temporary keychain, and **fails the release**
rather than publishing a build that is unsigned or signed by anything else.

### Rotating the key

The Actions secret is the only copy of the private key. If it is lost or exposed:

1. Delete `GitHub Notifications Signing` from Keychain Access
2. Run `./scripts/create-signing-certificate.sh` again
3. Replace both repository secrets with the values it prints

The consequence is unavoidable: the designated requirement changes, so every installed copy re-asks for keychain access
once, and macOS treats the app as new for notification and open-at-login permission. It is the same one-off cost as the
move from ad-hoc signing.

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
