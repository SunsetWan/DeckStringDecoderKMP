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

        val reserved = reader.readByte() ?: return DecodeResult.Failure(reader.currentFailure)
        if (reserved != 0) {
            return DecodeResult.Failure(DeckStringFailure.InvalidReservedByte(reserved))
        }

        val version = reader.readVarint() ?: return DecodeResult.Failure(reader.currentFailure)
        if (version != KMP_DECKSTRING_VERSION) {
            return DecodeResult.Failure(DeckStringFailure.UnsupportedVersion(version))
        }

        val formatValue = reader.readVarint() ?: return DecodeResult.Failure(reader.currentFailure)
        val format = KmpDeckFormat.fromRawValue(formatValue)
            ?: return DecodeResult.Failure(DeckStringFailure.InvalidFormat(formatValue))

        val heroCount = reader.readVarint() ?: return DecodeResult.Failure(reader.currentFailure)
        if (heroCount != 1) {
            return DecodeResult.Failure(DeckStringFailure.InvalidHeroCount(heroCount))
        }

        val heroes = ArrayList<Int>(heroCount)
        repeat(heroCount) {
            heroes += reader.readVarint() ?: return DecodeResult.Failure(reader.currentFailure)
        }

        val cards = reader.readNormalCardGroups()
            ?: return DecodeResult.Failure(reader.currentFailure)

        val sideboardCards: List<KmpSideboardCard> = if (reader.hasRemaining()) {
            val marker = reader.readByte() ?: return DecodeResult.Failure(reader.currentFailure)
            when (marker) {
                0 -> emptyList()
                1 -> reader.readSideboardCardGroups()
                    ?: return DecodeResult.Failure(reader.currentFailure)
                else -> return DecodeResult.Failure(DeckStringFailure.InvalidSideboardFormat)
            }
        } else {
            emptyList()
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

private class ByteReader(private val bytes: ByteArray) {
    private var index: Int = 0
    private var failure: DeckStringFailure? = null

    val currentFailure: DeckStringFailure
        get() = failure ?: DeckStringFailure.InvalidValue("reader failed without a recorded failure")

    fun hasRemaining(): Boolean = index < bytes.size

    fun readByte(): Int? {
        if (index >= bytes.size) {
            return fail(DeckStringFailure.UnexpectedEndOfData)
        }
        return bytes[index++].toInt() and 0xFF
    }

    fun readVarint(): Int? {
        if (index >= bytes.size) {
            return fail(DeckStringFailure.UnexpectedEndOfData)
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
                return fail(DeckStringFailure.MalformedVarint)
            }
            result = result or (payload shl shift)
            shift += 7

            if ((byte and 0x80) == 0) {
                return result
            }
        }

        return fail(
            if (bytesRead >= maxBytes) DeckStringFailure.MalformedVarint
            else DeckStringFailure.UnexpectedEndOfData
        )
    }

    fun readNormalCardGroups(): List<KmpCard>? {
        val singleCount = readVarint() ?: return null
        val singleCards = readNormalCardsWithFixedCount(singleCount, count = 1) ?: return null

        val doubleCount = readVarint() ?: return null
        val doubleCards = readNormalCardsWithFixedCount(doubleCount, count = 2) ?: return null

        val multiCount = readVarint() ?: return null
        val multiCards = readNormalCardsWithExplicitCount(multiCount) ?: return null

        val totalEntryCount = groupEntryCount(singleCount, doubleCount, multiCount)
            ?: return fail(DeckStringFailure.InvalidValue("card group count overflow"))
        return ArrayList<KmpCard>(totalEntryCount).apply {
            addAll(singleCards)
            addAll(doubleCards)
            addAll(multiCards)
        }
    }

    fun readSideboardCardGroups(): List<KmpSideboardCard>? {
        val singleCount = readVarint() ?: return null
        val singleCards = readSideboardCardsWithFixedCount(singleCount, count = 1) ?: return null

        val doubleCount = readVarint() ?: return null
        val doubleCards = readSideboardCardsWithFixedCount(doubleCount, count = 2) ?: return null

        val multiCount = readVarint() ?: return null
        val multiCards = readSideboardCardsWithExplicitCount(multiCount) ?: return null

        val totalEntryCount = groupEntryCount(singleCount, doubleCount, multiCount)
            ?: return fail(DeckStringFailure.InvalidValue("sideboard group count overflow"))
        return ArrayList<KmpSideboardCard>(totalEntryCount).apply {
            addAll(singleCards)
            addAll(doubleCards)
            addAll(multiCards)
        }
    }

    private fun readNormalCardsWithFixedCount(entryCount: Int, count: Int): List<KmpCard>? {
        if (!canReadMinimumVarints(entryCount, valuesPerEntry = 1)) {
            return fail(DeckStringFailure.UnexpectedEndOfData)
        }

        val cards = ArrayList<KmpCard>(entryCount)
        repeat(entryCount) {
            val cardId = readVarint() ?: return null
            cards += KmpCard(dbfId = cardId, count = count)
        }
        return cards
    }

    private fun readNormalCardsWithExplicitCount(entryCount: Int): List<KmpCard>? {
        if (!canReadMinimumVarints(entryCount, valuesPerEntry = 2)) {
            return fail(DeckStringFailure.UnexpectedEndOfData)
        }

        val cards = ArrayList<KmpCard>(entryCount)
        repeat(entryCount) {
            val cardId = readVarint() ?: return null
            val count = readVarint() ?: return null
            cards += KmpCard(dbfId = cardId, count = count)
        }
        return cards
    }

    private fun readSideboardCardsWithFixedCount(
        entryCount: Int,
        count: Int,
    ): List<KmpSideboardCard>? {
        if (!canReadMinimumVarints(entryCount, valuesPerEntry = 2)) {
            return fail(DeckStringFailure.UnexpectedEndOfData)
        }

        val cards = ArrayList<KmpSideboardCard>(entryCount)
        repeat(entryCount) {
            val cardId = readVarint() ?: return null
            val sideboardOwner = readVarint() ?: return null
            cards += KmpSideboardCard(dbfId = cardId, count = count, sideboardOwner = sideboardOwner)
        }
        return cards
    }

    private fun readSideboardCardsWithExplicitCount(entryCount: Int): List<KmpSideboardCard>? {
        if (!canReadMinimumVarints(entryCount, valuesPerEntry = 3)) {
            return fail(DeckStringFailure.UnexpectedEndOfData)
        }

        val cards = ArrayList<KmpSideboardCard>(entryCount)
        repeat(entryCount) {
            val cardId = readVarint() ?: return null
            val count = readVarint() ?: return null
            val sideboardOwner = readVarint() ?: return null
            cards += KmpSideboardCard(dbfId = cardId, count = count, sideboardOwner = sideboardOwner)
        }
        return cards
    }

    private fun canReadMinimumVarints(entryCount: Int, valuesPerEntry: Int): Boolean {
        if (entryCount < 0) {
            return false
        }
        val minimumBytes = entryCount.toLong() * valuesPerEntry.toLong()
        return minimumBytes <= (bytes.size - index).toLong()
    }

    private fun <T> fail(failure: DeckStringFailure): T? {
        this.failure = failure
        return null
    }
}

private class ByteWriter {
    private var bytes = ByteArray(64)
    private var size: Int = 0

    fun writeByte(value: Int) {
        ensureCapacity(size + 1)
        bytes[size] = (value and 0xFF).toByte()
        size += 1
    }

    fun writeVarint(value: Int): DeckStringFailure? {
        if (value < 0) {
            return DeckStringFailure.InvalidValue("varint value must be non-negative")
        }

        var remaining = value
        while (remaining >= 0x80) {
            writeByte((remaining and 0x7F) or 0x80)
            remaining = remaining ushr 7
        }
        writeByte(remaining and 0x7F)
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

    fun toByteArray(): ByteArray = bytes.copyOf(size)

    private fun ensureCapacity(requiredCapacity: Int) {
        if (requiredCapacity <= bytes.size) {
            return
        }

        var newCapacity = bytes.size
        while (newCapacity < requiredCapacity) {
            val doubledCapacity = newCapacity * 2
            newCapacity = if (doubledCapacity > newCapacity) doubledCapacity else requiredCapacity
        }
        bytes = bytes.copyOf(newCapacity)
    }
}

private data class CardGroups<T>(
    val singleCards: List<T>,
    val doubleCards: List<T>,
    val multiCards: List<T>,
)

private fun List<KmpCard>.trisort(): CardGroups<KmpCard> {
    val singleCards = ArrayList<KmpCard>()
    val doubleCards = ArrayList<KmpCard>()
    val multiCards = ArrayList<KmpCard>()
    for (card in this) {
        when (card.count) {
            1 -> singleCards += card
            2 -> doubleCards += card
            else -> multiCards += card
        }
    }
    return CardGroups(singleCards, doubleCards, multiCards)
}

private fun List<KmpSideboardCard>.trisort(): CardGroups<KmpSideboardCard> {
    val singleCards = ArrayList<KmpSideboardCard>()
    val doubleCards = ArrayList<KmpSideboardCard>()
    val multiCards = ArrayList<KmpSideboardCard>()
    for (card in this) {
        when (card.count) {
            1 -> singleCards += card
            2 -> doubleCards += card
            else -> multiCards += card
        }
    }
    return CardGroups(singleCards, doubleCards, multiCards)
}

private fun groupEntryCount(vararg counts: Int): Int? {
    var total = 0L
    for (count in counts) {
        total += count.toLong()
        if (total > Int.MAX_VALUE) {
            return null
        }
    }
    return total.toInt()
}

@OptIn(ExperimentalEncodingApi::class)
private fun decodeBase64(value: String): ByteArray = Base64.Default.decode(value)

@OptIn(ExperimentalEncodingApi::class)
private fun encodeBase64(bytes: ByteArray): String = Base64.Default.encode(bytes)
