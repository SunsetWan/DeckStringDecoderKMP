# deckstring-kmp-skie-distribution Specification

## Purpose
TBD - created by archiving change make-skie-distributable-framework. Update Purpose after archive.
## Requirements
### Requirement: 单 Framework SKIE 分发产物
The project SHALL produce a single SKIE-built `DeckStringDecoder.xcframework` that contains the Kotlin common core and the bundled Swift facade required by Swift consumers.

#### Scenario: Framework contains Swift facade and Kotlin core
- **WHEN** release `DeckStringDecoder.xcframework` is assembled
- **THEN** the framework SHALL expose Swift facade symbols for `DeckFormat`、`Card`、`SideboardCard`、`Deck`、`DeckStringError` 和 `DeckStringDecoder`
- **THEN** the same framework SHALL contain the Kotlin bridge required by those facade symbols

#### Scenario: Framework keeps distributable Swift interfaces
- **WHEN** the release XCFramework is inspected after assembly
- **THEN** its device and simulator slices SHALL retain generated `.swiftinterface` files
- **THEN** no build step SHALL delete `.swiftinterface` files or copy `.swiftmodule` files as a distribution workaround

#### Scenario: Swift interface workaround is reviewable
- **WHEN** the build uses a workaround for Swift textual interface generation
- **THEN** the workaround SHALL keep `verify-emitted-module-interface` enabled
- **THEN** the workaround SHALL be documented in this change's `design.md` with its purpose, boundary, and removal criteria
- **THEN** the workaround SHALL NOT rely on `-no-verify-emitted-module-interface`, disabling Swift library evolution as the final distribution strategy, or post-build mutation of `.swiftinterface` / `.swiftmodule` files

### Requirement: 未修补 XCFramework consumer 验证
The release XCFramework SHALL be validated by an external consumer that imports the original build output without local patching.

#### Scenario: Minimal consumer imports framework
- **WHEN** a minimal SwiftPM or Xcode consumer links the generated release `DeckStringDecoder.xcframework`
- **THEN** it SHALL compile with `import DeckStringDecoder`
- **THEN** it SHALL instantiate the public Swift decoder API without importing Kotlin/Native implementation types in consumer code

#### Scenario: Minimal consumer executes deckstring workflow
- **WHEN** the minimal consumer runs decode、encode、error mapping、sideboard and round-trip checks through the public Swift facade
- **THEN** all checks SHALL pass against the unmodified release XCFramework

### Requirement: iOS demo uses original SKIE framework
The `ios_demo` app SHALL consume the generated SKIE framework through a maintainable build path that does not patch Swift module artifacts after assembly.

#### Scenario: Demo build does not patch Swift module files
- **WHEN** `ios_demo/DeckCodeDecoderKMPDemo` builds for iOS simulator
- **THEN** its build phase SHALL NOT delete `.swiftinterface` files
- **THEN** its build phase SHALL NOT copy `.swiftmodule` files from `deckstring/build/bin` into the XCFramework

#### Scenario: Demo build has explicit Java and Gradle behavior
- **WHEN** the demo build phase invokes Gradle
- **THEN** it SHALL use documented Java resolution or a clear `JAVA_HOME` requirement
- **THEN** it SHALL avoid unconditional rebuilds when Xcode input/output file declarations can make the build incremental
