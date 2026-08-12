import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/swip_tokens.dart';
import 'support_goal.dart';

/// `F-111` — the support section at the foot of Settings.
///
/// ## The rule this is built to
///
/// Nothing is unlocked, nothing is removed, nothing is promised. Not for
/// squeamishness — it is the whole tax position. A contribution that buys the
/// donor something is a *supply* and carries GST; a contribution that buys them
/// nothing is a gift and is outside GST entirely. See `docs/27-DONATIONS.md`.
///
/// So the copy is the compliance, and it is written accordingly: no "supporter"
/// tier, no badge, no removal of anything, no thanks-in-the-app that could be
/// read as advertising the donor.
///
/// ## Collapsed by default, and quiet
///
/// It sits below the colophon, closed, as one row. A person who never opens it
/// never reads a word of it. That is deliberate: the difference between a
/// section someone discovers and a section someone is subjected to is entirely
/// whether it was already open.
class SupportSection extends StatefulWidget {
  const SupportSection({super.key});

  @override
  State<SupportSection> createState() => _SupportSectionState();
}

class _SupportSectionState extends State<SupportSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: SwipSpace.xxl),
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: SwipSpace.gutter, vertical: SwipSpace.md),
              child: Row(
                children: [
                  const Icon(Icons.volunteer_activism_outlined,
                      size: 18, color: SwipColors.textSecondary),
                  const SizedBox(width: SwipSpace.md),
                  Expanded(
                    child: Text('Help me if you wish to',
                        style: SwipType.label
                            .copyWith(color: SwipColors.textSecondary)),
                  ),
                  AnimatedRotation(
                    turns: _open ? .5 : 0,
                    duration: SwipMotion.standard,
                    child: const Icon(Icons.expand_more_rounded,
                        size: 20, color: SwipColors.textTertiary),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: _open
                ? const _SupportBody()
                : const SizedBox(width: double.infinity),
          ),
        ],
      );
}

class _SupportBody extends StatelessWidget {
  const _SupportBody();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            SwipSpace.gutter, 0, SwipSpace.gutter, SwipSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── the story ──
            //
            // Four lines. Written as a statement of fact rather than an appeal,
            // because the difference between the two is whether the reader is
            // being informed or worked on. No adjectives about hardship, no
            // "please", no second person until the last line.
            Text(
              'Why this app exists',
              style: SwipType.titleS.copyWith(color: SwipColors.textPrimary),
            ),
            const SizedBox(height: SwipSpace.sm),
            Text(
              'I spent years in a credit card and personal loan trap. Around '
              '₹39 lakh came in over that time and none of it stayed. What is '
              'left to clear is about ₹13.5 lakh, and I am paying it down from '
              'a salary while building this on a four-hour daily commute.\n\n'
              'SWIP is the thing I wish I had had: the category shown before '
              'the payment, so the right card gets used. It is free, it has no '
              'account, and nothing leaves your phone.',
              style: SwipType.bodyM.copyWith(color: SwipColors.textSecondary),
            ),
            const SizedBox(height: SwipSpace.xl),

            const _GoalBar(),
            const SizedBox(height: SwipSpace.xl),

            if (SupportGoal.isConfigured)
              const _PayRow()
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(SwipSpace.md),
                decoration: BoxDecoration(
                  color: SwipColors.surfaceRaised,
                  borderRadius: SwipRadius.inputAll,
                  border: Border.all(color: SwipColors.hairline),
                ),
                child: Text(
                  'Not switched on yet. The payment links are not set.',
                  style:
                      SwipType.bodyS.copyWith(color: SwipColors.textTertiary),
                ),
              ),

            const SizedBox(height: SwipSpace.md),
            Text(
              'A contribution buys nothing. No feature changes, nothing is '
              'unlocked, and no part of SWIP is behind it. A receipt is '
              'generated either way.',
              style: SwipType.bodyS.copyWith(color: SwipColors.textTertiary),
            ),
          ],
        ),
      );
}

/// The progress bar. Two segments, one milestone dot.
///
/// The milestone is drawn as a notch *on* the track rather than a second bar,
/// because the two figures are not two separate goals — the first is the part
/// that is urgent and the second is the part that is long.
class _GoalBar extends StatelessWidget {
  const _GoalBar();

  static String _lakh(int rupees) {
    final l = rupees / 100000;
    return '₹${l.toStringAsFixed(l >= 10 ? 1 : 2)} lakh';
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              return SizedBox(
                height: 26,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    // the track
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: SwipColors.surfaceRaised2,
                        borderRadius: SwipRadius.pillAll,
                      ),
                    ),
                    // what has come in
                    if (SupportGoal.raisedFraction > 0)
                      Container(
                        height: 8,
                        width: w * SupportGoal.raisedFraction,
                        decoration: BoxDecoration(
                          color: SwipColors.gold500,
                          borderRadius: SwipRadius.pillAll,
                        ),
                      ),
                    // the milestone notch
                    Positioned(
                      left: (w * SupportGoal.milestoneFraction) - 5,
                      child: Container(
                        width: 10,
                        height: 20,
                        decoration: BoxDecoration(
                          color: SwipColors.gold300,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: SwipColors.bg, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: SwipSpace.sm),
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(
                color: SwipColors.gold300, shape: BoxShape.circle)),
              const SizedBox(width: SwipSpace.sm),
              Expanded(
                child: Text(
                  'First: clear ${_lakh(SupportGoal.milestone)} of debt',
                  style:
                      SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: SwipSpace.xs),
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(
                color: SwipColors.surfaceRaised2, shape: BoxShape.circle,
                border: Border.all(color: SwipColors.hairline))),
              const SizedBox(width: SwipSpace.sm),
              Expanded(
                child: Text(
                  'Then: earn back ${_lakh(SupportGoal.stretch)}',
                  style:
                      SwipType.bodyS.copyWith(color: SwipColors.textTertiary),
                ),
              ),
            ],
          ),
        ],
      );
}

/// The two ways to help.
class _PayRow extends StatelessWidget {
  const _PayRow();

  @override
  Widget build(BuildContext context) => Row(
        children: [
          if (SupportGoal.hasUpi)
            Expanded(
              child: _PayTile(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Pay by UPI',
                sub: 'Any UPI app',
                onTap: () => _start(context, card: false),
              ),
            ),
          if (SupportGoal.hasUpi && SupportGoal.hasCard)
            const SizedBox(width: SwipSpace.md),
          if (SupportGoal.hasCard)
            Expanded(
              child: _PayTile(
                icon: Icons.credit_card_outlined,
                label: 'Pay by card',
                sub: 'Earn your own cashback',
                onTap: () => _start(context, card: true),
              ),
            ),
        ],
      );

  Future<void> _start(BuildContext context, {required bool card}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: SwipColors.surfaceRaised,
        builder: (_) => _OwnMccSheet(card: card),
      );
}

class _PayTile extends StatelessWidget {
  const _PayTile({
    required this.icon,
    required this.label,
    required this.sub,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: SwipColors.surface,
        borderRadius: SwipRadius.cardAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: SwipRadius.cardAll,
          child: Container(
            height: 92,
            padding: const EdgeInsets.symmetric(horizontal: SwipSpace.sm),
            decoration: BoxDecoration(
              borderRadius: SwipRadius.cardAll,
              border: Border.all(color: SwipColors.hairline),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 24, color: SwipColors.gold500),
                  const SizedBox(height: SwipSpace.sm),
                  Text(label,
                      style: SwipType.label
                          .copyWith(color: SwipColors.textPrimary)),
                  Text(sub,
                      style: SwipType.labelS
                          .copyWith(color: SwipColors.textTertiary)),
                ],
              ),
            ),
          ),
        ),
      );
}

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
    await _receipt(context, amount: _amount, card: widget.card);
  }

  @override
  Widget build(BuildContext context) {
    const mcc = SupportGoal.ownMccName;

    return SafeArea(
      child: Padding(
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
              Text('AMOUNT',
                  style: SwipType.labelS
                      .copyWith(color: SwipColors.textTertiary)),
              const SizedBox(height: SwipSpace.sm),
              Row(
                children: [
                  for (final a in SupportGoal.suggested) ...[
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
                    const SizedBox(width: SwipSpace.sm),
                  ],
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

/// The receipt. Deliberately a **receipt** and not a tax invoice.
///
/// A tax invoice asserts a taxable supply, needs a GSTIN and a sequential
/// series, and issuing one for a gift would claim the opposite of what the
/// no-GST position rests on. See `docs/27-DONATIONS.md` §2.5.
///
/// The last line is the load-bearing one: *nothing was supplied in return*. That
/// sentence is the evidence this was a gift.
Future<void> _receipt(BuildContext context,
    {required int amount, required bool card}) async {
  final now = DateTime.now();
  final ref = 'SWIP-${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
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
                    onPressed: () => Clipboard.setData(
                        ClipboardData(text: text)),
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
