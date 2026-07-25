<p align="center">
  <img src="assets/banner.png" alt="GitHub Notifications" width="620" />
</p>

<p align="center">
  <a href="../../releases"><img src="https://img.shields.io/badge/Download-DMG-2ea44f?style=for-the-badge&logo=apple&logoColor=white" alt="Download" /></a>
  <a href="#install"><img src="https://img.shields.io/badge/macOS-26%2B-1f2328?style=for-the-badge" alt="macOS 26+" /></a>
  <a href="#contributing"><img src="https://img.shields.io/badge/Dependencies-0-8957e5?style=for-the-badge" alt="Zero dependencies" /></a>
  <a href="#licence"><img src="https://img.shields.io/badge/Licence-Source--available-yellow.svg?style=for-the-badge" alt="Source-available licence" /></a>
</p>

**GitHub's notifications are a bell that never rings.** This one rings: a real macOS notification the moment someone
requests your review, mentions you, or assigns you something, in private and organisation repositories too.

## Why this exists

GitHub built an inbox with a number on it and then made you go and look at the number. Everything else on your machine
can interrupt you. The one queue that decides whether other people can get on with their work cannot.

The workarounds are all worse:

- **The web inbox** tells you nothing until you open the tab, which you only do once you already suspect you have
  missed something.
- **Email** flattens a review request and a passing CI run into the same grey line, and you filter the whole lot into a
  folder by the second week.
- **GitHub Mobile** is the only official push there is, and it goes to your phone. You are already at the machine you
  would do the work on.
- **Browser extensions and Electron apps** either want a tab left open forever or ship an entire browser engine to draw
  a list of forty rows.

So: a native menu bar app. Swift and Apple frameworks, no dependencies, no backend, no account, no telemetry. It costs
nothing while your inbox is quiet, and it speaks up when it is not.

<!-- Screenshots: drop panel.png and settings.png into assets/ and uncomment.
| Inbox | Settings |
|:---:|:---:|
| <img src="assets/panel.png" alt="The menu bar panel, grouped by repository" width="100%" /> | <img src="assets/settings.png" alt="Notification settings, work hours and customisation" width="100%" /> |
| Grouped by repository, review requests first | Fifteen notification types, work hours, per-banner customisation |
-->

## Key features

- **Real desktop notifications**, delivered by macOS, so Notification Centre, your sounds and your Focus rules all
  apply.
- **Grouped by repository and ordered by urgency**, so review requests and mentions sit above CI noise rather than
  above whatever happened last.
- **Fifteen notification types you can switch individually**, or a preset if you would rather not.
- **Work hours**, holding notifications outside your hours and delivering them together when your next working day
  starts. Per-day schedules if your week is not uniform.
- **Banners you can change**: what each one shows, whether it stacks by repository, and which sound plays.
- **You decide what a click does**: mark it read and keep it in view, dismiss it, or both.
- **Links that open the right page**: a pull request opens at the pull request, a comment opens at the comment.
- **Private and organisation repositories**, including SAML single sign-on, with no administrator involved.

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

The app talks to two hosts, both GitHub's. `api.github.com` handles everything it reads or changes.
`avatars.githubusercontent.com` serves the owner avatars in the panel; those requests carry no token, and each avatar
is cached on your machine after the first fetch. There is no backend, no telemetry, and no account to create.

| What | Where it stands |
| :-- | :-- |
| **Your token** | Kept in the macOS keychain. Never written anywhere else, never logged. |
| **Where it goes** | `api.github.com` over HTTPS, as a bearer token. Avatar requests carry no token. |
| **What it can do** | Read your inbox, mark threads read or done, and read your username. |
| **What it cannot do** | Anything you have not granted. Revoke it on GitHub and the app stops working at once. |
| **Dependencies** | None. Swift and Apple frameworks only. |

GitHub requires a **classic** personal access token. The notification endpoints are not open to GitHub Apps, and
fine-grained tokens have no notifications permission at all. Fine-grained tokens also need organisation approval, where
a classic token you authorise for a SAML organisation yourself.

| Scope | Why it is needed |
| :-- | :-- |
| `notifications` | Read your inbox, and mark threads read or done. |
| `repo` | See notifications from private and organisation repositories. |
| `read:user` | Show which account you are signed in as. |

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

A clone builds without a certificate, ad-hoc signed, and warns that it has. That costs a keychain prompt on every
rebuild; the next section explains how to stop it.

<details>
<summary><b>Signing, and why a self-signed certificate is enough</b></summary>

The signature is not for Gatekeeper. A self-signed certificate does nothing for notarisation, and the quarantine step
above still applies. It is for the keychain.

When the app first reads your token, macOS records which program is allowed to read it, identified by its **designated
requirement** rather than its path. An ad-hoc signature's requirement is a hash of the built code, so it changes with
every build: macOS sees a different program, forgets **Always Allow**, and asks again. Annoying while developing, and
worse once the app updates itself, since every update would prompt every user.

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
both repository secrets with what it prints. The designated requirement changes when you do, so every installed copy
asks for keychain access once more, and macOS treats the app as new for notification and open-at-login permission.

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
