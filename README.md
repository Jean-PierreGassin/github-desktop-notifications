# GitHub Notifications for macOS

A minimal menu bar app that watches your GitHub notification inbox and raises a native macOS notification when
something that matters arrives. Private and organisation repositories included.

GitHub's web inbox never triggers a desktop notification. This does.

## Why it polls

There is no push. GitHub has no user-level webhook, no SSE stream, no WebSocket and no GraphQL subscription for the
notification inbox. Webhooks are repository or organisation scoped, need a public endpoint, and do not carry inbox
semantics.

What GitHub does support is conditional polling: `GET /notifications` with an `If-Modified-Since` header returns
`304 Not Modified` when nothing has changed, which costs nothing against the 5000 requests/hour rate limit, and the
response carries an `X-Poll-Interval` header telling clients how often they may ask. This app obeys that header, so
notifications arrive within about a minute and rate limit usage stays near zero.

## Authentication

A classic personal access token, created by you, stored in your macOS keychain, sent only to `api.github.com`.

| Scope | Why |
| --- | --- |
| `notifications` | Read your inbox and mark threads as read |
| `repo` | See notifications from private and organisation repositories |
| `read:user` | Show which account you are signed in as |

The app links you to a token creation page with these pre-selected. Nothing else is required: no OAuth app to
register, no GitHub App to install, and no organisation admin involvement. If an organisation enforces SAML single
sign-on, press **Configure SSO** on your token afterwards and authorise it yourself.

Fine-grained tokens and GitHub Apps cannot be used here: GitHub does not expose the notifications endpoints to either.

## Build it yourself

Requires Xcode 26 or newer on macOS 14 or newer.

```sh
git clone https://github.com/<you>/github-desktop-notifications.git
cd github-desktop-notifications
./scripts/build.sh release
open build/Build/Products/Release/GitHubNotifications.app
```

Run the tests with `./scripts/test.sh`.

## Install a release

Download the zip from [Releases](../../releases), unzip, and move `GitHubNotifications.app` to `/Applications`.

The app is ad-hoc signed and **not notarised**, because notarisation needs a paid Apple Developer ID. macOS will
therefore quarantine the download. Open it once with right-click → **Open**, or clear the flag yourself:

```sh
xattr -d com.apple.quarantine /Applications/GitHubNotifications.app
```

Building from source avoids this entirely.

## First run

1. Click the menu bar icon and follow the sign-in steps
2. Allow notifications when macOS asks. If you dismiss the prompt, re-enable the app under
   System Settings → Notifications; the panel links you straight there

## Licence

MIT. The menu bar glyph is original artwork; this project is not affiliated with or endorsed by GitHub.
