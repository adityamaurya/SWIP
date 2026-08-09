import 'package:flutter/material.dart';

import '../core/settings/home_market.dart';
import '../core/theme/swip_tokens.dart';
import '../core/utils/swip_time.dart';
import '../data/models/capture_event.dart';
import '../data/models/mcc.dart';
import 'mcc_badge.dart';

/// One ledger row.
///
/// Implements ideation `D-04`–`D-10` exactly:
///
///   col 1  the MCC              — never truncated, fixed width  (`D-04`, `D-10`)
///   col 2  detailed category    — 2 lines max                   (`D-05`)
///          publication chips    — NATIONAL / INTL / RUPAY       (`D-05`)
///          confidence + merchant + vector
///   col 3  the time cell        — day+date+month over time      (`D-07`)
///
/// Everything that must give, gives in the merchant string. The MCC and the
/// category never do — those are the "primary" that you said must always be
/// visible.
class LedgerRow extends StatelessWidget {
  const LedgerRow({
    super.key,
    required this.event,
    required this.mcc,
    required this.timeFormat,
    this.verdict,
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

  /// `F-16` — domestic or international, decided by the caller against the
  /// user's home market. `null` when the capture carried no country.
  final MarketVerdict? verdict;

  final int? captureCount;

  /// `D-08` — every row is a hub. Three separate destinations from one row.
  final VoidCallback? onTap; // -> S-05 capture detail
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
          SizedBox(width: 56, child: _mccCell()),
          const SizedBox(width: SwipSpace.md),
          Expanded(child: _detailCell()),
          const SizedBox(width: SwipSpace.sm),
          SizedBox(width: 64, child: _timeCell()),
        ],
      );

  Widget _stacked(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_mccCell(), _timeCell(alignEnd: true)],
          ),
          const SizedBox(height: SwipSpace.sm),
          _detailCell(),
        ],
      );

  Widget _mccCell() => GestureDetector(
        onTap: onTapMcc,
        behavior: HitTestBehavior.opaque,
        child: MccBadge(event.mcc),
      );

  /// `F-44`, and a reversal of `D-05`.
  ///
  /// The category used to lead and the merchant was a footnote. In the field
  /// that reads backwards: you are standing in front of a shop you can see, so
  /// the row's job is *"which visit was this"* first and *"what was it filed
  /// as"* second. Line 1 is therefore the merchant — its registered name, or
  /// the payee handle when the code carried no trustworthy name — and line 2 is
  /// the category the code resolves to.
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

        if (mcc != null && mcc!.publications.isNotEmpty) ...[
          const SizedBox(height: SwipSpace.xs + 2),
          PublicationChips(mcc!.publications),
        ],

        const SizedBox(height: SwipSpace.xs + 2),
        Row(
          children: [
            ConfidencePill(event.confidence, compact: true),
            if (verdict != null) ...[
              const SizedBox(width: SwipSpace.sm),
              Text(
                verdict!.isInternational ? 'Intl' : 'Domestic',
                style: SwipType.bodyS.copyWith(
                  color: verdict!.isInternational
                      ? SwipColors.warningOnInk
                      : SwipColors.textTertiary,
                ),
              ),
            ],
            if (event.acquirer != null) ...[
              const SizedBox(width: SwipSpace.sm),
              // The payment company, kept visibly separate from the merchant.
              Flexible(
                child: Text(
                  event.acquirer!,
                  style:
                      SwipType.bodyS.copyWith(color: SwipColors.textTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const Spacer(),
            Text(
              _vectorGlyph(event.vector),
              style: SwipType.bodyS.copyWith(color: SwipColors.textTertiary),
              semanticsLabel: event.vector.longLabel,
            ),
            if (!event.isSynced) ...[
              const SizedBox(width: SwipSpace.xs),
              const Icon(Icons.bolt_outlined,
                  size: 12, color: SwipColors.textTertiary),
            ],
          ],
        ),
      ],
    );
  }

  /// `D-07`. Default: `08 Aug` over `4:12 PM`. Tap to switch the whole ledger
  /// to `2h ago`. The toggle is global and persisted — see [TimeFormatPref].
  Widget _timeCell({bool alignEnd = false}) {
    final cell = SwipTime.cell(event.capturedAt, timeFormat);

    return GestureDetector(
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
            crossAxisAlignment:
                alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.end,
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
                  style: SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
                  maxLines: 1,
                  textAlign: TextAlign.right,
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _vectorGlyph(CaptureVector v) => switch (v) {
        CaptureVector.qr => '▣',
        CaptureVector.nfc => '⌁',
        CaptureVector.link => '🔗',
        CaptureVector.intent => '⇥',
        CaptureVector.probe => '🪪',
        CaptureVector.manual => '✎',
        CaptureVector.graph => '◎',
      };
}
