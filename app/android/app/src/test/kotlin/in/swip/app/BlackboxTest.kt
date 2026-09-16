package `in`.swip.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * `F-187` — the recorder core, and the one assertion that only exists because
 * there are now **two** of these files.
 *
 * ## Why this is short where `BubbleTraceTest` is long
 *
 * This is not a second copy of the eleven escaping cases in `BubbleTraceTest`.
 * It is the same format, so a second set of hand-written expectations would be
 * two lists that agree today and drift apart the first time one is edited —
 * which is exactly what `CLAUDE.md` records as *"three copies of one bound is
 * how a bound drifts"*.
 *
 * So the escaping is asserted **by comparison**: the two recorders must agree,
 * character for character, on the same hostile input. That single test catches
 * every divergence the eleven would, and it keeps catching them after somebody
 * edits one file and forgets the other.
 *
 * The rest is what is genuinely new here: two named instances that must not
 * quietly turn out to be one.
 *
 * `BubbleTrace` is scheduled for deletion
 * ([`docs/38`](../../../../../../../docs/38-BUBBLE-TRACE.md) §4). When it goes,
 * the drift test goes with it and the escaping cases move here — which is on
 * the removal list there rather than left as a surprise.
 */
class BlackboxTest {

    private fun line(event: String, vararg fields: Pair<String, Any?>) =
        Blackbox.formatLine(
            atMs = 1_789_000_000_000L,
            upMs = 123_456L,
            pid = 4242,
            event = event,
            fields = fields.toList(),
        )

    @Test
    fun `a line carries the four things every event needs`() {
        val out = line("hce.field")
        assertTrue(out, out.startsWith("{\"t\":\""))
        assertTrue(out, out.contains("\"up\":123456"))
        assertTrue(out, out.contains("\"pid\":4242"))
        assertTrue(out, out.contains("\"e\":\"hce.field\""))
        assertTrue(out, out.endsWith("}\n"))
    }

    @Test
    fun `the two recorders have not drifted apart`() {
        // The whole escaping suite, by proxy. Every hostile input
        // `BubbleTraceTest` checks one at a time is in here at once, and the
        // assertion is that both files produce the identical byte sequence.
        //
        // If this ever fails the question is not "which one is right" but
        // "which one was edited", and the answer is in the diff.
        val control = 1.toChar() // a raw 0x01, which real Build.MODEL strings have carried
        val fields = listOf<Pair<String, Any?>>(
            "why" to "moved away",
            "count" to 3,
            "on" to false,
            "nothing" to null,
            "ratio" to Double.NaN,
            "model" to "a \"quoted\" \\ back\nslash\r\tand a $control control",
        )
        assertEquals(
            BubbleTrace.formatLine(99L, 88L, 7, "hce.end", fields),
            Blackbox.formatLine(99L, 88L, 7, "hce.end", fields),
        )
    }

    @Test
    fun `a field containing a newline still produces exactly one line`() {
        // JSONL's only rule. Asserted here as well as inside the drift test,
        // because this is the one that has to survive `BubbleTrace`'s deletion.
        val out = line("device", "model" to "Weird\nPhone\r\n2")
        assertEquals(1, out.count { it == '\n' })
        assertTrue(out, out.endsWith("}\n"))
    }

    @Test
    fun `an event with no fields omits the value object entirely`() {
        assertTrue(!line("hce.field").contains("\"v\""))
    }

    // The part that is new, and covered nowhere else.

    @Test
    fun `the three recorders write to three different files`() {
        // A copy-paste that gave `power` the tap recorder's filename would
        // interleave two unrelated traces into one file and **nothing would
        // fail**: both would still be written, both would still parse, and the
        // export screen would still show something. It would be found by a
        // person reading an export and wondering why a battery span was
        // sitting between two APDUs — which is a bad way to find it, during
        // the one session where a real failure had just been reproduced.
        //
        // Cheap to assert, invisible otherwise.
        assertNotEquals(Blackbox.tap.fileName, Blackbox.power.fileName)
        assertNotEquals("bubble-trace.log", Blackbox.tap.fileName)
        assertNotEquals("bubble-trace.log", Blackbox.power.fileName)
    }
}
