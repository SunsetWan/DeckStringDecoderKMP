import DeckStringDecoder
import XCTest

/// Supplemental donor probe. It is compiled against the frozen binary artifact;
/// it does not modify the donor facade or the committed local consumer sources.
final class SwiftNumericBoundaryProbeTests: XCTestCase {
    func testEverySwiftIntToKotlinInt32BoundaryRejectsOverflow() throws {
        let overflow = Int(Int32.max) + 1
        let decoder = DeckStringDecoder()
        let decks = [
            Deck(format: .standard, heroes: [overflow], cards: []),
            Deck(format: .standard, heroes: [7], cards: [Card(dbfId: overflow, count: 1)]),
            Deck(format: .standard, heroes: [7], cards: [Card(dbfId: 1, count: overflow)]),
            Deck(
                format: .standard,
                heroes: [7],
                cards: [],
                sideboardCards: [
                    SideboardCard(dbfId: overflow, count: 1, sideboardOwner: 1),
                ]),
            Deck(
                format: .standard,
                heroes: [7],
                cards: [],
                sideboardCards: [
                    SideboardCard(dbfId: 1, count: overflow, sideboardOwner: 1),
                ]),
            Deck(
                format: .standard,
                heroes: [7],
                cards: [],
                sideboardCards: [
                    SideboardCard(dbfId: 1, count: 1, sideboardOwner: overflow),
                ]),
        ]

        for deck in decks {
            XCTAssertThrowsError(try decoder.encode(deck)) { error in
                XCTAssertEqual(error as? DeckStringError, .unexpectedEndOfData)
            }
        }
    }
}
