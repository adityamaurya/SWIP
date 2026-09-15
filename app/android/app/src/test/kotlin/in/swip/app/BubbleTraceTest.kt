package `in`.swip.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * `F-176` — the one part of the flight recorder that can be wrong silently.
 *
 * ## Why escaping, of all things, is what gets a test
 *
 * Everything else in `BubbleTrace` fails loudly or not at all: a file that
 * cannot be written throws, a disabled build writes nothing. **Escaping fails
 * quietly and late.** A device name containing a quote, or a reason string
 * with a newline in it, produces a line no JSON reader will parse — and the
 * first anyone knows is an export that cannot be opened, *after* the
 * disappearance being chased has been reproduced and lost.
 *
 * The format is JSONL: one object per line, and a field that smuggles in a
 * newline splits one event into two broken halves. So the assertion that
 * matters most below is the dullest one — a line is exactly one line.
 *
 * `Build.MODEL` is manufacturer-supplied and has carried stray characters on
 * real devices, which is why this is not hypothetical.
 */
class BubbleTraceTest {

    private fun line(event: String, vararg fields: Pair<String, Any?>) =
        BubbleTrace.formatLine(
            atMs = 1_789_000_000_000L,
            upMs = 123_456L,
            pid = 4242,
            event = event,
            fields = fields.toList(),
        )

    @Test
    fun `a line carries the four things every event needs`() {
        val out = line("service.create")
        assertTrue(out, out.startsWith("{\"t\":\""))
        assertTrue(out, out.contains("\"up\":123456"))
        assertTrue(out, out.contains("\"pid\":4242"))
        assertTrue(out, out.contains("\"e\":\"service.create\""))
        assertTrue(out, out.endsWith("}\n"))
    }

    @Test
    fun `an event with no fields omits the value object entirely`() {
        // Rather than writing an empty `"v":{}`, which is noise on every
        // second line of a file meant to be read by eye.
        assertTrue(!line("bubble.remove").contains("\"v\""))
    }

    @Test
    fun `booleans and numbers are not quoted, strings are`() {
        // The whole point of the visibility line is comparing four booleans at
        // a glance. Quoted booleans would still parse and would be miserable
        // to read — and "false" is truthy in most things that would read it.
        val out = line(
            "visibility",
            "visible" to false,
            "screenOff" to false,
            "asleepMs" to 0L,
            "why" to "appInForeground",
        )
        assertTrue(out, out.contains("\"visible\":false"))
        assertTrue(out, out.contains("\"asleepMs\":0"))
        assertTrue(out, out.contains("\"why\":\"appInForeground\""))
    }

    @Test
    fun `null is null, not the string null`() {
        assertTrue(line("x", "why" to null).contains("\"why\":null"))
    }

    // ── the ones that protect the format ───────────────────────────────────

    @Test
    fun `a field containing a newline still produces exactly one line`() {
        // JSONL's only rule. Break it and one event becomes two unparseable
        // halves, and every line after it is read against the wrong event.
        val out = line("device", "model" to "Weird\nPhone\r\n2")
        assertEquals(1, out.count { it == '\n' })
        assertTrue(out, out.endsWith("}\n"))
        assertTrue(out, out.contains("\\n"))
        assertTrue(out, out.contains("\\r"))
    }

    @Test
    fun `quotes and backslashes are escaped`() {
        val out = line("device", "model" to """Pixel "6" \ Pro""")
        assertEquals(1, out.count { it == '\n' })
        assertTrue(out, out.contains("\\\""))
        assertTrue(out, out.contains("\\\\"))
    }

    @Test
    fun `a control character becomes a unicode escape`() {
        // Raw bytes under 0x20 are illegal inside a JSON string, and
        // manufacturer strings have carried them.
        val out = line("device", "model" to "PixelSix")
        assertTrue(out, out.contains("\\u0001"))
        assertEquals(1, out.count { it == '\n' })
    }

    @Test
    fun `an event name with a quote in it cannot break the line either`() {
        // Event names are ours, so this should never happen — which is exactly
        // why it would go unnoticed if it did.
        val out = line("bad\"name")
        assertTrue(out, out.contains("\"e\":\"bad\\\"name\""))
        assertEquals(1, out.count { it == '\n' })
    }

    @Test
    fun `a non-finite number is quoted rather than written as NaN`() {
        // JSON has no NaN or Infinity. Written bare they are a parse error;
        // written as strings the line survives and the oddity stays visible.
        val out = line("x", "ratio" to Double.NaN)
        assertTrue(out, out.contains("\"ratio\":\"NaN\""))
    }

    @Test
    fun `field order is preserved`() {
        // The visibility line is read as a row of flags, and a row whose
        // columns move between lines is a row nobody can scan.
        val out = line("visibility", "a" to 1, "b" to 2, "c" to 3)
        assertTrue(out, out.indexOf("\"a\"") < out.indexOf("\"b\""))
        assertTrue(out, out.indexOf("\"b\"") < out.indexOf("\"c\""))
    }
}
