package com.sunsetwan.deckstring

import kotlin.io.encoding.Base64
import kotlin.io.encoding.ExperimentalEncodingApi
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue

class DeckStringCoreTest {
    @Test
    fun decodesBasicWarriorDeck() {
        val deck = decodeSuccess(BASIC_WARRIOR_DECK)

        assertEquals(KmpDeckFormat.Standard, deck.format)
        assertEquals(listOf(7), deck.heroes)
        assertEquals(30, deck.totalCardCount)
        assertEquals(KmpCard(dbfId = 401, count = 2), deck.cards.single { it.dbfId == 401 })
    }

    @Test
    fun decodesDeathKnightDeckWithZilliaxSideboard() {
        val deck = decodeSuccess(DEATH_KNIGHT_DECK)

        assertEquals(KmpDeckFormat.Standard, deck.format)
        assertEquals(listOf(78065), deck.heroes)
        assertEquals(30, deck.totalCardCount)
        assertEquals(10, deck.cards.count { it.count == 1 })
        assertEquals(10, deck.cards.count { it.count == 2 })
        assertEquals(0, deck.cards.count { it.count > 2 })
        assertEquals(listOf(104949, 104951, 110446), deck.sideboardCards.map { it.dbfId }.sorted())
        assertTrue(deck.sideboardCards.all { it.count == 1 && it.sideboardOwner == 102983 })
    }

    @Test
    fun decodesSwiftDeathKnightZilliaxFixtureParity() {
        val deck = decodeSuccess(SWIFT_DEATH_KNIGHT_ZILLIAX_DECK)

        assertEquals(KmpDeckFormat.Standard, deck.format)
        assertEquals(listOf(78065), deck.heroes)
        assertEquals(30, deck.totalCardCount)
        assertEquals(10, deck.cards.count { it.count == 1 })
        assertEquals(10, deck.cards.count { it.count == 2 })
        assertEquals(0, deck.cards.count { it.count > 2 })
        assertEquals(KmpCard(dbfId = 102983, count = 1), deck.cards.single { it.dbfId == 102983 })
        assertEquals(3, deck.sideboardCards.size)
        assertTrue(deck.sideboardCards.all { it.count == 1 && it.sideboardOwner == 102983 })
        assertEquals(listOf(104949, 104951, 110440), deck.sideboardCards.map { it.dbfId }.sorted())
        assertEquals(deck.cards.map { it.dbfId }.sorted(), deck.cards.map { it.dbfId })
        assertEquals(deck.sideboardCards.map { it.dbfId }.sorted(), deck.sideboardCards.map { it.dbfId })
    }

    @Test
    fun decodesWildSideboardDeck() {
        val deck = decodeSuccess(WILD_SIDEBOARD_DECK)

        assertEquals(KmpDeckFormat.Wild, deck.format)
        assertEquals(listOf(101648), deck.heroes)
        assertEquals(40, deck.totalCardCount)
        assertEquals(3, deck.sideboardCards.size)
        assertEquals(90749, deck.sideboardCards.first().sideboardOwner)
    }

    @Test
    fun decodesWildDeck() {
        val deck = decodeSuccess(WILD_DECK)

        assertEquals(KmpDeckFormat.Wild, deck.format)
        assertEquals(30, deck.totalCardCount)
    }

    @Test
    fun trimsInputBeforeDecoding() {
        val deck = decodeSuccess("\n  $BASIC_WARRIOR_DECK\t")

        assertEquals(KmpDeckFormat.Standard, deck.format)
        assertEquals(30, deck.totalCardCount)
    }

    @Test
    fun roundTripsDecodedDeck() {
        val originalDeck = decodeSuccess(BASIC_WARRIOR_DECK)
        val encoded = encodeSuccess(originalDeck)
        val redecodedDeck = decodeSuccess(encoded)

        assertEquals(originalDeck, redecodedDeck)
    }

    @Test
    fun deckConstructionSortsCanonicalFields() {
        val deck = KmpDeck(
            format = KmpDeckFormat.Standard,
            heroes = listOf(9, 7),
            cards = listOf(
                KmpCard(dbfId = 300, count = 2),
                KmpCard(dbfId = 100, count = 1),
                KmpCard(dbfId = 200, count = 3),
            ),
            sideboardCards = listOf(
                KmpSideboardCard(dbfId = 30, count = 1, sideboardOwner = 2),
                KmpSideboardCard(dbfId = 20, count = 1, sideboardOwner = 1),
                KmpSideboardCard(dbfId = 10, count = 1, sideboardOwner = 1),
            ),
        )

        assertEquals(listOf(7, 9), deck.heroes)
        assertEquals(listOf(100, 200, 300), deck.cards.map { it.dbfId })
        assertEquals(listOf(10, 20, 30), deck.sideboardCards.map { it.dbfId })
    }

    @Test
    fun invalidInputsReturnFailures() {
        assertEquals(
            DeckStringFailure.InvalidBase64,
            decodeFailure("InvalidBase64!@#"),
        )
        assertEquals(
            DeckStringFailure.UnexpectedEndOfData,
            decodeFailure("AA=="),
        )
        assertEquals(
            DeckStringFailure.InvalidReservedByte(1),
            decodeFailure("AQECAQcAAAA="),
        )
        assertEquals(
            DeckStringFailure.UnsupportedVersion(2),
            decodeFailure("AAICAQcAAAA="),
        )
        assertEquals(
            DeckStringFailure.InvalidFormat(5),
            decodeFailure("AAEFAQcAAAA="),
        )
    }

    @Test
    fun invalidSideboardMarkerFails() {
        val invalid = deckStringBytes {
            writeByte(0)
            writeVarint(1)
            writeVarint(2)
            writeVarint(1)
            writeVarint(7)
            writeVarint(0)
            writeVarint(0)
            writeVarint(0)
            writeByte(2)
        }

        assertEquals(DeckStringFailure.InvalidSideboardFormat, decodeFailure(invalid))
    }

    @Test
    fun truncatedPayloadFails() {
        val truncated = deckStringBytes {
            writeByte(0)
            writeVarint(1)
            writeVarint(2)
            writeVarint(1)
            writeVarint(7)
            writeVarint(1)
        }

        assertEquals(DeckStringFailure.UnexpectedEndOfData, decodeFailure(truncated))
    }

    @Test
    fun maliciousMaxByteVarintFails() {
        val malicious = deckStringBytes {
            writeByte(0)
            repeat(5) { writeByte(0x80) }
        }

        assertEquals(DeckStringFailure.MalformedVarint, decodeFailure(malicious))
    }

    @Test
    fun encodesMultiCopyCardsAndSideboardCards() {
        val deck = KmpDeck(
            format = KmpDeckFormat.Standard,
            heroes = listOf(7),
            cards = listOf(
                KmpCard(dbfId = 100, count = 1),
                KmpCard(dbfId = 200, count = 2),
                KmpCard(dbfId = 300, count = 4),
            ),
            sideboardCards = listOf(
                KmpSideboardCard(dbfId = 400, count = 1, sideboardOwner = 900),
                KmpSideboardCard(dbfId = 500, count = 2, sideboardOwner = 900),
                KmpSideboardCard(dbfId = 600, count = 5, sideboardOwner = 901),
            ),
        )

        val decoded = decodeSuccess(encodeSuccess(deck))

        assertEquals(deck, decoded)
        assertEquals(7, decoded.totalCardCount)
        assertEquals(8, decoded.totalSideboardCardCount)
    }

    @Test
    fun canonicalEncodeIsStable() {
        val first = KmpDeck(
            format = KmpDeckFormat.Standard,
            heroes = listOf(7),
            cards = listOf(KmpCard(300, 2), KmpCard(100, 1), KmpCard(200, 3)),
        )
        val second = KmpDeck(
            format = KmpDeckFormat.Standard,
            heroes = listOf(7),
            cards = listOf(KmpCard(200, 3), KmpCard(300, 2), KmpCard(100, 1)),
        )

        assertEquals(encodeSuccess(first), encodeSuccess(second))
    }

    @Test
    fun encodeRejectsInvalidHeroCount() {
        val failure = encodeFailure(
            KmpDeck(
                format = KmpDeckFormat.Standard,
                heroes = emptyList(),
                cards = emptyList(),
            )
        )

        assertEquals(DeckStringFailure.InvalidHeroCount(0), failure)
    }

    private fun decodeSuccess(deckString: String): KmpDeck {
        val result = DeckStringCodecBridge.decode(deckString)
        return assertIs<DecodeResult.Success>(result).deck
    }

    private fun decodeFailure(deckString: String): DeckStringFailure {
        val result = DeckStringCodecBridge.decode(deckString)
        return assertIs<DecodeResult.Failure>(result).failure
    }

    private fun encodeSuccess(deck: KmpDeck): String {
        val result = DeckStringCodecBridge.encode(deck)
        return assertIs<EncodeResult.Success>(result).deckString
    }

    private fun encodeFailure(deck: KmpDeck): DeckStringFailure {
        val result = DeckStringCodecBridge.encode(deck)
        return assertIs<EncodeResult.Failure>(result).failure
    }

    private companion object {
        private const val BASIC_WARRIOR_DECK =
            "AAECAQcCrwSRvAIOHLACkQP/A44FqAXUBaQG7gbnB+8HgrACiLACub8CAAA="
        private const val DEATH_KNIGHT_DECK =
            "AAECAfHhBArHpAa9sQbC6Aap9QaSgwfDgweDigfvkweCmAf1mAcKquEG5uUGvugG9O0GtfoGgf0GloIHl4IHtpQH0JsHAAED9bMGx6QG97MGx6QG7t4Gx6QGAAA="
        private const val SWIFT_DEATH_KNIGHT_ZILLIAX_DECK =
            "AAECAfHhBArHpAa9sQbC6Aap9QaSgwfDgweDigfvkweCmAf1mAcKquEG5uUGvugG9O0GtfoGgf0GloIHl4IHtpQH0JsHAAED9bMGx6QG97MGx6QG6N4Gx6QGAAA="
        private const val WILD_SIDEBOARD_DECK =
            "AAEBAZCaBgjlsASotgSX7wTvkQXipAX9xAXPxgXGxwUQvp8EobYElrcE+dsEuNwEutwE9vAEhoMFopkF4KQFlMQFu8QFu8cFuJ4Gz54G0Z4GAAED8J8E/cQFuNkE/cQF/+EE/cQFAAA="
        private const val WILD_DECK =
            "AAEBAR8G+LEChwTmwgKhwgLZwgK7BQzquwKJwwKOwwKTwwK5tAK1A/4MqALsuwLrB86uAu0JAA=="
    }
}

private class TestByteWriter {
    private val bytes = mutableListOf<Byte>()

    fun writeByte(value: Int) {
        bytes += (value and 0xFF).toByte()
    }

    fun writeVarint(value: Int) {
        var remaining = value
        while (remaining >= 0x80) {
            writeByte((remaining and 0x7F) or 0x80)
            remaining = remaining ushr 7
        }
        writeByte(remaining)
    }

    fun toByteArray(): ByteArray = bytes.toByteArray()
}

@OptIn(ExperimentalEncodingApi::class)
private fun deckStringBytes(build: TestByteWriter.() -> Unit): String {
    val writer = TestByteWriter()
    writer.build()
    return Base64.Default.encode(writer.toByteArray())
}
