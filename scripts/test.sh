#!/usr/bin/env bash
set -euo pipefail

# Runs the unit test suite.
#
# Usage: scripts/test.sh [debug|release] [extra xcodebuild settings...]

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

CONFIGURATION="$(resolve_configuration "${1:-debug}")" || {
  printf '%s\n' "usage: scripts/test.sh [debug|release] [extra xcodebuild settings...]" >&2
  exit 2
}

if (( $# > 0 )); then
  shift
fi

run_xcodebuild -configuration "${CONFIGURATION}" "$@" test
