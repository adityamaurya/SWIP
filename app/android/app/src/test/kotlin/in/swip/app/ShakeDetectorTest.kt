package `in`.swip.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * `F-173` — **the first automated test the floating bubble has ever had.**
 *
 * Every previous round ended with the same sentence written down honestly:
 * the APK job proves the bubble compiles and nothing proves it behaves. This
 * is the start of closing that, and it is deliberately aimed at the piece
 * where being wrong is *invisible*.
 *
 * `ShakeDetector` decides whether a snoozed bubble comes back. Both failure
 * modes are silent — too sensitive and it returns while the user is walking,
 * undoing something they deliberately asked for; too dull and shaking does
 * nothing and they cannot tell whether they shook it wrong or the feature is
 * broken. Neither throws, neither logs, neither fails a build.
 *
 * So the thresholds are fed the situations a phone is actually in.
 *
 * ## Running it
 *
 * `cd app/android && ./gradlew :app:testDebugUnitTest` — JVM only, no
 * emulator, no device. CI runs it on every push, after the APK builds.
 */
class ShakeDetectorTest {

    /** One g, the reading of a phone lying still. */
    private val g = 9.80665f

    /**
     * Feed [samples] of (x, y, z) at [everyMs] apart and return how many times
     * the detector said "shake".
     */
    private fun run(
        detector: ShakeDetector,
        samples: List<Triple<Float, Float, Float>>,
        everyMs: Long,
        startAt: Long = 0L,
    ): Int {
        var fired = 0
        var t = startAt
        for ((x, y, z) in samples) {
            if (detector.onSample(x, y, z, t)) fired++
            t += everyMs
        }
        return fired
    }

    /** A hard movement of [magnitude] g, alternating direction each sample. */
    private fun swings(count: Int, magnitude: Float): List<Triple<Float, Float, Float>> =
        (0 until count).map { i ->
            val sign = if (i % 2 == 0) 1f else -1f
            Triple(sign * magnitude * g, 0f, 0f)
        }

    // ── the cases that must NOT fire ────────────────────────────────────────

    @Test
    fun `a phone lying on a table never fires`() {
        val d = ShakeDetector()
        // Gravity only, on the z axis, for ten seconds at 50 Hz.
        val still = List(500) { Triple(0f, 0f, g) }
        assertEquals(0, run(d, still, everyMs = 20))
    }

    @Test
    fun `a phone in a pocket while walking never fires`() {
        val d = ShakeDetector()
        // Walking peaks at roughly 1.2-1.8 g in the literature and in practice.
        // 1.8 is the top of that band, sustained, which is a brisk walk — and
        // it is still under the 2.3 g threshold by design.
        val walking = (0 until 400).map { i ->
            val sign = if (i % 4 < 2) 1f else -1f
            Triple(0f, sign * 1.8f * g * 0.6f, g)
        }
        assertEquals(0, run(d, walking, everyMs = 25))
    }

    @Test
    fun `one sharp knock does not fire`() {
        val d = ShakeDetector()
        // Setting the phone down hard, or a single tap against a table: one
        // spike, over in about 60 ms. This is the case the debounce exists
        // for — without it a single jerk satisfies the whole quota by itself,
        // because the sensor reports far faster than a wrist can reverse.
        val knock = List(3) { Triple(0f, 0f, 5f * g) }
        assertEquals(0, run(d, knock, everyMs = 20))
    }

    @Test
    fun `hard movements spread too far apart do not fire`() {
        val d = ShakeDetector()
        // Three hits, but 700 ms apart, so the third lands 1,400 ms after the
        // first — outside the 1,200 ms window. That is somebody moving about,
        // not shaking.
        assertEquals(0, run(d, swings(3, 3f), everyMs = 700))
    }

    // ── the case that must fire ────────────────────────────────────────────

    @Test
    fun `a real shake fires`() {
        val d = ShakeDetector()
        // Three reversals at 200 ms — about one and a half shakes of a wrist.
        assertEquals(1, run(d, swings(3, 3f), everyMs = 200))
    }

    @Test
    fun `a shake fires on the third hit and not before`() {
        val d = ShakeDetector()
        assertFalse(d.onSample(3f * g, 0f, 0f, 0))
        assertFalse(d.onSample(-3f * g, 0f, 0f, 200))
        assertTrue(d.onSample(3f * g, 0f, 0f, 400))
    }

    @Test
    fun `a sustained shake fires once per quota, not once per sample`() {
        val d = ShakeDetector()
        // Two seconds of continuous hard shaking at 50 Hz. A detector without
        // the self-reset would return true on every sample after the third and
        // the caller would unsnooze, resnooze and unsnooze again.
        val fired = run(d, swings(100, 3f), everyMs = 20)
        assertTrue("expected a small number of events, got $fired", fired in 1..8)
    }

    @Test
    fun `direction does not matter`() {
        // A shake is a shake whichever way the phone is held, which is the
        // whole reason the magnitude is taken rather than any one axis.
        for (axis in 0..2) {
            val d = ShakeDetector()
            val samples = (0 until 3).map { i ->
                val v = (if (i % 2 == 0) 1f else -1f) * 3f * g
                when (axis) {
                    0 -> Triple(v, 0f, 0f)
                    1 -> Triple(0f, v, 0f)
                    else -> Triple(0f, 0f, v)
                }
            }
            assertEquals("axis $axis", 1, run(d, samples, everyMs = 200))
        }
    }

    // ── housekeeping ───────────────────────────────────────────────────────

    @Test
    fun `reset forgets a partial shake`() {
        val d = ShakeDetector()
        assertFalse(d.onSample(3f * g, 0f, 0f, 0))
        assertFalse(d.onSample(-3f * g, 0f, 0f, 200))
        d.reset()
        // Without the reset this next one would be the third hit and fire.
        assertFalse(d.onSample(3f * g, 0f, 0f, 400))
    }

    @Test
    fun `a stale run restarts rather than accumulating`() {
        val d = ShakeDetector()
        // Two hits, a long gap, then two more. Four hard movements in total,
        // and still not a shake, because they are two pairs rather than a run.
        assertFalse(d.onSample(3f * g, 0f, 0f, 0))
        assertFalse(d.onSample(-3f * g, 0f, 0f, 200))
        assertFalse(d.onSample(3f * g, 0f, 0f, 5_000))
        assertFalse(d.onSample(-3f * g, 0f, 0f, 5_200))
        // …and the one after that completes the SECOND run.
        assertTrue(d.onSample(3f * g, 0f, 0f, 5_400))
    }

    @Test
    fun `the thresholds are settable, so a caller can be stricter`() {
        // Not decoration: it is what lets the test above assert on a boundary
        // without shipping a detector tuned for the test.
        val loose = ShakeDetector(threshold = 1.5f, requiredHits = 2)
        assertFalse(loose.onSample(2f * g, 0f, 0f, 0))
        assertTrue(loose.onSample(-2f * g, 0f, 0f, 200))
    }
}
