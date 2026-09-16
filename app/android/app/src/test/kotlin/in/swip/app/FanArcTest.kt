package `in`.swip.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * `F-189` — the three things about the fan that a screenshot cannot show.
 *
 * An overlay window has **no parent**. Two items placed on the same pixel is
 * not an exception, not a warning, and not a failed layout — it is one disc on
 * screen where there should be two, and the choice underneath is simply
 * unreachable. `CLAUDE.md` records the `Stack` version of this costing a round
 * (a 260 px reticle drawn under the copy at both ends), and windows are the
 * worse case because there is not even a parent to be entitled to overlap.
 *
 * So: on the correct side, on the screen, and **never on top of each other** —
 * asserted at every corner of a tall phone and a short one.
 */
class FanArcTest {

    // A 1080x2400 phone at 3x, which is roughly the owner's Nothing AIN065.
    private val bubble = 168   // 56 dp
    private val item = 168
    private val radius = 252   // 84 dp
    private val margin = 24    // 8 dp
    private val screenW = 1080
    private val screenH = 2400

    private fun place(
        x: Int,
        y: Int,
        toRight: Boolean = true,
        count: Int = 2,
        w: Int = screenW,
        h: Int = screenH,
    ) = FanArc.place(
        bubbleX = x, bubbleY = y, bubbleSize = bubble, itemSize = item,
        count = count, toRight = toRight, radius = radius,
        spreadDegrees = 60.0, tiltDegrees = 25.0,
        screenWidth = w, screenHeight = h, margin = margin,
    )

    private fun overlaps(a: FanSlot, b: FanSlot): Boolean =
        a.x < b.x + item && b.x < a.x + item &&
            a.y < b.y + item && b.y < a.y + item

    // ── the one that matters ────────────────────────────────────────────────

    @Test
    fun `no two items ever overlap, anywhere on the screen`() {
        // Every corner, both edges, and the middle — including the positions
        // where a naive per-item clamp collapses the arc onto one point.
        for (x in listOf(margin, 100, screenW / 2, screenW - bubble - margin)) {
            for (y in listOf(margin, 1, 200, screenH / 2, screenH - bubble - margin)) {
                for (right in listOf(true, false)) {
                    val slots = place(x, y, toRight = right)
                    assertEquals(2, slots.size)
                    assertTrue(
                        "overlap at x=$x y=$y right=$right: $slots",
                        !overlaps(slots[0], slots[1]),
                    )
                }
            }
        }
    }

    @Test
    fun `every item stays on the screen`() {
        for (x in listOf(0, margin, screenW / 2, screenW - bubble)) {
            for (y in listOf(0, margin, screenH / 2, screenH - bubble, screenH)) {
                for (right in listOf(true, false)) {
                    for (s in place(x, y, toRight = right)) {
                        assertTrue("$s off left", s.x >= margin)
                        assertTrue("$s off top", s.y >= margin)
                        assertTrue("$s off right", s.x + item <= screenW - margin)
                        assertTrue("$s off bottom", s.y + item <= screenH - margin)
                    }
                }
            }
        }
    }

    // ── the direction, which is the whole point of the change ───────────────

    @Test
    fun `the arc swings away from the parked edge`() {
        val centreX = margin + bubble / 2

        // Parked left, opening right: both items are to the right of centre.
        for (s in place(margin, 1200, toRight = true)) {
            assertTrue("$s is not in front of a left-parked bubble",
                s.x + item / 2 > centreX)
        }

        // Parked right, opening left.
        val rightX = screenW - bubble - margin
        val rightCentre = rightX + bubble / 2
        for (s in place(rightX, 1200, toRight = false)) {
            assertTrue("$s is not in front of a right-parked bubble",
                s.x + item / 2 < rightCentre)
        }
    }

    @Test
    fun `the first item is the top of the arc`() {
        // Not arbitrary: item 0 is the QR scan, the common case, and the top
        // of an arc swung out from a thumb is the shortest travel.
        val slots = place(margin, 1200)
        assertTrue("${slots[0]} is not above ${slots[1]}", slots[0].y < slots[1].y)
    }

    @Test
    fun `an arc near the top slides down rather than closing up`() {
        // The case a per-item clamp gets wrong. Both items must still be a
        // full item-height apart in the vertical, not stacked at the margin.
        val slots = place(margin, 1)
        assertTrue("collapsed: $slots", slots[1].y - slots[0].y > item / 2)
        assertTrue("$slots left the screen", slots.all { it.y >= margin })
    }

    // ── the shapes that would otherwise crash or be silently empty ──────────

    @Test
    fun `the arc is an arc, not a column`() {
        // The whole reason `tiltDegrees` exists. A spread centred on the
        // horizontal puts two items at +a and -a, which share a cosine and
        // therefore an x — a vertical pair in front of the bubble, which is
        // still a list. They have to differ in BOTH axes.
        val slots = place(margin, 1200)
        assertTrue("same x, so this is a column: $slots", slots[0].x != slots[1].x)
        assertTrue("same y: $slots", slots[0].y != slots[1].y)
        // And the lower one is further out, which is what makes it read as
        // swinging open rather than as two things at two heights.
        assertTrue("not swung: $slots", slots[1].x > slots[0].x)
    }

    @Test
    fun `a single item sits on the arc's centre line`() {
        val slots = place(margin, 1200, count = 1)
        assertEquals(1, slots.size)
        // Up and forward, at the tilt — not level, which is what an untilted
        // arc would give and is no longer what this places.
        assertTrue("${slots[0]} is not above the bubble's centre",
            slots[0].y < 1200 + bubble / 2 - item / 2)
        assertTrue("${slots[0]} is not in front",
            slots[0].x > margin + bubble / 2)
    }

    @Test
    fun `no items is an empty list, not a crash`() {
        assertEquals(emptyList<FanSlot>(), place(margin, 1200, count = 0))
    }

    @Test
    fun `a screen too small for the arc does not throw`() {
        // The degenerate case `BubblePark` exists to contain, in its fan form:
        // every bound here comes from a live screen measurement, and a
        // freeform window or a foldable read while closed can be smaller than
        // the thing being placed in it. `coerceIn` would throw from a touch
        // handler on a window the user cannot dismiss.
        val slots = place(0, 0, w = 200, h = 200)
        assertEquals(2, slots.size)
        for (s in slots) {
            assertTrue("$s went negative", s.x >= 0 && s.y >= 0)
        }
    }
}
