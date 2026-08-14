import 'package:flutter/material.dart';

import '../../core/theme/swip_tokens.dart';
import 'goal_bar.dart';
import 'support_flow.dart';
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
///
/// `F-121`. The long version of this — the narration, the glossary — lives
/// behind the pull at the foot of the dashboard
/// (`features/support/support_story.dart`). This stays the short version, and
/// both open the same sheet through [openSupportSheet].
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
            // ── the story, short version ──
            //
            // Written as a statement of fact rather than an appeal, because the
            // difference between the two is whether the reader is being
            // informed or worked on. No adjectives about hardship, no "please",
            // no second person until the last line.
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

            const GoalBar(),
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
            const SizedBox(height: SwipSpace.md),
            Text(
              'The longer version — how it happened, and what P2M and P2PM '
              'mean for your card — is behind the pull at the foot of the home '
              'page.',
              style: SwipType.bodyS.copyWith(color: SwipColors.textTertiary),
            ),
          ],
        ),
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
                onTap: () => openSupportSheet(context, card: false),
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
                onTap: () => openSupportSheet(context, card: true),
              ),
            ),
        ],
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
