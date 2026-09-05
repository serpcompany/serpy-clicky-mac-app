#!/bin/zsh
set -euo pipefail

system_path=/usr/bin:/bin:/usr/sbin:/sbin
safety_scripts=(
  scripts/run-headless-check.sh
  scripts/test-headless-check.sh
  scripts/run-golden-ui-test.sh
  scripts/test-golden-ui-runner.sh
)

if /usr/bin/grep -En '(^|[[:space:]])rg([[:space:]]|$)' "${safety_scripts[@]}"; then
  print -u2 "CI safety scripts must use macOS system tools, not ripgrep"
  exit 1
fi

env PATH="$system_path" scripts/test-headless-check.sh
env PATH="$system_path" scripts/test-golden-ui-runner.sh
print "system-PATH CI safety checks: PASS"
