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
import '../../data/sources/merchant_reconciler.dart';
import '../../widgets/mcc_badge.dart';
import '../../widgets/merchant_link_card.dart';

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
    this.linkProposal,
    this.onConfirmLink,
    this.onDismissLink,
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

  /// `F-49`. "Is this the same shop?" — shown above the capture tiles, where
  /// it is unmissable but not modal.
  final MerchantLinkProposal? linkProposal;
  final void Function(MerchantLinkProposal)? onConfirmLink;
  final void Function(MerchantLinkProposal)? onDismissLink;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const _recentCount = 5;
  static const _bandHeight = 208.0;

  final _pages = PageController();
  int _page = 0;

  /// `F-66`. Whether the camera band is the square shape. A square matches the
  /// shape of the thing being looked at, so a stubborn code lines up far more
  /// easily — and it is one tap back to the wide band that fits more of the
  /// dashboard on screen.
  bool _squared = false;

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
            if (widget.linkProposal != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(SwipSpace.gutter, 0,
                      SwipSpace.gutter, SwipSpace.section),
                  child: MerchantLinkCard(
                    proposal: widget.linkProposal!,
                    onConfirm: () =>
                        widget.onConfirmLink?.call(widget.linkProposal!),
                    onDismiss: () =>
                        widget.onDismissLink?.call(widget.linkProposal!),
                  ),
                ),
              ),
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
    final bandHeight = _squared ? _squareHeight(context) : _bandHeight;

    final cards = <Widget>[
      LiveViewfinder(
        // The camera runs only when the dashboard is foreground *and* this
        // page of the carousel is the one on screen.
        active: widget.active && _page == 0,
        height: bandHeight,
        squared: _squared,
        onDetect: (raw) => widget.onScanned?.call(raw),
        onToggleShape: () => setState(() => _squared = !_squared),
        onExpand: () => widget.onOpenCapture?.call(CaptureVector.qr),
      ),
      if (last != null)
        _LastCaptureHero(
          event: last,
          mcc: widget.mccFor(last.mcc),
          height: bandHeight,
          onTap: () => widget.onOpenEvent?.call(last),
        )
      else
        _FirstRunCard(height: bandHeight),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          SwipSpace.gutter, 0, SwipSpace.gutter, SwipSpace.section),
      child: Column(
        children: [
          // `F-66`. Animated so the morph is a movement rather than a jump —
          // a card that changes size instantly reads as a layout bug.
          AnimatedSize(
            duration: SwipMotion.standard,
            curve: SwipMotion.captureCurve,
            child: SizedBox(
            height: bandHeight,
            child: PageView(
              controller: _pages,
              onPageChanged: (i) => setState(() => _page = i),
              children: cards,
            ),
          ),
          ),
          const SizedBox(height: SwipSpace.md),
          _Dots(count: cards.length, index: _page),
        ],
      ),
    );
  }

  /// The square. Capped so it never eats the whole screen on a tall phone —
  /// the tiles and the recent list have to stay reachable without scrolling.
  static double _squareHeight(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width - SwipSpace.gutter * 2;
    return width.clamp(220.0, 340.0);
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

  /// `F-81`. Three equal tiles said the three routes were equally useful. They
  /// are not: scanning a shop's QR and tapping its card machine are how a
  /// category is actually read, and Link is a fallback for a payment page you
  /// were sent. So the two that matter get the room and the larger type, and
  /// Link is dimmed to a third — still tappable, because a greyed control you
  /// cannot press is just a broken one.
  Widget _captureTiles() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: SwipSpace.gutter),
        // **Never `CrossAxisAlignment.stretch` here.**
        //
        // `F-84`, and the reason the whole dashboard went black. This Row lives
        // in a `SliverToBoxAdapter`, which hands its child an **unbounded**
        // height. `stretch` makes `RenderFlex` pass that height down as a tight
        // constraint — `BoxConstraints.tightFor(height: infinity)` — which
        // throws during layout. The exception takes the entire `CustomScrollView`
        // with it, so the header, the camera band, the tiles and the recent list
        // all vanish at once and the body renders as nothing at all.
        //
        // It was also pointless: the tiles are already the same height, because
        // each one is a `Container(height: 104)`.
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: _CaptureTile(
                icon: Icons.qr_code_scanner_rounded,
                label: 'Scan QR',
                sublabel: 'The shop\'s code',
                onTap: () => widget.onOpenCapture?.call(CaptureVector.qr),
              ),
            ),
            const SizedBox(width: SwipSpace.md),
            Expanded(
              flex: 3,
              child: _CaptureTile(
                icon: Icons.contactless_rounded,
                label: 'Tap POS',
                sublabel: 'The card machine',
                enabled: widget.tapAvailable,
                onTap: () => widget.onOpenCapture?.call(CaptureVector.nfc),
              ),
            ),
            const SizedBox(width: SwipSpace.md),
            Expanded(
              flex: 2,
              child: _CaptureTile(
                icon: Icons.link_rounded,
                label: 'Link',
                sublabel: 'Later',
                enabled: false,
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
    this.onTap,
  });

  final CaptureEvent event;
  final double height;
  final Mcc? mcc;
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
                  // `F-74`. Where, not whether-it-was-abroad. The same swap the
                  // ledger row made: you know which country you are standing
                  // in, and "the Bandra one" is how a capture is recalled.
                  if (event.placeLabel != null)
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.place_outlined,
                              size: 13, color: SwipColors.textTertiary),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              event.placeLabel!,
                              style: SwipType.labelS
                                  .copyWith(color: SwipColors.textTertiary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                    // On Ink, gold returns to full text duty — 8.4:1. `F-76`:
                    // `NA` in grey when there is no code, so an absence can
                    // never be mistaken for a value.
                    Text(
                    // `F-86`. Every item in this row is flexible, because a
                    // 40 px number becomes a 64 px number the moment someone
                    // turns text size up — and four of those plus a pill, a tag
                    // and a timestamp do not fit across a phone. `scaleDown`
                    // touches nothing until it has to, then gives back exactly
                    // the width the rest of the row needs.
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomLeft,
                        child: Text(
                          event.mcc ?? 'NA',
                          style: SwipType.mcc.copyWith(
                            fontSize: 40,
                            color: event.mcc == null
                                ? SwipColors.textTertiary
                                : SwipColors.gold500,
                          ),
                          maxLines: 1,
                          semanticsLabel: event.mcc == null
                              ? 'No category code'
                              : 'Category ${event.mcc!.split('').join(' ')}',
                        ),
                      ),
                    ),
                    const SizedBox(width: SwipSpace.md),
                    Flexible(child: ConfidencePill(event.confidence)),
                    const SizedBox(width: SwipSpace.sm),
                    VectorTag(event.vector),
                    const SizedBox(width: SwipSpace.sm),
                    Flexible(
                      child: Text(
                        SwipTime.relative(event.capturedAt),
                        style: SwipType.bodyS
                            .copyWith(color: SwipColors.textTertiary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
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
            // `F-86`. Three lines of prose in a card of fixed height is the
            // most reliable way to overflow there is — it only takes someone
            // turning text size up. Flexible plus ellipsis: the sentence gives
            // before the card does.
            Flexible(
              child: Text(
                'Every shop is filed under a four-digit category code. It '
                'decides what your card pays back — and nobody shows it to you '
                'before you pay. SWIP does.',
                style: SwipType.bodyM.copyWith(color: SwipColors.textSecondary),
                overflow: TextOverflow.ellipsis,
                maxLines: 5,
              )
                  .animate()
                  .fadeIn(delay: 120.ms, duration: 420.ms)
                  .moveY(begin: 10, curve: SwipMotion.captureCurve),
            ),
            const SizedBox(height: SwipSpace.lg),
            Row(children: [
              const Icon(Icons.swipe_left_rounded,
                  size: 18, color: SwipColors.gold500),
              const SizedBox(width: SwipSpace.sm),
              Flexible(
                child: Text(
                  'Swipe back for the camera',
                  style: SwipType.label.copyWith(color: SwipColors.gold500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]).animate().fadeIn(delay: 260.ms, duration: 420.ms),
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
    final fg = enabled ? SwipColors.textPrimary : SwipColors.textTertiary;

    return Semantics(
      button: true,
      enabled: enabled,
      label: '$label. $sublabel',
      child: Material(
        color: SwipColors.surface,
        borderRadius: SwipRadius.cardAll,
        child: InkWell(
          // Still tappable when disabled. A dimmed tile says "not the thing you
          // want right now"; a dead one says "broken", and they must not look
          // the same.
          onTap: onTap,
          borderRadius: SwipRadius.cardAll,
          child: Container(
            height: 104,
            padding:
                const EdgeInsets.symmetric(horizontal: SwipSpace.sm),
            decoration: BoxDecoration(
              borderRadius: SwipRadius.cardAll,
              border: SwipElevation.e1,
            ),
            // `F-84`. Bigger type inside a fixed-height tile is an overflow
            // waiting for someone with large text switched on. `scaleDown` does
            // nothing at all until the content would not fit, and then shrinks
            // it just enough — which beats both a clipped tile and a tile that
            // paints hazard stripes.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      size: 28, color: enabled ? SwipColors.gold500 : fg),
                  const SizedBox(height: SwipSpace.sm),
                  // `F-81`. titleS rather than label: these are the two things
                  // the screen is for, and they were being read at arm's length
                  // in a shop.
                  Text(
                    label,
                    style: SwipType.titleS.copyWith(color: fg),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    sublabel,
                    style:
                        SwipType.bodyS.copyWith(color: SwipColors.textTertiary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
