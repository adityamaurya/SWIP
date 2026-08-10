import 'package:flutter/material.dart';

import '../core/theme/swip_tokens.dart';
import '../core/utils/swip_time.dart';
import '../data/models/capture_event.dart';
import '../data/models/mcc.dart';
import 'mcc_badge.dart';

/// One ledger row.
///
/// ## The three columns
///
///   col 1  the MCC, large, with its confidence word directly beneath  (`F-73`)
///   col 2  the merchant, the category, and **where you were**         (`F-74`)
///   col 3  the time, with a tag saying how it was read                (`F-75`)
///
/// ## What was removed, and why
///
/// The row had grown a second language of its own: `NATIONAL`/`INTL` chips, a
/// `▣` glyph, a lightning bolt, the acquirer's name, and the word "Domestic".
/// Five signals, none of them legible without a legend, competing with the two
/// facts the row exists to carry.
///
///   * **`NATIONAL` / `INTL` chips** — where a code is *published* is a fact
///     about the code, not about your visit. It belongs on the MCC screen.
///   * **`▣` and the bolt** — a private glyph alphabet nobody was taught. The
///     vector is now a word: `SCAN`, `POS`, `LINK`.
///   * **"Domestic"** — true and useless. You know which country you are in.
///     The slot now carries the thing you actually search by: the place.
///   * **The acquirer ("Paytm")** — on a row it reads as the shop's name, which
///     is exactly the confusion `F-42` was about. It moved into the sheet,
///     under a label that says what it is.
class LedgerRow extends StatelessWidget {
  const LedgerRow({
    super.key,
    required this.event,
    required this.mcc,
    required this.timeFormat,
    this.captureCount,
    this.onTap,
    this.onTapMcc,
    this.onTapMerchant,
    this.onToggleTimeFormat,
    this.onLongPress,
  });

  final CaptureEvent event;

  /// Resolved definition. `null` when the code is not in the table — the row
  /// still renders, showing the digits and the ISO range.
  final Mcc? mcc;

  final TimeFormatPref timeFormat;

  final int? captureCount;

  /// `D-08` — every row is a hub.
  final VoidCallback? onTap; // -> the capture detail sheet
  final VoidCallback? onTapMcc; // -> S-06 MCC detail
  final VoidCallback? onTapMerchant; // -> S-07 merchant detail
  final VoidCallback? onToggleTimeFormat; // `D-07` toggle
  final VoidCallback? onLongPress;

  /// Above this text scale the three-column layout stops working and the row
  /// reflows to stacked. 1.3 is where the category starts clipping on a 360dp
  /// device, measured rather than guessed.
  static const _reflowScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    final stacked = scale >= _reflowScale;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: SwipSpace.lg, vertical: SwipSpace.md),
        child: stacked ? _stacked(context) : _columns(context),
      ),
    );
  }

  Widget _columns(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 62, child: _mccCell()),
          const SizedBox(width: SwipSpace.md),
          Expanded(child: _detailCell()),
          const SizedBox(width: SwipSpace.sm),
          SizedBox(width: 70, child: _timeCell()),
        ],
      );

  /// The large-text layout. `F-86`.
  ///
  /// Both cells are `Flexible`, and that is not decoration. This branch only
  /// runs above [_reflowScale], which is exactly where the MCC, the confidence
  /// word, the date, the time and the vector tag have all grown by 60 % — and
  /// two natural-width cells at that size do not fit side by side on a 360 dp
  /// phone. Without a flex factor the row overflowed and painted hazard stripes
  /// across the ledger for anyone with large text switched on: the readers who
  /// most needed the reflow were the only ones who saw it fail.
  Widget _stacked(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(child: _mccCell()),
              Flexible(child: _timeCell()),
            ],
          ),
          const SizedBox(height: SwipSpace.sm),
          _detailCell(),
        ],
      );

  /// `F-73`. The code, and immediately under it how much to trust it.
  ///
  /// Confidence used to sit in the third line of the middle column, next to
  /// four other things, where "Verified" read as a property of the *merchant*.
  /// It is a property of the **number**, so it lives with the number — smaller,
  /// directly beneath, the way a caption sits under a figure.
  Widget _mccCell() => GestureDetector(
        onTap: onTapMcc,
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            MccBadge(event.mcc, size: MccBadgeSize.lg),
            const SizedBox(height: 1),
            ConfidenceCaption(event.confidence),
          ],
        ),
      );

  /// `F-44`, and a reversal of `D-05`.
  ///
  /// The category used to lead and the merchant was a footnote. In the field
  /// that reads backwards: you are standing in front of a shop you can see, so
  /// the row's job is *"which visit was this"* first and *"what was it filed
  /// as"* second.
  Widget _detailCell() {
    final identity = event.identityLine;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1 ── who
        GestureDetector(
          onTap: onTapMerchant,
          behavior: HitTestBehavior.opaque,
          child: Text(
            identity ?? 'Unnamed merchant',
            style: SwipType.bodyM.copyWith(
              color: identity == null
                  ? SwipColors.textSecondary
                  : SwipColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 1),

        // 2 ── what kind of business, from the code
        Text(
          mcc?.displayName ?? event.categoryFallback,
          style: SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        // 3 ── `F-74`. Where you were standing.
        //
        // "Domestic" told you nothing you did not already know. The place is
        // how a person actually finds a past capture — *the Bandra one* — so
        // the slot goes to the neighbourhood and the city. Absent when location
        // is switched off, rather than filled with a placeholder.
        if (event.placeLabel != null) ...[
          const SizedBox(height: SwipSpace.xs),
          Row(
            children: [
              const Icon(Icons.place_outlined,
                  size: 12, color: SwipColors.textTertiary),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  event.placeLabel!,
                  style:
                      SwipType.bodyS.copyWith(color: SwipColors.textTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// `D-07`. Default: `08 Aug` over `4:12 PM`. Tap to switch the whole ledger
  /// to `2h ago`. Below it, `F-75`: how this capture was read.
  Widget _timeCell() {
    final cell = SwipTime.cell(event.capturedAt, timeFormat);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onToggleTimeFormat,
          behavior: HitTestBehavior.opaque,
          child: Semantics(
            label: SwipTime.full(event.capturedAt),
            excludeSemantics: true,
            button: onToggleTimeFormat != null,
            child: AnimatedSwitcher(
              duration: SwipMotion.micro,
              child: Column(
                key: ValueKey(timeFormat),
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    cell.primary,
                    style:
                        SwipType.label.copyWith(color: SwipColors.textPrimary),
                    maxLines: 1,
                    textAlign: TextAlign.right,
                  ),
                  if (cell.secondary != null)
                    Text(
                      cell.secondary!,
                      style: SwipType.bodyS
                          .copyWith(color: SwipColors.textSecondary),
                      maxLines: 1,
                      textAlign: TextAlign.right,
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: SwipSpace.xs),
        VectorTag(event.vector),
      ],
    );
  }
}

/// `F-75` — how the capture was read, as a word.
///
/// This replaces the `▣` / `⌁` / `🔗` glyphs and the lightning bolt. Those were
/// a private alphabet: correct, compact, and unreadable without being taught.
/// `SCAN` and `POS` need no legend, and the one thing a person asks of an old
/// row — *did I tap this or scan it?* — is answered without opening anything.
class VectorTag extends StatelessWidget {
  const VectorTag(this.vector, {super.key});

  final CaptureVector vector;

  /// Short enough to sit under a date column at any text scale.
  static String labelFor(CaptureVector v) => switch (v) {
        CaptureVector.qr => 'SCAN',
        CaptureVector.nfc => 'POS',
        CaptureVector.link => 'LINK',
        CaptureVector.intent => 'APP',
        CaptureVector.statement => 'BANK',
        CaptureVector.manual => 'TYPED',
        CaptureVector.graph => 'KNOWN',
        CaptureVector.probe => 'PROBE',
      };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          borderRadius: SwipRadius.chipAll,
          border: Border.all(color: SwipColors.hairline),
        ),
        child: Text(
          labelFor(vector),
          style: SwipType.labelS.copyWith(color: SwipColors.textTertiary),
          maxLines: 1,
          semanticsLabel: 'Read by ${vector.longLabel}',
        ),
      );
}
