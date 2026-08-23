import Foundation

public let DECKSTRING_VERSION: UInt8 = 1

public enum DeckFormat: CaseIterable, Hashable, Codable, Sendable, RawRepresentable {
    public typealias RawValue = Int
    public typealias AllCases = [DeckFormat]

    case unknown
    case wild
    case standard
    case classic
    case twist

    public init?(rawValue: Int) {
        switch rawValue {
        case 0:
            self = .unknown
        case 1:
            self = .wild
        case 2:
            self = .standard
        case 3:
            self = .classic
        case 4:
            self = .twist
        default:
            return nil
        }
    }

    public var rawValue: Int {
        switch self {
        case .unknown:
            return 0
        case .wild:
            return 1
        case .standard:
            return 2
        case .classic:
            return 3
        case .twist:
            return 4
        }
    }

    public static var allCases: [DeckFormat] {
        [.unknown, .wild, .standard, .classic, .twist]
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        guard let value = DeckFormat(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid DeckFormat raw value: \(rawValue)"
            )
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct Card: Equatable, Comparable, Hashable, Codable, Sendable {
    public let dbfId: Int
    public let count: Int

    public init(dbfId: Int, count: Int) {
        self.dbfId = dbfId
        self.count = count
    }

    public static func < (lhs: Card, rhs: Card) -> Bool {
        lhs.dbfId < rhs.dbfId
    }

    public static func == (lhs: Card, rhs: Card) -> Bool {
        lhs.dbfId == rhs.dbfId && lhs.count == rhs.count
    }
}

public struct SideboardCard: Equatable, Comparable, Hashable, Codable, Sendable {
    public let dbfId: Int
    public let count: Int
    public let sideboardOwner: Int

    public init(dbfId: Int, count: Int, sideboardOwner: Int) {
        self.dbfId = dbfId
        self.count = count
        self.sideboardOwner = sideboardOwner
    }

    public static func < (lhs: SideboardCard, rhs: SideboardCard) -> Bool {
        if lhs.sideboardOwner != rhs.sideboardOwner {
            return lhs.sideboardOwner < rhs.sideboardOwner
        }
        return lhs.dbfId < rhs.dbfId
    }

    public static func == (lhs: SideboardCard, rhs: SideboardCard) -> Bool {
        lhs.dbfId == rhs.dbfId
            && lhs.count == rhs.count
            && lhs.sideboardOwner == rhs.sideboardOwner
    }
}

public struct Deck: Hashable, Codable, Sendable {
    public let format: DeckFormat
    public let heroes: [Int]
    public let cards: [Card]
    public let sideboardCards: [SideboardCard]

    public init(
        format: DeckFormat,
        heroes: [Int],
        cards: [Card],
        sideboardCards: [SideboardCard] = []
    ) {
        self.format = format
        self.heroes = heroes.sorted()
        self.cards = cards.sorted()
        self.sideboardCards = sideboardCards.sorted()
    }

    public var totalCardCount: Int {
        cards.reduce(0) { $0 + $1.count }
    }

    public var totalSideboardCardCount: Int {
        sideboardCards.reduce(0) { $0 + $1.count }
    }

    public static func == (lhs: Deck, rhs: Deck) -> Bool {
        lhs.format == rhs.format
            && lhs.heroes == rhs.heroes
            && lhs.cards == rhs.cards
            && lhs.sideboardCards == rhs.sideboardCards
    }
}

public enum DeckStringError: Error, LocalizedError, Equatable {
    case invalidBase64
    case invalidFormat(Int)
    case unsupportedVersion(Int)
    case invalidReservedByte(UInt8)
    case unexpectedEndOfData
    case invalidHeroCount(Int)
    case invalidSideboardFormat

    public var errorDescription: String? {
        switch self {
        case .invalidBase64:
            return "Invalid base64 encoding in deck string"
        case let .invalidFormat(format):
            return "Unsupported deck format: \(format)"
        case let .unsupportedVersion(version):
            return "Unsupported deck string version: \(version)"
        case let .invalidReservedByte(byte):
            return "Invalid reserved byte: \(byte), expected 0"
        case .unexpectedEndOfData:
            return "Unexpected end of data while parsing deck string"
        case let .invalidHeroCount(count):
            return "Invalid hero count: \(count), expected 1"
        case .invalidSideboardFormat:
            return "Invalid sideboard format"
        }
    }

    public static func == (lhs: DeckStringError, rhs: DeckStringError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidBase64, .invalidBase64):
            return true
        case let (.invalidFormat(lhsFormat), .invalidFormat(rhsFormat)):
            return lhsFormat == rhsFormat
        case let (.unsupportedVersion(lhsVersion), .unsupportedVersion(rhsVersion)):
            return lhsVersion == rhsVersion
        case let (.invalidReservedByte(lhsByte), .invalidReservedByte(rhsByte)):
            return lhsByte == rhsByte
        case (.unexpectedEndOfData, .unexpectedEndOfData):
            return true
        case let (.invalidHeroCount(lhsCount), .invalidHeroCount(rhsCount)):
            return lhsCount == rhsCount
        case (.invalidSideboardFormat, .invalidSideboardFormat):
            return true
        default:
            return false
        }
    }
}

// Preserve the equality entry points emitted by HS_DeckStringDecoder 1.0.1.
// Existing consumer object files can then link the same-named KMP binary module
// without requiring a DerivedData cleanup during the package replacement.
@_silgen_name("$s17DeckStringDecoder4CardV23__derived_struct_equalsySbAC_ACtFZ")
func sourcePackageCardEquals(_ lhs: Card, _ rhs: Card) -> Bool {
    lhs == rhs
}

@_silgen_name("$s17DeckStringDecoder13SideboardCardV23__derived_struct_equalsySbAC_ACtFZ")
func sourcePackageSideboardCardEquals(_ lhs: SideboardCard, _ rhs: SideboardCard) -> Bool {
    lhs == rhs
}

@_silgen_name("$s17DeckStringDecoder0A0V23__derived_struct_equalsySbAC_ACtFZ")
func sourcePackageDeckEquals(_ lhs: Deck, _ rhs: Deck) -> Bool {
    lhs == rhs
}

@_silgen_name("$s17DeckStringDecoder0aB5ErrorO21__derived_enum_equalsySbAC_ACtFZ")
func sourcePackageDeckStringErrorEquals(
    _ lhs: DeckStringError,
    _ rhs: DeckStringError
) -> Bool {
    lhs == rhs
}

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
