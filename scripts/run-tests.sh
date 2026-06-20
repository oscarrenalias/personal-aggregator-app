#!/usr/bin/env bash
# Test gate for takt merges and CI: regenerate the (gitignored) Xcode project
# from project.yml so any newly added source files are included, then run tests.
# takt invokes test_command without a shell, so chaining lives here, not in config.
set -euo pipefail
xcodegen generate
xcodebuild test \
  -project AggregatorApp.xcodeproj \
  -scheme AggregatorApp \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  -quiet
