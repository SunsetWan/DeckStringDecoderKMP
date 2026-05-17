## MODIFIED Requirements

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

#### Scenario: Trailing bytes compatibility remains unchanged
- **WHEN** decoded bytes contain a valid deck payload followed by existing trailing bytes after sideboard marker handling
- **THEN** decode SHALL continue returning a successful `DecodeResult` for this change

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

#### Scenario: Canonical encode output remains unchanged after grouping optimization
- **WHEN** `DeckStringCodecBridge.encode` receives a deck decoded from a Swift golden fixture
- **THEN** encode SHALL produce the same canonical deck string as before the internal grouping optimization

### Requirement: Kotlin common golden tests
KMP core SHALL include common tests that lock compatibility with current Swift deckstring behavior and malformed input handling.

#### Scenario: Swift fixture coverage exists
- **WHEN** Kotlin common tests run
- **THEN** they SHALL cover standard, wild, sideboard, round-trip, sorting, invalid base64, invalid reserved byte, unsupported version, and invalid format fixtures from the Swift test suite

#### Scenario: Kotlin boundary coverage exists
- **WHEN** Kotlin common tests run
- **THEN** they SHALL cover invalid sideboard marker, truncated data, malicious max-byte varint, multi-copy normal card, multi-copy sideboard card, and canonical encode behavior

#### Scenario: Swift Rogue fixture coverage exists
- **WHEN** Kotlin common tests run
- **THEN** they SHALL include the Swift Rogue / Pool Party Maiev fixture and assert format, hero `122992`, total count `30`, single copy count `12`, double copy count `9`, and large DBF ID parsing

#### Scenario: Swift specific card parsing coverage exists
- **WHEN** Kotlin common tests run
- **THEN** they SHALL include Swift specific card parsing assertions for the Death Knight fixture covering Zilliax `102983` as single copy and Wakener `111678` as double copy

#### Scenario: Empty string decode failure parity exists
- **WHEN** Kotlin common tests run
- **THEN** they SHALL assert empty string decode returns `DeckStringFailure.UnexpectedEndOfData`
