import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/runtime/surface.dart';
import '../core/settings/home_market.dart';
import '../core/theme/swip_tokens.dart';
import '../data/models/capture_event.dart';
import '../data/models/mcc.dart';
import '../data/sources/mcc_route.dart';
import '../data/sources/merchant_identity.dart';
import '../data/sources/rupay_outlook.dart';
import 'capture_sheet.dart';
import 'capture_sheet_shell.dart';

/// `F-175` — **the result of a live capture, without taking the screen.**
///
/// > *"the output screen shown in a full screen format — can we have a non
/// > intrusive UI where you could simply show a pop up like you do on
/// > dashboard just above the CTA, and split the CTA into View all and Tap
/// > POS"*
///
/// ## Why the full-screen page was right once and is not right now
///
/// `F-144` replaced a sheet with a full-screen page, and the argument was
/// good: *the number is the product*, and a sheet capped four digits at about
/// 60 px over a live camera feed showing through a scrim. That reasoning still
/// holds for the two vectors that arrive from somewhere else — the share sheet
/// and the pay-by-app handover — and both of those keep the page.
///
/// It stopped holding for the two **live** vectors, and the thing that changed
/// is what is behind them. A QR scan and a POS tap both happen with the
/// capture surface still running underneath: the camera is still pointed at
/// the counter, the phone is still near the terminal. Covering that completely
/// to announce a result means the next capture needs a dismissal first, and
/// the screen that was covering it had a button whose entire job was to undo
/// the covering — *"Try another"*, which is a button that exists only because
/// the design took something away.
///
/// A sheet gives that back for free. **The scanner is still live behind this,
/// so "try another" is not a button, it is putting the sheet down.** Which is
/// what frees both CTA slots for the two the owner asked for.
///
/// ## The split CTA, and why the second one is Tap POS
///
/// *View all* expands this same sheet into the full breakdown — the reason the
/// category is missing, the routes to getting it, the detection line, the
/// field table. In place, not as a second screen, so there is never more than
/// one thing to dismiss.
///
/// *Tap POS* is the owner's idea and it is the better half of this change. On
/// a capture with no category the old screen printed a list headed **HOW TO
/// GET IT**, whose first item was *"tap their card machine"* — advice, about a
/// thing SWIP can do, printed next to no way to do it. Promoting it to a
/// button turns the most common failure of this product into a single tap
/// towards the one vector that resolves it.
class CaptureResultSheet extends StatefulWidget {
  const CaptureResultSheet({
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
    this.onPos,
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

  /// What the second button does, or null to say this capture came **from**
  /// the POS surface and there is nowhere to send them.
  ///
  /// Supplied by the caller rather than decided here, because the right answer
  /// depends on which of SWIP's two windows this is in — a push inside the
  /// app, and bringing the app forward from the hovering card, where
  /// `MainActivity`'s NFC channel does not exist. See `SwipSurface`.
  final VoidCallback? onPos;

  /// Show it over whatever opened it, and return when it is dismissed.
  ///
  /// `showModalBottomSheet` rather than a route, and the difference is the
  /// point: the scanner underneath keeps running and keeps its camera, so
  /// dismissing this is instantly ready for the next code.
  ///
  /// Inside the hovering card this is bounded to the card, because `F-168`
  /// gave that card its own `Navigator` and a modal route finds the nearest
  /// one. The same call therefore produces a sheet over the app in one window
  /// and a sheet inside the card in the other, with nothing branching.
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
    VoidCallback? onPos,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: SwipColors.surfaceRaised,
        // The shell caps its own height, so the sheet never covers everything
        // even when the content is long.
        shape: const RoundedRectangleBorder(borderRadius: SwipRadius.sheetTop),
        builder: (_) => CaptureResultSheet(
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
          onPos: onPos,
        ),
      );

  @override
  State<CaptureResultSheet> createState() => _CaptureResultSheetState();
}

class _CaptureResultSheetState extends State<CaptureResultSheet> {
  /// Whether *View all* has been pressed.
  ///
  /// A field rather than a second route. Pushing the full breakdown would mean
  /// two things to dismiss to get back to the camera, which is the exact
  /// complaint that started this change.
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final known = widget.event.hasMcc;

    return CaptureSheetShell(
      // Expanded, this is the ledger's own full breakdown and can be long, so
      // it is allowed more of the screen. Collapsed it is four short blocks
      // and will not come near the cap.
      maxHeightFraction: _all ? 0.86 : 0.62,
      footer: _Footer(
        known: known,
        expanded: _all,
        onViewAll: () => setState(() => _all = !_all),
        posLabel: widget.onPos == null ? null : 'Tap POS',
        onPos: widget.onPos,
      ),
      child: CaptureSheet(
        event: widget.event,
        mcc: widget.mcc,
        sourceLabel: widget.sourceLabel,
        // Only handed over once expanded. In the brief layout the sheet does
        // not render a field table at all, and passing one would be a silent
        // claim that it does.
        details: _all ? widget.details : const {},
        rawPayload: widget.rawPayload,
        noCategoryTitle: widget.noCategoryTitle,
        noCategoryBody: widget.noCategoryBody,
        verdict: widget.verdict,
        payeeKind: widget.payeeKind,
        tier: widget.tier,
        rupay: widget.rupay,
        absence: widget.absence,
        layout: _all ? CaptureLayout.sheet : CaptureLayout.brief,
        // The sheet layout draws its own primary button at the end of its
        // content; this one is pinned in the footer, so that is suppressed.
        showFurniture: false,
      ),
    );
  }
}

/// `F-175` — two buttons and one line of confirmation.
///
/// ## Why the emphasis moves rather than the buttons
///
/// The pair is the same in both cases, because two buttons that change places
/// between captures is a row you have to read every time. What changes is
/// which one is filled, and it follows the finding:
///
///   * **No category** — *Tap POS* is filled. The category was not in the
///     code, and the shop's terminal is the one place it certainly is. That is
///     the useful next action and it should look like it.
///   * **A category** — *View all* is filled. The question has been answered;
///     the only thing left worth doing is looking at the answer more closely.
///
/// Neither button is ever the way to capture again, and that is deliberate:
/// the scanner is still live behind this sheet, so dismissing it is the way,
/// and a button duplicating a dismissal would be a third thing to read.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.known,
    required this.expanded,
    required this.onViewAll,
    required this.posLabel,
    required this.onPos,
  });

  final bool known;
  final bool expanded;
  final VoidCallback onViewAll;
  final String? posLabel;
  final VoidCallback? onPos;

  @override
  Widget build(BuildContext context) {
    final viewAll = _Action(
      label: expanded ? 'Show less' : 'View all',
      icon: expanded
          ? Icons.keyboard_arrow_up_rounded
          : Icons.keyboard_arrow_down_rounded,
      filled: known,
      onPressed: onViewAll,
    );

    final pos = posLabel == null
        ? null
        : _Action(
            label: posLabel!,
            icon: Icons.contactless_outlined,
            filled: !known,
            onPressed: onPos,
          );

    return Container(
      decoration: BoxDecoration(
        color: SwipColors.surfaceRaised,
        border: Border(top: BorderSide(color: SwipColors.hairline)),
      ),
      padding: const EdgeInsets.fromLTRB(
          SwipSpace.xl, SwipSpace.md, SwipSpace.xl, SwipSpace.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(child: viewAll),
              if (pos != null) ...[
                const SizedBox(width: SwipSpace.md),
                Expanded(child: pos),
              ],
            ],
          ),
          const SizedBox(height: SwipSpace.sm),
          Text(
            known
                ? 'Saved to your ledger'
                : 'Saved to your ledger as uncategorised',
            style: SwipType.bodyS.copyWith(color: SwipColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// One of the two. Filled or outlined on the same 52 px line, so the pair
/// reads as a pair rather than as a button next to a link.
class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: SwipSpace.sm),
        // A two-word label at a large text scale is what overflows a split
        // button row, and an overflowing button is unreadable rather than
        // merely ugly. Shrinking is the graceful failure.
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );

    return SizedBox(
      height: 52,
      child: filled
          ? FilledButton(onPressed: onPressed, child: child)
          : OutlinedButton(onPressed: onPressed, child: child),
    );
  }
}

/// `F-175` — send the user to SWIP's POS capture screen, from either window.
///
/// ## The two cases, and why they cannot be the same call
///
/// **In the app**, the POS screen is an ordinary route and this pushes it.
///
/// **In the hovering card**, it is not reachable at all. That window runs its
/// own Flutter engine, and `MainActivity`'s `in.swip.app/nfc` channel does not
/// exist in it — the handler is a closure over `MainActivity` state, and
/// `MainActivity` is not on screen. NFC is read entirely through that channel,
/// so pushing the POS screen there would show a card that waits for a reply
/// that can never arrive. `CLAUDE.md` records the shape: *a `MethodChannel`
/// future completes when the platform replies, and never completes if it does
/// not.*
///
/// So in that window this asks the platform to bring the real app forward at
/// the POS screen, and then closes the card. Which is also the honest thing
/// for the user: tapping a terminal means holding the phone against it, and
/// that is not something to do through a window floating over somebody else's
/// app.
Future<void> openPosCapture(BuildContext context, VoidCallback inApp) async {
  if (!SwipSurface.isHoverWindow) {
    inApp();
    return;
  }

  // Timed out like every other platform read in this project. An unanswered
  // channel call here would leave the user on a card that has stopped
  // responding to its own button.
  await const MethodChannel('in.swip.app/nfc')
      .invokeMethod<bool>('openTapScreen')
      .timeout(const Duration(seconds: 3))
      .catchError((_) => false);

  // Close the hovering card. The app is coming forward behind it, and leaving
  // this on top would put a scrim over the screen the user was just sent to.
  SystemNavigator.pop();
}
