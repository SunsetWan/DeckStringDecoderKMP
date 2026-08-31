# Task 5.1 final verification evidence

Recorded: 2026-09-01 (Asia/Shanghai)

- Donor manifest validation passed against the clean detached baseline worktree at exact commit `af490607cc79c5f28152537a375dd07adf9f099d`.
- Receiver acceptance validation returned `accepted`.
- Handoff and documentation automation passed 7/7 tests. Generated Python caches were moved to a temporary recovery directory and are not part of the change.
- `./gradlew :deckstring:jvmTest :deckstring:iosSimulatorArm64Test --console=plain` succeeded. Test XML records JVM 21/21 and iOS Simulator arm64 21/21, with zero skipped, failures, or errors.
- `./gradlew :deckstring:verifyDeckStringDecoderSwiftPMConsumer --console=plain` succeeded; the retained consumer passed 3/3 with zero failures. The freshly rebuilt artifact and checksum matched `7e1a72f27245deb582adab0459ee7f10095cf5a04b6c17ff21bfe6d9add60806`, and `scripts/verify-swiftpm-artifact.sh` passed. This is donor-retention evidence, not a new BobNote release.
- In an isolated donor clone, `--write-verification-metadata sha256` generated the same 101-component metadata SHA-256 `ed5c73013243ae5153f7c1f114d27103dff3c6d6a89a8120a4f96e4c8249513f`; strict dependency verification then reran JVM/iOS gates successfully. The first orchestration attempt ran from the wrong directory without fail-fast and is explicitly discarded; the accepted rerun used the clone as cwd with `set -euo pipefail`.
- `./gradlew --offline --version` confirmed Gradle 9.3.0 and Java 21.0.11; wrapper JAR SHA-256 remained `b3a875ddc1f044746e1b1a55f645584505f4a10438c1afea9f15e92a7c42ec13`.
- Source/build/demo/workflow diff audit was empty, `git diff --check` passed, and only handoff/OpenSpec/README inputs belong to this change.
