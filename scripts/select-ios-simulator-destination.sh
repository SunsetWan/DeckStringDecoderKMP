#!/usr/bin/env bash
set -euo pipefail

if [ -n "${IOS_SIMULATOR_DESTINATION:-}" ]; then
  printf '%s\n' "$IOS_SIMULATOR_DESTINATION"
  exit 0
fi

preferred_device="iPhone 17"
if xcrun simctl list devices available | grep -q "${preferred_device} ("; then
  printf 'platform=iOS Simulator,name=%s\n' "$preferred_device"
  exit 0
fi

device_name="$(
  xcrun simctl list devices available |
    awk '/-- iOS/{in_ios = 1; next} /^-- /{in_ios = 0} in_ios && /iPhone/ && /\((Booted|Shutdown)\)/ { print; exit }' |
    sed -E 's/^[[:space:]]*//; s/ \([A-F0-9-]+\) \((Booted|Shutdown)\)$//'
)"

if [ -z "$device_name" ]; then
  echo "No available iPhone simulator was found." >&2
  exit 1
fi

printf 'platform=iOS Simulator,name=%s\n' "$device_name"
