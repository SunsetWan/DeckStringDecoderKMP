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

if printf '%s\n' "$entries" | grep -Eq '(^|/)\.\.(/|$)|^/'; then
  echo "Artifact contains an unsafe zip path." >&2
  exit 1
fi

verification_dir="$(mktemp -d "${TMPDIR:-/tmp}/deckstring-artifact-verification.XXXXXX")"
cleanup() {
  rm -rf -- "$verification_dir"
}
trap cleanup EXIT

ditto -x -k "$artifact_path" "$verification_dir"

compatibility_symbols=(
  '_$s17DeckStringDecoder4CardV23__derived_struct_equalsySbAC_ACtFZ'
  '_$s17DeckStringDecoder13SideboardCardV23__derived_struct_equalsySbAC_ACtFZ'
  '_$s17DeckStringDecoder0A0V23__derived_struct_equalsySbAC_ACtFZ'
  '_$s17DeckStringDecoder0aB5ErrorO21__derived_enum_equalsySbAC_ACtFZ'
)

framework_count=0
while IFS= read -r framework_binary; do
  framework_count=$((framework_count + 1))
  exported_symbols="$(nm -gj "$framework_binary")"
  for symbol in "${compatibility_symbols[@]}"; do
    if ! printf '%s\n' "$exported_symbols" | grep -Fqx "$symbol"; then
      echo "Missing source-package compatibility symbol in $framework_binary:" >&2
      echo "$symbol" >&2
      exit 1
    fi
  done
done < <(
  find "$verification_dir/DeckStringDecoder.xcframework" \
    -type f \
    -path '*/DeckStringDecoder.framework/DeckStringDecoder' \
    -print
)

if [ "$framework_count" -lt 2 ]; then
  echo "Expected at least device and simulator framework binaries." >&2
  exit 1
fi

printf 'Verified %s\n' "$artifact_path"
