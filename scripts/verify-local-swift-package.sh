#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
package_dir="$repo_root/swiftpm-binary"
result_root="${SWIFT_VERIFICATION_RESULTS:-$repo_root/build/swift-verification/$(date +%Y%m%d-%H%M%S)}"
destination="${IOS_SIMULATOR_DESTINATION:-platform=iOS Simulator,name=iPhone 17}"
mkdir -p "$result_root"
swift test --package-path "$package_dir" 2>&1 | tee "$result_root/macos.log"
verify_ios() {
    local directory="$1" scheme="$2" name="$3"
    test "$(xcsift --version)" = "1.3.2-sunset.2"
    (cd "$directory" && xcodebuild -scheme "$scheme" -destination "$destination" \
        -resultBundlePath "$result_root/$name.xcresult" test 2>&1) \
        | tee "$result_root/$name.log" | xcsift --exit-on-failure
    xcrun xcresulttool get test-results summary --path "$result_root/$name.xcresult" \
        > "$result_root/$name-summary.json"
}
verify_ios "$package_dir" DeckStringDecoderKMPPackage-Package contract
verify_ios "$package_dir/consumer" DeckStringDecoderBinaryConsumer consumer
