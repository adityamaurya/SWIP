import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/settings/home_market.dart';
import '../../core/theme/swip_tokens.dart';
import '../../core/utils/swip_time.dart';
import '../../data/models/capture_event.dart';
import '../../data/models/mcc.dart';
import '../../widgets/ledger_row.dart';
import '../../widgets/live_viewfinder.dart';
import '../../widgets/mcc_badge.dart';
import '../../widgets/scan_flash_card.dart';

/// S-01 — Dashboard.
///
/// The most important screen in the product. Ideation `A-09` (minimal, straight
/// to doing), `D-03` (the ledger table lives on the dashboard itself), `D-10`
/// (primary always visible), and feedback `F-01`–`F-03`.
///
/// Composition rules, which are load-bearing rather than stylistic:
///
///  * The top band is a **live camera**, not a summary. Opening SWIP at a
///    counter should require zero taps before the app is looking at the code.
///    `F-01`.
///  * That band is a **carousel** — camera first, last capture second — with
///    dot indicators, because the second question after "what is this?" is
///    "what was the last one?" and it should not cost a screen. `F-03`.
///  * Both cards are **the same height**, so swiping does not resize the page
///    under your thumb.
///  * Exactly **five** recent rows. Five fits above the fold on a 6.1" device;
///    the sixth is what turns a dashboard into a list.
///  * The three capture tiles are **always in the same place**, always three,
///    never reordered by recency. Muscle memory beats personalisation for an
///    action performed twenty times a week.
class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.recent,
    required this.mccFor,
    required this.timeFormat,
    required this.tapAvailable,
    required this.active,
    this.homeMarket,
    this.onToggleTimeFormat,
    this.onOpenCapture,
    this.onScanned,
    this.onOpenLedger,
    this.onOpenSettings,
    this.onOpenEvent,
    this.flash,
    this.onExpandFlash,
    this.onDismissFlash,
  });

  /// Newest first. At most [_recentCount] are rendered.
  final List<CaptureEvent> recent;
  final Mcc? Function(String? code) mccFor;
  final TimeFormatPref timeFormat;

  /// False on iOS and on Android devices without HCE — the Tap tile is then
  /// dimmed and routes to S-22 rather than being hidden. A missing feature
  /// reads as a bug; an explained one reads as honesty.
  final bool tapAvailable;

  /// True only when this tab is visible and the app is resumed. Gates the
  /// camera: an `IndexedStack` keeps every tab alive, so without this the
  /// viewfinder would hold the camera open behind the Ledger.
  final bool active;

  /// `F-14`. Used to mark a capture domestic or international.
  final HomeMarket? homeMarket;

  final VoidCallback? onToggleTimeFormat;
  final void Function(CaptureVector)? onOpenCapture;

  /// A code read by the inline viewfinder. Raw payload, unresolved.
  final void Function(String raw)? onScanned;

  final VoidCallback? onOpenLedger;
  final VoidCallback? onOpenSettings;
  final void Function(CaptureEvent)? onOpenEvent;

  /// `F-61`. The most recent ambient scan, shown as a condensed card under the
  /// camera instead of a modal that covers it.
  final CaptureEvent? flash;
  final void Function(CaptureEvent)? onExpandFlash;
  final VoidCallback? onDismissFlash;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const _recentCount = 5;
  static const _bandHeight = 208.0;

  final _pages = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = widget.recent.isEmpty ? null : widget.recent.first;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _header(context)),
            SliverToBoxAdapter(child: _band(last)),
            SliverToBoxAdapter(child: _captureTiles()),
            if (widget.recent.isNotEmpty) ...[
              SliverToBoxAdapter(child: _recentHeader()),
              SliverToBoxAdapter(child: _recentList()),
            ],
            const SliverToBoxAdapter(
                child: SizedBox(height: SwipSpace.colossal)),
          ],
        ),
      ),
    );
  }

  /// `F-03` — the swipeable band. Card 1 is always the camera.
  Widget _band(CaptureEvent? last) {
    final cards = <Widget>[
      LiveViewfinder(
        // The camera runs only when the dashboard is foreground *and* this
        // page of the carousel is the one on screen.
        active: widget.active && _page == 0,
        height: _bandHeight,
        onDetect: (raw) => widget.onScanned?.call(raw),
        onExpand: () => widget.onOpenCapture?.call(CaptureVector.qr),
      ),
      if (last != null)
        _LastCaptureHero(
          event: last,
          mcc: widget.mccFor(last.mcc),
          verdict: widget.homeMarket?.verdictFor(last.countryCode,
              deviceCountry: last.placeCountry),
          height: _bandHeight,
          onTap: () => widget.onOpenEvent?.call(last),
        )
      else
        const _FirstRunCard(height: _bandHeight),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          SwipSpace.gutter, 0, SwipSpace.gutter, SwipSpace.section),
      child: Column(
        children: [
          SizedBox(
            height: _bandHeight,
            child: PageView(
              controller: _pages,
              onPageChanged: (i) => setState(() => _page = i),
              children: cards,
            ),
          ),
          const SizedBox(height: SwipSpace.md),
          _Dots(count: cards.length, index: _page),

          // `F-61`. Sits directly under the viewfinder, so the answer appears
          // where the eye already is and never covers the camera.
          if (widget.flash != null) ...[
            const SizedBox(height: SwipSpace.md),
            ScanFlashCard(
              key: ValueKey(widget.flash!.id),
              event: widget.flash!,
              mcc: widget.mccFor(widget.flash!.mcc),
              onExpand: () => widget.onExpandFlash?.call(widget.flash!),
              onDismiss: widget.onDismissFlash,
            ),
          ],
        ],
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            SwipSpace.gutter, SwipSpace.md, SwipSpace.sm, SwipSpace.xl),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SvgPicture.asset('assets/brand/swip-wordmark-ink.svg',
                height: 20, semanticsLabel: 'SWIP'),
            Row(children: [
              if (widget.homeMarket != null)
                Padding(
                  padding: const EdgeInsets.only(right: SwipSpace.xs),
                  child: Text(
                    widget.homeMarket!.flag,
                    style: const TextStyle(fontSize: 18),
                    semanticsLabel:
                        'Home country ${widget.homeMarket!.displayName}',
                  ),
                ),
              IconButton(
                onPressed: widget.onOpenSettings,
                icon: const Icon(Icons.settings_outlined),
                color: SwipColors.textSecondary,
                tooltip: 'Settings',
              ),
            ]),
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
                onTap: () => widget.onOpenCapture?.call(CaptureVector.qr),
              ),
            ),
            const SizedBox(width: SwipSpace.md),
            Expanded(
              child: _CaptureTile(
                icon: Icons.contactless_rounded,
                label: 'Tap',
                sublabel: 'POS',
                enabled: widget.tapAvailable,
                onTap: () => widget.onOpenCapture?.call(CaptureVector.nfc),
              ),
            ),
            const SizedBox(width: SwipSpace.md),
            Expanded(
              child: _CaptureTile(
                icon: Icons.link_rounded,
                label: 'Link',
                sublabel: 'check',
                onTap: () => widget.onOpenCapture?.call(CaptureVector.link),
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
                style:
                    SwipType.label.copyWith(color: SwipColors.textSecondary)),
            if (widget.recent.length > _recentCount)
              GestureDetector(
                onTap: widget.onOpenLedger,
                child: Row(children: [
                  Text('See all',
                      style: SwipType.label
                          .copyWith(color: SwipColors.textPrimary)),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: SwipColors.textPrimary),
                ]),
              ),
          ],
        ),
      );

  Widget _recentList() {
    final rows = widget.recent.take(_recentCount).toList();
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
              mcc: widget.mccFor(rows[i].mcc),
              timeFormat: widget.timeFormat,
              verdict: widget.homeMarket?.verdictFor(rows[i].countryCode,
                  deviceCountry: rows[i].placeCountry),
              onTap: () => widget.onOpenEvent?.call(rows[i]),
              onToggleTimeFormat: widget.onToggleTimeFormat,
            ),
          ],
        ],
      ),
    );
  }
}

/// `F-03` — which card you are on. Gold for the active one; the camera dot is
/// deliberately first so its position never moves as captures accumulate.
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: SwipMotion.micro,
              curve: SwipMotion.standardCurve,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == index ? SwipColors.gold500 : SwipColors.hairline,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      );
}

/// The black hero card. `D-10` — the MCC and its category are never behind a
/// tap. `F-44` — the merchant leads, the category follows.
class _LastCaptureHero extends StatelessWidget {
  const _LastCaptureHero({
    required this.event,
    required this.height,
    this.mcc,
    this.verdict,
    this.onTap,
  });

  final CaptureEvent event;
  final double height;
  final Mcc? mcc;
  final MarketVerdict? verdict;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: SwipColors.surfaceInverse,
        borderRadius: SwipRadius.cardAll,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: height,
            padding: const EdgeInsets.all(SwipSpace.xl),
            decoration: BoxDecoration(
              borderRadius: SwipRadius.cardAll,
              border: SwipElevation.e1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('LAST CAPTURE',
                      style: SwipType.labelS
                          .copyWith(color: SwipColors.textTertiary)),
                  const Spacer(),
                  if (verdict != null) _VerdictChip(verdict!),
                ]),
                const SizedBox(height: SwipSpace.md),

                // `F-44` — who it was, first.
                Text(
                  event.identityLine ?? 'Unnamed merchant',
                  style:
                      SwipType.titleM.copyWith(color: SwipColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: SwipSpace.xs),

                // Then what kind of business it is.
                Text(
                  mcc?.displayName ?? event.categoryFallback,
                  style: SwipType.bodyM
                      .copyWith(color: SwipColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const Spacer(),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // On Ink, gold returns to full text duty — 8.4:1.
                    Text(
                      event.mcc ?? '—',
                      style: SwipType.mcc
                          .copyWith(fontSize: 40, color: SwipColors.gold500),
                      semanticsLabel: event.mcc == null
                          ? 'No category code'
                          : 'Category ${event.mcc!.split('').join(' ')}',
                    ),
                    const SizedBox(width: SwipSpace.md),
                    Expanded(child: ConfidencePill(event.confidence)),
                    Text(
                      '${event.vector.shortLabel} · '
                      '${SwipTime.relative(event.capturedAt)}',
                      style: SwipType.bodyS
                          .copyWith(color: SwipColors.textTertiary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

/// First run, second card. The camera is card one and already explains itself,
/// so this says what the app is *for* rather than repeating the instruction.
class _FirstRunCard extends StatelessWidget {
  const _FirstRunCard({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: double.infinity,
        padding: const EdgeInsets.all(SwipSpace.xl),
        decoration: BoxDecoration(
          color: SwipColors.surfaceRaised,
          borderRadius: SwipRadius.cardAll,
          border: SwipElevation.e1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Know before you pay',
                    style: SwipType.titleM
                        .copyWith(color: SwipColors.textPrimary))
                .animate()
                .fadeIn(duration: 420.ms)
                .moveY(begin: 10, curve: SwipMotion.captureCurve),
            const SizedBox(height: SwipSpace.sm),
            Text(
              'Every shop is filed under a four-digit category code. It decides '
              'what your card pays back — and nobody shows it to you before you '
              'pay. SWIP does.',
              style: SwipType.bodyM.copyWith(color: SwipColors.textSecondary),
            )
                .animate()
                .fadeIn(delay: 120.ms, duration: 420.ms)
                .moveY(begin: 10, curve: SwipMotion.captureCurve),
            const SizedBox(height: SwipSpace.lg),
            Row(children: [
              const Icon(Icons.swipe_left_rounded,
                  size: 18, color: SwipColors.gold500),
              const SizedBox(width: SwipSpace.sm),
              Text('Swipe back for the camera',
                  style: SwipType.label.copyWith(color: SwipColors.gold500)),
            ]).animate().fadeIn(delay: 260.ms, duration: 420.ms),
          ],
        ),
      );
}

/// `F-16` — domestic or international, at a glance.
class _VerdictChip extends StatelessWidget {
  const _VerdictChip(this.verdict);
  final MarketVerdict verdict;

  @override
  Widget build(BuildContext context) {
    final intl = verdict.isInternational;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: SwipSpace.sm, vertical: 3),
      decoration: BoxDecoration(
        color: intl ? SwipColors.warningFill : Colors.transparent,
        borderRadius: SwipRadius.chipAll,
        border: Border.all(
            color: intl ? SwipColors.warningOnInk : SwipColors.hairline),
      ),
      child: Text(
        verdict.label.toUpperCase(),
        style: SwipType.labelS.copyWith(
            color:
                intl ? SwipColors.warningOnInk : SwipColors.textTertiary),
      ),
    );
  }
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
    final fg = enabled ? SwipColors.textPrimary : SwipColors.textTertiary;

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
                Icon(icon, size: 26, color: enabled ? SwipColors.gold500 : fg),
                const SizedBox(height: SwipSpace.sm),
                Text(label, style: SwipType.label.copyWith(color: fg)),
                Text(sublabel,
                    style: SwipType.bodyS
                        .copyWith(color: SwipColors.textTertiary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
