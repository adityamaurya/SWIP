package `in`.swip.app

import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin

/** Where one fan item's window goes, top-left, in screen pixels. */
data class FanSlot(val x: Int, val y: Int)

/**
 * `F-189` — **where the fan's items sit, as arithmetic that can be checked.**
 *
 * > *"the behaviour of the launcher icon populating sub options should be
 * > placed in circular way in front rather than top positioned reveal it
 * > should be in front like tree branches in miro"*
 *
 * `F-185` stacked the items straight up from the bubble at the same `x`. That
 * is a menu, and a menu opening upward from a button parked on an edge is the
 * shape of a dropdown — it reads as *a list appeared* rather than as *the
 * button opened*. It also puts the items where the bubble's own edge already
 * is, so the first thing the eye does is look past them at the screen edge.
 *
 * An arc **in front** — swung away from the edge the bubble is parked on —
 * puts the choices over the screen the user is already looking at, at the
 * distance a thumb pivots through. Which is what the owner means by tree
 * branches: they come off the trunk sideways.
 *
 * ## Why this is a separate file with no Android in it
 *
 * `CLAUDE.md`: *"a `Stack` is entitled to overlap its children, so a layout
 * that is wrong throws nothing"*. Overlay windows are worse than a `Stack` —
 * there is no parent at all, so two items placed on the same pixel is not an
 * error, not a warning, and not visible in a screenshot taken a frame early.
 * A 260 px reticle drawn under the copy cost a round for exactly this reason.
 *
 * Everything below is integers and trigonometry, so it runs on the JVM and
 * `FanArcTest` asserts the things a person cannot see: that the items are on
 * the correct side, that none of them leaves the screen, and that **no two of
 * them overlap** — on a tall phone, a short one, and with the bubble jammed
 * into every corner. Same split as `BubblePark` and `ShakeDetector`, for the
 * same reason.
 */
object FanArc {

    /**
     * Place [count] items on an arc in front of a bubble.
     *
     * [toRight] is the direction the arc swings — away from the edge the
     * bubble is parked against, so a bubble on the left opens rightwards.
     *
     * The first item is the **top** of the arc. That is not arbitrary: the QR
     * scan is the common case and the top of an arc swung out from a thumb is
     * the shortest travel from the bubble.
     *
     * [tiltDegrees] swings the whole arc; see the note on the angle below for
     * why an untilted two-item arc is not an arc at all.
     */
    fun place(
        bubbleX: Int,
        bubbleY: Int,
        bubbleSize: Int,
        itemSize: Int,
        count: Int,
        toRight: Boolean,
        radius: Int,
        spreadDegrees: Double,
        tiltDegrees: Double,
        screenWidth: Int,
        screenHeight: Int,
        margin: Int,
    ): List<FanSlot> {
        if (count <= 0) return emptyList()

        val centreX = bubbleX + bubbleSize / 2.0
        val centreY = bubbleY + bubbleSize / 2.0
        val direction = if (toRight) 1.0 else -1.0

        val raw = (0 until count).map { i ->
            // -0.5 for the first item, +0.5 for the last, 0 when there is only
            // one — so a single item sits straight out in front rather than
            // needing a special case at the call site.
            val t = if (count == 1) 0.0 else i.toDouble() / (count - 1) - 0.5
            // Negated so the FIRST item is the top of the arc. Screen y grows
            // downward, which is the opposite of how the angle reads.
            //
            // [tiltDegrees] is what makes this an arc rather than a column.
            // A spread centred on the horizontal puts the items at **+a and
            // -a**, which share a cosine — so they land on the same `x`, one
            // above the other, 71 dp in front of the bubble. That is better
            // than `F-185`'s stack and it is still a list. Swinging the whole
            // arc up by a tilt gives every item a different angle, so each one
            // differs from its neighbour in both axes and the set reads as
            // something opening outward.
            val radians = Math.toRadians(tiltDegrees - t * spreadDegrees)
            val x = centreX + direction * radius * cos(radians) - itemSize / 2.0
            val y = centreY - radius * sin(radians) - itemSize / 2.0
            x to y
        }

        // ── keep the arc on screen by moving ALL of it ──────────────────────
        //
        // Clamping each item on its own is the obvious version and it is
        // wrong: near the top of the screen the upper item stops and the lower
        // one keeps going, so the arc closes up and at the extreme the two
        // land on the same pixel. Two 56 dp discs exactly on top of each other
        // look like one disc, and the choice underneath is unreachable with
        // nothing failing anywhere.
        //
        // Shifting the whole set preserves the shape: it slides down the
        // screen instead of collapsing.
        val shiftX = groupShift(
            raw.minOf { it.first }, raw.maxOf { it.first } + itemSize,
            margin, screenWidth - margin,
        )
        val shiftY = groupShift(
            raw.minOf { it.second }, raw.maxOf { it.second } + itemSize,
            margin, screenHeight - margin,
        )

        return raw.map { (x, y) ->
            FanSlot(
                // A per-item clamp as well, as a backstop for a screen so
                // small the group cannot fit however it is shifted. `max`
                // before `min` rather than `coerceIn`, which throws when its
                // maximum is below its minimum — the hazard `BubblePark`
                // exists to contain, and every bound here comes from a live
                // screen measurement.
                x = clamp(x + shiftX, margin, screenWidth - margin - itemSize),
                y = clamp(y + shiftY, margin, screenHeight - margin - itemSize),
            )
        }
    }

    /**
     * How far to move a group so it sits inside [low]..[high].
     *
     * Zero when it already does. Biased toward the low edge when the group is
     * wider than the space, because the alternative is pushing it off the top
     * of the screen to get it off the bottom.
     */
    private fun groupShift(from: Double, to: Double, low: Int, high: Int): Double {
        if (from < low) return low - from
        if (to > high) return max(high - to, low - from)
        return 0.0
    }

    private fun clamp(v: Double, low: Int, high: Int): Int =
        min(max(v, low.toDouble()), max(low, high).toDouble()).roundToInt()
}
