#!/usr/bin/env bash
# Runs the unit test suite.
#
# Usage: scripts/test.sh

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

run_xcodebuild -configuration Debug test
