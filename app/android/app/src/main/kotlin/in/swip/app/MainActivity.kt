package `in`.swip.app

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.nfc.NfcAdapter
import android.nfc.cardemulation.CardEmulation
import android.os.Build
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

    private companion object {
        const val METHOD_CHANNEL = "in.swip.app/nfc"
        const val EVENT_CHANNEL = "in.swip.app/nfc/captures"
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

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        capturePaymentIntent(intent)
        captureSharedPayload(intent)
    }

    /** `launchMode="singleTop"`, so a second checkout arrives here. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        capturePaymentIntent(intent)
        captureSharedPayload(intent)
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
                        applyPreferredService(true)
                        result.success(null)
                    }

                    "stopListening" -> {
                        listening = false
                        applyPreferredService(false)
                        result.success(null)
                    }

                    "openNfcSettings" -> {
                        startActivity(Intent(android.provider.Settings.ACTION_NFC_SETTINGS))
                        result.success(null)
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
                            }.fold(
                                onSuccess = { result.success(true) },
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
    }

    override fun onPause() {
        applyPreferredService(false)
        super.onPause()
    }

    override fun onDestroy() {
        unregisterCaptureReceiver()
        super.onDestroy()
    }
}
