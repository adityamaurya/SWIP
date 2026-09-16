package `in`.swip.app

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.SystemClock

/**
 * `F-188` — **the black box for battery.**
 *
 * > *"can you help me get a gauge or create a black box for this application,
 * > wherever whichever part of this application is consuming too much battery?
 * > I just want to keep a log of which part of this application is consuming
 * > too many battery resources while being in the background."*
 *
 * ## What this can honestly measure, and what it cannot
 *
 * **It cannot measure milliamps.** No app can measure its own power draw on
 * Android. `BatteryManager` reports the *phone's* current, which is every app
 * and the screen together, and `BatteryStats` — the thing that actually
 * attributes drain per app — needs `BATTERY_STATS`, a signature permission
 * granted only to the system.
 *
 * Saying that plainly matters, because the obvious thing to build here is a
 * screen with a number on it, and that number would be fiction.
 *
 * **What it can measure exactly is how long each subsystem was awake**, and
 * that is the thing the question is really about. Battery cost on a phone is
 * dominated by *duration*, not by instantaneous draw: an accelerometer
 * listener registered for six hours costs more than a camera open for ten
 * seconds, and neither is visible from outside.
 *
 * So this records **spans**. Every subsystem that can be expensive calls
 * [awake] when it starts and [asleep] when it stops, the span is written with
 * its duration, and the export adds up to *"the overlay window was up for 4 h,
 * the accelerometer for 11 min, the camera for 40 s"*. That is attributable,
 * it is true, and it is enough to find the thing that is wrong.
 *
 * The battery percentage is sampled alongside each span, so a long span and a
 * large drop in the same window is a real signal even though neither number
 * alone is.
 *
 * ## The subsystems worth naming
 *
 * | Name | Why it costs |
 * |---|---|
 * | `service` | The foreground service itself — a notification and a process that cannot be killed |
 * | `overlay` | The bubble's window. Composited on every frame the screen draws |
 * | `sensor` | The accelerometer, armed only while snoozed (`F-173`) |
 * | `camera` | The scanner. The most expensive thing here by a wide margin, and the shortest-lived |
 * | `nfc` | The reader, while the POS screen is open |
 * | `engine` | The hovering card's second Flutter engine |
 *
 * The first two are the ones to watch: they are the only ones that are
 * supposed to last hours, which makes them the only ones where "too long" is
 * hard to notice.
 */
object PowerTrace {

    /** When each open span started, by name. */
    private val started = mutableMapOf<String, Long>()

    /**
     * A subsystem has started costing something.
     *
     * Idempotent: a second `awake` for a name already open is ignored rather
     * than restarting its clock. `applyVisibility` runs on every broadcast and
     * most change nothing, so a naive implementation would reset the overlay's
     * span dozens of times an hour and report a four-hour window as four
     * minutes.
     */
    @Synchronized
    fun awake(context: Context, what: String) {
        if (!Blackbox.enabled(context)) return
        if (started.containsKey(what)) return
        started[what] = SystemClock.elapsedRealtime()
        Blackbox.power.log(
            context, "awake",
            "what" to what,
            "battery" to level(context),
        )
    }

    /**
     * And has stopped.
     *
     * A name that was never opened is recorded as `unmatched` rather than
     * dropped. An unmatched close is a real finding — it means a subsystem was
     * already running when the recorder started, or that something is being
     * released twice, and both are worth seeing.
     */
    @Synchronized
    fun asleep(context: Context, what: String) {
        if (!Blackbox.enabled(context)) return
        val from = started.remove(what)
        if (from == null) {
            Blackbox.power.log(context, "asleep", "what" to what,
                "unmatched" to true)
            return
        }
        Blackbox.power.log(
            context, "asleep",
            "what" to what,
            // `elapsedRealtime`, not the wall clock: the wall clock jumps when
            // the network corrects it, and a backwards jump would report a
            // negative span.
            "forMs" to (SystemClock.elapsedRealtime() - from),
            "battery" to level(context),
        )
    }

    /**
     * Battery percentage, or null if it cannot be read.
     *
     * A sticky broadcast rather than `BatteryManager.BATTERY_PROPERTY_CAPACITY`
     * because the property returns -1 on a number of devices while the
     * broadcast is populated on all of them, and a missing sample is worse
     * than a slightly coarser one.
     */
    private fun level(context: Context): Int? = runCatching {
        val status = context.applicationContext
            .registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            ?: return@runCatching null
        val now = status.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = status.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        if (now < 0 || scale <= 0) null else now * 100 / scale
    }.getOrNull()
}
