import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/swip_tokens.dart';
import '../../core/utils/swip_time.dart';
import '../../data/models/capture_event.dart';
import '../../data/models/mcc.dart';
import '../../widgets/ledger_row.dart';
import '../../widgets/mcc_badge.dart';

/// S-01 — Dashboard.
///
/// The most important screen in the product. Ideation `A-09` (minimal, straight
/// to doing), `D-03` (the ledger table lives on the dashboard itself), `D-10`
/// (primary always visible).
///
/// Composition rules, which are load-bearing rather than stylistic:
///
///  * The hero is the **last capture**, not a summary statistic. The question a
///    user opens SWIP with is "what did that come out as?", not "how am I doing
///    this month?"
///  * Exactly **five** recent rows. Five fits above the fold on a 6.1" device
///    with the hero and the tiles; the sixth is what turns a dashboard into
///    a list.
///  * The three capture tiles are **always in the same place**, always three,
///    never reordered by recency. Muscle memory beats personalisation for an
///    action performed twenty times a week.
class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.recent,
    required this.mccFor,
    required this.timeFormat,
    required this.tapAvailable,
    this.onToggleTimeFormat,
    this.onOpenCapture,
    this.onOpenLedger,
    this.onOpenSettings,
    this.onOpenEvent,
  });

  /// Newest first. At most [_recentCount] are rendered.
  final List<CaptureEvent> recent;
  final Mcc? Function(String? code) mccFor;
  final TimeFormatPref timeFormat;

  /// False on iOS and on Android devices without HCE — the Tap tile is then
  /// dimmed and routes to S-22 rather than being hidden. A missing feature
  /// reads as a bug; an explained one reads as honesty.
  final bool tapAvailable;

  final VoidCallback? onToggleTimeFormat;
  final void Function(CaptureVector)? onOpenCapture;
  final VoidCallback? onOpenLedger;
  final VoidCallback? onOpenSettings;
  final void Function(CaptureEvent)? onOpenEvent;

  static const _recentCount = 5;

  @override
  Widget build(BuildContext context) {
    final last = recent.isEmpty ? null : recent.first;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _header(context)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(SwipSpace.gutter, 0,
                    SwipSpace.gutter, SwipSpace.section),
                child: last == null
                    ? const _FirstRunHero()
                    : _LastCaptureHero(
                        event: last,
                        mcc: mccFor(last.mcc),
                        onTap: () => onOpenEvent?.call(last),
                      ),
              ),
            ),
            SliverToBoxAdapter(child: _captureTiles()),
            if (recent.isNotEmpty) ...[
              SliverToBoxAdapter(child: _recentHeader()),
              SliverToBoxAdapter(child: _recentList()),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: SwipSpace.colossal)),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            SwipSpace.gutter, SwipSpace.md, SwipSpace.sm, SwipSpace.xl),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Ink wordmark — the ONLY correct mark on the light background.
            // The foil variant loses its shadow stops on white and turns to mud.
            SvgPicture.asset('assets/brand/swip-wordmark-ink.svg',
                height: 20, semanticsLabel: 'SWIP'),
            IconButton(
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
              color: SwipColors.ink500,
              tooltip: 'Settings',
            ),
          ],
        ),
      );

  Widget _captureTiles() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: SwipSpace.gutter),
        child: Row(
          children: [
            Expanded(
              child: _CaptureTile(
                icon: Icons.qr_code_scanner_rounded,
                label: 'Scan',
                sublabel: 'QR',
                onTap: () => onOpenCapture?.call(CaptureVector.qr),
              ),
            ),
            const SizedBox(width: SwipSpace.md),
            Expanded(
              child: _CaptureTile(
                icon: Icons.contactless_rounded,
                label: 'Tap',
                sublabel: 'POS',
                enabled: tapAvailable,
                onTap: () => onOpenCapture?.call(CaptureVector.nfc),
              ),
            ),
            const SizedBox(width: SwipSpace.md),
            Expanded(
              child: _CaptureTile(
                icon: Icons.link_rounded,
                label: 'Link',
                sublabel: 'check',
                onTap: () => onOpenCapture?.call(CaptureVector.link),
              ),
            ),
          ],
        ),
      );

  Widget _recentHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(SwipSpace.gutter, SwipSpace.section,
            SwipSpace.gutter, SwipSpace.md),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('RECENT',
                style: SwipType.label.copyWith(color: SwipColors.ink500)),
            if (recent.length > _recentCount)
              GestureDetector(
                onTap: onOpenLedger,
                child: Row(children: [
                  Text('See all',
                      style: SwipType.label.copyWith(color: SwipColors.ink900)),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: SwipColors.ink900),
                ]),
              ),
          ],
        ),
      );

  Widget _recentList() {
    final rows = recent.take(_recentCount).toList();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: SwipSpace.gutter),
      decoration: BoxDecoration(
        borderRadius: SwipRadius.cardAll,
        border: SwipElevation.e1,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: SwipSpace.lg),
            LedgerRow(
              event: rows[i],
              mcc: mccFor(rows[i].mcc),
              timeFormat: timeFormat,
              onTap: () => onOpenEvent?.call(rows[i]),
              onToggleTimeFormat: onToggleTimeFormat,
            ),
          ],
        ],
      ),
    );
  }
}

/// The black hero card. `D-10` — the MCC and its category are never behind a tap.
class _LastCaptureHero extends StatelessWidget {
  const _LastCaptureHero({required this.event, this.mcc, this.onTap});

  final CaptureEvent event;
  final Mcc? mcc;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: SwipColors.surfaceInverse,
        borderRadius: SwipRadius.cardAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(SwipSpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LAST CAPTURE',
                    style: SwipType.labelS.copyWith(color: SwipColors.ink300)),
                const SizedBox(height: SwipSpace.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // On Ink, gold returns to full text duty — 8.4:1.
                    Text(
                      event.mcc ?? '—',
                      style: SwipType.mcc.copyWith(color: SwipColors.gold500),
                      semanticsLabel: event.mcc == null
                          ? 'No category code'
                          : 'Category ${event.mcc!.split('').join(' ')}',
                    ),
                    const Spacer(),
                    ConfidencePill(event.confidence, onInk: true),
                  ],
                ),
                const SizedBox(height: SwipSpace.xs),
                Text(
                  mcc?.displayName ??
                      (event.isUnclassified
                          ? 'Unclassified — personal handle'
                          : 'Unknown category'),
                  style: SwipType.bodyL.copyWith(color: SwipColors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: SwipSpace.lg),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        [
                          event.merchantName,
                          event.merchantCity,
                        ].whereType<String>().join(' · '),
                        style: SwipType.bodyS.copyWith(color: SwipColors.ink300),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${event.vector.shortLabel} · '
                      '${SwipTime.relative(event.capturedAt)}',
                      style: SwipType.bodyS.copyWith(color: SwipColors.ink300),
                    ),
                  ],
                ),
                if (mcc != null && mcc!.publications.isNotEmpty) ...[
                  const SizedBox(height: SwipSpace.md),
                  PublicationChips(mcc!.publications, onInk: true),
                ],
              ],
            ),
          ),
        ),
      );
}

/// First run. No hero, no empty ledger section — one sentence and an arrow at
/// the thing to do next.
class _FirstRunHero extends StatelessWidget {
  const _FirstRunHero();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(SwipSpace.xl),
        decoration: BoxDecoration(
          color: SwipColors.surfaceSunken,
          borderRadius: SwipRadius.cardAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Know before you pay', style: SwipType.titleM),
            const SizedBox(height: SwipSpace.sm),
            Text(
              'Scan any payment QR and SWIP shows its category code — '
              'the four digits that decide your rewards.',
              style: SwipType.bodyM.copyWith(color: SwipColors.ink500),
            ),
            const SizedBox(height: SwipSpace.lg),
            Row(children: [
              const Icon(Icons.arrow_downward_rounded,
                  size: 18, color: SwipColors.goldInk),
              const SizedBox(width: SwipSpace.sm),
              Text('Start with Scan',
                  style: SwipType.label.copyWith(color: SwipColors.goldInk)),
            ]),
          ],
        ),
      );
}

class _CaptureTile extends StatelessWidget {
  const _CaptureTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    this.enabled = true,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fg = enabled ? SwipColors.ink900 : SwipColors.ink300;

    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label $sublabel',
      child: Material(
        color: SwipColors.surface,
        borderRadius: SwipRadius.cardAll,
        child: InkWell(
          // Still tappable when disabled: it routes to S-22, which explains why.
          onTap: onTap,
          borderRadius: SwipRadius.cardAll,
          child: Container(
            height: 96,
            decoration: BoxDecoration(
              borderRadius: SwipRadius.cardAll,
              border: SwipElevation.e1,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 26, color: enabled ? SwipColors.goldInk : fg),
                const SizedBox(height: SwipSpace.sm),
                Text(label, style: SwipType.label.copyWith(color: fg)),
                Text(sublabel,
                    style: SwipType.bodyS.copyWith(color: SwipColors.ink300)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
