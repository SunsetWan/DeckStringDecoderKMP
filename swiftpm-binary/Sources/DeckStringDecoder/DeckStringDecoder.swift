#if os(iOS)
import Foundation
import DeckStringRuntime

#if !DECKSTRING_INTEGRATED_DEBUG
public typealias Deck = DeckStringModels.Deck
public typealias Card = DeckStringModels.Card
public typealias SideboardCard = DeckStringModels.SideboardCard
public typealias DeckFormat = DeckStringModels.DeckFormat
public typealias DeckStringError = DeckStringModels.DeckStringError
public let DECKSTRING_VERSION = DeckStringModels.DECKSTRING_VERSION

import DeckStringModels
#endif

public struct DeckStringDecoder {
    public init() {}

    public func decode(_ deckString: String) throws -> Deck {
        let result = DeckStringCodecBridge.shared.decode(deckString: deckString)

        if let success = result as? DecodeResult.Success {
            return Deck(kmpDeck: success.deck)
        } else if let failure = result as? DecodeResult.Failure {
            throw DeckStringError(kmpFailure: failure.failure)
        }

        throw DeckStringError.unexpectedEndOfData
    }

    public func encode(_ deck: Deck) throws -> String {
        let result = DeckStringCodecBridge.shared.encode(deck: try deck.makeKmpDeck())

        if let success = result as? EncodeResult.Success {
            return success.deckString
        } else if let failure = result as? EncodeResult.Failure {
            throw DeckStringError(kmpFailure: failure.failure)
        }

        throw DeckStringError.unexpectedEndOfData
    }
}

private extension Deck {
    init(kmpDeck: KmpDeck) {
        self.init(
            format: DeckFormat(kmpFormat: kmpDeck.format),
            heroes: kmpDeck.heroes.map { Int(truncating: $0) },
            cards: kmpDeck.cards.map(Card.init(kmpCard:)),
            sideboardCards: kmpDeck.sideboardCards.map(SideboardCard.init(kmpSideboardCard:))
        )
    }

    func makeKmpDeck() throws -> KmpDeck {
        try KmpDeck(
            format: format.kmpFormat,
            heroes: heroes.map { KotlinInt(int: try checkedBridgeInt32($0)) },
            cards: cards.map { try $0.makeKmpCard() },
            sideboardCards: sideboardCards.map { try $0.makeKmpSideboardCard() }
        )
    }
}

private extension Card {
    init(kmpCard: KmpCard) {
        self.init(dbfId: Int(kmpCard.dbfId), count: Int(kmpCard.count))
    }

    func makeKmpCard() throws -> KmpCard {
        try KmpCard(
            dbfId: checkedBridgeInt32(dbfId),
            count: checkedBridgeInt32(count)
        )
    }
}

private extension SideboardCard {
    init(kmpSideboardCard: KmpSideboardCard) {
        self.init(
            dbfId: Int(kmpSideboardCard.dbfId),
            count: Int(kmpSideboardCard.count),
            sideboardOwner: Int(kmpSideboardCard.sideboardOwner)
        )
    }

    func makeKmpSideboardCard() throws -> KmpSideboardCard {
        try KmpSideboardCard(
            dbfId: checkedBridgeInt32(dbfId),
            count: checkedBridgeInt32(count),
            sideboardOwner: checkedBridgeInt32(sideboardOwner)
        )
    }
}

private func checkedBridgeInt32(_ value: Int) throws -> Int32 {
    guard let bridged = Int32(exactly: value) else {
        throw DeckStringError.unexpectedEndOfData
    }
    return bridged
}

private extension DeckFormat {
    init(kmpFormat: KmpDeckFormat) {
        self = DeckFormat(rawValue: Int(kmpFormat.rawValue)) ?? .unknown
    }

    var kmpFormat: KmpDeckFormat {
        switch self {
        case .unknown:
            return .unknown
        case .wild:
            return .wild
        case .standard:
            return .standard
        case .classic:
            return .classic
        case .twist:
            return .twist
        }
    }
}

private extension DeckStringError {
    init(kmpFailure: DeckStringFailure) {
        switch kmpFailure {
        case is DeckStringFailure.InvalidBase64:
            self = .invalidBase64
        case let failure as DeckStringFailure.InvalidFormat:
            self = .invalidFormat(Int(failure.format))
        case let failure as DeckStringFailure.UnsupportedVersion:
            self = .unsupportedVersion(Int(failure.version))
        case let failure as DeckStringFailure.InvalidReservedByte:
            self = .invalidReservedByte(UInt8(clamping: failure.byte))
        case is DeckStringFailure.UnexpectedEndOfData:
            self = .unexpectedEndOfData
        case let failure as DeckStringFailure.InvalidHeroCount:
            self = .invalidHeroCount(Int(failure.count))
        case is DeckStringFailure.InvalidSideboardFormat:
            self = .invalidSideboardFormat
        case is DeckStringFailure.MalformedVarint, is DeckStringFailure.InvalidValue:
            self = .unexpectedEndOfData
        default:
            self = .unexpectedEndOfData
        }
    }
}

#endif
