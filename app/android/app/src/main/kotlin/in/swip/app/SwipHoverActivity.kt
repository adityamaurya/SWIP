package `in`.swip.app

import android.content.Intent
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
     * So the channel is registered with that single method and no others.
     * Anything else returns `notImplemented` rather than being quietly
     * swallowed, which is what makes a missing wire show up.
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

                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // `docs/32` §2 — the bubble is never over a payment, and it is never
        // over its own scanner either. A 48 dp circle sitting on top of the
        // card the user just opened is a smudge on the viewfinder.
        //
        // This is the same shared-state route `MainActivity` uses rather than
        // a broadcast, for the reason recorded in `SwipBubbleService`: an
        // event can be missed, a value that is read cannot.
        SwipBubbleService.noteForeground(this, true)
    }

    override fun onDestroy() {
        // Hand the screen back. Ordered before `super` so that a caller
        // watching for the bubble's return sees it as the card goes away
        // rather than a frame later.
        SwipBubbleService.noteForeground(this, false)
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
