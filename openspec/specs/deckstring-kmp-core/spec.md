# deckstring-kmp-core Specification

## Purpose
TBD - created by archiving change migrate-deckstring-core-to-kmp. Update Purpose after archive.
## Requirements
### Requirement: Kotlin common deck model
KMP core SHALL provide Kotlin common model types for deck format, cards, sideboard cards, and decks, and deck construction SHALL produce canonical ordering compatible with the current Swift model.

#### Scenario: Deck construction sorts canonical fields
- **WHEN** a `KmpDeck` is constructed with unsorted heroes, cards, and sideboard cards
- **THEN** heroes SHALL be sorted ascending, cards SHALL be sorted by `dbfId`, and sideboard cards SHALL be sorted by `sideboardOwner` then `dbfId`

#### Scenario: Deck totals are exposed
- **WHEN** a `KmpDeck` contains normal cards and sideboard cards
- **THEN** it SHALL expose total normal card count and total sideboard card count as sums of their `count` values

### Requirement: Kotlin common decode behavior
KMP core SHALL decode standard Hearthstone deck strings in Kotlin common with behavior aligned to the current Swift implementation.

#### Scenario: Valid deck string decodes
- **WHEN** `DeckStringCodecBridge.decode` receives a valid trimmed or whitespace-padded deck string with reserved byte `0`, version `1`, one supported format, one hero, normal cards, and optional sideboard data
- **THEN** it SHALL return a successful `DecodeResult` containing the decoded `KmpDeck`

#### Scenario: Invalid base64 fails
- **WHEN** `DeckStringCodecBridge.decode` receives a string that cannot be decoded as standard Base64
- **THEN** it SHALL return a failed `DecodeResult` with `DeckStringFailure.InvalidBase64`

#### Scenario: Invalid header fails
- **WHEN** decoded bytes contain a non-zero reserved byte, unsupported version, unsupported format, or an invalid hero count
- **THEN** decode SHALL return the corresponding `DeckStringFailure`

#### Scenario: Malformed payload fails
- **WHEN** decoded bytes end unexpectedly, contain a malformed varint, or contain a sideboard marker other than `0` or `1`
- **THEN** decode SHALL return a failed `DecodeResult`

### Requirement: Kotlin common encode behavior
KMP core SHALL encode `KmpDeck` values to canonical standard Base64 deck strings compatible with current Swift decode behavior.

#### Scenario: Valid deck encodes
- **WHEN** `DeckStringCodecBridge.encode` receives a deck with exactly one hero and a supported format
- **THEN** it SHALL return a successful `EncodeResult` containing a standard Base64 deck string with reserved byte `0`, version `1`, grouped normal cards, and sideboard marker `0` or `1`

#### Scenario: Invalid hero count fails
- **WHEN** `DeckStringCodecBridge.encode` receives a deck whose hero count is not exactly one
- **THEN** it SHALL return a failed `EncodeResult` with `DeckStringFailure.InvalidHeroCount`

#### Scenario: Canonical encode is stable
- **WHEN** two equivalent decks differ only by input card order
- **THEN** encode SHALL produce identical deck strings

### Requirement: Kotlin common golden tests
KMP core SHALL include common tests that lock compatibility with current Swift deckstring behavior and malformed input handling.

#### Scenario: Swift fixture coverage exists
- **WHEN** Kotlin common tests run
- **THEN** they SHALL cover standard, wild, sideboard, round-trip, sorting, invalid base64, invalid reserved byte, unsupported version, and invalid format fixtures from the Swift test suite

#### Scenario: Kotlin boundary coverage exists
- **WHEN** Kotlin common tests run
- **THEN** they SHALL cover invalid sideboard marker, truncated data, malicious max-byte varint, multi-copy normal card, multi-copy sideboard card, and canonical encode behavior

### Requirement: SKIE Swift facade parity
The SKIE-bundled Swift facade SHALL preserve the Swift-facing behavior of the existing source package while delegating deckstring parsing and encoding to the Kotlin common core.

#### Scenario: Decode parity through Swift facade
- **WHEN** Swift calls `DeckStringDecoder().decode` through the SKIE-built framework with standard、wild、sideboard and whitespace-padded fixtures from the Swift test suite
- **THEN** the returned `Deck` SHALL match the source Swift implementation for format、heroes、cards、sideboard cards and canonical sorting

#### Scenario: Encode parity through Swift facade
- **WHEN** Swift calls `DeckStringDecoder().encode` through the SKIE-built framework with decks covering normal cards、sideboard cards、round trip and canonical sorting
- **THEN** the returned deck string SHALL match the source Swift implementation for the same semantic deck

#### Scenario: Error mapping parity through Swift facade
- **WHEN** Swift calls `DeckStringDecoder().decode` or `DeckStringDecoder().encode` through the SKIE-built framework with invalid base64、invalid reserved byte、unsupported version、invalid format、invalid hero count、truncated data and invalid sideboard marker cases
- **THEN** the thrown `DeckStringError` SHALL match the source Swift API error case expected by existing Swift tests

### Requirement: Swift/Kotlin boundary validation
The Swift facade SHALL define and validate the numeric boundary between Swift `Int` public models and Kotlin/Native `Int32` bridge models.

#### Scenario: Hearthstone DBF IDs and counts bridge safely
- **WHEN** Swift facade converts valid Hearthstone hero IDs、card DBF IDs、card counts and sideboard owner IDs into Kotlin bridge models
- **THEN** values SHALL round trip without truncation or sign changes

#### Scenario: Out-of-range Swift values fail explicitly
- **WHEN** Swift facade receives a `Deck` containing a value that cannot be represented by the Kotlin bridge type used by `KmpDeck`、`KmpCard` or `KmpSideboardCard`
- **THEN** encode SHALL fail with a documented Swift `DeckStringError` behavior rather than silently truncating the value

