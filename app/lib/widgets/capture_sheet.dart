import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/settings/home_market.dart';
import '../core/theme/swip_tokens.dart';
import '../data/models/capture_event.dart';
import '../data/models/mcc.dart';
import '../data/sources/merchant_identity.dart';
import '../data/sources/payload_kind.dart';
import 'mcc_badge.dart';

/// The one capture sheet. Every vector ends here — QR, POS tap, pay-by-app
/// intent, link, manual.
///
/// Hierarchy is fixed and deliberate (`F-10`–`F-13`):
///
///   1. the MCC
///   2. what the MCC means
///   3. the merchant
///   4. everything else, below a rule, labelled with the source's own names
///
/// It replaces the two near-identical sheets that had grown in scan_page and
/// intent_capture. One screen means one place to fix copy, one place to add a
/// field, and no chance of the QR path and the tap path disagreeing about how
/// a capture is described.
class CaptureSheet extends StatelessWidget {
  const CaptureSheet({
    super.key,
    required this.event,
    required this.mcc,
    required this.sourceLabel,
    this.details = const {},
    this.rawPayload,
    this.onPrimary,
    this.primaryLabel = 'Done',
    this.noCategoryTitle,
    this.noCategoryBody,
    this.verdict,
    this.payeeKind = PayeeKind.undetermined,
    this.tier = MerchantTier.unknown,
  });

  final CaptureEvent event;
  final Mcc? mcc;

  /// Human provenance — "UPI QR", "POS terminal", "Razorpay payment link".
  final String sourceLabel;

  /// `F-13`. Whatever the source actually gave us, keyed by **its own field
  /// name**, in the order it should be read. Not a fixed schema: a POS tap and
  /// a QR return different things and both are shown as they came.
  final Map<String, String> details;

  final String? rawPayload;
  final VoidCallback? onPrimary;
  final String primaryLabel;

  /// Override the "no category" copy when the vector knows better than a
  /// payload sniff can. A POS terminal that returned no `9F15` is a different
  /// story from a QR with no tag 52, and calling a terminal "this code" is the
  /// kind of small wrongness that makes a person stop believing the rest.
  final String? noCategoryTitle;
  final String? noCategoryBody;

  /// `F-16`. Domestic or international, decided against the user's home market.
  final MarketVerdict? verdict;

  /// `F-42`. Whether the payee is a registered business or a person. Changes
  /// what "no category" *means*, which is the whole difference between "this
  /// will not earn" and "this shop's bank did not publish it".
  final PayeeKind payeeKind;

  /// `F-46`, `F-47`. P2M or P2PM. Drives the RuPay line and turns "no category
  /// found" into "no category exists" where that is the truth.
  final MerchantTier tier;

  @override
  Widget build(BuildContext context) {
    final known = event.hasMcc;

    // [PayloadExplanation] reads the payload as *the code someone pointed at*.
    // A POS tap's payload is an APDU trace — a log of the conversation, not a
    // code — so sniffing it would label a terminal read "Just text". Only the
    // vectors whose raw payload really is the code get explained.
    final explanation = rawPayload == null || !_payloadIsTheCode(event.vector)
        ? null
        : PayloadExplanation.of(rawPayload!, hasMcc: known);

    final isRegisteredMerchant = payeeKind == PayeeKind.registeredMerchant;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            SwipSpace.xl, SwipSpace.md, SwipSpace.xl, SwipSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── source badge, top right — F-17 ──
            Row(
              children: [
                Expanded(
                  child: Text(
                    sourceLabel.toUpperCase(),
                    style: SwipType.labelS
                        .copyWith(color: SwipColors.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (verdict != null) ...[
                  _Badge(
                    text: verdict!.isInternational ? 'INTL' : 'DOMESTIC',
                    accent: verdict!.isInternational,
                  ),
                  const SizedBox(width: SwipSpace.xs),
                ],
                _Badge(text: explanation?.badge ?? _vectorBadge(event.vector)),
              ],
            ),
            const SizedBox(height: SwipSpace.lg),

            if (known) ...[
              // 1 ── the code
              _FoilCode(event.mcc!),
              const SizedBox(height: SwipSpace.xs),

              // 2 ── what it means
              Text(
                mcc?.displayName ?? 'Not in the offline table yet',
                style: SwipType.bodyL.copyWith(color: SwipColors.textPrimary),
              )
                  .animate()
                  .fadeIn(delay: 240.ms, duration: 320.ms)
                  .moveY(begin: 10, curve: SwipMotion.captureCurve),
            ] else ...[
              // No category. `F-64` — say what this is in a headline you can
              // read at a glance, and ONE short line under it.
              //
              // The previous copy was four sentences per case. At a counter,
              // with a queue behind you, four sentences is the same as nothing:
              // the long version now lives behind "View technical details",
              // where someone who wants it will go looking.
              //
              // Precedence: what the vector knows > what the handle proves >
              // what the payload sniff guessed.
              Text(
                noCategoryTitle ?? _emptyTitle(explanation, isRegisteredMerchant),
                style: SwipType.titleM.copyWith(color: SwipColors.textPrimary),
              ),
              const SizedBox(height: SwipSpace.xs),
              Text(
                noCategoryBody ?? _emptyBody(explanation, isRegisteredMerchant),
                style: SwipType.bodyM
                    .copyWith(color: SwipColors.textSecondary),
              ),
            ],

            // `F-47` — the line CRED shows, with the reason attached.
            //
            // Whether a shop takes a RuPay credit card and whether it has a
            // category are the SAME fact: both follow from its NPCI tier. So
            // this is not a second lookup, it is the same finding said in the
            // words the person is actually asking in.
            if (tier.rupayNote != null) ...[
              const SizedBox(height: SwipSpace.md),
              _Note(
                text: tier.rupayNote!,
                icon: tier == MerchantTier.fullMerchant
                    ? Icons.credit_score_outlined
                    : Icons.credit_card_off_outlined,
                good: tier == MerchantTier.fullMerchant,
              ),
            ],

            // `F-53` — which mode of payment the category was read from.
            // Asked for explicitly, and it is the difference between a number
            // you can act on and a number you have to take on trust.
            const SizedBox(height: SwipSpace.md),
            _DetectionLine(vector: event.vector, hasMcc: known),

            // 3 ── the merchant, registered name where one exists.
            //
            // `F-42`. Falls back to the payee handle rather than to the PSP's
            // name. `paytmqr6twbbd@ptys` is checkable against the sticker in
            // front of you; "Paytm" is the payment company and was appearing as
            // the shop on every Paytm QR in the country.
            if (event.identityLine != null) ...[
              const SizedBox(height: SwipSpace.md),
              Row(
                children: [
                  Icon(
                    event.merchantName == null
                        ? Icons.alternate_email_rounded
                        : Icons.storefront_outlined,
                    size: 16,
                    color: SwipColors.textTertiary,
                  ),
                  const SizedBox(width: SwipSpace.sm),
                  Expanded(
                    child: Text(
                      [event.identityLine, event.merchantCity]
                          .whereType<String>()
                          .join(' · '),
                      style: SwipType.titleS.copyWith(
                        color: event.merchantName == null
                            ? SwipColors.textSecondary
                            : SwipColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // `F-40` — where you were, discreetly. Read off the event rather
            // than passed in by each vector, so it appears everywhere the
            // moment location is switched on and nowhere when it is not.
            if (event.placeLabel != null) ...[
              const SizedBox(height: SwipSpace.xs),
              Row(
                children: [
                  const Icon(Icons.place_outlined,
                      size: 14, color: SwipColors.textTertiary),
                  const SizedBox(width: SwipSpace.sm),
                  Expanded(
                    child: Text(
                      event.placeLabel!,
                      style: SwipType.bodyS
                          .copyWith(color: SwipColors.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            if (known) ...[
              const SizedBox(height: SwipSpace.md),
              Row(children: [
                ConfidencePill(event.confidence),
                if (mcc != null && mcc!.publications.isNotEmpty) ...[
                  const SizedBox(width: SwipSpace.md),
                  Flexible(child: PublicationChips(mcc!.publications)),
                ],
              ]),
            ],

            // 4 ── everything else, under a rule, with the source's own labels
            if (details.isNotEmpty) ...[
              const SizedBox(height: SwipSpace.lg),
              const Divider(height: 1),
              const SizedBox(height: SwipSpace.md),
              for (final entry in details.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: SwipSpace.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 132,
                        child: Text(entry.key,
                            style: SwipType.bodyS
                                .copyWith(color: SwipColors.textTertiary)),
                      ),
                      Expanded(
                        child: Text(entry.value,
                            style: SwipType.bodyS
                                .copyWith(color: SwipColors.textSecondary)),
                      ),
                    ],
                  ),
                ),
            ],

            const SizedBox(height: SwipSpace.xl),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    onPrimary ?? () => Navigator.of(context).maybePop(),
                child: Text(primaryLabel),
              ),
            ),

            // F-18 — the quiet confirmation under the button.
            const SizedBox(height: SwipSpace.sm),
            Center(
              child: Text(
                known
                    ? 'Saved to your ledger'
                    : 'Saved to your ledger as uncategorised',
                style:
                    SwipType.bodyS.copyWith(color: SwipColors.textTertiary),
              ),
            ),

            // F-23 — technical detail, available but never in the way.
            if (rawPayload != null) ...[
              const SizedBox(height: SwipSpace.xs),
              Center(
                child: TextButton(
                  onPressed: () => _showRaw(context, rawPayload!),
                  child: Text('View technical details',
                      style: SwipType.bodyS
                          .copyWith(color: SwipColors.textSecondary)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// `F-64`. A headline, four words or fewer where possible.
  static String _emptyTitle(PayloadExplanation? e, bool isMerchant) {
    if (isMerchant) return 'A real shop, no category published';
    return switch (e?.kind) {
      PayloadKind.personalUpi => 'A person, not a shop',
      PayloadKind.webLink => 'A website',
      PayloadKind.appStore => 'An app link',
      PayloadKind.wifi => 'A wifi code',
      PayloadKind.contact => 'A contact card',
      PayloadKind.phone => 'A phone number',
      PayloadKind.sms => 'A text message',
      PayloadKind.location => 'A map pin',
      PayloadKind.crypto => 'A crypto address',
      PayloadKind.damaged => 'Damaged code',
      PayloadKind.empty => 'Empty code',
      PayloadKind.plainText => 'Just text',
      _ => 'No category in this code',
    };
  }

  /// One line. Says what it means for the person, not what it is technically.
  static String _emptyBody(PayloadExplanation? e, bool isMerchant) {
    if (isMerchant) {
      return 'Tap their card machine to find it.';
    }
    return switch (e?.kind) {
      PayloadKind.personalUpi => 'No category exists. Nothing to earn here.',
      PayloadKind.webLink => 'Not a payment code.',
      PayloadKind.appStore => 'Not a payment code.',
      PayloadKind.wifi => 'Joins a network. Not a payment.',
      PayloadKind.contact => 'Someone\'s details. Not a payment.',
      PayloadKind.phone => 'Dials a number. Not a payment.',
      PayloadKind.sms => 'Writes a message. Not a payment.',
      PayloadKind.location => 'Opens a map. Not a payment.',
      PayloadKind.crypto => 'Crypto skips card networks, so no category.',
      PayloadKind.damaged => 'It failed its own checksum. Scan again.',
      PayloadKind.empty => 'The code scanned, but held nothing.',
      PayloadKind.plainText => 'Plain text, not payment details.',
      _ => 'SWIP will fill this in if this shop is captured another way.',
    };
  }

  static bool _payloadIsTheCode(CaptureVector v) =>
      v == CaptureVector.qr ||
      v == CaptureVector.link ||
      v == CaptureVector.intent ||
      v == CaptureVector.manual;

  static String _vectorBadge(CaptureVector v) => switch (v) {
        CaptureVector.qr => 'QR',
        CaptureVector.nfc => 'POS',
        CaptureVector.intent => 'APP',
        CaptureVector.link => 'LINK',
        CaptureVector.probe => 'PROBE',
        CaptureVector.manual => 'YOU',
        CaptureVector.graph => 'KNOWN',
        CaptureVector.statement => 'BANK',
      };

  static void _showRaw(BuildContext context, String raw) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SwipColors.surfaceRaised,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SwipSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Exactly what was read',
                  style: SwipType.titleS
                      .copyWith(color: SwipColors.textPrimary)),
              const SizedBox(height: SwipSpace.sm),
              Text(
                'This is the untouched payload. SWIP shows its working so you '
                'never have to take a category on trust.',
                style: SwipType.bodyS
                    .copyWith(color: SwipColors.textSecondary),
              ),
              const SizedBox(height: SwipSpace.lg),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 260),
                padding: const EdgeInsets.all(SwipSpace.md),
                decoration: BoxDecoration(
                  color: SwipColors.surfaceRaised2,
                  borderRadius: SwipRadius.inputAll,
                ),
                child: SingleChildScrollView(
                  child: SelectableText(raw, style: SwipType.mono
                      .copyWith(color: SwipColors.textSecondary)),
                ),
              ),
              const SizedBox(height: SwipSpace.lg),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: raw));
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The four digits, gold, landing one by one under a single foil sweep.
class _FoilCode extends StatelessWidget {
  const _FoilCode(this.code);
  final String code;

  @override
  Widget build(BuildContext context) {
    final digits = code.split('');
    return ShaderMask(
      // One shader across the whole run — per-glyph gradients shatter the foil.
      shaderCallback: (b) => SwipGradients.foil.createShader(b),
      blendMode: BlendMode.srcIn,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < digits.length; i++)
            Text(digits[i],
                    style: SwipType.mcc.copyWith(
                        fontSize: 60,
                        height: 64 / 60,
                        color: SwipColors.gold500))
                .animate()
                .fadeIn(delay: (i * 50).ms, duration: 240.ms)
                .moveY(
                    begin: 24,
                    delay: (i * 50).ms,
                    duration: SwipMotion.capture,
                    curve: SwipMotion.captureCurve),
        ],
      ),
    ).animate().shimmer(
        delay: 320.ms,
        duration: SwipMotion.foilSweep,
        color: SwipColors.gold100);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, this.accent = false});

  final String text;

  /// `F-16`. Amber, only for International. Domestic is the common case and a
  /// badge on every single row stops being read after a week — the colour is
  /// reserved for the one that changes what a card pays.
  final bool accent;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: SwipSpace.sm, vertical: 3),
        decoration: BoxDecoration(
          color: accent ? SwipColors.warningFill : null,
          borderRadius: SwipRadius.chipAll,
          border: Border.all(
              color: accent ? SwipColors.warningOnInk : SwipColors.hairline),
        ),
        child: Text(text,
            style: SwipType.labelS.copyWith(
                color: accent
                    ? SwipColors.warningOnInk
                    : SwipColors.textSecondary)),
      );
}

/// `F-53` — which mode of payment produced the category.
///
/// Deliberately names the *physical thing that answered*, not the vector's
/// internal name. "Read from the shop's card terminal" is checkable by someone
/// standing at the counter; "Vector 2" is not.
class _DetectionLine extends StatelessWidget {
  const _DetectionLine({required this.vector, required this.hasMcc});

  final CaptureVector vector;
  final bool hasMcc;

  @override
  Widget build(BuildContext context) {
    final (icon, what, how) = switch (vector) {
      CaptureVector.nfc => (
          Icons.contactless_rounded,
          "Read from the shop's card terminal",
          'EMV tag 9F15',
        ),
      CaptureVector.qr => (
          Icons.qr_code_scanner_rounded,
          'Read from the QR code',
          'UPI mc / EMVCo tag 52',
        ),
      CaptureVector.intent => (
          Icons.open_in_new_rounded,
          "Read from the checkout's hand-off",
          'UPI intent mc',
        ),
      CaptureVector.link => (
          Icons.link_rounded,
          'Worked out from a payment link',
          'inferred — never verified',
        ),
      CaptureVector.graph => (
          Icons.hub_outlined,
          'Answered from what SWIP already knew',
          'merchant graph',
        ),
      CaptureVector.manual => (
          Icons.edit_outlined,
          'You told SWIP this',
          'from your statement',
        ),
      CaptureVector.probe => (
          Icons.badge_outlined,
          'Read from a declined authorisation',
          'SWIP Probe',
        ),
      CaptureVector.statement => (
          Icons.receipt_long_rounded,
          'Read from your bank statement',
          'what the acquirer actually posted',
        ),
    };

    return Row(
      children: [
        Icon(icon, size: 15, color: SwipColors.gold500),
        const SizedBox(width: SwipSpace.sm),
        Expanded(
          child: RichText(
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(children: [
              TextSpan(
                text: hasMcc ? what : what.replaceFirst('Read', 'Looked'),
                style:
                    SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
              ),
              TextSpan(
                text: '  ·  $how',
                style:
                    SwipType.bodyS.copyWith(color: SwipColors.textTertiary),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

/// A one-line coloured note. Green when the answer helps, amber when it warns.
class _Note extends StatelessWidget {
  const _Note({required this.text, required this.icon, required this.good});

  final String text;
  final IconData icon;
  final bool good;

  @override
  Widget build(BuildContext context) {
    final fg = good ? SwipConfidenceColors.verifiedOnInk : SwipColors.warningOnInk;
    return Container(
      padding: const EdgeInsets.all(SwipSpace.md),
      decoration: BoxDecoration(
        color: good ? SwipColors.successFill : SwipColors.warningFill,
        borderRadius: SwipRadius.inputAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: SwipSpace.sm),
          Expanded(
            child: Text(text, style: SwipType.bodyS.copyWith(color: fg)),
          ),
        ],
      ),
    );
  }
}
