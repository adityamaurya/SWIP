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

/// `F-180`. How a capture page ended, handed back through `Navigator.pop`.
///
/// The shell `await`s the push in `_openCapture`, so a result travelling back
/// up that existing `Future` is the whole wire — no notifier, no provider, no
/// static. A page that pops with nothing returns null and the shell does what
/// it always did.
enum CaptureExit {
  /// *View all* was pressed. Show the ledger tab.
  ledger,
}

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
/// *View all* opens **the app, at the ledger.**
///
/// `F-175` had it expand this same sheet in place, on the argument that a
/// second screen is a second thing to dismiss. `F-180` reversed that on the
/// owner's instruction — *"the view all shouldn't open in the same view it
/// should open the app and the ledger screen"* — and the instruction is right
/// for a reason the first design missed: **expanding in place answered a
/// question nobody had asked yet.** The breakdown of a capture taken two
/// seconds ago is not urgent; the capture has just been saved, and the useful
/// destination is the place all of them live, where this one is the top row.
///
/// It also removes a state. The sheet had a collapsed and an expanded form,
/// two heights, and a button whose label flipped between *View all* and
/// *Show less* — all of it in front of a live camera. Now the sheet has one
/// shape and one job.
///
/// *Tap POS* is the owner's idea and it is the better half of this change. On
/// a capture with no category the old screen printed a list headed **HOW TO
/// GET IT**, whose first item was *"tap their card machine"* — advice, about a
/// thing SWIP can do, printed next to no way to do it. Promoting it to a
/// button turns the most common failure of this product into a single tap
/// towards the one vector that resolves it.
class CaptureResultSheet extends StatelessWidget {
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
    this.onViewAll,
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

  /// `F-180`. Open the app at the ledger.
  ///
  /// Supplied by the caller for the same reason as [onPos]: the route out
  /// depends on which of SWIP's two windows this sheet is in, and the sheet
  /// does not get to know. In the app it is a pop back to the shell carrying a
  /// result; from the hovering card it is a platform call and a goodbye. Both
  /// are wrapped in [openLedgerScreen], which is the only thing a caller needs
  /// to reach for.
  ///
  /// Null renders the button disabled rather than absent — a footer whose
  /// button count changes between captures is a row that has to be re-read.
  final VoidCallback? onViewAll;

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
    VoidCallback? onViewAll,
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
          onViewAll: onViewAll,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final known = event.hasMcc;

    return CaptureSheetShell(
      // One height now. `F-175` had two — 0.62 collapsed and 0.86 expanded —
      // because *View all* grew the sheet in place. It does not any more, so
      // the second number went with the state that chose between them.
      maxHeightFraction: 0.62,
      footer: _Footer(
        known: known,
        onViewAll: onViewAll,
        posLabel: onPos == null ? null : 'Tap POS',
        onPos: onPos,
      ),
      child: CaptureSheet(
        event: event,
        mcc: mcc,
        sourceLabel: sourceLabel,
        // `F-180`. Never handed over. The brief layout does not render a field
        // table, and passing one would be a silent claim that it does — the
        // full breakdown is the ledger's job now, which is the whole point of
        // the change. `details` stays on the constructor because the two
        // callers build it and the ledger's own detail sheet reads the same
        // map from the stored event.
        details: const {},
        rawPayload: rawPayload,
        noCategoryTitle: noCategoryTitle,
        noCategoryBody: noCategoryBody,
        verdict: verdict,
        payeeKind: payeeKind,
        tier: tier,
        rupay: rupay,
        absence: absence,
        layout: CaptureLayout.brief,
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
    required this.onViewAll,
    required this.posLabel,
    required this.onPos,
  });

  final bool known;
  final VoidCallback? onViewAll;
  final String? posLabel;
  final VoidCallback? onPos;

  @override
  Widget build(BuildContext context) {
    final viewAll = _Action(
      label: 'View all',
      // `F-180`. An arrow that leaves, not a chevron that unfolds. The label
      // is the same two words it always was and the button now does something
      // else entirely, so the icon is the only thing on the row that can say
      // so before it is pressed.
      icon: Icons.north_east_rounded,
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

/// `F-180` — send the user to the ledger, from either window.
///
/// > *"the view all shouldn't open in the same view it should open the app and
/// > the ledger screen"*
///
/// ## Why this is not simply a `Navigator.push`
///
/// Because in one of the two windows there is no ledger to push to. The
/// hovering card runs its **own Flutter engine** with its own
/// `ProviderContainer`, so a `LedgerPage` built there would open a second
/// sqflite handle on the same file as the one the app holds. `CLAUDE.md`
/// records what that costs: sqflite caches open databases **by path**, and two
/// handles to one path is a bug this project has already paid for once.
///
/// So the card asks the platform to bring `MainActivity` forward with
/// `EXTRA_OPEN_LEDGER`, which `consumeTileLaunch` reports to `main.dart` as
/// `'ledger'`, and the shell switches tabs. The same handshake the quick
/// settings tile and *Tap POS* already use — a third destination on a road
/// that exists, rather than a second road.
///
/// **In the app** [inApp] runs instead, and what it does is pop: the sheet,
/// then the capture page, carrying a result the shell acts on. A push would
/// have left a live camera underneath the ledger.
Future<void> openLedgerScreen(BuildContext context, VoidCallback inApp) async {
  if (!SwipSurface.isHoverWindow) {
    inApp();
    return;
  }

  // Timed out like every other platform read in this project: a channel call
  // that never completes would leave the user on a card whose button has
  // stopped responding, with no way to tell it apart from a slow phone.
  await const MethodChannel('in.swip.app/nfc')
      .invokeMethod<bool>('openLedger')
      .timeout(const Duration(seconds: 3))
      .catchError((_) => false);

  SystemNavigator.pop();
}
