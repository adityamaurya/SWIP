import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/swip_tokens.dart';
import 'support_goal.dart';

/// `F-111`, `F-121` — the contribution flow, in one place.
///
/// It lived inside the Settings section until the dashboard grew its own
/// support panel behind the pull. Two entry points opening two copies of the
/// same sheet is how a receipt ends up saying one thing in one place and
/// another somewhere else, so both now call [openSupportSheet].
Future<void> openSupportSheet(BuildContext context, {required bool card}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SwipColors.surfaceRaised,
      shape: const RoundedRectangleBorder(borderRadius: SwipRadius.sheetTop),
      builder: (_) => _OwnMccSheet(card: card),
    );

/// `F-111` — **SWIP shows its own MCC before it takes a rupee.**
///
/// The app doing to itself exactly what it does to every other merchant: here is
/// the category this payment will post under, here is what your card earns on
/// it, decide. It is the only honest version of a donation screen in an app
/// whose entire premise is that you should know this before you pay.
///
/// Then a countdown, because a hand-off that happens without warning feels like
/// a hijack, and one that waits for a second tap feels like a nag. Ten seconds
/// with a visible timer and a skip is neither.
class _OwnMccSheet extends StatefulWidget {
  const _OwnMccSheet({required this.card});
  final bool card;

  @override
  State<_OwnMccSheet> createState() => _OwnMccSheetState();
}

class _OwnMccSheetState extends State<_OwnMccSheet> {
  static const _seconds = 10;
  int _left = _seconds;
  Timer? _tick;
  int _amount = SupportGoal.suggested[1];

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _left--);
      if (_left <= 0) {
        t.cancel();
        _go();
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _go() async {
    _tick?.cancel();
    final target = widget.card
        ? SupportGoal.razorpayLink
        : 'upi://pay?pa=${SupportGoal.upiId}'
            '&pn=${Uri.encodeComponent(SupportGoal.ownName)}'
            '&am=$_amount&cu=INR'
            '&tn=${Uri.encodeComponent('SWIP - voluntary contribution')}';

    // Handed to Android through the same channel the app already owns, so there
    // is no new dependency for one intent.
    await const MethodChannel('in.swip.app/nfc')
        .invokeMethod<void>('openExternal', {'uri': target})
        .catchError((_) {});

    if (!mounted) return;
    Navigator.of(context).pop();
    await showContributionReceipt(context,
        amount: _amount, card: widget.card);
  }

  @override
  Widget build(BuildContext context) {
    const mcc = SupportGoal.ownMccName;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SwipSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SWIP, READ BY SWIP',
                style:
                    SwipType.labelS.copyWith(color: SwipColors.textTertiary)),
            const SizedBox(height: SwipSpace.lg),
            Text(SupportGoal.ownMcc,
                style: SwipType.mcc
                    .copyWith(fontSize: 52, color: SwipColors.gold500)),
            const SizedBox(height: SwipSpace.xs),
            Text(mcc,
                style:
                    SwipType.bodyL.copyWith(color: SwipColors.textPrimary)),
            const SizedBox(height: SwipSpace.md),
            Text(
              'That is the category this contribution posts under. Check it '
              'against your cards the way you would for any other shop - if one '
              'of them pays back on software or online spend, use that one.',
              style: SwipType.bodyM.copyWith(color: SwipColors.textSecondary),
            ),

            const SizedBox(height: SwipSpace.xl),
            if (!widget.card) ...[
              // `F-121`. The VPA, on screen, before the hand-off — because a
              // UPI intent that opens someone else's app with a pre-filled
              // payee is exactly the shape of a scam, and the only difference
              // is whether you were shown the payee first.
              if (SupportGoal.hasUpi) ...[
                _CopyRow(
                  label: 'UPI ID',
                  value: SupportGoal.upiId,
                ),
                const SizedBox(height: SwipSpace.lg),
              ],
              Text('AMOUNT',
                  style: SwipType.labelS
                      .copyWith(color: SwipColors.textTertiary)),
              const SizedBox(height: SwipSpace.sm),
              Wrap(
                spacing: SwipSpace.sm,
                runSpacing: SwipSpace.sm,
                children: [
                  for (final a in SupportGoal.suggested)
                    ChoiceChip(
                      label: Text('₹$a'),
                      selected: _amount == a,
                      onSelected: (_) => setState(() => _amount = a),
                      showCheckmark: false,
                      backgroundColor: SwipColors.surfaceRaised2,
                      selectedColor: SwipColors.gold900,
                      side: BorderSide(
                          color: _amount == a
                              ? SwipColors.gold700
                              : SwipColors.hairline),
                      labelStyle: SwipType.label.copyWith(
                        color: _amount == a
                            ? SwipColors.gold300
                            : SwipColors.textSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: SwipSpace.xl),
            ],

            Row(
              children: [
                Expanded(
                  child: Text(
                    'Opening in $_left…',
                    style: SwipType.bodyS
                        .copyWith(color: SwipColors.textTertiary),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _tick?.cancel();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Not now'),
                ),
                const SizedBox(width: SwipSpace.sm),
                FilledButton(
                  onPressed: _go,
                  child: const Text('Continue now'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A value you can read and copy. Used for the VPA.
class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: SwipType.labelS.copyWith(color: SwipColors.textTertiary)),
          const SizedBox(height: SwipSpace.sm),
          InkWell(
            borderRadius: SwipRadius.inputAll,
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              HapticFeedback.selectionClick();
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                const SnackBar(content: Text('Copied')),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: SwipSpace.md, vertical: SwipSpace.md),
              decoration: BoxDecoration(
                color: SwipColors.surfaceRaised2,
                borderRadius: SwipRadius.inputAll,
                border: Border.all(color: SwipColors.hairline),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: SwipType.mono
                          .copyWith(color: SwipColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: SwipSpace.sm),
                  const Icon(Icons.copy_rounded,
                      size: 16, color: SwipColors.textTertiary),
                ],
              ),
            ),
          ),
        ],
      );
}

/// The receipt. Deliberately a **receipt** and not a tax invoice.
///
/// A tax invoice asserts a taxable supply, needs a GSTIN and a sequential
/// series, and issuing one for a gift would claim the opposite of what the
/// no-GST position rests on. See `docs/27-DONATIONS.md` §2.5.
///
/// The last line is the load-bearing one: *nothing was supplied in return*. That
/// sentence is the evidence this was a gift.
Future<void> showContributionReceipt(BuildContext context,
    {required int amount, required bool card}) async {
  final now = DateTime.now();
  final ref =
      'SWIP-${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
  final text = '''
SWIP - CONTRIBUTION RECEIPT

Reference     $ref
Date          ${now.toLocal().toString().split('.').first}
Amount        ${card ? 'as entered on the payment page' : '₹$amount'}
Method        ${card ? 'Card, via Razorpay payment page' : 'UPI'}
Category      ${SupportGoal.ownMcc} - ${SupportGoal.ownMccName}

This is a voluntary contribution. No goods or services were supplied in
return, no feature of SWIP was unlocked by it, and nothing in the app is
withheld from anyone who does not contribute.

This is a receipt, not a tax invoice.
''';

  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SwipColors.surfaceRaised,
    shape: const RoundedRectangleBorder(borderRadius: SwipRadius.sheetTop),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(SwipSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.receipt_long_rounded,
                size: 30, color: SwipColors.gold500),
            const SizedBox(height: SwipSpace.lg),
            Text('Thank you',
                style:
                    SwipType.titleM.copyWith(color: SwipColors.textPrimary)),
            const SizedBox(height: SwipSpace.sm),
            Text(
              'Reference $ref. Keep it if you want a record - SWIP does not '
              'store it, because SWIP has nowhere to store it.',
              style: SwipType.bodyM.copyWith(color: SwipColors.textSecondary),
            ),
            const SizedBox(height: SwipSpace.xl),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: text)),
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: SwipSpace.md),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () =>
                        Share.share(text, subject: 'SWIP receipt $ref'),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Save'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SwipSpace.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
