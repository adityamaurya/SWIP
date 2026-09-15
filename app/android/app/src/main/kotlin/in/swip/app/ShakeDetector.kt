package `in`.swip.app

import kotlin.math.sqrt

/**
 * `F-173` — **did the user just shake the phone?**
 *
 * > *"if I shake the phone it should be back"*
 *
 * ## Why this is a class with no Android in it
 *
 * Because it is the one piece of the floating bubble that can be **tested**,
 * and until now nothing about the bubble could be. There is no instrumentation
 * here and no emulator in CI; what there is, after this file, is a JVM unit
 * test — see `ShakeDetectorTest.kt` and the `testImplementation` line in
 * `tool/bootstrap.sh`.
 *
 * That matters more than it looks. The two ways this feature fails are
 * opposite and both are silent:
 *
 *   * **too sensitive** — the bubble reappears while the user is walking, or
 *     puts the phone down, or takes it out of a pocket. They snoozed it and it
 *     came back on its own, which reads as the app ignoring them;
 *   * **too dull** — they shake it and nothing happens, and there is no way to
 *     tell whether the gesture was wrong or the feature is broken.
 *
 * Neither produces a crash, a log line or a failing build. The only way to
 * know where the line sits is to feed the arithmetic a walk, a pocket, a
 * tabletop and a real shake and assert on what comes out — which is exactly
 * what the test does, and why every threshold below is a constructor
 * parameter rather than a literal buried in a sensor callback.
 *
 * ## The algorithm, and why it is not just "is the phone moving"
 *
 * A single acceleration reading cannot tell a shake from a drop, a jog or the
 * phone being set down hard — all of them spike. What distinguishes a shake is
 * that it is **repeated and reciprocating**: several hard accelerations,
 * quickly, in a row.
 *
 * So a sample above [threshold] is not a shake, it is a *hit*. [requiredHits]
 * of them inside [windowMs] is a shake. [debounceMs] stops one swing being
 * counted several times, because the accelerometer reports far faster than a
 * wrist moves and a single jerk otherwise satisfies the whole quota by itself
 * — which is the bug that makes naive shake detectors fire when you set the
 * phone on a table.
 *
 * ## Why gravity is subtracted by dividing rather than by filtering
 *
 * `TYPE_ACCELEROMETER` includes gravity, so a phone lying still reads about
 * 1 g, not 0. The textbook answer is a high-pass filter to isolate linear
 * acceleration, or `TYPE_LINEAR_ACCELERATION`, which does it in the platform.
 *
 * Neither is used, deliberately. A filter carries state across samples, which
 * is more to get wrong for a gesture whose whole definition is "much larger
 * than gravity"; and `TYPE_LINEAR_ACCELERATION` is a *composite* sensor that
 * not every device provides, so relying on it would mean the feature silently
 * not existing on some phones. Dividing the magnitude by gravity gives a
 * number where "1" means at rest in any orientation, and the threshold reads
 * as what it is: how many times harder than gravity the movement was.
 */
class ShakeDetector(
    /**
     * How many g the movement must exceed to count as a hit.
     *
     * 2.3 is deliberately high. Published shake detectors commonly use 1.2–2.7;
     * the low end of that range fires when a phone is set down on a desk, and
     * this one lives behind a snooze the user has just explicitly asked for —
     * so a false positive undoes a deliberate action, which is much worse than
     * needing a second shake.
     */
    private val threshold: Float = 2.3f,

    /** Hits needed inside [windowMs]. Three is roughly one and a half shakes. */
    private val requiredHits: Int = 3,

    /** How long the hits have to arrive within. */
    private val windowMs: Long = 1_200L,

    /** Minimum gap between two hits, so one swing counts once. */
    private val debounceMs: Long = 150L,
) {

    private var hits = 0
    private var firstHitAt = 0L
    private var lastHitAt = 0L

    /** Forget any partial shake. Called when the detector is switched on. */
    fun reset() {
        hits = 0
        firstHitAt = 0L
        lastHitAt = 0L
    }

    /**
     * Feed one accelerometer sample.
     *
     * [atMs] is a monotonic millisecond clock — `SystemClock.elapsedRealtime()`
     * at the call site, and an ordinary counter in the test. **Not**
     * `System.currentTimeMillis()`: that jumps when the network corrects the
     * clock, and a backwards jump mid-gesture would put [firstHitAt] in the
     * future and stop the detector until it was reset.
     *
     * @return true **exactly once** per detected shake, at the moment the
     * quota is met. The detector resets itself on the way out, so a continued
     * shake produces one more `true` a full quota later rather than one per
     * sample — a caller can therefore act on this directly without its own
     * cooldown.
     */
    fun onSample(x: Float, y: Float, z: Float, atMs: Long): Boolean {
        val g = sqrt(x * x + y * y + z * z) / GRAVITY
        if (g < threshold) return false

        // One swing, counted once. Without this the quota is met by a single
        // jerk, because the sensor reports every ~20 ms and a wrist takes
        // longer than that to change direction.
        if (hits > 0 && atMs - lastHitAt < debounceMs) return false

        // Start a new window if the last one has gone stale. The `hits == 0`
        // arm is the first hit of all; the other is a hit arriving too late to
        // belong to the run it would otherwise have joined.
        if (hits == 0 || atMs - firstHitAt > windowMs) {
            hits = 1
            firstHitAt = atMs
            lastHitAt = atMs
            return requiredHits <= 1
        }

        hits++
        lastHitAt = atMs
        if (hits < requiredHits) return false

        reset()
        return true
    }

    private companion object {
        /**
         * Earth gravity in m/s², the same value as
         * `android.hardware.SensorManager.GRAVITY_EARTH`.
         *
         * Written out rather than imported so this file has **no Android
         * dependency at all**, which is what lets the test run on the JVM in
         * CI instead of needing a device.
         */
        const val GRAVITY = 9.80665f
    }
}
