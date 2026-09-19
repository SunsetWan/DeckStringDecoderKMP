#if os(iOS)
import DeckStringDecoder
import DeckStringModels
import Foundation
import Testing

@Suite struct DeckStringDecoderTests {
    @Test func sourceContractHasOneTypeIdentity() throws {
        let decoder = DeckStringDecoder()
        let code = "AAECAQcCrwSRvAIOHLACkQP/A44FqAXUBaQG7gbnB+8HgrACiLACub8CAAA="
        let deck: DeckStringModels.Deck = try decoder.decode(code)
        #expect(deck.format == .standard)
        #expect(deck.totalCardCount == 30)
        #expect(try decoder.decode(decoder.encode(deck)) == deck)
    }

    @Test func sideboardsRoundTrip() throws {
        let decoder = DeckStringDecoder()
        let deck = try decoder.decode("AAEBAZCaBgjlsASotgSX7wTvkQXipAX9xAXPxgXGxwUQvp8EobYElrcE+dsEuNwEutwE9vAEhoMFopkF4KQFlMQFu8QFu8cFuJ4Gz54G0Z4GAAED8J8E/cQFuNkE/cQF/+EE/cQFAAA=")
        #expect(deck.sideboardCards.count == 3)
        #expect(try decoder.decode(decoder.encode(deck)) == deck)
    }

    @Test func errorsUsePortableContract() {
        let decoder = DeckStringDecoder()
        #expect(throws: DeckStringModels.DeckStringError.invalidBase64) { try decoder.decode("InvalidBase64!@#") }
        #expect(throws: DeckStringModels.DeckStringError.invalidHeroCount(0)) { try decoder.encode(Deck(format: .standard, heroes: [], cards: [])) }
        #expect(throws: DeckStringModels.DeckStringError.unexpectedEndOfData) { try decoder.encode(Deck(format: .standard, heroes: [Int.max], cards: [])) }
    }
}
#endif
