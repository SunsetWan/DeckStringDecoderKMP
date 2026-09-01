# Task 3.3 receiver provenance and semantic audit evidence

Recorded: 2026-09-01 (Asia/Shanghai)

## Immutable source completeness

The donor manifest remains byte-valid against clean detached commit `af490607cc79c5f28152537a375dd07adf9f099d`. Shared's provenance verifier resolved all 12 donor entries: four Kotlin production/test files are byte-identical with their Git blob SHA-256 values, and eight build/facade-context entries are explicitly reference-only rather than silently omitted. No extra donor path, nested Git metadata, Maven/KLIB/JAR, XCFramework, demo, workflow, or network source input entered `:deckstring`.

## Approved adaptation review

Shared final evidence commit is `2642442f485d784d1efd6c8d2cbc788be442b58d`; BobNote's immutable source gitlink remains the earlier complete build-input commit `4a14ecf03d6b9c2069c1b39e73f1df34cb825aca`. The later commits add acceptance/report evidence only.

The machine `deckstring-adaptation.json` intentionally freezes the Task 1.3 Kotlin-import phase, where the Swift facade was deferred. The final human report at `docs/provenance/deckstring-adaptation.md` has SHA-256 `6f0c3004b8d6d00d25514497a0c1917b1795c2f7858d58cb06638fb05845935c` and records the completed overlay path and hashes:

- donor facade SHA-256 `cf27da00384a662ec7e93f5cf5ec26b7aa2a8ceec2bb95bb0a73d93a597436e2`;
- receiver `swift-overlay/Sources/BobNoteShared/DeckString/DeckStringFacade.swift` SHA-256 `eef555259c3a2b4c7ca122e530449413c80a0489f938a0236489a1d76039f03c`.

Manual semantic review found only the approved module relocation, private Core bridge/model/error adapters, and preserved Swift numeric checks. Public type names, initializers, decode/encode, canonical sorting, sideboards, errors, Codable, Equatable, Hashable, and historical archive behavior are unchanged. Shared deckstring tests passed 21/21 on JVM and 21/21 on iOS; overlay Pod consumer tests passed 31/31 in both Debug and Release; BobNote passed 908/908 including the 35,807-card parity matrix. No behavior change is accepted by this ownership transfer.
