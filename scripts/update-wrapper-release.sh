#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <release-tag> <checksum> <wrapper-repo-dir>" >&2
  exit 64
fi

release_tag="$1"
checksum="$2"
wrapper_dir="$3"
wrapper_repo="SunsetWan/DeckStringDecoderKMPPackage"
artifact_name="DeckStringDecoder.xcframework.zip"
artifact_url="https://github.com/${wrapper_repo}/releases/download/${release_tag}/${artifact_name}"

if ! printf '%s\n' "$release_tag" | grep -Eq '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)-kmp\.[1-9][0-9]*$'; then
  echo "Release tag must match <semver>-kmp.<positive-integer>." >&2
  exit 1
fi

if [ ! -f "$wrapper_dir/Package.swift" ]; then
  echo "Wrapper repo Package.swift not found in $wrapper_dir" >&2
  exit 1
fi

if ! printf '%s' "$checksum" | grep -Eq '^[0-9a-f]{64}$'; then
  echo "Checksum must be a 64-character lowercase hex SwiftPM checksum." >&2
  exit 1
fi

ARTIFACT_URL="$artifact_url" CHECKSUM="$checksum" perl -0pi -e '
  s#url: "https://github\.com/SunsetWan/DeckStringDecoderKMPPackage/releases/download/[^"]+/DeckStringDecoder\.xcframework\.zip"#url: "$ENV{ARTIFACT_URL}"#g;
  s#checksum: "[0-9a-f]{64}"#checksum: "$ENV{CHECKSUM}"#g;
' "$wrapper_dir/Package.swift"

cat > "$wrapper_dir/README.md" <<EOF
# DeckStringDecoderKMPPackage

SwiftPM binary package wrapper for the KMP/SKIE build of \`DeckStringDecoder\`.

This repository is the public SwiftPM entry point. The KMP source repository remains responsible for Kotlin Multiplatform source, tests, XCFramework generation, and release automation.

## Installation

Add this package in Xcode or SwiftPM:

\`\`\`text
https://github.com/SunsetWan/DeckStringDecoderKMPPackage.git
\`\`\`

Use version:

\`\`\`text
${release_tag}
\`\`\`

Import the module as before:

\`\`\`swift
import DeckStringDecoder
\`\`\`

## Platform Scope

The current binary artifact contains iOS device and iOS Simulator slices only. It does not currently include macOS, watchOS, tvOS, or visionOS slices.

## Artifact

- Release tag: \`${release_tag}\`
- Asset: \`${artifact_name}\`
- URL: \`${artifact_url}\`
- Checksum: \`${checksum}\`

The SwiftPM manifest uses:

\`\`\`swift
.binaryTarget(
    name: "DeckStringDecoder",
    url: "${artifact_url}",
    checksum: "${checksum}"
)
\`\`\`

## Updating a Release

Releases are generated from \`DeckStringDecoderKMP\` through its manual release workflow. That workflow builds the XCFramework zip, verifies checksum and module interface contents, updates this wrapper repo, creates the GitHub Release, uploads \`${artifact_name}\`, downloads it from the public URL, and runs the public consumer tests.

## Verification

This repository includes a minimal public consumer under \`Verification/Consumer\`. After the release asset exists, run:

\`\`\`sh
scripts/verify-public-consumer.sh
\`\`\`

The consumer verifies \`import DeckStringDecoder\`, \`DeckStringDecoder()\` construction, decode, encode round trip, sideboard decoding, error mapping, and native Swift model conformances through the Swift-facing API only.
EOF

changelog="$wrapper_dir/CHANGELOG.md"
tmp_changelog="$(mktemp)"
{
  printf '# Changelog\n\n'
  printf '## %s\n\n' "$release_tag"
  printf -- '- Updated the SwiftPM binary target URL to `%s`.\n' "$artifact_url"
  printf -- '- Updated the SwiftPM checksum to `%s`.\n' "$checksum"
  printf -- '- Release automation verified the local artifact, public download checksum, and public consumer tests.\n\n'
  if [ -f "$changelog" ]; then
    tail -n +2 "$changelog" | sed '/^$/N;/^\n$/D'
  fi
} > "$tmp_changelog"
mv "$tmp_changelog" "$changelog"

mkdir -p "$wrapper_dir/releases"
cat > "$wrapper_dir/releases/${release_tag}.md" <<EOF
# DeckStringDecoderKMPPackage ${release_tag}

## Artifact

- Asset: \`${artifact_name}\`
- URL: \`${artifact_url}\`
- Checksum: \`${checksum}\`

## Verification

- KMP iOS simulator tests run in \`DeckStringDecoderKMP\`.
- SwiftPM binary artifact zip structure and checksum are verified.
- Device and simulator slices are checked for \`.swiftinterface\` files.
- Local SwiftPM binary consumer tests run before publishing.
- Device and simulator binaries retain the source-package equality entry points needed for incremental replacement.
- The public release asset is downloaded and checksum-verified after upload.
- Public SwiftPM consumer tests run through \`DeckStringDecoderKMPPackage\`.
EOF

verification_package="$wrapper_dir/Verification/Consumer/Package.swift"
if [ -f "$verification_package" ]; then
  RELEASE_TAG="$release_tag" perl -0pi -e 's#exact: "[^"]+"#exact: "$ENV{RELEASE_TAG}"#g' "$verification_package"
fi

rm -f "$wrapper_dir/Verification/Consumer/Package.resolved"

mkdir -p "$wrapper_dir/scripts"
cat > "$wrapper_dir/scripts/verify-public-consumer.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONSUMER_DIR="$REPO_ROOT/Verification/Consumer"
IOS_SIMULATOR_DESTINATION="${IOS_SIMULATOR_DESTINATION:-platform=iOS Simulator,name=iPhone 17}"

cd "$CONSUMER_DIR"

xcodebuild \
  -scheme DeckStringDecoderPublicConsumer \
  -destination "$IOS_SIMULATOR_DESTINATION" \
  -derivedDataPath .build/xcode-derived-data \
  test
EOF

chmod +x "$wrapper_dir/scripts/verify-public-consumer.sh"
