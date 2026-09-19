import Foundation
import Testing
import DeckStringModels

@Suite struct DeckStringModelsTests {
    @Test func initializerOrdersValues() {
        let deck = Deck(format: .standard, heroes: [7, 1], cards: [Card(dbfId: 9, count: 1), Card(dbfId: 2, count: 2)], sideboardCards: [SideboardCard(dbfId: 1, count: 1, sideboardOwner: 9), SideboardCard(dbfId: 3, count: 2, sideboardOwner: 2)])
        #expect(deck.heroes == [1, 7])
        #expect(deck.cards.map(\.dbfId) == [2, 9])
        #expect(deck.sideboardCards.map(\.sideboardOwner) == [2, 9])
        #expect(deck.totalCardCount == 3)
        #expect(deck.totalSideboardCardCount == 3)
    }

    @Test func decodingPreservesStoredOrder() throws {
        let data = Data(#"{"format":2,"heroes":[7,1],"cards":[{"dbfId":9,"count":1},{"dbfId":2,"count":2}],"sideboardCards":[]}"#.utf8)
        let deck = try JSONDecoder().decode(Deck.self, from: data)
        #expect(deck.heroes == [7, 1])
        #expect(deck.cards.map(\.dbfId) == [9, 2])
        #expect(try JSONDecoder().decode(Deck.self, from: JSONEncoder().encode(deck)) == deck)
    }

    @Test(arguments: DeckFormat.allCases) func formatUsesIntegerJSON(format: DeckFormat) throws {
        let encoded = try JSONEncoder().encode(format)
        #expect(String(decoding: encoded, as: UTF8.self) == String(format.rawValue))
        #expect(try JSONDecoder().decode(DeckFormat.self, from: encoded) == format)
    }

    @Test func unknownRawFormatFails() {
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(DeckFormat.self, from: Data("99".utf8)) }
        #expect(DeckFormat(rawValue: 99) == nil)
    }

    @Test(arguments: [
        #"{"format":2,"heroes":[7],"cards":[]}"#,
        #"{"format":2,"heroes":[7],"cards":[{"dbfId":1}],"sideboardCards":[]}"#,
        #"{"format":2,"heroes":[7],"cards":[],"sideboardCards":[{"dbfId":1,"count":1}]}"#
    ]) func missingRequiredFieldsFail(json: String) {
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(Deck.self, from: Data(json.utf8)) }
    }
}
