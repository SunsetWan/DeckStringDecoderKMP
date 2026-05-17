package com.sunsetwan.deckstring

import kotlin.io.encoding.Base64
import kotlin.io.encoding.ExperimentalEncodingApi

public const val KMP_DECKSTRING_VERSION: Int = 1

public enum class KmpDeckFormat(public val rawValue: Int) {
    Unknown(0),
    Wild(1),
    Standard(2),
    Classic(3),
    Twist(4);

    public companion object {
        public fun fromRawValue(rawValue: Int): KmpDeckFormat? =
            entries.firstOrNull { it.rawValue == rawValue }
    }
}

public data class KmpCard(
    public val dbfId: Int,
    public val count: Int,
) : Comparable<KmpCard> {
    override fun compareTo(other: KmpCard): Int = dbfId.compareTo(other.dbfId)
}

public data class KmpSideboardCard(
    public val dbfId: Int,
    public val count: Int,
    public val sideboardOwner: Int,
) : Comparable<KmpSideboardCard> {
    override fun compareTo(other: KmpSideboardCard): Int {
        val ownerComparison = sideboardOwner.compareTo(other.sideboardOwner)
        return if (ownerComparison != 0) ownerComparison else dbfId.compareTo(other.dbfId)
    }
}

public class KmpDeck(
    public val format: KmpDeckFormat,
    heroes: List<Int>,
    cards: List<KmpCard>,
    sideboardCards: List<KmpSideboardCard> = emptyList(),
) {
    public val heroes: List<Int> = heroes.sorted()
    public val cards: List<KmpCard> = cards.sorted()
    public val sideboardCards: List<KmpSideboardCard> = sideboardCards.sorted()

    public val totalCardCount: Int
        get() = cards.sumOf { it.count }

    public val totalSideboardCardCount: Int
        get() = sideboardCards.sumOf { it.count }

    override fun equals(other: Any?): Boolean =
        other is KmpDeck &&
            format == other.format &&
            heroes == other.heroes &&
            cards == other.cards &&
            sideboardCards == other.sideboardCards

    override fun hashCode(): Int {
        var result = format.hashCode()
        result = 31 * result + heroes.hashCode()
        result = 31 * result + cards.hashCode()
        result = 31 * result + sideboardCards.hashCode()
        return result
    }

    override fun toString(): String =
        "KmpDeck(format=$format, heroes=$heroes, cards=$cards, sideboardCards=$sideboardCards)"
}

public sealed class DeckStringFailure {
    public data object InvalidBase64 : DeckStringFailure()
    public data class InvalidFormat(public val format: Int) : DeckStringFailure()
    public data class UnsupportedVersion(public val version: Int) : DeckStringFailure()
    public data class InvalidReservedByte(public val byte: Int) : DeckStringFailure()
    public data object UnexpectedEndOfData : DeckStringFailure()
    public data class InvalidHeroCount(public val count: Int) : DeckStringFailure()
    public data object InvalidSideboardFormat : DeckStringFailure()
    public data object MalformedVarint : DeckStringFailure()
    public data class InvalidValue(public val reason: String) : DeckStringFailure()
}

public sealed class DecodeResult {
    public data class Success(public val deck: KmpDeck) : DecodeResult()
    public data class Failure(public val failure: DeckStringFailure) : DecodeResult()
}

public sealed class EncodeResult {
    public data class Success(public val deckString: String) : EncodeResult()
    public data class Failure(public val failure: DeckStringFailure) : EncodeResult()
}

public object DeckStringCodecBridge {
    public fun decode(deckString: String): DecodeResult {
        val bytes = try {
            decodeBase64(deckString.trim())
        } catch (_: IllegalArgumentException) {
            return DecodeResult.Failure(DeckStringFailure.InvalidBase64)
        }

        val reader = ByteReader(bytes)

        val reserved = when (val result = reader.readByte()) {
            is ReadResult.Success -> result.value
            is ReadResult.Failure -> return DecodeResult.Failure(result.failure)
        }
        if (reserved != 0) {
            return DecodeResult.Failure(DeckStringFailure.InvalidReservedByte(reserved))
        }

        val version = when (val result = reader.readVarint()) {
            is ReadResult.Success -> result.value
            is ReadResult.Failure -> return DecodeResult.Failure(result.failure)
        }
        if (version != KMP_DECKSTRING_VERSION) {
            return DecodeResult.Failure(DeckStringFailure.UnsupportedVersion(version))
        }

        val formatValue = when (val result = reader.readVarint()) {
            is ReadResult.Success -> result.value
            is ReadResult.Failure -> return DecodeResult.Failure(result.failure)
        }
        val format = KmpDeckFormat.fromRawValue(formatValue)
            ?: return DecodeResult.Failure(DeckStringFailure.InvalidFormat(formatValue))

        val heroCount = when (val result = reader.readVarint()) {
            is ReadResult.Success -> result.value
            is ReadResult.Failure -> return DecodeResult.Failure(result.failure)
        }
        if (heroCount != 1) {
            return DecodeResult.Failure(DeckStringFailure.InvalidHeroCount(heroCount))
        }

        val heroes = mutableListOf<Int>()
        repeat(heroCount) {
            val hero = when (val result = reader.readVarint()) {
                is ReadResult.Success -> result.value
                is ReadResult.Failure -> return DecodeResult.Failure(result.failure)
            }
            heroes += hero
        }

        val cards = mutableListOf<KmpCard>()
        when (val result = reader.readNormalCardGroups(cards)) {
            is ReadResult.Success -> Unit
            is ReadResult.Failure -> return DecodeResult.Failure(result.failure)
        }

        val sideboardCards = mutableListOf<KmpSideboardCard>()
        if (reader.hasRemaining()) {
            val marker = when (val result = reader.readByte()) {
                is ReadResult.Success -> result.value
                is ReadResult.Failure -> return DecodeResult.Failure(result.failure)
            }

            when (marker) {
                0 -> Unit
                1 -> when (val result = reader.readSideboardCardGroups(sideboardCards)) {
                    is ReadResult.Success -> Unit
                    is ReadResult.Failure -> return DecodeResult.Failure(result.failure)
                }
                else -> return DecodeResult.Failure(DeckStringFailure.InvalidSideboardFormat)
            }
        }

        return DecodeResult.Success(KmpDeck(format, heroes, cards, sideboardCards))
    }

    public fun encode(deck: KmpDeck): EncodeResult {
        if (deck.heroes.size != 1) {
            return EncodeResult.Failure(DeckStringFailure.InvalidHeroCount(deck.heroes.size))
        }

        val writer = ByteWriter()
        writer.writeByte(0)
        writer.writeVarint(KMP_DECKSTRING_VERSION)
        writer.writeVarint(deck.format.rawValue)
        writer.writeVarint(deck.heroes.size)
        deck.heroes.forEach { hero ->
            val failure = writer.writeVarint(hero)
            if (failure != null) return EncodeResult.Failure(failure)
        }

        val (singleCards, doubleCards, multiCards) = deck.cards.trisort()
        val failure = writer.writeNormalCardGroups(singleCards, doubleCards, multiCards)
        if (failure != null) return EncodeResult.Failure(failure)

        if (deck.sideboardCards.isEmpty()) {
            writer.writeByte(0)
        } else {
            writer.writeByte(1)
            val (singleSideboards, doubleSideboards, multiSideboards) = deck.sideboardCards.trisort()
            val sideboardFailure =
                writer.writeSideboardCardGroups(singleSideboards, doubleSideboards, multiSideboards)
            if (sideboardFailure != null) return EncodeResult.Failure(sideboardFailure)
        }

        return EncodeResult.Success(encodeBase64(writer.toByteArray()))
    }
}

private sealed class ReadResult {
    data class Success(val value: Int) : ReadResult()
    data class Failure(val failure: DeckStringFailure) : ReadResult()
}

private class ByteReader(private val bytes: ByteArray) {
    private var index: Int = 0

    fun hasRemaining(): Boolean = index < bytes.size

    fun readByte(): ReadResult {
        if (index >= bytes.size) {
            return ReadResult.Failure(DeckStringFailure.UnexpectedEndOfData)
        }
        return ReadResult.Success(bytes[index++].toInt() and 0xFF)
    }

    fun readVarint(): ReadResult {
        if (index >= bytes.size) {
            return ReadResult.Failure(DeckStringFailure.UnexpectedEndOfData)
        }

        var shift = 0
        var result = 0
        var bytesRead = 0
        val maxBytes = 5

        while (index < bytes.size && bytesRead < maxBytes) {
            val byte = bytes[index++].toInt() and 0xFF
            bytesRead += 1

            val payload = byte and 0x7F
            if (shift == 28 && payload > 0x07) {
                return ReadResult.Failure(DeckStringFailure.MalformedVarint)
            }
            result = result or (payload shl shift)
            shift += 7

            if ((byte and 0x80) == 0) {
                return ReadResult.Success(result)
            }
        }

        return ReadResult.Failure(
            if (bytesRead >= maxBytes) DeckStringFailure.MalformedVarint
            else DeckStringFailure.UnexpectedEndOfData
        )
    }

    fun readNormalCardGroups(cards: MutableList<KmpCard>): ReadResult {
        val singleCount = readVarintOrReturnFailure() ?: return lastFailure
        repeat(singleCount) {
            val cardId = readVarintOrReturnFailure() ?: return lastFailure
            cards += KmpCard(dbfId = cardId, count = 1)
        }

        val doubleCount = readVarintOrReturnFailure() ?: return lastFailure
        repeat(doubleCount) {
            val cardId = readVarintOrReturnFailure() ?: return lastFailure
            cards += KmpCard(dbfId = cardId, count = 2)
        }

        val multiCount = readVarintOrReturnFailure() ?: return lastFailure
        repeat(multiCount) {
            val cardId = readVarintOrReturnFailure() ?: return lastFailure
            val count = readVarintOrReturnFailure() ?: return lastFailure
            cards += KmpCard(dbfId = cardId, count = count)
        }

        return ReadResult.Success(0)
    }

    fun readSideboardCardGroups(cards: MutableList<KmpSideboardCard>): ReadResult {
        val singleCount = readVarintOrReturnFailure() ?: return lastFailure
        repeat(singleCount) {
            val cardId = readVarintOrReturnFailure() ?: return lastFailure
            val sideboardOwner = readVarintOrReturnFailure() ?: return lastFailure
            cards += KmpSideboardCard(dbfId = cardId, count = 1, sideboardOwner = sideboardOwner)
        }

        val doubleCount = readVarintOrReturnFailure() ?: return lastFailure
        repeat(doubleCount) {
            val cardId = readVarintOrReturnFailure() ?: return lastFailure
            val sideboardOwner = readVarintOrReturnFailure() ?: return lastFailure
            cards += KmpSideboardCard(dbfId = cardId, count = 2, sideboardOwner = sideboardOwner)
        }

        val multiCount = readVarintOrReturnFailure() ?: return lastFailure
        repeat(multiCount) {
            val cardId = readVarintOrReturnFailure() ?: return lastFailure
            val count = readVarintOrReturnFailure() ?: return lastFailure
            val sideboardOwner = readVarintOrReturnFailure() ?: return lastFailure
            cards += KmpSideboardCard(dbfId = cardId, count = count, sideboardOwner = sideboardOwner)
        }

        return ReadResult.Success(0)
    }

    private lateinit var lastFailure: ReadResult.Failure

    private fun readVarintOrReturnFailure(): Int? =
        when (val result = readVarint()) {
            is ReadResult.Success -> result.value
            is ReadResult.Failure -> {
                lastFailure = result
                null
            }
        }
}

private class ByteWriter {
    private val bytes = mutableListOf<Byte>()

    fun writeByte(value: Int) {
        bytes += (value and 0xFF).toByte()
    }

    fun writeVarint(value: Int): DeckStringFailure? {
        if (value < 0) {
            return DeckStringFailure.InvalidValue("varint value must be non-negative")
        }

        var remaining = value
        while (remaining >= 0x80) {
            bytes += (((remaining and 0x7F) or 0x80) and 0xFF).toByte()
            remaining = remaining ushr 7
        }
        bytes += (remaining and 0x7F).toByte()
        return null
    }

    fun writeNormalCardGroups(
        singleCards: List<KmpCard>,
        doubleCards: List<KmpCard>,
        multiCards: List<KmpCard>,
    ): DeckStringFailure? {
        writeVarint(singleCards.size)?.let { return it }
        singleCards.forEach { card -> writeVarint(card.dbfId)?.let { return it } }

        writeVarint(doubleCards.size)?.let { return it }
        doubleCards.forEach { card -> writeVarint(card.dbfId)?.let { return it } }

        writeVarint(multiCards.size)?.let { return it }
        multiCards.forEach { card ->
            writeVarint(card.dbfId)?.let { return it }
            writeVarint(card.count)?.let { return it }
        }

        return null
    }

    fun writeSideboardCardGroups(
        singleCards: List<KmpSideboardCard>,
        doubleCards: List<KmpSideboardCard>,
        multiCards: List<KmpSideboardCard>,
    ): DeckStringFailure? {
        writeVarint(singleCards.size)?.let { return it }
        singleCards.forEach { card ->
            writeVarint(card.dbfId)?.let { return it }
            writeVarint(card.sideboardOwner)?.let { return it }
        }

        writeVarint(doubleCards.size)?.let { return it }
        doubleCards.forEach { card ->
            writeVarint(card.dbfId)?.let { return it }
            writeVarint(card.sideboardOwner)?.let { return it }
        }

        writeVarint(multiCards.size)?.let { return it }
        multiCards.forEach { card ->
            writeVarint(card.dbfId)?.let { return it }
            writeVarint(card.count)?.let { return it }
            writeVarint(card.sideboardOwner)?.let { return it }
        }

        return null
    }

    fun toByteArray(): ByteArray = bytes.toByteArray()
}

private data class CardGroups<T>(
    val singleCards: List<T>,
    val doubleCards: List<T>,
    val multiCards: List<T>,
)

private fun List<KmpCard>.trisort(): CardGroups<KmpCard> =
    CardGroups(
        singleCards = filter { it.count == 1 },
        doubleCards = filter { it.count == 2 },
        multiCards = filter { it.count != 1 && it.count != 2 },
    )

private fun List<KmpSideboardCard>.trisort(): CardGroups<KmpSideboardCard> =
    CardGroups(
        singleCards = filter { it.count == 1 },
        doubleCards = filter { it.count == 2 },
        multiCards = filter { it.count != 1 && it.count != 2 },
    )

@OptIn(ExperimentalEncodingApi::class)
private fun decodeBase64(value: String): ByteArray = Base64.Default.decode(value)

@OptIn(ExperimentalEncodingApi::class)
private fun encodeBase64(bytes: ByteArray): String = Base64.Default.encode(bytes)
