package `in`.swip.app

import android.content.Intent
import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.util.Log

/**
 * SWIP Listen — Capture Vector 2.
 *
 * Reads the **Merchant Category Code** out of a physical POS terminal by
 * presenting the phone as an EMV payment card and then refusing to transact.
 *
 * ## Why this works
 *
 * In EMV, the *card* dictates the agenda. When the terminal issues
 * `SELECT AID`, the card replies with an FCI containing a **PDOL** (Processing
 * Data Object List, tag `9F38`) — a list of data objects the card requires the
 * terminal to hand over before it will process anything. The terminal is
 * obliged to supply them, in order, in the `GET PROCESSING OPTIONS` command.
 *
 * One of the tags a card may request is **`9F15` — Merchant Category Code**,
 * whose source is the terminal (EMV Book 4, ISO 8583 Card Acceptor Business
 * Code). So SWIP is simply a card that asks a question cards are allowed to ask.
 *
 * No exploit. No relay. No interception. See docs/03-RESEARCH §3.
 *
 * ## Why nothing can be charged
 *
 * After capturing the GPO command data the service returns
 * `SW=6985` (conditions of use not satisfied) and stops. There is no PAN in
 * this binary, no cryptogram is generated, no `GENERATE AC` is answered. The
 * terminal shows a read error and the cashier retries with a real card.
 *
 * This is exactly ideation `C-13`: *"they get their payment declined because
 * there wouldn't be any payment done... it's not related to payments or money."*
 *
 * ## Field-test caveat
 *
 * EMV requires a terminal to supply *something* of the correct length for every
 * PDOL tag requested. A terminal whose kernel has no MCC provisioned supplies
 * zeros. **What fraction of terminals in the field carry a real `9F15` is the
 * single most important unknown in this product and cannot be looked up — it
 * must be measured.** See the field-test protocol in docs/03-RESEARCH §3.4.
 *
 * Even at a zero hit rate the feature has a floor: `9F16` (Merchant
 * Identifier), `9F1C` (Terminal ID) and `9F1A` (Terminal Country Code) come
 * back from essentially every terminal, and those alone key the merchant graph.
 */
class SwipListenService : HostApduService() {

    companion object {
        private const val TAG = "SwipListen"

        /** Broadcast consumed by [MainActivity] and forwarded over the method channel. */
        const val ACTION_CAPTURE = "in.swip.app.CAPTURE"
        const val EXTRA_TLV = "tlv"
        const val EXTRA_TRACE = "trace"

        // ---- status words ----
        private val SW_OK = byteArrayOf(0x90.toByte(), 0x00)
        private val SW_COND_NOT_SATISFIED = byteArrayOf(0x69, 0x85.toByte())
        private val SW_FILE_NOT_FOUND = byteArrayOf(0x6A, 0x82.toByte())
        private val SW_INS_NOT_SUPPORTED = byteArrayOf(0x6D, 0x00)

        // ---- APDU ----
        private const val CLA_ISO = 0x00.toByte()
        private const val INS_SELECT = 0xA4.toByte()
        private const val INS_GPO = 0xA8.toByte()

        private const val PPSE = "2PAY.SYS.DDF01"

        /**
         * The PDOL SWIP advertises, in tag order. The terminal concatenates the
         * values in exactly this sequence, with exactly these lengths, so the
         * response is parsed positionally against this list.
         *
         * Ordered most-wanted first so that a terminal which truncates its
         * response still yields the MCC.
         */
        val PDOL: List<Pair<String, Int>> = listOf(
            "9F15" to 2,  // Merchant Category Code            <- the prize
            "9F16" to 15, // Merchant Identifier               <- graph key
            "9F1C" to 8,  // Terminal Identification
            "9F1A" to 2,  // Terminal Country Code             <- national/intl
            "5F2A" to 2,  // Transaction Currency Code
            "9F02" to 6,  // Amount, Authorised
            "9A" to 3,    // Transaction Date
            "9F21" to 3,  // Transaction Time
            "9F35" to 1,  // Terminal Type
            "9F33" to 3,  // Terminal Capabilities
            "9F37" to 4,  // Unpredictable Number
            "9F4E" to 20  // Merchant Name and Location
        )

        /** Payment AIDs mirrored in `res/xml/apduservice.xml`. */
        private val AIDS = listOf(
            "A0000000031010",     // Visa
            "A0000000041010",     // Mastercard
            "A0000005241010",     // RuPay
            "A00000002501",       // Amex
            "A0000000651010",     // JCB
            "A000000333010101"    // UnionPay
        )
    }

    /** Accumulated across the exchange; emitted once the GPO lands. */
    private val trace = StringBuilder()

    override fun processCommandApdu(apdu: ByteArray?, extras: Bundle?): ByteArray {
        if (apdu == null || apdu.size < 4) return SW_INS_NOT_SUPPORTED
        trace.append("<< ").append(apdu.toHex()).append('\n')

        return when {
            isSelect(apdu) -> handleSelect(apdu)
            apdu[1] == INS_GPO -> handleGpo(apdu)
            // Anything else means the terminal got further than we intend to go.
            else -> SW_COND_NOT_SATISFIED
        }.also { trace.append(">> ").append(it.toHex()).append('\n') }
    }

    private fun isSelect(apdu: ByteArray) =
        apdu[0] == CLA_ISO && apdu[1] == INS_SELECT

    /**
     * Step 1 and 2 of the flow: `SELECT PPSE` then `SELECT AID`.
     *
     * The PPSE response advertises our AIDs; the AID response carries the PDOL,
     * which is the entire point of this service.
     */
    private fun handleSelect(apdu: ByteArray): ByteArray {
        val lc = if (apdu.size > 4) apdu[4].toInt() and 0xFF else 0
        if (lc == 0 || apdu.size < 5 + lc) return SW_FILE_NOT_FOUND
        val name = apdu.copyOfRange(5, 5 + lc)

        return if (String(name, Charsets.US_ASCII) == PPSE) {
            ppseResponse() + SW_OK
        } else {
            // Any AID we advertised: reply with the FCI carrying the PDOL.
            fciWithPdol(name) + SW_OK
        }
    }

    /**
     * Step 3 — the payoff.
     *
     * The command data is `83 <len> <concatenated PDOL values>`. We slice it
     * positionally against [PDOL], emit the capture, and then decline.
     */
    private fun handleGpo(apdu: ByteArray): ByteArray {
        val lc = if (apdu.size > 4) apdu[4].toInt() and 0xFF else 0
        if (lc > 0 && apdu.size >= 5 + lc) {
            val body = apdu.copyOfRange(5, 5 + lc)
            // Strip the 0x83 template header if present.
            val values = if (body.isNotEmpty() && body[0] == 0x83.toByte()) {
                val len = body[1].toInt() and 0xFF
                if (body.size >= 2 + len) body.copyOfRange(2, 2 + len) else body
            } else {
                body
            }
            emit(slicePdol(values))
        }

        // Decline. Nothing is authorised, no cryptogram is produced, and the
        // conversation ends here by design.
        return SW_COND_NOT_SATISFIED
    }

    /**
     * Splits the terminal's concatenated PDOL response into tag -> hex.
     *
     * Values that are entirely zero or entirely 0xFF are dropped: EMV requires
     * the terminal to send *something* of the right length for every requested
     * tag, so an unprovisioned data element arrives as padding. Recording
     * `9F15 = 0000` as if it were a real category would be worse than recording
     * nothing — the app would show "0000 / unclassified" with the authority of
     * a live capture.
     */
    private fun slicePdol(values: ByteArray): Map<String, String> {
        val out = LinkedHashMap<String, String>()
        var i = 0
        for ((tag, len) in PDOL) {
            if (i + len > values.size) break
            val slice = values.copyOfRange(i, i + len)
            i += len
            if (slice.all { it == 0x00.toByte() } || slice.all { it == 0xFF.toByte() }) {
                Log.d(TAG, "$tag not provisioned by terminal")
                continue
            }
            out[tag] = slice.toHex()
        }
        return out
    }

    private fun emit(tlv: Map<String, String>) {
        Log.i(TAG, "captured: $tlv")
        sendBroadcast(
            Intent(ACTION_CAPTURE)
                .setPackage(packageName)
                .putExtra(EXTRA_TLV, HashMap(tlv))
                .putExtra(EXTRA_TRACE, trace.toString())
        )
    }

    /** FCI for `2PAY.SYS.DDF01`, listing our AIDs as directory entries. */
    private fun ppseResponse(): ByteArray {
        val entries = AIDS.flatMapIndexed { idx, aid ->
            // 61 <len> [ 4F <len> AID | 87 01 priority ]
            val aidBytes = aid.hexToBytes()
            val inner = byteArrayOf(0x4F, aidBytes.size.toByte()) + aidBytes +
                byteArrayOf(0x87.toByte(), 0x01, (idx + 1).toByte())
            (byteArrayOf(0x61, inner.size.toByte()) + inner).toList()
        }.toByteArray()

        val dfName = PPSE.toByteArray(Charsets.US_ASCII)
        val fciIssuer = tlv(0xBF0C, entries)
        val fciProprietary = tlv(0xA5, fciIssuer)
        val body = tlv(0x84, dfName) + fciProprietary
        return tlv(0x6F, body)
    }

    /**
     * FCI for a selected AID, carrying the PDOL in tag `9F38`.
     *
     * This is the single most important byte sequence in the product: it is the
     * request that makes a terminal disclose its merchant category code.
     */
    private fun fciWithPdol(aid: ByteArray): ByteArray {
        val pdol = PDOL.flatMap { (tag, len) ->
            (tag.hexToBytes() + byteArrayOf(len.toByte())).toList()
        }.toByteArray()

        val label = "SWIP".toByteArray(Charsets.US_ASCII)
        val proprietary = tlv(0x50, label) +          // Application Label
            byteArrayOf(0x87.toByte(), 0x01, 0x01) +            // Priority Indicator
            tlv(0x9F38, pdol)                          // PDOL
        val body = tlv(0x84, aid) + tlv(0xA5, proprietary)
        return tlv(0x6F, body)
    }

    /**
     * BER-TLV with short-form length only.
     *
     * Sufficient here because every structure this service emits is well under
     * 128 bytes. If the PDOL or AID list grows past that, this needs long-form
     * length encoding (0x81 <len>) or terminals will reject the FCI.
     */
    private fun tlv(tag: Int, value: ByteArray): ByteArray {
        require(value.size < 0x80) { "TLV value too long for short-form length" }
        val tagBytes = when {
            tag <= 0xFF -> byteArrayOf(tag.toByte())
            tag <= 0xFFFF -> byteArrayOf((tag shr 8).toByte(), tag.toByte())
            else -> byteArrayOf((tag shr 16).toByte(), (tag shr 8).toByte(), tag.toByte())
        }
        return tagBytes + byteArrayOf(value.size.toByte()) + value
    }

    override fun onDeactivated(reason: Int) {
        trace.setLength(0)
    }

    private fun ByteArray.toHex() =
        joinToString("") { "%02X".format(it) }

    private fun String.hexToBytes() =
        chunked(2).map { it.toInt(16).toByte() }.toByteArray()
}
