#!/usr/bin/env bash
# Builds GitHubNotifications.app into build/Build/Products/<configuration>/.
#
# Usage: scripts/build.sh [debug|release] [extra xcodebuild settings...]

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

CONFIGURATION="Debug"

if [[ "${1:-debug}" == "release" ]]; then
  CONFIGURATION="Release"
fi

shift || true

run_xcodebuild -configuration "${CONFIGURATION}" "$@" build

echo "Built ${DERIVED_DATA}/Build/Products/${CONFIGURATION}/GitHubNotifications.app"
