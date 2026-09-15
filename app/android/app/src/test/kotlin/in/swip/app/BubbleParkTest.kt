package `in`.swip.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * `F-180`. The arithmetic behind *"the bubble came back in the middle of the
 * screen"*.
 *
 * Every number here is in pixels on a notional 1080 × 2400 phone with the
 * project's real margins — 8 dp and 72 dp at density 3, so 24 and 216 — and a
 * 56 dp bubble, so 168.
 *
 * The tests that matter are the last three. The first few state the obvious so
 * that a change which breaks the obvious says so.
 */
class BubbleParkTest {

    private val margin = 24
    private val bottomGap = 216
    private val bubble = 168
    private val screenW = 1080
    private val screenH = 2400

    @Test
    fun `parks left at the margin`() {
        assertEquals(margin, BubblePark.edgeX(false, screenW, bubble, margin))
    }

    @Test
    fun `parks right a margin in from the far edge`() {
        assertEquals(
            screenW - bubble - margin,
            BubblePark.edgeX(true, screenW, bubble, margin),
        )
    }

    @Test
    fun `the lowest rest is a bottom gap up from the bottom`() {
        assertEquals(
            screenH - bubble - bottomGap,
            BubblePark.lowestY(screenH, bubble, margin, bottomGap),
        )
    }

    @Test
    fun `a remembered position is returned unchanged`() {
        assertEquals(
            700,
            BubblePark.restY(700, screenH, bubble, margin, bottomGap),
        )
    }

    @Test
    fun `no remembered position falls back to a third down`() {
        // The same place `addBubble` starts it, so a snooze taken before the
        // first drag returns the bubble to where it began.
        assertEquals(
            screenH / 3,
            BubblePark.restY(null, screenH, bubble, margin, bottomGap),
        )
    }

    // ── the three that are actually load-bearing ────────────────────────────

    @Test
    fun `a remembered position below the floor is pulled back up`() {
        // The phone was rotated, folded, or the bubble was snoozed on a taller
        // display. A Y that was legal then is off the bottom now, and restoring
        // it verbatim would put the button under the gesture bar — where it
        // cannot be dragged back out.
        val lowest = BubblePark.lowestY(screenH, bubble, margin, bottomGap)
        assertEquals(
            lowest,
            BubblePark.restY(screenH + 500, screenH, bubble, margin, bottomGap),
        )
    }

    @Test
    fun `a remembered position above the ceiling is pushed back down`() {
        assertEquals(
            margin,
            BubblePark.restY(-4000, screenH, bubble, margin, bottomGap),
        )
    }

    @Test
    fun `a screen too short for the gaps does not throw`() {
        // THE test. `coerceIn(min, max)` throws when max < min, and every
        // maximum here comes from a live screen measurement. A freeform window
        // or a foldable read while closed can be shorter than the bubble plus
        // its two gaps — and the exception would be thrown from a touch
        // handler, on a window the user has no way to dismiss.
        //
        // 200 px tall: the subtraction lands at 200 - 168 - 216 = -184, well
        // under the margin.
        val shortScreen = 200
        val lowest = BubblePark.lowestY(shortScreen, bubble, margin, bottomGap)
        assertTrue("the floor must never sink under the ceiling", lowest >= margin)

        // All three inputs — remembered, absent, and absurd — have to survive.
        assertEquals(margin, BubblePark.restY(900, shortScreen, bubble, margin, bottomGap))
        assertEquals(margin, BubblePark.restY(null, shortScreen, bubble, margin, bottomGap))
        assertEquals(margin, BubblePark.restY(-1, shortScreen, bubble, margin, bottomGap))
    }

    @Test
    fun `a screen narrower than the bubble still parks on screen`() {
        // The mirror of the case above, on the other axis. Without the
        // `coerceAtLeast` in `edgeX` a 100 px wide window would park a 168 px
        // bubble at -92 — off the left edge, while claiming to be on the right.
        assertEquals(margin, BubblePark.edgeX(true, 100, bubble, margin))
        assertEquals(margin, BubblePark.edgeX(false, 100, bubble, margin))
    }

    @Test
    fun `the restored position is always inside the legal strip`() {
        // A sweep rather than a handful of cases, because the bug this file
        // exists for was a position nobody looked at until ten minutes later.
        for (height in listOf(200, 640, 1280, 2400, 3200)) {
            val lowest = BubblePark.lowestY(height, bubble, margin, bottomGap)
            for (remembered in listOf(null, -9999, 0, 1, height / 2, height, 99999)) {
                val y = BubblePark.restY(remembered, height, bubble, margin, bottomGap)
                assertTrue("y=$y under the margin on a $height px screen", y >= margin)
                assertTrue("y=$y past the floor on a $height px screen", y <= lowest)
            }
        }
    }
}
