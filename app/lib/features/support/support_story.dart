import 'package:flutter/material.dart';

import '../../core/theme/swip_tokens.dart';
import 'goal_bar.dart';
import 'support_flow.dart';
import 'support_goal.dart';

/// `F-121` — what is behind the pull on the dashboard.
///
/// ## Why this is a story and not a donate button
///
/// The thing being asked for is money, and there are exactly two honest ways to
/// ask. One is a button that says "donate", which is a transaction. The other is
/// to say what happened, in order, and let the reader decide — which is what
/// this is.
///
/// It is placed **behind a pull at the foot of the home page**, which is the
/// least prominent position in the app. Somebody who never pulls never reads a
/// word of it. That is deliberate and it is the whole design: a request that
/// arrives uninvited is a solicitation; one you had to go looking for is a
/// disclosure.
///
/// ## The narration
///
/// Three scenes, each behind a gold margin rule, in the order the thing
/// happened: the trap, the commute, the app. Then the numbers, then the two
/// words that decide whether a card pays you back — because a person reading
/// this in an MCC app should leave knowing something useful even if they close
/// it without paying anything.
///
/// No adjectives about hardship. No "please". No second person until the end.
class SupportStory extends StatelessWidget {
  const SupportStory({super.key, required this.count});

  /// How many codes this phone has read. Used for one line, and only when it is
  /// not zero — congratulating someone on nothing is worse than silence.
  final int count;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            SwipSpace.gutter, SwipSpace.xl, SwipSpace.gutter, 0),
        child: Container(
          decoration: BoxDecoration(
            color: SwipColors.surfaceRaised,
            borderRadius: SwipRadius.cardAll,
            border: Border.all(color: SwipColors.gold900),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── the title plate ──
              //
              // A thin foil band across the top, so the panel announces itself
              // as the one gold thing on a page that is otherwise grey.
              Container(
                height: 3,
                width: double.infinity,
                decoration:
                    const BoxDecoration(gradient: SwipGradients.foil),
              ),
              Padding(
                padding: const EdgeInsets.all(SwipSpace.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded,
                            size: 15, color: SwipColors.gold500),
                        const SizedBox(width: SwipSpace.sm),
                        Expanded(
                          child: Text(
                            'THE PART NOBODY READS',
                            style: SwipType.labelS
                                .copyWith(color: SwipColors.gold300),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: SwipSpace.lg),
                    Text(
                      'Why this app exists',
                      style: SwipType.titleM
                          .copyWith(color: SwipColors.textPrimary),
                    ),
                    const SizedBox(height: SwipSpace.lg),

                    // ── the three scenes ──
                    const _Scene(
                      'For years I paid the wrong card at the right shop. Not '
                      'once — as a habit. About ₹39 lakh passed through my '
                      'hands over that time and none of it stayed, because '
                      'every rupee went out on whichever card was nearest and '
                      'came back on whichever one was cheapest. Which was '
                      'never the same card.',
                    ),
                    const _Scene(
                      'What is left to clear is about ₹13.5 lakh. It is being '
                      'paid down from a salary, on time, every month. That is '
                      'the number the first marker on the bar below is.',
                    ),
                    const _Scene(
                      'SWIP was written on a four-hour daily commute between '
                      'Thane and work, on a phone, in the gaps. It is the '
                      'thing I wish someone had handed me at the start: the '
                      'category, shown before the payment, so the right card '
                      'gets used the first time.',
                      last: true,
                    ),

                    if (count > 0) ...[
                      const SizedBox(height: SwipSpace.sm),
                      Text(
                        'You have read $count '
                        '${count == 1 ? "code" : "codes"} with it. Every one '
                        'of those was a decision made with the number in front '
                        'of you instead of a month later on a statement.',
                        style: SwipType.bodyM
                            .copyWith(color: SwipColors.textPrimary),
                      ),
                    ],

                    const SizedBox(height: SwipSpace.xxl),
                    const Divider(height: 1, color: SwipColors.hairline),
                    const SizedBox(height: SwipSpace.xxl),

                    // ── the numbers ──
                    Text('THE ROAD',
                        style: SwipType.labelS
                            .copyWith(color: SwipColors.textTertiary)),
                    const SizedBox(height: SwipSpace.md),
                    const GoalBar(),

                    const SizedBox(height: SwipSpace.xxl),
                    const Divider(height: 1, color: SwipColors.hairline),
                    const SizedBox(height: SwipSpace.xxl),

                    // ── the useful bit ──
                    const _Glossary(),

                    const SizedBox(height: SwipSpace.xxl),

                    // ── the two ways ──
                    if (SupportGoal.isConfigured)
                      const _Ways()
                    else
                      const _NotYet(),

                    const SizedBox(height: SwipSpace.lg),
                    Text(
                      'A contribution buys nothing. No feature changes, '
                      'nothing is unlocked, and no part of SWIP is behind it. '
                      'SWIP shows you its own category code before it takes a '
                      'rupee, the same way it does for every shop.',
                      style: SwipType.bodyS
                          .copyWith(color: SwipColors.textTertiary),
                    ),
                    const SizedBox(height: SwipSpace.lg),
                    Row(
                      children: [
                        const Icon(Icons.favorite_rounded,
                            size: 13, color: SwipColors.gold500),
                        const SizedBox(width: SwipSpace.sm),
                        Text('a.r.my.',
                            style: SwipType.label
                                .copyWith(color: SwipColors.gold300)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// One paragraph of the narration, behind a gold margin rule.
///
/// The rule is what makes three paragraphs read as *scenes* rather than as a
/// block of apology. It is 2px and gold at low alpha — enough to group, not
/// enough to become a quote block.
class _Scene extends StatelessWidget {
  const _Scene(this.text, {this.last = false});

  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : SwipSpace.lg),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 2,
                decoration: BoxDecoration(
                  color: SwipColors.gold700,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
              const SizedBox(width: SwipSpace.md),
              Expanded(
                child: Text(
                  text,
                  style: SwipType.bodyM
                      .copyWith(color: SwipColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      );
}

/// `F-121` — the two words that decide whether your card pays you back.
///
/// This is in the donation panel on purpose. Somebody who pulled this open is
/// reading about money; the most valuable thing to hand them is not the goal
/// bar, it is the reason a UPI payment sometimes earns nothing at all no matter
/// which card they pick.
///
/// Sourced from `docs/22-FEEDBACK-ROUND-3.md` and NPCI's operating circular for
/// RuPay credit cards on UPI.
class _Glossary extends StatelessWidget {
  const _Glossary();

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('WHILE YOU ARE HERE',
              style:
                  SwipType.labelS.copyWith(color: SwipColors.textTertiary)),
          const SizedBox(height: SwipSpace.md),
          Text(
            'Two letters on a QR sticker decide whether any card can reward '
            'you at that shop.',
            style: SwipType.bodyM.copyWith(color: SwipColors.textPrimary),
          ),
          const SizedBox(height: SwipSpace.lg),
          const _Term(
            term: 'P2M',
            expansion: 'Person to Merchant',
            body: 'A registered business account. It has a category code, so '
                'your card knows what it is paying and pays back accordingly. '
                'A credit card on UPI works here.',
          ),
          const _Term(
            term: 'P2PM',
            expansion: 'Person to Person-Merchant',
            body: 'The small-merchant tier — the tea stall, the vegetable '
                'cart. There is no category code at all, and NPCI does not '
                'permit a credit card on UPI at these. Bank account only, and '
                'no reward from any card. SWIP says so instead of showing you '
                'a blank.',
          ),
          const _Term(
            term: 'PPI',
            expansion: 'Prepaid Payment Instrument',
            body: 'A wallet balance. Paying a merchant from one above ₹2,000 '
                'carries a small interchange — paid by the merchant, never by '
                'you.',
          ),
          const _Term(
            term: 'CC on UPI',
            expansion: 'Credit card, linked to UPI',
            body: 'Only RuPay credit cards can be linked. The reward still '
                'follows the merchant category, which is the number SWIP '
                'exists to show you first.',
            last: true,
          ),
        ],
      );
}

class _Term extends StatelessWidget {
  const _Term({
    required this.term,
    required this.expansion,
    required this.body,
    this.last = false,
  });

  final String term;
  final String expansion;
  final String body;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : SwipSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // `F-84`. Never a fixed-width label column here: `CC on UPI` at
            // 1.6x text scale is wider than the phone, and a Row with a rigid
            // first cell is how that becomes an overflow stripe.
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: SwipSpace.sm,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: SwipSpace.sm, vertical: 3),
                  decoration: BoxDecoration(
                    color: SwipColors.gold900,
                    borderRadius: SwipRadius.chipAll,
                  ),
                  child: Text(term,
                      style: SwipType.labelS
                          .copyWith(color: SwipColors.gold300)),
                ),
                Text(expansion,
                    style: SwipType.bodyS
                        .copyWith(color: SwipColors.textTertiary)),
              ],
            ),
            const SizedBox(height: SwipSpace.sm),
            Text(body,
                style:
                    SwipType.bodyS.copyWith(color: SwipColors.textSecondary)),
          ],
        ),
      );
}

/// The two ways to help. Stacked rather than side by side, because each one
/// carries a sentence and two 40 %-width cards cannot hold a sentence.
class _Ways extends StatelessWidget {
  const _Ways();

  @override
  Widget build(BuildContext context) => Column(
        children: [
          if (SupportGoal.hasCard) ...[
            _Way(
              icon: Icons.credit_card_rounded,
              title: 'Donate by card, and get rewarded',
              // Accurate, and worth being precise about: the reward is the
              // donor's own card benefit on a category they can check first.
              // Nothing is returned to them by SWIP.
              body: 'It posts under ${SupportGoal.ownMcc}. If one of your '
                  'cards pays back on software or online spend, this is a '
                  'category it earns on — check it first, the way SWIP would '
                  'have you check any shop.',
              onTap: () => openSupportSheet(context, card: true),
            ),
            if (SupportGoal.hasUpi) const SizedBox(height: SwipSpace.md),
          ],
          if (SupportGoal.hasUpi)
            _Way(
              icon: Icons.account_balance_wallet_rounded,
              title: 'Donate by UPI',
              body: SupportGoal.upiId,
              mono: true,
              onTap: () => openSupportSheet(context, card: false),
            ),
        ],
      );
}

class _Way extends StatelessWidget {
  const _Way({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.mono = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  final bool mono;

  @override
  Widget build(BuildContext context) => Material(
        color: SwipColors.surfaceRaised2,
        borderRadius: SwipRadius.cardAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: SwipRadius.cardAll,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(SwipSpace.lg),
            decoration: BoxDecoration(
              borderRadius: SwipRadius.cardAll,
              border: Border.all(color: SwipColors.gold900),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: SwipColors.gold500),
                    const SizedBox(width: SwipSpace.md),
                    Expanded(
                      child: Text(title,
                          style: SwipType.titleS
                              .copyWith(color: SwipColors.textPrimary)),
                    ),
                    const Icon(Icons.arrow_forward_rounded,
                        size: 16, color: SwipColors.textTertiary),
                  ],
                ),
                const SizedBox(height: SwipSpace.sm),
                Text(
                  body,
                  style: (mono ? SwipType.mono : SwipType.bodyS).copyWith(
                    color: mono
                        ? SwipColors.gold300
                        : SwipColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// While the links are not set. Says which one is missing rather than pretending
/// the section is not there — a disabled thing with no explanation reads as a
/// bug, and this one is just unfinished.
class _NotYet extends StatelessWidget {
  const _NotYet();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(SwipSpace.lg),
        decoration: BoxDecoration(
          color: SwipColors.surfaceRaised2,
          borderRadius: SwipRadius.cardAll,
          border: Border.all(color: SwipColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Not switched on yet',
                style: SwipType.label.copyWith(color: SwipColors.textPrimary)),
            const SizedBox(height: SwipSpace.xs),
            Text(
              'The UPI ID and the card payment page are not set, so there is '
              'nothing here to tap. The story stands on its own until they '
              'are.',
              style: SwipType.bodyS.copyWith(color: SwipColors.textTertiary),
            ),
          ],
        ),
      );
}
