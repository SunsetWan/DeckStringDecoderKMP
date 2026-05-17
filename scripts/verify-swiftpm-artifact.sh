#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <DeckStringDecoder.xcframework.zip> <checksum-file>" >&2
  exit 64
fi

artifact_path="$1"
checksum_file="$2"

if [ ! -f "$artifact_path" ]; then
  echo "Artifact not found: $artifact_path" >&2
  exit 1
fi

if [ ! -f "$checksum_file" ]; then
  echo "Checksum file not found: $checksum_file" >&2
  exit 1
fi

expected_checksum="$(tr -d '[:space:]' < "$checksum_file")"
actual_checksum="$(swift package compute-checksum "$artifact_path" | tr -d '[:space:]')"

if [ "$actual_checksum" != "$expected_checksum" ]; then
  echo "Checksum mismatch." >&2
  echo "Expected: $expected_checksum" >&2
  echo "Actual:   $actual_checksum" >&2
  exit 1
fi

entries="$(zipinfo -1 "$artifact_path")"
top_levels="$(printf '%s\n' "$entries" | awk -F/ 'NF > 0 && $1 != "" { print $1 }' | sort -u)"

if [ "$top_levels" != "DeckStringDecoder.xcframework" ]; then
  echo "Unexpected zip top-level entries:" >&2
  printf '%s\n' "$top_levels" >&2
  exit 1
fi

if ! printf '%s\n' "$entries" | grep -Eq '^DeckStringDecoder\.xcframework/ios-arm64/DeckStringDecoder\.framework/Modules/DeckStringDecoder\.swiftmodule/.+\.swiftinterface$'; then
  echo "Device slice is missing DeckStringDecoder.swiftinterface." >&2
  exit 1
fi

if ! printf '%s\n' "$entries" | grep -Eq '^DeckStringDecoder\.xcframework/ios-.+-simulator/DeckStringDecoder\.framework/Modules/DeckStringDecoder\.swiftmodule/.+\.swiftinterface$'; then
  echo "Simulator slice is missing DeckStringDecoder.swiftinterface." >&2
  exit 1
fi

printf 'Verified %s\n' "$artifact_path"
