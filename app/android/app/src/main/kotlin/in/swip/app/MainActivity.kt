package `in`.swip.app

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.nfc.NfcAdapter
import android.nfc.cardemulation.CardEmulation
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import java.io.ByteArrayOutputStream
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges the HCE capture (Vector 2) into Flutter, and owns the one piece of
 * Android state the Dart side cannot: foreground-preferred NFC routing.
 *
 * ## Foreground preference
 *
 * SWIP registers real payment AIDs, so on a device where Google Wallet is the
 * default payment app the terminal's APDUs go to Wallet, not to SWIP. The fix
 * is [CardEmulation.setPreferredService], which routes to us **only while our
 * Activity is in the foreground**.
 *
 * This is both the correct mechanism and the honest one: SWIP competes for the
 * NFC field only while the user is deliberately looking at the Tap screen, and
 * gives it straight back on pause. A wallet app that hijacked routing in the
 * background would be a genuine problem; this is not that.
 */
class MainActivity : FlutterFragmentActivity() {

    companion object {
        const val METHOD_CHANNEL = "in.swip.app/nfc"

        /**
         * `F-175`. Open SWIP at the **POS reader** rather than the dashboard.
         *
         * Set by [SwipHoverActivity] when *Tap POS* is pressed in the hovering
         * card. That window runs its own Flutter engine, in which this
         * Activity's method channel does not exist, so NFC cannot be read
         * there at all — the only honest answer to the button is to bring the
         * real app forward at the right screen. Holding a phone against a card
         * machine is not a thing to do through a card floating over somebody
         * else's app anyway.
         *
         * Public, unlike the rest of this companion, because the hovering
         * Activity is the thing that sets it.
         */
        const val EXTRA_OPEN_TAP = "in.swip.app.OPEN_TAP"

        /**
         * `F-180`. Set by [SwipHoverActivity] when *View all* is pressed.
         *
         * > *"the view all shouldn't open in the same view it should open the
         * > app and the ledger screen"*
         *
         * Same shape as [EXTRA_OPEN_TAP] and for a related reason: the answer
         * to the button is a screen that lives in the real app, so the honest
         * thing is to bring the real app forward at it rather than to build a
         * second copy inside a window that cannot reach the database provider
         * the first one is watching.
         */
        const val EXTRA_OPEN_LEDGER = "in.swip.app.OPEN_LEDGER"
        const val EVENT_CHANNEL = "in.swip.app/nfc/captures"

        /** `F-159`. Request code for the POST_NOTIFICATIONS dialog. */
        const val NOTIFICATION_REQUEST = 0x5117

        /**
         * What `consumeTileLaunch` answers with. These two strings are matched
         * in `main.dart`; anything else is treated there as "nothing pending",
         * so a typo fails closed — the app opens on the dashboard rather than
         * on a screen nobody asked for.
         */
        const val OPEN_QR = "qr"
        const val OPEN_NFC = "nfc"

        /** `F-180`. Not a capture vector — the ledger tab. See `main.dart`. */
        const val OPEN_LEDGER = "ledger"
    }

    private var cardEmulation: CardEmulation? = null
    private var events: EventChannel.EventSink? = null
    private var receiver: BroadcastReceiver? = null

    /** True while S-03 is on screen. Drives preferred-service registration. */
    private var listening = false

    /**
     * The `upi://pay?...` URI SWIP was launched with, if any.
     *
     * Held here rather than pushed straight to Dart because the Flutter engine
     * may not be attached yet when the Activity is created cold from a
     * merchant's checkout — Dart pulls it when it is ready.
     */
    private var pendingUpi: String? = null

    /**
     * Something shared *into* SWIP from another app's share sheet.
     *
     * This is the answer to the checkout apps that build their UPI list from an
     * allowlist rather than by asking Android: SWIP cannot get onto that list,
     * but every one of those screens has a copy or share action, and the share
     * sheet is a list nobody curates. One extra tap, works everywhere.
     *
     * Two shapes, both held until Dart asks:
     *   text  → the shared string, resolved exactly like a scanned payload
     *   image → a path in cacheDir, for reading a QR out of a screenshot
     */
    private var pendingShareKind: String? = null
    private var pendingShareValue: String? = null

    /**
     * `F-115`. True when SWIP was launched from the Quick Settings tile, which
     * means the user is standing in front of a code right now and wants the
     * scanner, not the dashboard.
     */
    /**
     * Which capture surface to open on the next Dart poll, or null.
     *
     * `F-175`. **A string rather than the boolean it used to be.** There are
     * two callers now — the Quick Settings tile, which means "the scanner",
     * and the hovering card's *Tap POS*, which means the POS reader — and a
     * second boolean would have been a second thing for Dart to ask about and
     * a state where both could be true at once.
     */
    private var pendingOpenCapture: String? = null

    /**
     * `F-159`. The Dart side of an in-flight `POST_NOTIFICATIONS` request.
     *
     * A `MethodChannel.Result` may be completed **exactly once** — a second
     * call throws — and the system can deliver a permission result more than
     * once across a configuration change. So it is nulled the instant it is
     * used, and every path checks for null first.
     */
    private var pendingNotificationResult: MethodChannel.Result? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        capturePaymentIntent(intent)
        captureSharedPayload(intent)
        captureTileLaunch(intent)

    }

    /** `launchMode="singleTop"`, so a second checkout arrives here. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        capturePaymentIntent(intent)
        captureSharedPayload(intent)
        captureTileLaunch(intent)
    }

    private fun captureTileLaunch(intent: Intent?) {
        if (intent == null) return
        if (intent.getBooleanExtra(SwipTile.EXTRA_OPEN_SCANNER, false)) {
            pendingOpenCapture = OPEN_QR
        }
        // `F-175`. Checked second and therefore wins a (impossible) tie, which
        // is the right way round: the tap extra is only ever set by a
        // deliberate button press, the scanner extra by a tile that may have
        // been pressed a moment earlier.
        if (intent.getBooleanExtra(EXTRA_OPEN_TAP, false)) {
            pendingOpenCapture = OPEN_NFC
        }
        // `F-180`. Last, so it wins over both — and like the tap extra it is
        // only ever set by a deliberate button press, never by a tile that may
        // have been pressed a moment earlier.
        if (intent.getBooleanExtra(EXTRA_OPEN_LEDGER, false)) {
            pendingOpenCapture = OPEN_LEDGER
        }
    }

    private fun capturePaymentIntent(intent: Intent?) {
        val data = intent?.data ?: return
        if (data.scheme?.lowercase() != "upi") return
        pendingUpi = data.toString()
    }

    /**
     * Pull whatever arrived on an ACTION_SEND.
     *
     * The image branch copies the stream into our own cache rather than holding
     * the `content://` URI: the grant that came with the intent is scoped to
     * this Activity instance and dies on rotation, which would turn "share a
     * screenshot" into an intermittent failure that only reproduces on other
     * people's phones.
     */
    private fun captureSharedPayload(intent: Intent?) {
        if (intent == null) return
        if (intent.action != Intent.ACTION_SEND) return

        val type = intent.type.orEmpty()

        if (type.startsWith("text/")) {
            val text = intent.getStringExtra(Intent.EXTRA_TEXT)?.trim()
            if (!text.isNullOrEmpty()) {
                pendingShareKind = "text"
                pendingShareValue = text
            }
            return
        }

        if (type.startsWith("image/")) {
            val uri: android.net.Uri? =
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, android.net.Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                }
            if (uri == null) return

            runCatching {
                val target = java.io.File(cacheDir, "shared_qr_${System.currentTimeMillis()}.img")
                contentResolver.openInputStream(uri)?.use { input ->
                    target.outputStream().use { output -> input.copyTo(output) }
                }
                target
            }.onSuccess { file ->
                if (file.exists() && file.length() > 0) {
                    pendingShareKind = "image"
                    pendingShareValue = file.absolutePath
                }
            }
        }
    }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)

        val adapter = NfcAdapter.getDefaultAdapter(this)
        cardEmulation = adapter?.let { CardEmulation.getInstance(it) }

        MethodChannel(engine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Capability probe, called before S-01 renders the Tap tile.
                    "status" -> result.success(
                        mapOf(
                            "hasNfc" to (adapter != null),
                            "enabled" to (adapter?.isEnabled == true),
                            "hasHce" to packageManager.hasSystemFeature(
                                android.content.pm.PackageManager.FEATURE_NFC_HOST_CARD_EMULATION
                            ),
                            // F-55, F-56. THE thing that decides whether a tap
                            // reaches SWIP at all.
                            //
                            // Android routes the contactless field to whichever
                            // app holds the default-payment slot. On any phone
                            // with Google Wallet set up, that is Wallet — so the
                            // terminal's APDUs go there and SWIP never sees them.
                            // setPreferredService covers only the foreground
                            // case and only once the screen is already open.
                            //
                            // Nothing in the app said so, which made a correctly
                            // configured feature look broken.
                            "isDefaultPayment" to (
                                cardEmulation?.isDefaultServiceForCategory(
                                    ComponentName(this, SwipListenService::class.java),
                                    CardEmulation.CATEGORY_PAYMENT
                                ) == true
                                )
                        )
                    )

                    // Deep-link to Settings ▸ Connected devices ▸ NFC ▸
                    // Contactless payments, where the default is chosen.
                    "openPaymentSettings" -> {
                        val opened = runCatching {
                            startActivity(
                                Intent(android.provider.Settings.ACTION_NFC_PAYMENT_SETTINGS)
                            )
                        }.isSuccess || runCatching {
                            // Some OEM skins do not expose the payment screen.
                            startActivity(Intent(android.provider.Settings.ACTION_NFC_SETTINGS))
                        }.isSuccess
                        result.success(opened)
                    }

                    "startListening" -> {
                        listening = true
                        // `F-187`. The POS screen is open, so this is the
                        // moment to record what state the phone is in —
                        // **before** a tap rather than after one. Four of the
                        // seven ways a tap can fail are knowable right here,
                        // and three of them the user can fix.
                        TapTrace.snapshot(this, "screen")
                        PowerTrace.awake(this, "nfc")
                        applyPreferredService(true)
                        result.success(null)
                    }

                    "stopListening" -> {
                        listening = false
                        PowerTrace.asleep(this, "nfc")
                        applyPreferredService(false)
                        result.success(null)
                    }

                    // Camera permission, permanently denied. Android stops
                    // showing the prompt after two refusals, so app settings is
                    // the only remaining route back — and an app that cannot
                    // offer that route has simply lost the feature.
                    "openAppSettings" -> {
                        val ok = runCatching {
                            startActivity(
                                Intent(
                                    android.provider.Settings
                                        .ACTION_APPLICATION_DETAILS_SETTINGS,
                                    android.net.Uri.fromParts("package", packageName, null)
                                )
                            )
                        }.isSuccess
                        result.success(ok)
                    }

                    // `F-131`. The floating scan bubble's permission.
                    //
                    // `SYSTEM_ALERT_WINDOW` is a **special** permission: it
                    // cannot be granted by a runtime dialog, only by the user
                    // walking into Settings and flipping a switch. So there are
                    // two calls, and Flutter must use them in that order -
                    // explain first, send second. Firing the Settings intent
                    // without the explanation is how an app gets denied and
                    // never asked again.
                    // ── `F-158`: the floating bubble ─────────────────────
                    //
                    // The old screen wrote a `SharedPreferences` boolean and
                    // stopped. These three are what make the switch mean
                    // something: the service owns the state, so Dart sets and
                    // asks rather than keeping a second copy that can drift.

                    // ── `F-159`: the notification permission ─────────────
                    //
                    // Android 13+. A foreground service is *required* to post
                    // an ongoing notice, and without this permission the
                    // system silently suppresses it. The service still runs
                    // and the bubble still appears, so this is not a
                    // prerequisite — but the user loses the "Turn off" action
                    // and any visible reason SWIP is running, which is exactly
                    // the transparency an overlay app owes them.
                    //
                    // Below Android 13 the permission does not exist and is
                    // granted at install, so the honest answer is `true`.
                    "notificationsAllowed" -> {
                        result.success(
                            if (Build.VERSION.SDK_INT >=
                                Build.VERSION_CODES.TIRAMISU
                            ) {
                                checkSelfPermission(
                                    android.Manifest.permission.POST_NOTIFICATIONS
                                ) == android.content.pm.PackageManager
                                    .PERMISSION_GRANTED
                            } else {
                                true
                            }
                        )
                    }

                    "requestNotifications" -> {
                        if (Build.VERSION.SDK_INT <
                            Build.VERSION_CODES.TIRAMISU
                        ) {
                            result.success(true)
                        } else if (checkSelfPermission(
                                android.Manifest.permission.POST_NOTIFICATIONS
                            ) == android.content.pm.PackageManager
                                .PERMISSION_GRANTED
                        ) {
                            result.success(true)
                        } else {
                            // Held rather than answered now: the system dialog
                            // is asynchronous and the answer arrives in
                            // `onRequestPermissionsResult`. Dart is awaiting
                            // this, so it must be completed exactly once —
                            // see the guard there.
                            pendingNotificationResult = result
                            requestPermissions(
                                arrayOf(
                                    android.Manifest.permission
                                        .POST_NOTIFICATIONS
                                ),
                                NOTIFICATION_REQUEST,
                            )
                        }
                    }

                    /*
                     * `F-189`. **As close to "App battery usage" as Android
                     * lets a third party get.**
                     *
                     * > *"we need direct redirections to the SWIPs app battery
                     * > usage in the onboarding wizard"*
                     *
                     * There is **no public intent for that screen.** It is
                     * `com.android.settings.fuelgauge.AdvancedPowerUsageDetail`,
                     * an unexported fragment inside Settings, and every OEM
                     * moves it — Samsung keeps its own copy in
                     * `com.samsung.android.lool`. Firing a hard component name
                     * at it gets a `SecurityException` on a stock phone and
                     * nothing at all on half the others, so this does not try.
                     *
                     * What it does instead is real and documented behaviour:
                     * App info, with AOSP's **highlight-a-setting** extras
                     * pointing at the battery row. That is the mechanism
                     * Settings search itself uses to deep-link a row, so the
                     * user lands on SWIP's App info page with *App battery
                     * usage* picked out and pulsing, one tap from
                     * Unrestricted.
                     *
                     * On a build that ignores the extras it is still App info,
                     * which is where the button went before and is never
                     * wrong. Both outcomes return true; there is nothing
                     * useful to tell Dart apart, and the wizard's copy names
                     * the row either way rather than assuming the highlight
                     * landed.
                     *
                     * Deliberately NOT `ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`,
                     * which is public and would open the Doze exemption list.
                     * `docs/36` D-45 declined that on Play policy: the
                     * exemption is for messaging, VOIP, safety, task
                     * automation and peripheral companions, and a floating
                     * button is none of them. Walking somebody to the list is
                     * inviting the grant.
                     */
                    "openBatterySettings" -> {
                        val ok = runCatching {
                            val key = "battery"
                            startActivity(
                                Intent(
                                    android.provider.Settings
                                        .ACTION_APPLICATION_DETAILS_SETTINGS,
                                    android.net.Uri.parse("package:$packageName")
                                )
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    .putExtra(":settings:fragment_args_key", key)
                                    .putExtra(
                                        ":settings:show_fragment_args",
                                        android.os.Bundle().apply {
                                            putString(
                                                ":settings:fragment_args_key",
                                                key,
                                            )
                                        },
                                    )
                            )
                        }.isSuccess
                        result.success(ok)
                    }

                    // `F-164`. Send SWIP to the background so the bubble is
                    // visible immediately.
                    //
                    // The bubble hides while SWIP is in the foreground, which
                    // means the moment the setup wizard finishes is the exact
                    // moment the user cannot see the thing they just switched
                    // on. The wizard's last screen explains that, and an
                    // explanation is still a worse answer than showing them.
                    //
                    // `moveTaskToBack` rather than `finish()`: finishing would
                    // close SWIP outright, so returning to it would be a cold
                    // start rather than picking up where they were.
                    "moveToBackground" -> {
                        result.success(runCatching { moveTaskToBack(true) }
                            .getOrDefault(false))
                    }

                    "startBubble" -> {
                        // Returns false when the overlay permission is not
                        // granted. Dart must not paint the switch as ON in
                        // that case - that is exactly the lie `F-131` told.
                        result.success(SwipBubbleService.start(this))
                    }

                    // `F-167`. End a snooze early.
                    "wakeBubble" -> {
                        SwipBubbleService.wake(this, from = "settings")
                        result.success(true)
                    }

                    "stopBubble" -> {
                        SwipBubbleService.stop(this)
                        result.success(true)
                    }

                    // Two different questions, and the Settings screen needs
                    // both: `wanted` is what the user asked for and drives the
                    // switch; `running` is whether a window actually exists
                    // right now, which is false while the service is being
                    // restarted or the permission has been revoked in
                    // Settings since.
                    "bubbleStatus" -> {
                        result.success(
                            mapOf(
                                "wanted" to SwipBubbleService.isWanted(this),
                                "running" to SwipBubbleService.running,
                                // `F-167`. Epoch millis, or 0 for awake. Sent
                                // as the deadline rather than a boolean so the
                                // Settings screen can say *when* it comes back
                                // — "asleep" with no end is indistinguishable
                                // from broken, which is the shape of report
                                // this feature keeps generating.
                                "snoozedUntil" to
                                    SwipBubbleService.snoozedUntil(this),
                            )
                        )
                    }

                    "canDrawOverlays" -> {
                        result.success(
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                android.provider.Settings.canDrawOverlays(this)
                            } else {
                                true
                            }
                        )
                    }

                    "requestOverlayPermission" -> {
                        val ok = runCatching {
                            startActivity(
                                Intent(
                                    android.provider.Settings
                                        .ACTION_MANAGE_OVERLAY_PERMISSION,
                                    android.net.Uri.parse("package:$packageName")
                                )
                            )
                        }.isSuccess
                        result.success(ok)
                    }

                    "openNfcSettings" -> {
                        startActivity(Intent(android.provider.Settings.ACTION_NFC_SETTINGS))
                        result.success(null)
                    }

                    // `F-111`. Hand a URI to whichever app owns it — a `upi://`
                    // for the UPI route, an `https://` payment page for the card
                    // route.
                    //
                    // Separate from `forwardUpiIntent` on purpose: that one wraps
                    // the intent in a chooser and excludes SWIP from it, which is
                    // right when SWIP is *relaying* a merchant's payment. Here
                    // SWIP is the payee, there is nothing to exclude, and the
                    // user's default handler is the correct destination.
                    "openExternal" -> {
                        val uri = call.argument<String>("uri")
                        if (uri.isNullOrBlank()) {
                            result.error("no_uri", "openExternal needs a uri", null)
                        } else {
                            runCatching {
                                startActivity(
                                    Intent(Intent.ACTION_VIEW, android.net.Uri.parse(uri))
                                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                )
                                // `F-158`. This route opens the OWNER's
                                // Razorpay page and the `upi://` deep link
                                // behind the support section, so it is a
                                // payment about to be on screen just as much
                                // as `forwardUpiIntent` is. The scheme test
                                // keeps the 90-second silence off the
                                // `https://` links that are only
                                // documentation - the privacy policy, the
                                // repository - because going quiet there
                                // would be silencing the bubble for reading.
                                val scheme = android.net.Uri.parse(uri)
                                    .scheme?.lowercase()
                                if (scheme == "upi" || uri.contains("razorpay")) {
                                    SwipBubbleService.notePaymentStarted(
                                        this@MainActivity)
                                }
                            }.fold(
                                onSuccess = { result.success(true) },
                                // No app to take it — a phone with no UPI app
                                // installed, or no browser. Reported, not thrown.
                                onFailure = { result.success(false) }
                            )
                        }
                    }

                    // ── Vector 7: the pay-by-app intent ──────────────────
                    //
                    // Returns the pending upi:// URI once and clears it, so a
                    // rebuild or a rotation cannot replay the same capture.
                    "consumeUpiIntent" -> {
                        result.success(pendingUpi)
                        pendingUpi = null
                    }

                    // Share-to-SWIP. Same read-once contract as the UPI intent:
                    // returning it clears it, so a rotation cannot replay the
                    // same share as a second capture.
                    // `F-115`. Read once and cleared, same contract as the
                    // UPI intent and the share payload: a rotation must not
                    // re-open the scanner.
                    // ── `F-176`, the temporary bubble trace ──────────
                    //
                    // Three methods, and they are the entire Dart-facing
                    // surface of the recorder. When the cause of the
                    // disappearing bubble is found, deleting `BubbleTrace.kt`,
                    // these three cases and `bubble_trace_page.dart` removes
                    // the feature completely — `docs/38` has the list.
                    //
                    // `traceEnabled` is what the Settings screen asks before
                    // showing the row at all, so on a Play Store build the
                    // entry point does not exist rather than existing and
                    // being empty.
                    "traceEnabled" -> result.success(BubbleTrace.enabled(this))

                    "traceDump" -> result.success(BubbleTrace.dump(this))

                    "traceClear" -> {
                        BubbleTrace.clear(this)
                        result.success(true)
                    }

                    // `F-187`, `F-188`. The other two black boxes.
                    //
                    // Three pairs of methods rather than one pair taking a
                    // name, and that is deliberate: `check_wiring.py` matches
                    // channel method names between this file and `lib/` in
                    // both directions, and a name assembled from a string at
                    // runtime is a name that check cannot see. Three explicit
                    // pairs stay checkable.
                    "tapTraceDump" -> result.success(Blackbox.tap.dump(this))

                    "tapTraceClear" -> {
                        Blackbox.tap.clear(this)
                        result.success(true)
                    }

                    "powerTraceDump" -> result.success(Blackbox.power.dump(this))

                    "powerTraceClear" -> {
                        Blackbox.power.clear(this)
                        result.success(true)
                    }

                    // `F-187`. **Deliberately not `traceEnabled` reused.**
                    //
                    // The two boxes above are permanent and `BubbleTrace` is
                    // not — `docs/38` §4 step 4 deletes `traceEnabled` along
                    // with it. Had the Diagnostics section kept asking that
                    // question, the deletion would have taken the POS and
                    // battery boxes off the Settings screen as well: the
                    // future would resolve false, the section would stop
                    // drawing, and **nothing would fail**. No file would be
                    // unimported, no channel name unmatched, no preference
                    // unread. It is the exact shape `check_wiring.py` exists
                    // for and the one variant it cannot see.
                    //
                    // Both answers come from `FLAG_DEBUGGABLE` and are always
                    // equal today. That is not the point; the point is which
                    // one survives.
                    "blackboxEnabled" -> result.success(Blackbox.enabled(this))

                    "consumeTileLaunch" -> {
                        if (pendingOpenCapture != null) {
                            BubbleTrace.log(this, "launch.consumed",
                                "vector" to pendingOpenCapture)
                        }
                        // `F-175`. Answers with "qr", "nfc" or null. It was a
                        // boolean; the name is kept because renaming a channel
                        // method means the Dart and Kotlin halves can disagree
                        // for exactly one commit, and `check_wiring.py` only
                        // catches that if both sides are changed in the same
                        // one. The doc comment is the cheaper fix.
                        result.success(pendingOpenCapture)
                        pendingOpenCapture = null
                    }

                    "consumeSharedPayload" -> {
                        val kind = pendingShareKind
                        val value = pendingShareValue
                        result.success(
                            if (kind == null || value == null) null
                            else mapOf("kind" to kind, "value" to value)
                        )
                        pendingShareKind = null
                        pendingShareValue = null
                    }

                    // Hand the payment on to a real UPI app.
                    //
                    // EXTRA_EXCLUDE_COMPONENTS removes SWIP from the chooser it
                    // opens. Without it the user would pick SWIP, be shown a
                    // chooser containing SWIP, and could loop forever.
                    "forwardUpiIntent" -> {
                        val uri = call.argument<String>("uri")
                        if (uri == null) {
                            result.error("no_uri", "forwardUpiIntent needs a uri", null)
                        } else {
                            runCatching {
                                val target = Intent(
                                    Intent.ACTION_VIEW,
                                    android.net.Uri.parse(uri)
                                )
                                val chooser = Intent.createChooser(target, "Pay with")
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                                    chooser.putExtra(
                                        Intent.EXTRA_EXCLUDE_COMPONENTS,
                                        arrayOf(
                                            ComponentName(
                                                this@MainActivity,
                                                MainActivity::class.java
                                            )
                                        )
                                    )
                                }
                                startActivity(chooser)
                                // `F-158`. The bubble goes quiet for 90
                                // seconds from here. This line is the
                                // enforcement of the first promise on the
                                // bubble Settings screen - "it never appears
                                // over a payment" - and handing a `upi://` to
                                // a wallet is the only moment SWIP knows for
                                // certain that a payment is about to be on
                                // screen.
                                SwipBubbleService.notePaymentStarted(
                                    this@MainActivity)
                            }.fold(
                                onSuccess = { result.success(true) },
                                onFailure = { result.success(false) }
                            )
                        }
                    }

                    // `F-195`. The phone, for the master export's header.
                    //
                    // Everything here is about the DEVICE, never the user:
                    // model, manufacturer, Android version, and which SWIP
                    // build is running. No identifiers — not `ANDROID_ID`, not
                    // the advertising id, not the serial. A black box that is
                    // meant to be exported and mailed must not carry anything
                    // that survives being forwarded, which is the same rule
                    // `TapTrace.tagFields` enforces through its signature.
                    "deviceReport" -> {
                        runCatching {
                            val pkg = packageManager.getPackageInfo(packageName, 0)
                            mapOf(
                                "device" to "${Build.MANUFACTURER} ${Build.MODEL}",
                                "androidRelease" to Build.VERSION.RELEASE,
                                "androidSdk" to Build.VERSION.SDK_INT,
                                "appVersion" to (pkg.versionName ?: "?"),
                                "debuggable" to Blackbox.enabled(this@MainActivity)
                            )
                        }.fold(
                            onSuccess = { result.success(it) },
                            onFailure = { result.success(emptyMap<String, Any>()) }
                        )
                    }

                    // `F-194`. Every installed app that can take a UPI
                    // payment, so SWIP can draw its own "Pay with" list
                    // instead of handing the user to the system chooser.
                    //
                    // ## The permission this deliberately does not use
                    //
                    // On Android 11+ an app cannot see other packages by
                    // default. `QUERY_ALL_PACKAGES` would lift that wholesale
                    // and Google Play treats it as a RESTRICTED permission,
                    // granted only when broad visibility is the app's core
                    // purpose. SWIP's core purpose is a shop's category. That
                    // is the same trade `docs/36` D-45 declined for the Doze
                    // exemption, and it is declined here for the same reason.
                    //
                    // What the manifest declares instead is a `<queries>`
                    // INTENT SIGNATURE — "who can VIEW a `upi:` URI" — which
                    // needs no permission and no review, and can see nothing
                    // else on the phone. The list below is therefore
                    // structurally incapable of being an inventory.
                    //
                    // ## Why the icon travels as PNG bytes
                    //
                    // Because the alternative is a package name and a
                    // `PackageManager` lookup on the Flutter side, which does
                    // not exist. The icons are ~40 dp; eight of them is a few
                    // tens of kilobytes on one channel call, once per sheet.
                    // A failed icon returns null rather than failing the row —
                    // `PayWithSheet` draws a monogram, which still tells two
                    // apps apart.
                    "upiApps" -> {
                        runCatching {
                            val probe = Intent(
                                Intent.ACTION_VIEW,
                                android.net.Uri.parse("upi://pay")
                            )
                            val pm = packageManager
                            val found = if (Build.VERSION.SDK_INT >= 33) {
                                pm.queryIntentActivities(
                                    probe,
                                    PackageManager.ResolveInfoFlags.of(0L)
                                )
                            } else {
                                @Suppress("DEPRECATION")
                                pm.queryIntentActivities(probe, 0)
                            }

                            // `LinkedHashMap` rather than a list: several
                            // launcher aliases of one app resolve the same
                            // intent, and three identical PhonePe rows is a
                            // list nobody trusts. First wins, order kept.
                            val seen = LinkedHashMap<String, Map<String, Any?>>()
                            for (ri in found) {
                                val pkg = ri.activityInfo?.packageName ?: continue
                                if (pkg == packageName) continue  // never offer SWIP
                                if (seen.containsKey(pkg)) continue
                                seen[pkg] = mapOf(
                                    "package" to pkg,
                                    "label" to ri.loadLabel(pm).toString(),
                                    "icon" to iconBytes(ri.loadIcon(pm))
                                )
                            }
                            seen.values.toList()
                        }.fold(
                            onSuccess = { result.success(it) },
                            // An empty list, not an error. `PayWithSheet`
                            // treats empty as "fall through to the system
                            // chooser", which is a working hand-off; an error
                            // would be a dead button.
                            onFailure = { result.success(emptyList<Any>()) }
                        )
                    }

                    // `F-194`. Open one named app on this URI.
                    //
                    // `setPackage` rather than a chooser, because the user has
                    // already chosen — in SWIP's own sheet, one tap ago.
                    "payWithApp" -> {
                        val pkg = call.argument<String>("package")
                        val uri = call.argument<String>("uri")
                        if (pkg.isNullOrBlank() || uri.isNullOrBlank()) {
                            result.error(
                                "bad_args", "payWithApp needs package and uri", null)
                        } else {
                            runCatching {
                                startActivity(
                                    Intent(
                                        Intent.ACTION_VIEW,
                                        android.net.Uri.parse(uri)
                                    )
                                        .setPackage(pkg)
                                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                )
                                // Same promise `forwardUpiIntent` keeps, and
                                // for the same reason: handing a `upi://` to a
                                // wallet is the one moment SWIP knows for
                                // certain a payment is about to be on screen,
                                // and the bubble must not be over it. `F-158`.
                                SwipBubbleService.notePaymentStarted(
                                    this@MainActivity)
                            }.fold(
                                onSuccess = { result.success(true) },
                                // False, not an error. The sheet turns false
                                // into the system chooser; an exception would
                                // turn it into nothing happening.
                                onFailure = { result.success(false) }
                            )
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        EventChannel(engine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    events = sink
                    registerCaptureReceiver()
                }

                override fun onCancel(args: Any?) {
                    unregisterCaptureReceiver()
                    events = null
                }
            })
    }

    /**
     * `F-194`. A launcher icon as PNG bytes, or null.
     *
     * `BitmapDrawable` is the common case and is unwrapped directly. Everything
     * else — adaptive icons, vectors, layer lists — has no bitmap to take, so
     * it is drawn into one at its own intrinsic size. An icon with no intrinsic
     * size (some `ColorDrawable` placeholders report -1) would make
     * `createBitmap` throw, so it is floored at 1 px and the row falls back to
     * a monogram, which is the honest outcome for an icon that is one pixel.
     */
    private fun iconBytes(d: Drawable?): ByteArray? {
        if (d == null) return null
        return runCatching {
            val bmp = if (d is BitmapDrawable && d.bitmap != null) {
                d.bitmap
            } else {
                val w = d.intrinsicWidth.coerceAtLeast(1).coerceAtMost(192)
                val h = d.intrinsicHeight.coerceAtLeast(1).coerceAtMost(192)
                val out = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                val canvas = Canvas(out)
                d.setBounds(0, 0, canvas.width, canvas.height)
                d.draw(canvas)
                out
            }
            val bytes = ByteArrayOutputStream()
            bmp.compress(Bitmap.CompressFormat.PNG, 100, bytes)
            bytes.toByteArray()
        }.getOrNull()
    }

    private fun registerCaptureReceiver() {
        if (receiver != null) return
        receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context?, intent: Intent?) {
                if (intent?.action != SwipListenService.ACTION_CAPTURE) return

                @Suppress("UNCHECKED_CAST")
                val tlv = intent.getSerializableExtra(SwipListenService.EXTRA_TLV)
                    as? HashMap<String, String> ?: return

                events?.success(
                    mapOf(
                        "tlv" to tlv,
                        "trace" to intent.getStringExtra(SwipListenService.EXTRA_TRACE),
                        // `F-143`. How far the exchange got. An empty `tlv` with
                        // a reason of "no_gpo" or "no_select" is a real result,
                        // not a dropped one — the Dart side turns it into a
                        // sentence about the terminal. Forwarding this is what
                        // stops a tap ending in silence.
                        "reason" to (
                            intent.getStringExtra(SwipListenService.EXTRA_REASON)
                                ?: SwipListenService.REASON_READ
                            ),
                        "capturedAt" to System.currentTimeMillis()
                    )
                )
            }
        }

        val filter = IntentFilter(SwipListenService.ACTION_CAPTURE)
        // Android 13+ requires an explicit export flag. This broadcast is
        // strictly in-process, so it is NOT exported.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(receiver, filter)
        }
    }

    private fun unregisterCaptureReceiver() {
        receiver?.let { runCatching { unregisterReceiver(it) } }
        receiver = null
    }

    private fun applyPreferredService(enable: Boolean) {
        val ce = cardEmulation ?: return
        val component = ComponentName(this, SwipListenService::class.java)
        runCatching {
            if (enable) {
                ce.setPreferredService(this, component)
            } else {
                ce.unsetPreferredService(this)
            }
        }
    }

    // Preferred-service registration is only valid while resumed, so it is
    // re-applied on every resume and always released on pause — including when
    // the user backgrounds the app mid-tap.
    override fun onResume() {
        super.onResume()
        if (listening) applyPreferredService(true)

        // Claimed BEFORE `restoreIfWanted` below, not after. Starting the
        // service first would let it come up believing SWIP is in the
        // background and flash a bubble over this very screen before the next
        // line corrected it.
        SwipBubbleService.noteForeground(this, true, from = "app.onResume")

        // `F-158`. The bubble is a foreground service, so Android kills it
        // with the process. `SwipBootReceiver` brings it back after a reboot
        // or an app update; this covers everything else — a process death
        // under memory pressure, or a force-stop the user has since recovered
        // from by opening SWIP.
        //
        // In `onResume` rather than `onCreate` because Android 12+ throws
        // ForegroundServiceStartNotAllowedException for a start from the
        // background, and `onCreate` is the edge of that window while
        // `onResume` is provably inside it. It is guarded on the service not
        // already running, so calling it on every resume costs nothing.
        SwipBubbleService.restoreIfWanted(this)

        // `docs/32` §2. A bubble over SWIP's own scanner is a smudge on the
        // viewfinder. This is also how the rule "never over a payment" is kept
        // WITHOUT usage-access or an accessibility service: SWIP can only ever
        // observe its own lifecycle, so it reports that and infers nothing.
        //
        // Recorded whether or not the service is running. It used to be sent
        // as a broadcast that a not-yet-started service could not receive,
        // which is precisely how the bubble ended up permanently hidden.
    }

    override fun onPause() {
        applyPreferredService(false)
        SwipBubbleService.noteForeground(this, false, from = "app.onPause")
        super.onPause()
    }

    /**
     * `F-159`. The answer to the `POST_NOTIFICATIONS` dialog.
     *
     * `take`-then-null, because a `MethodChannel.Result` can only be completed
     * once and this callback is not guaranteed to arrive only once.
     */
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != NOTIFICATION_REQUEST) return
        val pending = pendingNotificationResult ?: return
        pendingNotificationResult = null
        pending.success(
            grantResults.isNotEmpty() &&
                grantResults[0] ==
                android.content.pm.PackageManager.PERMISSION_GRANTED
        )
    }

    override fun onDestroy() {
        // An unanswered Dart Future would hang the wizard's button forever.
        pendingNotificationResult?.success(false)
        pendingNotificationResult = null
        unregisterCaptureReceiver()
        super.onDestroy()
    }
}
