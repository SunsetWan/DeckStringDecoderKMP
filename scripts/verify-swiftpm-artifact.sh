#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <DeckStringRuntime.xcframework.zip> <checksum-file>" >&2
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

if [ "$top_levels" != "DeckStringRuntime.xcframework" ]; then
  echo "Unexpected zip top-level entries:" >&2
  printf '%s\n' "$top_levels" >&2
  exit 1
fi

for slice in ios-arm64 ios-arm64_x86_64-simulator; do
  for member in Headers/DeckStringRuntime.h Modules/module.modulemap DeckStringRuntime; do
    if ! printf '%s\n' "$entries" | grep -Fxq "DeckStringRuntime.xcframework/$slice/DeckStringRuntime.framework/$member"; then
      echo "Missing runtime artifact member: $slice/$member" >&2
      exit 1
    fi
  done
done

printf 'Verified %s\n' "$artifact_path"
