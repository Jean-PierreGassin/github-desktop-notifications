#!/usr/bin/env bash
# Builds GitHubNotifications.app into build/Build/Products/<configuration>/.
#
# Signs with SIGNING_IDENTITY when it is set, so a fresh clone still builds
# without the certificate. It costs a keychain prompt per rebuild, hence the
# warning.
#
# Usage: scripts/build.sh [debug|release] [extra xcodebuild settings...]

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

CONFIGURATION="Debug"

if [[ "${1:-debug}" == "release" ]]; then
  CONFIGURATION="Release"
fi

shift || true

if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  set -- "CODE_SIGN_IDENTITY=${SIGNING_IDENTITY}" "$@"
else
  echo "warning: SIGNING_IDENTITY is unset, building ad-hoc." >&2
  echo "         macOS will re-prompt for keychain access after every rebuild." >&2
fi

run_xcodebuild -configuration "${CONFIGURATION}" "$@" build

echo "Built ${DERIVED_DATA}/Build/Products/${CONFIGURATION}/GitHub Notifications.app"
