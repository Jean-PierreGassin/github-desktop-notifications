<p align="center">
  <img src="assets/banner.png" alt="GitHub Notifications" width="620" />
</p>

<p align="center">
  <a href="../../releases"><img src="https://img.shields.io/badge/Download-DMG-2ea44f?style=for-the-badge&logo=apple&logoColor=white" alt="Download" /></a>
  <a href="#install"><img src="https://img.shields.io/badge/macOS-26%2B-1f2328?style=for-the-badge" alt="macOS 26+" /></a>
  <a href="#contributing"><img src="https://img.shields.io/badge/Dependencies-0-8957e5?style=for-the-badge" alt="Zero dependencies" /></a>
  <a href="#licence"><img src="https://img.shields.io/badge/Licence-Source--available-yellow.svg?style=for-the-badge" alt="Source-available licence" /></a>
</p>

**GitHub Notifications** raises a real desktop notification the moment someone requests your review, mentions you, or
assigns you something. Private and organisation repositories included. GitHub's web inbox never does.

## Why this exists

GitHub will not interrupt you. The one inbox that gates other people's work is the only thing on your machine you have
to remember to go and check. Every way round that gives something up:

- **The web inbox:** raises nothing at all. You find out about a review request by deciding to look for one.
- **Email:** everything lands in the same pile, with no distinction between a review request and a CI run, and it stops
  being a signal by the second week.
- **GitHub Mobile:** the only official push GitHub ships. It requires picking up your phone, which is the opposite of
  what you want while sitting at the machine you would do the work on.
- **Browser extensions and Electron wrappers:** a tab that has to stay open, or a hundred megabytes of Chromium to
  render a list of forty rows.

So this is the native one: Swift and Apple frameworks, no dependencies, no backend, no account, no telemetry. It sits in
the menu bar, costs effectively nothing while your inbox is quiet, and interrupts you exactly as much as you tell it to.

<!-- Screenshots: drop panel.png and settings.png into assets/ and uncomment.
| Inbox | Settings |
|:---:|:---:|
| <img src="assets/panel.png" alt="The menu bar panel, grouped by repository" width="100%" /> | <img src="assets/settings.png" alt="Notification settings, work hours and customisation" width="100%" /> |
| Grouped by repository, review requests first | Fifteen notification types, work hours, per-banner customisation |
-->

## Key features

- **Real desktop notifications:** delivered by macOS, in Notification Centre, with your sounds and your Focus rules.
- **Grouped by repository, ordered by urgency:** review requests and mentions sort above CI noise, never by timestamp.
- **Fifteen notification types, individually switchable:** take a preset, or decide exactly which reasons are allowed to
  interrupt you.
- **Work hours:** hold notifications outside your hours and deliver them together when the next working day starts,
  with per-day schedules if your week is not uniform.
- **Customisable banners:** decide what each one shows, whether it stacks by repository, and which sound plays.
- **Links that land:** mark read or dismiss from the panel, or click through to exactly the right page. A pull request
  opens at the pull request, a comment opens at the comment.
- **Private and organisation repositories:** SAML single sign-on supported, with no administrator involved.
- **Nothing between you and GitHub:** one host, `api.github.com`. No backend, no account, no telemetry.

## Install

Requires macOS 26 or newer.

Download the latest DMG from [Releases](../../releases) and drag `GitHub Notifications.app` to `/Applications`. The zip
beside it is what the app's own updater downloads; either works.

Releases are signed with a self-signed certificate and **not notarised**, because notarisation requires a paid Apple
Developer ID. macOS will quarantine the download. Open it once with right-click → **Open**, or clear the flag:

```sh
xattr -d com.apple.quarantine "/Applications/GitHub Notifications.app"
```

Building from source avoids this entirely.

## Setup

1. Click the menu bar icon. The sign-in panel links you to GitHub's classic token page with the right scopes and
   *No expiration* already selected.
2. Paste the token. If it is already on your clipboard, the field fills itself.
3. Allow notifications when macOS asks.

If an organisation enforces SAML single sign-on, press **Configure SSO** on the token afterwards and authorise it. No
organisation administrator is involved in that step.

## How it works

There is no push. GitHub has no user-level webhook, no event stream, and no subscription API for the notification
inbox. Webhooks are repository-scoped and carry no inbox semantics.

What GitHub does support is conditional polling, and it is explicit about how: send `If-Modified-Since` with the
previous `Last-Modified`, receive `304 Not Modified` when nothing has changed, and obey the `X-Poll-Interval` header. A
`304` costs nothing against your rate limit.

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
which classic tokens do not: you authorise your own token for a SAML organisation yourself, without an administrator.

| Scope | Why |
| --- | --- |
| `notifications` | Read your inbox and mark threads as read |
| `repo` | See notifications from private and organisation repositories |
| `read:user` | Show which account you are signed in as |

Use `public_repo` instead of `repo` if you only care about public repositories.

## Build from source

Requires Xcode 26 or newer, on macOS 26 or newer.

```sh
git clone https://github.com/Jean-PierreGassin/github-desktop-notifications.git
cd github-desktop-notifications
./scripts/build.sh release
open "build/Build/Products/Release/GitHub Notifications.app"
```

Run the test suite with `./scripts/test.sh`.

A clone builds without any certificate, ad-hoc signed, and the build warns when it does. That costs you a keychain
prompt on every rebuild, which the next section explains how to stop.

<details>
<summary><b>Signing, and why a self-signed certificate is enough</b></summary>

The signature is not for Gatekeeper. A self-signed certificate does nothing for notarisation, and the quarantine step
above still applies. It is for the keychain.

When the app first reads your token, macOS records an access control list entry naming the program allowed to read it.
The program is identified by its **designated requirement**, not its path. An ad-hoc signature's designated requirement
is a hash of the built code, so it changes on every single build, and macOS treats the next build as a different
program: **Always Allow** is forgotten, and you are asked again. That is merely annoying while developing, and it would
be much worse once the app updates itself, since every update would prompt every user.

A certificate replaces that hash with a stable requirement naming the certificate, which survives rebuilds. Apple's
[TN2206](https://developer.apple.com/library/archive/technotes/tn2206/_index.html) is explicit that the keychain cares
about stability rather than about who issued the certificate, so a self-signed one is enough.

```sh
./scripts/create-signing-certificate.sh
SIGNING_IDENTITY="GitHub Notifications Signing" ./scripts/build.sh release
```

The script generates a self-signed code signing certificate, imports it into your login keychain, trusts it for code
signing, and prints the private key as base64 for the repository secrets.

Releases are signed the same way. `.github/workflows/release.yml` imports the certificate from the
`SIGNING_CERTIFICATE_P12` and `SIGNING_CERTIFICATE_PASSWORD` secrets into a temporary keychain, and **fails the
release** rather than publishing a build that is unsigned or signed by anything else.

**Rotating the key.** The Actions secret is the only copy of the private key. If it is lost or exposed, delete
`GitHub Notifications Signing` from Keychain Access, run `./scripts/create-signing-certificate.sh` again, and replace
both repository secrets with the values it prints. The consequence is unavoidable: the designated requirement changes,
so every installed copy re-asks for keychain access once, and macOS treats the app as new for notification and
open-at-login permission. It is the same one-off cost as the move from ad-hoc signing.

</details>

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

The banner and the app icon are drawn from the same geometry as the menu bar glyph, by
`scripts/generate-banner.swift` and `scripts/generate-app-icon.swift`. Edit the script rather than the PNG.

## Licence

Copyright (c) 2026 Jean-Pierre Gassin. Source-available, not open source: read [LICENSE](LICENSE) for the exact terms.

The short version. Use it, at home or at work. Change it. Share it. Send patches, they are welcome. What you may not do
is make money from it: no selling copies, no charging for access, no bundling it into something you sell, no paid
hosting of it. If you want to do any of that, ask.

The menu bar glyph, app icon and banner are original artwork under the same terms. This project is not affiliated with
or endorsed by GitHub.
