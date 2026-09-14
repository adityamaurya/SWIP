import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/settings/home_market.dart';
import '../core/theme/swip_tokens.dart';
import '../data/models/capture_event.dart';
import '../data/models/mcc.dart';
import '../data/sources/mcc_route.dart';
import '../data/sources/merchant_identity.dart';
import '../data/sources/rupay_outlook.dart';
import 'capture_sheet.dart';
import 'raw_data_lock.dart';

/// `F-144` — **the capture result, full screen.**
///
/// > *"If I double-tap into the main screen, the pop-up will not come. It will
/// > come as a single full-screen where the MCC is on the full-page screen…
/// > The same goes for the POS tab. Once the POS tab is detected, it should
/// > show in a full-screen format, like the MCC at the top or maybe the
/// > centre."*
///
/// ## Why a sheet was the wrong container
///
/// A modal bottom sheet is a container for a *decision* — it covers the thing
/// you were doing, you answer it, it goes away, and the thing underneath is
/// still the point. That is the wrong shape for this screen, for two reasons
/// that only became obvious once the sheet was used at a counter.
///
/// **The number is the product.** `docs/33` §1.1 argues that every reference
/// screen has exactly one near-black, heavy object on a paper ground, and that
/// SWIP's is four digits. A sheet caps that at about 60 px and surrounds it
/// with a live camera feed showing through the scrim — the busiest possible
/// background for the one thing that has to be read in a hurry.
///
/// **A sheet has no bottom.** Its content ends wherever it ends, so a primary
/// button sits at an unpredictable height that moves between a capture with a
/// category and one without. The owner asked for a CTA *"stuck to the
/// bottom"*, and a sheet cannot give one without a second scroll view inside
/// a draggable one, which fights itself on Android.
///
/// ## What this page adds, and what it does not
///
/// It adds three things and no content: the viewport, the pinned bottom bar,
/// and the collapsed technical panel. **Every sentence on this screen is still
/// written in [CaptureSheet]** and rendered through
/// [CaptureLayout.fullScreen], so the QR path, the POS path and the ledger
/// cannot drift apart in what they say about a capture. That was the original
/// reason the one sheet existed and it has not stopped being true.
class CaptureResultPage extends StatelessWidget {
  const CaptureResultPage({
    super.key,
    required this.event,
    required this.mcc,
    required this.sourceLabel,
    this.details = const {},
    this.rawPayload,
    this.noCategoryTitle,
    this.noCategoryBody,
    this.verdict,
    this.payeeKind = PayeeKind.undetermined,
    this.tier = MerchantTier.unknown,
    this.rupay,
    this.absence,
    this.onCaptureAnother,
    this.primaryLabel,
    this.dismissible = true,
  });

  final CaptureEvent event;
  final Mcc? mcc;
  final String sourceLabel;
  final Map<String, String> details;
  final String? rawPayload;
  final String? noCategoryTitle;
  final String? noCategoryBody;
  final MarketVerdict? verdict;
  final PayeeKind payeeKind;
  final MerchantTier tier;
  final RupayVerdict? rupay;
  final MccAbsence? absence;

  /// What the bottom button does. Defaults to popping back to whatever opened
  /// this — the live viewfinder, or the tap screen, both of which resume on
  /// their own. A caller that needs to do more (re-arm a controller, clear a
  /// cooldown) passes its own.
  final VoidCallback? onCaptureAnother;

  /// Override the bottom button's text.
  ///
  /// Exactly one caller needs this and it is worth naming: the pay-by-app
  /// handover. That screen is not the end of a capture, it is the middle of a
  /// payment the user started somewhere else, and "Capture another" there
  /// would abandon the thing they were doing. It says "Continue to pay" and
  /// hands the intent on.
  ///
  /// Everywhere else this stays null and [_ctaLabel] decides, which is what
  /// keeps "Capture another" and "Try another" from being retyped per caller
  /// and drifting.
  final String? primaryLabel;

  /// Whether the × and the system back gesture may leave this screen.
  final bool dismissible;

  /// Push it. Returns when the user leaves the result.
  ///
  /// `fullscreenDialog: true` gives the platform's modal transition — up from
  /// the bottom on Android — so the gesture still *feels* like the sheet it
  /// replaces even though the destination is a page. The continuity matters:
  /// this screen arrives unannounced, a fraction of a second after a code is
  /// read, and a page that slides in from the right would read as navigation
  /// the user did not ask for.
  static Future<void> open(
    BuildContext context, {
    required CaptureEvent event,
    required Mcc? mcc,
    required String sourceLabel,
    Map<String, String> details = const {},
    String? rawPayload,
    String? noCategoryTitle,
    String? noCategoryBody,
    MarketVerdict? verdict,
    PayeeKind payeeKind = PayeeKind.undetermined,
    MerchantTier tier = MerchantTier.unknown,
    RupayVerdict? rupay,
    MccAbsence? absence,
    VoidCallback? onCaptureAnother,
    String? primaryLabel,
    bool dismissible = true,
  }) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => PopScope(
            // The pay-by-app handover passes `dismissible: false`: a result
            // reached in the middle of someone else's checkout must not be
            // swiped away, because the payment it is standing in front of has
            // not happened yet.
            canPop: dismissible,
            child: CaptureResultPage(
              event: event,
              mcc: mcc,
              sourceLabel: sourceLabel,
              details: details,
              rawPayload: rawPayload,
              noCategoryTitle: noCategoryTitle,
              noCategoryBody: noCategoryBody,
              verdict: verdict,
              payeeKind: payeeKind,
              tier: tier,
              rupay: rupay,
              absence: absence,
              onCaptureAnother: onCaptureAnother,
              primaryLabel: primaryLabel,
              dismissible: dismissible,
            ),
          ),
        ),
      );

  /// `F-145`. **"Capture another" on a hit, "Try another" on a miss.**
  ///
  /// > *"If I want to add a new CTA just at the very bottom, which is stuck to
  /// > the bottom, it should say 'Capture another.' If it fails, then try
  /// > another comes."*
  ///
  /// The two labels are doing different jobs and the difference is not
  /// cosmetic. *Capture another* is an invitation to keep going — the last one
  /// worked, do it again. *Try another* concedes that this one did not land
  /// and points at the next thing, which is the honest word when the code held
  /// no category. Using "Capture another" after a miss would quietly claim a
  /// success that did not happen, in a product whose entire position is that
  /// it does not overclaim.
  String get _ctaLabel =>
      primaryLabel ?? (event.hasMcc ? 'Capture another' : 'Try another');

  @override
  Widget build(BuildContext context) {
    final known = event.hasMcc;

    return Scaffold(
      backgroundColor: SwipColors.bg,
      body: Column(
        children: [
          // ── the close affordance ──
          //
          // A full-screen result has to be dismissible without a gesture
          // anyone has to be taught. `fullscreenDialog` gives Android a back
          // arrow by default; an explicit × in the corner reads as "this is a
          // result you are finished with" rather than "you have navigated
          // somewhere".
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.centerLeft,
              child: dismissible
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: SwipColors.textSecondary,
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).maybePop(),
                    )
                  : const SizedBox(height: 48),
            ),
          ),

          // ── the capture itself ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: SwipSpace.xl),
              child: CaptureSheet(
                event: event,
                mcc: mcc,
                sourceLabel: sourceLabel,
                rawPayload: rawPayload,
                noCategoryTitle: noCategoryTitle,
                noCategoryBody: noCategoryBody,
                verdict: verdict,
                payeeKind: payeeKind,
                tier: tier,
                rupay: rupay,
                absence: absence,
                layout: CaptureLayout.fullScreen,
              ),
            ),
          ),

          // ── the furniture, pinned ──
          _BottomBar(
            label: _ctaLabel,
            known: known,
            details: details,
            rawPayload: rawPayload,
            onPressed:
                onCaptureAnother ?? () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

/// `F-145` — the technical panel and the CTA, pinned to the bottom of the
/// viewport.
///
/// > *"The technical part of it should be at the very bottom, collapsed… and
/// > the CTA just below it."*
///
/// Order is exactly that, and the order is the argument: the expandable sits
/// **above** the button, so opening it pushes nothing off screen and the
/// button never moves. A collapsible below a fixed button would either cover
/// it or shove it out of the safe area the moment it opened.
class _BottomBar extends StatefulWidget {
  const _BottomBar({
    required this.label,
    required this.known,
    required this.details,
    required this.rawPayload,
    required this.onPressed,
  });

  final String label;
  final bool known;
  final Map<String, String> details;
  final String? rawPayload;
  final VoidCallback onPressed;

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar> {
  bool _open = false;

  bool get _hasTechnical =>
      widget.details.isNotEmpty || widget.rawPayload != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: SwipColors.bg,
        border: Border(top: BorderSide(color: SwipColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_hasTechnical) ...[
              // ── the collapsed header ──
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _open = !_open);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: SwipSpace.xl, vertical: SwipSpace.md),
                  child: Row(
                    children: [
                      Icon(Icons.data_object_rounded,
                          size: 15, color: SwipColors.textTertiary),
                      const SizedBox(width: SwipSpace.sm),
                      Expanded(
                        child: Text('TECHNICAL DETAILS',
                            style: SwipType.labelS
                                .copyWith(color: SwipColors.textTertiary)),
                      ),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 20, color: SwipColors.textTertiary),
                      ),
                    ],
                  ),
                ),
              ),

              // ── the panel ──
              //
              // Capped at 40 % of the viewport. An APDU trace can be hundreds
              // of lines, and a panel that grows without limit would push the
              // button it is supposed to sit above straight off the screen.
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: !_open
                    ? const SizedBox(width: double.infinity)
                    : ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * 0.40,
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(
                              SwipSpace.xl, 0, SwipSpace.xl, SwipSpace.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final entry in widget.details.entries)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: SwipSpace.sm),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width: 128,
                                        child: Text(entry.key,
                                            style: SwipType.bodyS.copyWith(
                                                color:
                                                    SwipColors.textTertiary)),
                                      ),
                                      Expanded(
                                        child: SelectableText(entry.value,
                                            style: SwipType.bodyS.copyWith(
                                                color:
                                                    SwipColors.textSecondary)),
                                      ),
                                    ],
                                  ),
                                ),
                              if (widget.rawPayload != null) ...[
                                const SizedBox(height: SwipSpace.sm),
                                RawDataLock(raw: widget.rawPayload!),
                              ],
                            ],
                          ),
                        ),
                      ),
              ),
              const Divider(height: 1, color: SwipColors.hairline),
            ],

            // ── the CTA ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  SwipSpace.xl, SwipSpace.md, SwipSpace.xl, SwipSpace.md),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: widget.onPressed,
                      child: Text(widget.label),
                    ),
                  ),
                  const SizedBox(height: SwipSpace.sm),
                  Text(
                    widget.known
                        ? 'Saved to your ledger'
                        : 'Saved to your ledger as uncategorised',
                    style:
                        SwipType.bodyS.copyWith(color: SwipColors.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 280.ms).moveY(
          begin: 24,
          duration: 360.ms,
          curve: Curves.easeOutCubic,
        );
  }
}
