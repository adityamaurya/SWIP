package `in`.swip.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * `F-159` — the bubble comes back after a reboot.
 *
 * > *"I want it to be present, omnipresent, throughout the background, no
 * > matter what, everywhere."*
 *
 * A foreground service dies with its process, and a reboot kills every
 * process. Without this, switching the bubble on and then restarting the phone
 * left the user with a Settings screen that said "on" and no bubble — which is
 * the same complaint that this whole feature has been reported under twice.
 *
 * **`F-158` deliberately did not do this**, on the grounds that a category
 * reader restarting itself at boot was a worse trade than one app launch. The
 * owner has since asked for omnipresence explicitly, so that trade is
 * reversed. It is recorded in `docs/36` rather than quietly changed.
 *
 * ## Why this is allowed, specifically
 *
 * Android 15 forbids a `BOOT_COMPLETED` receiver from starting a foreground
 * service of type `dataSync`, `camera`, `mediaPlayback`, `phoneCall`,
 * `mediaProjection` or `microphone` — it throws
 * `ForegroundServiceStartNotAllowedException`. **`specialUse` is not on that
 * list**, and `specialUse` is what the bubble is
 * (<https://developer.android.com/about/versions/15/behavior-changes-15>).
 *
 * ## The one case this cannot cover, which the user has to know
 *
 * An app that has been **force-stopped** from Settings, or that has never been
 * opened since install, does not receive `BOOT_COMPLETED` at all. Android puts
 * it in the "stopped" state and no broadcast reaches it until the user opens
 * it once. There is no permission or flag that changes this, and any app
 * claiming otherwise on a stock device is mistaken. It is on the wizard's last
 * screen for exactly that reason.
 *
 * ## Why `MY_PACKAGE_REPLACED` is here too
 *
 * Updating SWIP kills the process the same way a reboot does. Without this
 * line the bubble would silently vanish on every app update, which is a much
 * more frequent event than a reboot and a far more confusing one.
 */
class SwipBootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context?, intent: Intent?) {
        val ctx = context ?: return
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            -> {
                // A no-op unless the user switched the bubble on and still
                // holds the overlay permission. `restoreIfWanted` checks both,
                // and `start` swallows a refusal rather than crashing a
                // receiver — a crash here would show the user a "SWIP has
                // stopped" dialog at boot, which is worse than no bubble.
                runCatching { SwipBubbleService.restoreIfWanted(ctx) }
            }
        }
    }
}
