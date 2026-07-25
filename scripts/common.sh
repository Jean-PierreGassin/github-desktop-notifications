#!/usr/bin/env bash
# Shared xcodebuild wrapper.
#
# Toolchain environment variables set by other package managers (nix, homebrew
# shells, direnv) make xcodebuild link with the wrong linker and SDK, so they are
# stripped before every invocation.

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="${PROJECT_ROOT}/GitHubNotifications.xcodeproj"
SCHEME="GitHubNotifications"
DERIVED_DATA="${PROJECT_ROOT}/build"

## Resolves a real Xcode toolchain, ignoring a DEVELOPER_DIR pointing at a
## standalone SDK that cannot build app bundles.
resolve_developer_dir() {
  if [[ "${DEVELOPER_DIR:-}" == *"Xcode.app"* ]]; then
    echo "${DEVELOPER_DIR}"
  elif [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
    echo "/Applications/Xcode.app/Contents/Developer"
  else
    xcode-select --print-path
  fi
}

run_xcodebuild() {
  env \
    -u LD -u CC -u CXX -u SDKROOT -u MACOSX_DEPLOYMENT_TARGET \
    -u CFLAGS -u LDFLAGS -u NIX_CFLAGS_COMPILE -u NIX_LDFLAGS \
    -u NIX_CC -u NIX_BINTOOLS -u NIX_HARDENING_ENABLE \
    DEVELOPER_DIR="$(resolve_developer_dir)" \
    xcodebuild \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -derivedDataPath "${DERIVED_DATA}" \
    "$@"
}
