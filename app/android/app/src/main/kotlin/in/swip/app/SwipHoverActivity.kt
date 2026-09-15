package `in`.swip.app

import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * `F-163` — the scanner, hovering over whatever app you are in.
 *
 * > *"can we get a hovering window on tap of this widget accessible anywhere
 * > everywhere and same camera window of the dashboard"*
 *
 * Tapping the bubble used to open `MainActivity` full-screen, which meant
 * leaving the app you were in — the one thing a floating button exists to
 * avoid. This is a **transparent** Activity: the app underneath stays drawn,
 * and Flutter paints a floating card over it containing `ScanPage` itself.
 *
 * ## The three things that make it transparent, none of which is optional
 *
 * 1. **The theme** (`SwipHoverTheme`, in `res/values/swip_hover_styles.xml`)
 *    sets `windowIsTranslucent` and a transparent window background. Android
 *    decides whether a window is translucent when it is created, so this
 *    cannot be switched on later from code — which is exactly why this is a
 *    separate Activity rather than a mode of `MainActivity`.
 * 2. **[getBackgroundMode]** below. Flutter's default is opaque, and an opaque
 *    Flutter surface over a translucent window paints black over everything.
 * 3. **The Dart side** uses `Scaffold(backgroundColor: Colors.transparent)` —
 *    see `hover_scan.dart`. A default `Scaffold` would paint the theme's
 *    ground over both of the above.
 *
 * Get any one of the three wrong and the result is a black screen rather than
 * an error, which is the kind of failure that costs an afternoon.
 *
 * ## Why its own task
 *
 * `singleInstance` plus `excludeFromRecents`. Without them the hovering
 * scanner joins `MainActivity`'s task, so dismissing it can surface the main
 * app — the user taps the bubble over their bank, closes the card, and finds
 * themselves in SWIP instead of back where they were. Its own task means
 * closing returns them to whatever was underneath.
 *
 * ## Why a second Flutter engine, and what that costs
 *
 * `FlutterFragmentActivity` starts its own engine; this does not share
 * `MainActivity`'s. Sharing would mean a cached engine that can only be
 * attached to one Activity at a time, and detaching it from `MainActivity`
 * while that is alive tears down its view.
 *
 * The cost is a cold start — roughly half a second before the card appears —
 * and some tens of megabytes while it is open, both ending when it closes.
 * Keeping a warm engine would remove the delay and pay the memory *the whole
 * time the bubble is switched on*, which for a button that sits idle all day
 * is the wrong trade.
 */
class SwipHoverActivity : FlutterFragmentActivity() {

    /**
     * Tells Flutter to render with a transparent surface.
     *
     * Without it the engine draws an opaque background and the translucent
     * window beneath is irrelevant — the whole screen goes black and the app
     * underneath disappears.
     */
    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    /**
     * The one platform method the hovering scanner can actually reach for.
     *
     * **This engine is not `MainActivity`'s.** Every plugin registers itself
     * here as usual, but `MainActivity`'s own `in.swip.app/nfc` channel does
     * not exist in this engine — its handler is a closure over `MainActivity`
     * state, and `MainActivity` is not on screen.
     *
     * `ScanPage` reaches for exactly one method on that channel:
     * `openAppSettings`, and only when the camera permission has been refused,
     * to send the user somewhere they can grant it. It wraps the call in
     * `catchError`, so an unregistered channel here would not crash — it would
     * do **nothing**, silently, on the one screen whose entire job at that
     * moment is to unblock the user. That is a worse failure than a crash
     * because nobody would ever report it.
     *
     * So the channel is registered with the handful of methods this window
     * can genuinely answer and no others. Anything else returns
     * `notImplemented` rather than being quietly swallowed, which is what
     * makes a missing wire show up.
     *
     * `F-175` added the second: `openTapScreen`. It is here rather than in
     * `MainActivity` precisely *because* this engine cannot do NFC — the whole
     * method exists to hand the job to the Activity that can.
     */
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)

        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openAppSettings" -> {
                        val ok = runCatching {
                            startActivity(
                                Intent(
                                    android.provider.Settings
                                        .ACTION_APPLICATION_DETAILS_SETTINGS,
                                    android.net.Uri.fromParts(
                                        "package", packageName, null)
                                )
                            )
                        }.isSuccess
                        result.success(ok)
                    }

                    /**
                     * `F-175`. *Tap POS*, pressed inside the hovering card.
                     *
                     * NFC is read entirely through `MainActivity`'s channel,
                     * which does not exist in this engine, so the POS screen
                     * cannot be opened here — it would come up and wait for a
                     * platform reply that can never arrive.
                     *
                     * `SINGLE_TOP` so a running SWIP is reused rather than
                     * stacked, which is also what delivers the extra to
                     * `onNewIntent` and therefore to `captureTileLaunch`.
                     */
                    "openTapScreen" -> {
                        BubbleTrace.log(this, "hover.openTapScreen")
                        val ok = runCatching {
                            startActivity(
                                Intent(this, MainActivity::class.java).apply {
                                    addFlags(
                                        Intent.FLAG_ACTIVITY_NEW_TASK or
                                            Intent.FLAG_ACTIVITY_SINGLE_TOP
                                    )
                                    putExtra(MainActivity.EXTRA_OPEN_TAP, true)
                                }
                            )
                        }.isSuccess
                        result.success(ok)
                    }

                    /**
                     * `F-180`. *View all*, pressed inside the hovering card.
                     *
                     * > *"the view all shouldn't open in the same view it
                     * > should open the app and the ledger screen"*
                     *
                     * The ledger is a Riverpod tree over the SQLite repository
                     * that `MainActivity`'s engine owns. This window runs a
                     * second engine with a second provider container, so
                     * rendering the ledger here would open a **different**
                     * database handle over the same file — `CLAUDE.md` records
                     * what two handles to one sqflite path costs. Bringing the
                     * real app forward is the correct answer, not the lazy one.
                     */
                    "openLedger" -> {
                        BubbleTrace.log(this, "hover.openLedger")
                        val ok = runCatching {
                            startActivity(
                                Intent(this, MainActivity::class.java).apply {
                                    addFlags(
                                        Intent.FLAG_ACTIVITY_NEW_TASK or
                                            Intent.FLAG_ACTIVITY_SINGLE_TOP
                                    )
                                    putExtra(MainActivity.EXTRA_OPEN_LEDGER, true)
                                }
                            )
                        }.isSuccess
                        result.success(ok)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        BubbleTrace.log(this, "hover.create")

        // `F-177`. Kill the system's activity-open animation.
        //
        // > *"it feels like there's a shadow or transition being applied from
        // > the bottom upward first which is kinda harsh… almost as if another
        // > app is opening"*
        //
        // That is exactly what it was: Android's default activity transition
        // is a bottom-up slide with a dim behind it, and it is what an app
        // opening looks like because it **is** what an app opening looks like.
        //
        // `SwipHoverTheme` already sets `windowAnimationStyle` to `@null`, and
        // that was not enough — a theme attribute is advisory, several OEM
        // skins substitute their own, and `@null` is honoured inconsistently
        // across versions. Overriding the pending transition here is the
        // instruction rather than the preference.
        //
        // The card's own entrance is then Flutter's, in `hover_scan.dart`,
        // which can be as gentle as it likes because nothing is competing
        // with it.
        killTransition()
    }

    /**
     * `F-177`. No enter animation, no exit animation, at any API level.
     *
     * `overrideActivityTransition` is the Android 14 replacement and the older
     * call throws nothing but does nothing on 34+, so both are needed. Zero
     * rather than a custom animation resource: the point is that no window
     * appears to arrive at all.
     */
    private fun killTransition() {
        runCatching {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                // Qualified. Kotlin does not pull a Java superclass's static
                // fields into unqualified scope the way Java does, and finding
                // that out costs a CI round trip.
                overrideActivityTransition(
                    android.app.Activity.OVERRIDE_TRANSITION_OPEN, 0, 0)
                overrideActivityTransition(
                    android.app.Activity.OVERRIDE_TRANSITION_CLOSE, 0, 0)
            } else {
                @Suppress("DEPRECATION")
                overridePendingTransition(0, 0)
            }
        }
    }

    /**
     * `F-178`. **Foreground state is claimed here, not in `onCreate`.**
     *
     * `docs/32` §2 — the bubble is never over a payment, and never over its
     * own scanner either; a disc sitting on the card the user just opened is a
     * smudge on the viewfinder. Same shared-state route `MainActivity` uses
     * rather than a broadcast, for the reason recorded in `SwipBubbleService`:
     * an event can be missed, a value that is read cannot.
     *
     * ## The bug this pairing fixes
     *
     * It used to be `onCreate` / `onDestroy`, while `MainActivity` has always
     * used `onResume` / `onPause`. That asymmetry is not cosmetic — **it is
     * almost certainly the disappearing bubble.**
     *
     * Open the hovering card and press Home. The Activity is *stopped*, not
     * destroyed, so `onDestroy` never runs, `appInForeground` stays `true`,
     * and `applyVisibility` hides the bubble on every evaluation from then on.
     * And this Activity is `excludeFromRecents`, so the user cannot return to
     * it to close it — the card is alive, invisible, unreachable, and holding
     * the bubble down. The only escape is opening SWIP and leaving again,
     * because `MainActivity.onPause` sets the same flag false.
     *
     * Which matches the report exactly: *"it disappears randomly while using
     * certain other apps."*
     */
    override fun onResume() {
        super.onResume()
        SwipBubbleService.noteForeground(this, true, from = "hover.onResume")
    }

    override fun onPause() {
        SwipBubbleService.noteForeground(this, false, from = "hover.onPause")
        super.onPause()
    }

    /**
     * `F-178`. A card that has left the screen is finished, not kept.
     *
     * This Activity is `singleInstance` in its own task and
     * `excludeFromRecents`, so once it is backgrounded there is **no way for
     * the user to get back to it** — it is not in Recents and the bubble
     * launches a fresh intent rather than resurfacing it. Keeping it alive
     * therefore holds a camera and a second Flutter engine for a window nobody
     * can ever see again.
     *
     * `onStop` rather than `onPause`: a permission dialog pauses this Activity
     * without stopping it, and finishing the card out from under the camera
     * prompt would be a new bug in place of the old one.
     */
    override fun onStop() {
        super.onStop()
        if (!isFinishing) {
            BubbleTrace.log(this, "hover.finishOnStop")
            finish()
        }
    }

    override fun onDestroy() {
        BubbleTrace.log(this, "hover.destroy")
        // Belt as well as braces: `onPause` has already cleared this in every
        // ordinary path, and a process torn down between the two would leave
        // it set.
        SwipBubbleService.noteForeground(this, false, from = "hover.onDestroy")
        super.onDestroy()
    }

    companion object {
        /**
         * Flutter's own extra for the initial route. Spelled out rather than
         * referenced from `FlutterActivityLaunchConfigs` because that class is
         * not part of the embedding's public surface and has moved before.
         *
         * `hover_scan.dart`'s `HoverScanApp.route` is the other half of this
         * pair; the Dart entrypoint branches on it, and if the two strings
         * ever disagree the bubble silently opens the entire app instead of a
         * card.
         */
        const val EXTRA_ROUTE = "route"
        const val ROUTE_HOVER = "/hover"

        /** Must match `MainActivity.METHOD_CHANNEL`. */
        private const val CHANNEL = "in.swip.app/nfc"
    }
}
