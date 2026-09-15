package `in`.swip.app

/**
 * `F-180` — where the floating button is allowed to rest, as arithmetic that
 * can be tested.
 *
 * ## Why this is its own file with no Android in it
 *
 * The same reason [ShakeDetector] is. Everything else about the bubble's
 * position runs through `WindowManager`, which cannot be exercised without a
 * device, so the numbers inside it have never been checked by anything. They
 * are also the numbers that were wrong: the bug this round fixed was the
 * bubble reappearing at the snooze target because nothing put it back, and the
 * fix is a calculation performed ten minutes after the gesture that caused it,
 * at a moment nobody is watching.
 *
 * A calculation nobody watches, in a file nothing can test, is how the first
 * version of this shipped. So it is here, it is pure, and `BubbleParkTest`
 * runs on the JVM in CI.
 *
 * ## The hazard this exists to contain
 *
 * `coerceIn(min, max)` **throws** when `max < min`, and every maximum here is
 * derived from a live screen measurement. On a short display — or a foldable
 * being read while closed, or a phone in a small freeform window — the
 * subtraction can land under the margin, and the exception would be thrown
 * from inside a touch handler on a window the user has no way to dismiss.
 *
 * Every function below is therefore written so its range is provably non-empty
 * before anything is coerced into it, and there is a test for the degenerate
 * screen rather than a comment claiming it was considered.
 */
internal object BubblePark {

    /**
     * The lowest Y the bubble may rest at.
     *
     * [bottomGap] is larger than [margin] on purpose: the bottom strip of a
     * phone is where the gesture bar lives and where most apps put their
     * primary action, and a floating button parked on top of either is a
     * button that has to be moved before the app underneath can be used.
     */
    fun lowestY(
        screenHeight: Int,
        viewHeight: Int,
        margin: Int,
        bottomGap: Int,
    ): Int = (screenHeight - viewHeight - bottomGap).coerceAtLeast(margin)

    /**
     * Where to put the bubble when it comes back from a snooze.
     *
     * [remembered] is the position it settled at before the snooze, or null if
     * it has never settled — which is only true before the first drag. The
     * fallback is a third of the way down, the same place `addBubble` starts
     * it, so a snooze taken on a fresh install returns it to where it began
     * rather than to the top of the screen.
     *
     * A remembered position is still clamped. The screen can rotate, or fold,
     * or the bubble can be restored on a different display than the one it was
     * snoozed on, and a Y that was legal then can be off the bottom now.
     */
    fun restY(
        remembered: Int?,
        screenHeight: Int,
        viewHeight: Int,
        margin: Int,
        bottomGap: Int,
    ): Int = (remembered ?: (screenHeight / 3))
        .coerceIn(margin, lowestY(screenHeight, viewHeight, margin, bottomGap))

    /**
     * The X of whichever edge the bubble is parked against.
     *
     * There is no remembered X and there should not be: the bubble only ever
     * rests against one of two edges, and which one is already recorded by the
     * drag that put it there. Two sources of truth for one fact is how the
     * pill's left edge and the spring's target came to disagree in `F-165`.
     */
    fun edgeX(
        parkedRight: Boolean,
        screenWidth: Int,
        viewWidth: Int,
        margin: Int,
    ): Int = if (parkedRight) {
        (screenWidth - viewWidth - margin).coerceAtLeast(margin)
    } else {
        margin
    }
}
