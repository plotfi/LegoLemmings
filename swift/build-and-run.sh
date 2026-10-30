#!/bin/bash
# Builds and runs the Swift/AppKit port. Assets are read from ../assets.
set -e
cd "$(dirname "$0")"
swift build -c release
exec .build/release/LegoLemmings "$@"
