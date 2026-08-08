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
                            )
                        )
                    )

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
