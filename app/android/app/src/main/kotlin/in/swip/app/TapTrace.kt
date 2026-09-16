package `in`.swip.app

import android.content.ComponentName
import android.content.Context
import android.nfc.NfcAdapter
import android.nfc.cardemulation.CardEmulation
import android.os.Build

/**
 * `F-187` — **the black box for tapping a card machine.**
 *
 * > *"I'm not sure what the issue is with the POS tapping. Some happen to be
 * > successful, and a few fail. The major issue is that I don't know what the
 * > issue is."*
 *
 * That is the whole problem, and it is the same shape as the floating button's
 * disappearance: **every way a tap can fail looks identical from outside.** The
 * phone is held against a terminal, nothing happens, and there are at least
 * seven distinct reasons why — none of which the user can tell apart.
 *
 * ## The seven, in the order they can go wrong
 *
 * 1. **The phone has no NFC.** Nothing will ever work; the app should say so
 *    once and stop offering the feature.
 * 2. **NFC is switched off.** The field never opens.
 * 3. **SWIP is not the default contactless payment app.** This is the big one.
 *    Android routes the whole field to whichever app holds that slot, so on any
 *    phone with Google Wallet set up the terminal's commands go to Wallet and
 *    **SWIP never sees a single byte**. `F-55` found it; nothing recorded it
 *    per-tap until now.
 * 4. **The screen is off or the phone is locked.** Payment AIDs are not routed
 *    to an app behind the keyguard.
 * 5. **The terminal never sent a SELECT we recognise** — it opened the field,
 *    did something else, and left. `REASON_NO_SELECT`.
 * 6. **The terminal selected us and never asked for processing options.** It
 *    got the PDOL and walked away. `REASON_NO_GPO`.
 * 7. **It answered, and the answer was padding.** EMV requires a terminal to
 *    send something of the right length for every requested tag, so an
 *    unprovisioned category arrives as `0000` or `FFFF`. The exchange
 *    succeeded and there is still no MCC.
 *
 * Only 5, 6 and 7 are the terminal's doing. **1 to 4 are the phone, and they
 * are all knowable before the tap** — which is why [snapshot] exists and why
 * it runs on every tap rather than only when something breaks.
 *
 * ## The privacy rule, which is stricter here than anywhere else
 *
 * An APDU exchange is the one place in SWIP where a **merchant identifier**
 * genuinely lives, so this file writes tag *names* and value *lengths* and
 * never values. [tags] is the only way an exchange's contents reach the log,
 * and it cannot emit a value because it is never given one.
 *
 * That is deliberate design rather than discipline: a rule enforced by the
 * shape of a function survives a hurried edit, and a rule written in a comment
 * above a call site does not. The file leaves the phone by design — it is
 * meant to be exported and sent — and a debug log that quietly carried a
 * merchant ID would be a privacy hole opened for convenience, in the one app
 * whose whole claim is that nothing leaves it.
 */
object TapTrace {

    fun log(context: Context, event: String, vararg fields: Pair<String, Any?>) =
        Blackbox.tap.log(context, event, *fields)

    /**
     * Which EMV tags came back and how long each value was — **never what it
     * said.**
     *
     * Lengths are worth having on their own: a `9F15` of length 2 that was
     * dropped as padding and a `9F15` that never arrived are different
     * failures with the same symptom, and the length is how they are told
     * apart afterwards.
     */
    fun tags(context: Context, event: String, tlv: Map<String, String>) =
        Blackbox.tap.log(context, event, *tagFields(tlv).toTypedArray())

    /**
     * The privacy rule, as a pure function — **so it can be proved rather than
     * promised.** See `TapTraceTest`.
     *
     * Separated from [tags] for one reason: this is the single place in SWIP
     * where a merchant identifier could leak off the phone, and a rule that
     * lives inside a `Context`-bound call cannot be tested on the JVM. A test
     * that hands this a map full of real-looking values and asserts that not
     * one of them appears in the output is worth more than the paragraph above
     * it, because the paragraph cannot fail CI.
     */
    internal fun tagFields(tlv: Map<String, String>): List<Pair<String, Any?>> {
        val sorted = tlv.entries.sortedBy { it.key }
        return listOf(
            "tags" to sorted.joinToString(",") { it.key },
            "count" to tlv.size,
            // Hex, so a length here is half a value's character count.
            "lengths" to sorted.joinToString(",") { "${it.key}:${it.value.length / 2}" },
        )
    }

    /**
     * Everything about this phone that decides whether a tap can work at all.
     *
     * Written **on every tap**, not only on a failure. A snapshot that only
     * appears when something breaks cannot be compared against a working one,
     * and *"what was different about the taps that succeeded"* is the question
     * this file exists to answer.
     *
     * Every value is read from the platform at the moment it is written. None
     * of it is remembered state, for the reason `CLAUDE.md` gives about the
     * floating button's switch: **a flag that stores its own answer cannot be
     * wrong on screen**, and cannot be wrong in a log either.
     */
    fun snapshot(context: Context, why: String) {
        if (!Blackbox.enabled(context)) return

        val adapter = runCatching { NfcAdapter.getDefaultAdapter(context) }.getOrNull()
        val emulation = adapter?.let {
            runCatching { CardEmulation.getInstance(it) }.getOrNull()
        }
        val isDefault = runCatching {
            emulation?.isDefaultServiceForCategory(
                ComponentName(context, SwipListenService::class.java),
                CardEmulation.CATEGORY_PAYMENT,
            )
        }.getOrNull()

        val keyguard = runCatching {
            val km = context.getSystemService(android.app.KeyguardManager::class.java)
            km?.isKeyguardLocked
        }.getOrNull()

        val screenOn = runCatching {
            val pm = context.getSystemService(android.os.PowerManager::class.java)
            pm?.isInteractive
        }.getOrNull()

        Blackbox.tap.log(
            context, "nfc.state",
            "why" to why,
            // Null and false mean different things: no adapter is a phone that
            // can never do this, and a disabled adapter is a setting away.
            "hasNfc" to (adapter != null),
            "nfcOn" to adapter?.isEnabled,
            // THE field. `F-55`: on a phone with Wallet set up this is false,
            // the terminal's APDUs go to Wallet, and SWIP sees nothing at all.
            "isDefaultPayment" to isDefault,
            // `isSecureNfcEnabled` (API 29+) refuses NFC while locked entirely,
            // which is a second, separate way for a locked phone to fail.
            "secureNfc" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                runCatching { adapter?.isSecureNfcEnabled }.getOrNull()
            } else {
                null
            },
            "locked" to keyguard,
            "screenOn" to screenOn,
        )
    }
}
