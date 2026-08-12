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
    this.captureCount,
    this.onTap,
    this.onTapMcc,
    this.onTapMerchant,
    this.onLongPress,
  });

  final CaptureEvent event;

  /// Resolved definition. `null` when the code is not in the table — the row
  /// still renders, showing the digits and the ISO range.
  final Mcc? mcc;

  final int? captureCount;

  /// `D-08` — every row is a hub.
  final VoidCallback? onTap; // -> the capture detail sheet
  final VoidCallback? onTapMcc; // -> S-06 MCC detail
  final VoidCallback? onTapMerchant; // -> S-07 merchant detail
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

  /// `F-91`. The MCC column is 76, not 62.
  ///
  /// Four digits of `SwipType.mcc` at 26 px are about 66 px wide with tabular
  /// figures, so 62 clipped the last digit into the merchant name beside it —
  /// which is the one thing `D-04` says must never happen. 76 fits the digits
  /// and the word "Verified" beneath them with room to spare, and the gap after
  /// it is widened so the number can never touch the name even mid-animation.
  static const _mccColumn = 76.0;
  static const _timeColumn = 76.0;

  Widget _columns(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: _mccColumn, child: _mccCell()),
          const SizedBox(width: SwipSpace.lg),
          Expanded(child: _detailCell()),
          const SizedBox(width: SwipSpace.sm),
          SizedBox(width: _timeColumn, child: _timeCell()),
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
  ///
  /// `F-90`. **The gesture detector is only attached when there is somewhere to
  /// go.** It used to be unconditional and `opaque`, and no caller ever passed
  /// [onTapMcc] — so the MCC swallowed every tap that landed on it and the
  /// detail sheet never opened. The largest, most obviously tappable thing in
  /// the row was the one dead spot in it.
  Widget _mccCell() {
    final cell = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // `F-103`. Nothing under the number.
        //
        // "Verified" was the last survivor of a confidence system that had
        // already lost "Likely" and "Unknown", and on a row where every code is
        // read from a real payment it said the same thing on every single line.
        // A label that never varies is not information, it is a watermark. The
        // provenance that *does* vary is the route tag in the third column, and
        // the full confidence picture is one tap away in the sheet.
        MccBadge(event.mcc, size: MccBadgeSize.lg),
      ],
    );

    if (onTapMcc == null) return cell;
    return GestureDetector(
      onTap: onTapMcc,
      behavior: HitTestBehavior.opaque,
      child: cell,
    );
  }

  /// `F-44`, and a reversal of `D-05`.
  ///
  /// The category used to lead and the merchant was a footnote. In the field
  /// that reads backwards: you are standing in front of a shop you can see, so
  /// the row's job is *"which visit was this"* first and *"what was it filed
  /// as"* second.
  Widget _merchantText(String? identity) => Text(
        identity ?? 'Unnamed merchant',
        style: SwipType.bodyM.copyWith(
          color: identity == null
              ? SwipColors.textSecondary
              : SwipColors.textPrimary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );

  Widget _detailCell() {
    final identity = event.identityLine;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1 ── who
        //
        // `F-90` again: wrapped only when there is a destination. An opaque
        // gesture detector with a null callback is a hole in the row.
        if (onTapMerchant != null)
          GestureDetector(
            onTap: onTapMerchant,
            behavior: HitTestBehavior.opaque,
            child: _merchantText(identity),
          )
        else
          _merchantText(identity),
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

  /// The date, the time, and how the capture was read.
  ///
  /// `F-92`. **No more tap-to-toggle.** `D-07` let a tap swap the whole ledger
  /// between `08 Aug / 4:12 PM` and `53 mins ago`. Two problems: a row is a
  /// record, and a record that rewrites itself when brushed is unsettling; and
  /// the relative form loses the very thing you scan a ledger for, which is
  /// *when* — "53 mins ago" is useless the moment you come back tomorrow.
  ///
  /// So the date and the time are simply shown, always, and the tap the cell
  /// used to eat now reaches the row and opens the capture.
  Widget _timeCell() {
    final cell = SwipTime.cell(event.capturedAt, TimeFormatPref.absolute);

    return Semantics(
      label: SwipTime.full(event.capturedAt),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            cell.primary,
            style: SwipType.label.copyWith(color: SwipColors.textPrimary),
            maxLines: 1,
            textAlign: TextAlign.right,
          ),
          if (cell.secondary != null)
            Text(
              cell.secondary!,
              style:
                  SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
              maxLines: 1,
              textAlign: TextAlign.right,
            ),
          const SizedBox(height: SwipSpace.xs),
          VectorTag(event.vector),
        ],
      ),
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

  /// `F-102` — **three routes, two lines each.**
  ///
  /// `QR SCAN`, `POS TAP` and `APP DIRECT` were right but too wide: set on one
  /// line they squeezed the date column and ellipsised on a narrow phone. Split
  /// over two lines they take the width of the longest single word instead of
  /// the whole phrase, which is how a column label is supposed to behave.
  ///
  ///     QR        NFC        APP
  ///     SCAN      POS      REDIRECT
  ///
  /// `KNOWN` is gone from the ledger entirely. It was never a route — see
  /// `F-87`, where the vector was being overwritten whenever the digits came
  /// from memory. Any row still carrying it renders as the route it was
  /// captured by is no longer recoverable, so it reads as a dash rather than
  /// inventing one.
  static List<String> linesFor(CaptureVector v) => switch (v) {
        CaptureVector.qr => const ['QR', 'SCAN'],
        CaptureVector.nfc => const ['NFC', 'POS'],
        CaptureVector.intent => const ['APP', 'REDIRECT'],
        CaptureVector.statement => const ['BANK', 'LINE'],
        // Retired vectors. Rows captured before they were removed still exist
        // in people's ledgers, so they must still render something truthful.
        CaptureVector.link => const ['LINK'],
        CaptureVector.manual => const ['TYPED'],
        CaptureVector.graph => const ['-'],
        CaptureVector.probe => const ['PROBE'],
      };

  /// Single-line form, for the filter chips where width is not constrained.
  static String labelFor(CaptureVector v) => linesFor(v).join(' ');

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          borderRadius: SwipRadius.chipAll,
          border: Border.all(color: SwipColors.hairline),
        ),
        child: Semantics(
          label: 'Read by ${vector.longLabel}',
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final line in linesFor(vector))
                Text(
                  line,
                  style: SwipType.labelS.copyWith(
                    color: SwipColors.textTertiary,
                    height: 1.15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
            ],
          ),
        ),
      );
}
