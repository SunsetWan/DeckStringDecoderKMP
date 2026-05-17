import Foundation
import XCTest
import DeckStringDecoder
import DeckStringDecoderBinaryConsumer

final class DeckStringDecoderBinaryConsumerTests: XCTestCase {
    func testDecodeEncodeAndSideboardThroughSwiftFacade() throws {
        let decoder = DeckStringDecoderBinaryConsumer.makeDecoder()

        let standardDeckString = "AAECAQcCrwSRvAIOHLACkQP/A44FqAXUBaQG7gbnB+8HgrACiLACub8CAAA="
        let standardDeck = try decoder.decode(standardDeckString)
        XCTAssertEqual(standardDeck.format, .standard)
        XCTAssertEqual(standardDeck.heroes, [7])
        XCTAssertEqual(standardDeck.totalCardCount, 30)

        let encodedStandardDeck = try decoder.encode(standardDeck)
        let decodedStandardDeck = try decoder.decode(encodedStandardDeck)
        XCTAssertEqual(decodedStandardDeck, standardDeck)

        let sideboardDeckString = "AAEBAZCaBgjlsASotgSX7wTvkQXipAX9xAXPxgXGxwUQvp8EobYElrcE+dsEuNwEutwE9vAEhoMFopkF4KQFlMQFu8QFu8cFuJ4Gz54G0Z4GAAED8J8E/cQFuNkE/cQF/+EE/cQFAAA="
        let sideboardDeck = try decoder.decode(sideboardDeckString)
        XCTAssertEqual(sideboardDeck.format, .wild)
        XCTAssertEqual(sideboardDeck.totalCardCount, 40)
        XCTAssertEqual(sideboardDeck.sideboardCards.count, 3)
    }

    func testErrorMappingThroughSwiftFacade() throws {
        let decoder = DeckStringDecoder()

        try expectError(.invalidBase64) {
            _ = try decoder.decode("InvalidBase64!@#")
        }
        try expectError(.invalidReservedByte(1)) {
            _ = try decoder.decode("AQECAQcAAAA=")
        }
        try expectError(.unsupportedVersion(2)) {
            _ = try decoder.decode("AAICAQcAAAA=")
        }
        try expectError(.invalidFormat(5)) {
            _ = try decoder.decode("AAEFAQcAAAA=")
        }
        try expectError(.invalidHeroCount(0)) {
            _ = try decoder.encode(Deck(format: .standard, heroes: [], cards: []))
        }
        try expectError(.unexpectedEndOfData) {
            _ = try decoder.decode("AA==")
        }

        let invalidSideboardMarker = Data([0, 1, 2, 1, 7, 0, 0, 0, 2]).base64EncodedString()
        try expectError(.invalidSideboardFormat) {
            _ = try decoder.decode(invalidSideboardMarker)
        }
    }

    private func expectError(
        _ expected: DeckStringError,
        body: () throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        do {
            try body()
            XCTFail("Expected \(expected), but no error was thrown", file: file, line: line)
        } catch let error as DeckStringError {
            XCTAssertEqual(error, expected, file: file, line: line)
        }
    }
}
