package `in`.swip.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * `F-187` — **the privacy rule, proved rather than promised.**
 *
 * An APDU exchange is the one place in SWIP where a real merchant identifier
 * lives: EMV tag `9F16`. The POS black box is meant to be exported and sent —
 * that is the whole ritual it exists for — so a debug log that quietly carried
 * a merchant ID off the phone would be a privacy hole opened for convenience,
 * in the one app whose entire claim is that nothing leaves it.
 *
 * `TapTrace` is written so that cannot happen: [TapTrace.tagFields] is the only
 * route by which an exchange's contents reach a file, and it emits tag names
 * and value lengths. The paragraph above it in the source says so. **A
 * paragraph cannot fail CI**, so this does.
 *
 * The test below hands it a map of real-looking hex — a merchant name, a
 * merchant ID, an MCC — and asserts that not one of those values appears
 * anywhere in what comes back. It is written to fail on the obvious future
 * edit: somebody adding `"raw" to tlv.toString()` to a debug line while chasing
 * something else.
 */
class TapTraceTest {

    /**
     * A plausible GPO response. `9F16` is the merchant identifier and `5F20`
     * the cardholder/merchant name — the two fields that must never be written.
     */
    private val realistic = mapOf(
        // "SHRIBALAJI" in ASCII hex.
        "9F16" to "5348524942414C414A49",
        "5F20" to "534852492042414C414A492053544F524553",
        // MCC 5411, grocery.
        "9F15" to "5411",
        "9F1A" to "0356",
    )

    @Test
    fun `no value from the exchange appears in the output`() {
        val out = TapTrace.tagFields(realistic).joinToString("|") { "${it.first}=${it.second}" }
        for ((tag, value) in realistic) {
            assertTrue(
                "the value of $tag reached the log: $out",
                !out.contains(value, ignoreCase = true),
            )
        }
    }

    @Test
    fun `the tag names do appear, because they are the finding`() {
        // Which tags a terminal answered with is the whole diagnosis — a
        // `9F15` that never arrived and one that arrived as padding are
        // different failures with the same symptom.
        val tags = TapTrace.tagFields(realistic).first { it.first == "tags" }.second as String
        assertEquals("5F20,9F15,9F16,9F1A", tags)
    }

    @Test
    fun `a length is half the hex character count`() {
        // Hex, so two characters per byte. A `9F15` of length 2 that was
        // dropped as padding and a `9F15` that never came are told apart by
        // this number and nothing else.
        val lengths = TapTrace.tagFields(realistic).first { it.first == "lengths" }.second as String
        assertTrue(lengths, lengths.contains("9F15:2"))
        assertTrue(lengths, lengths.contains("9F16:10"))
    }

    @Test
    fun `order is stable, so two exchanges can be compared by eye`() {
        // The question this file answers is "what was different about the taps
        // that worked", and that is read by putting two lines next to each
        // other. A map's iteration order is not something to rely on for that.
        val shuffled = mapOf(
            "9F1A" to "0356",
            "9F16" to "5348524942414C414A49",
            "9F15" to "5411",
            "5F20" to "534852492042414C414A492053544F524553",
        )
        assertEquals(TapTrace.tagFields(realistic), TapTrace.tagFields(shuffled))
    }

    @Test
    fun `an empty exchange is still a line worth writing`() {
        // A terminal that selected us and answered with nothing is failure 7,
        // and it has to be distinguishable from a tap that never got here at
        // all. So this writes a count of zero rather than writing nothing.
        val out = TapTrace.tagFields(emptyMap())
        assertEquals(0, out.first { it.first == "count" }.second)
        assertEquals("", out.first { it.first == "tags" }.second)
    }
}
