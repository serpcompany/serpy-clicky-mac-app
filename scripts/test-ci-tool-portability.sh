#!/bin/zsh
set -euo pipefail

system_path=/usr/bin:/bin:/usr/sbin:/sbin
safety_scripts=(
  scripts/run-headless-check.sh
  scripts/test-headless-check.sh
)

if /usr/bin/grep -En '(^|[[:space:]])rg([[:space:]]|$)' "${safety_scripts[@]}"; then
  print -u2 "CI safety scripts must use macOS system tools, not ripgrep"
  exit 1
fi

env PATH="$system_path" scripts/test-headless-check.sh
print "system-PATH CI safety checks: PASS"
