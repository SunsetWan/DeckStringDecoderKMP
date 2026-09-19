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

