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
artifact_name="DeckStringRuntime.xcframework.zip"
artifact_url="https://github.com/${wrapper_repo}/releases/download/${release_tag}/${artifact_name}"

if [ ! -f "$wrapper_dir/Package.swift" ]; then
  echo "Wrapper repo Package.swift not found in $wrapper_dir" >&2
  exit 1
fi

if ! printf '%s' "$checksum" | grep -Eq '^[0-9a-f]{64}$'; then
  echo "Checksum must be a 64-character lowercase hex SwiftPM checksum." >&2
  exit 1
fi

source_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$source_root/swiftpm-binary" "$wrapper_dir" "$artifact_url" "$checksum" <<'PYTHON'
from pathlib import Path
import shutil
import sys
source, target = map(Path, sys.argv[1:3])
url, checksum = sys.argv[3:5]
manifest = (source / "Package.swift").read_text()
local_artifact = 'path: "Artifacts/DeckStringRuntime.xcframework.zip"'
assert manifest.count(local_artifact) == 1
manifest = manifest.replace(local_artifact, f'url: "{url}", checksum: "{checksum}"')
(target / "Package.swift").write_text(manifest)
for directory in ("Sources", "Tests"):
    shutil.copytree(source / directory, target / directory, dirs_exist_ok=True)
PYTHON

cat > "$wrapper_dir/README.md" <<EOF
# DeckStringDecoderKMPPackage

SwiftPM source facade and portable model contract for the KMP deck codec.

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

The \`DeckStringModels\` source product supports macOS 14 and iOS 15. The \`DeckStringDecoder\` facade and \`DeckStringRuntime\` binary support iOS only.

The facade uses aliases to the portable model types. Consumers must rebuild: moving these public types changes nominal module identity and is not an ABI-compatible binary replacement. JSON fields, integer formats, required-field failures, and value ordering retain their existing behavior.

Swift sources are generated from \`DeckStringDecoderKMP/swiftpm-binary/Sources\`. Make source changes there; do not maintain separate model implementations in this distribution repository.

## Artifact

- Release tag: \`${release_tag}\`
- Asset: \`${artifact_name}\`
- URL: \`${artifact_url}\`
- Checksum: \`${checksum}\`

The SwiftPM manifest uses:

\`\`\`swift
.binaryTarget(
    name: "DeckStringRuntime",
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

The consumer verifies \`import DeckStringDecoder\`, \`DeckStringDecoder()\` construction, decode, encode round trip, sideboard decoding, and error mapping through the Swift-facing API only.
EOF

changelog="$wrapper_dir/CHANGELOG.md"
tmp_changelog="$(mktemp)"
{
  printf '# Changelog\n\n'
  printf '## %s\n\n' "$release_tag"
  printf -- '- Updated the SwiftPM binary target URL to `%s`.\n' "$artifact_url"
  printf -- '- Updated the SwiftPM checksum to `%s`.\n' "$checksum"
  printf -- '- Release automation must verify the local artifact, public download checksum, and public consumer tests.\n\n'
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
- Device and simulator slices are checked for Kotlin bridge headers, module maps, and binaries.
- Portable model tests run on macOS. Swift facade and consumer tests run on iOS.
- The source facade is compiled by the consumer toolchain; model type identity moves to \`DeckStringModels\` and requires recompilation.
- Local SwiftPM binary consumer tests run before publishing.
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

test "$(xcsift --version)" = "1.3.2-sunset.2"
xcodebuild \
  -scheme DeckStringDecoderPublicConsumer \
  -destination "$IOS_SIMULATOR_DESTINATION" \
  -derivedDataPath .build/xcode-derived-data \
  test 2>&1 | xcsift --exit-on-failure
EOF

chmod +x "$wrapper_dir/scripts/verify-public-consumer.sh"
