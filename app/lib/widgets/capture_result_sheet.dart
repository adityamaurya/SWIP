import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/pay/upi_handoff.dart';
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
import 'ledger_row.dart';
import 'pay_with_sheet.dart';

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
    this.condensed = false,
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

  /// `F-189` — **the same capture, at two sizes, because it arrives in two
  /// very different places.**
  ///
  /// > *"the card that is being shown on the scanning via the launcher is not
  /// > supposed to be that view it is supposed to be a condensed card view
  /// > that is shown on the dashboard"*
  ///
  /// > *"in the full screen scanner view the output card will not be the one
  /// > [crossed out] but instead the card will be as same as marked"* — the
  /// > ledger's own detail sheet
  ///
  /// `F-175` gave both vectors one presentation, and both complaints are the
  /// same mistake seen from either end: **the right amount of result depends
  /// on what is underneath it, and the two windows have opposite answers.**
  ///
  ///   * The hovering card is 62% of a screen belonging to **somebody else's
  ///     app**, opened mid-checkout. Everything past the verdict is something
  ///     the user did not stop to read, covering something they did. One row —
  ///     the same row the dashboard has always used — is the whole finding.
  ///   * The full-screen scanner is **SWIP's own screen**, opened on purpose,
  ///     with nothing behind it but a viewfinder. There is no cost to the
  ///     detail here and it was being withheld for a reason that only ever
  ///     applied to the other window.
  ///
  /// So this is not a preference about density. It is the sheet asking which
  /// of SWIP's two windows it is in, which `SwipSurface` already answers for
  /// the *Tap POS* button three fields up, for the same underlying reason.
  final bool condensed;

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
    bool? condensed,
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
          // Defaulted rather than read inside `build`: a widget that consults
          // a global cannot be rendered both ways in a test, and both ways is
          // exactly what needs asserting.
          condensed: condensed ?? SwipSurface.isHoverWindow,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final known = event.hasMcc;

    return CaptureSheetShell(
      // `F-189`. Two heights again, and for a better reason than `F-175`'s.
      // That round's pair was a collapsed and an expanded state of one sheet;
      // this pair is two different sheets, and the number follows the content
      // rather than a toggle the user has to find.
      maxHeightFraction: condensed ? 0.40 : 0.86,
      footer: _Footer(
        known: known,
        onViewAll: onViewAll,
        posLabel: onPos == null ? null : 'Tap POS',
        onPos: onPos,
        // `F-194`. Null on a POS tap and on any code that is not a payable
        // UPI address — see `UpiHandoff.payUriFor`, which returns null far
        // more often than it returns a string.
        payUri: UpiHandoff.payUriFor(event),
        payeeLabel: event.merchantName ?? event.merchantKey ?? 'this shop',
      ),
      child: condensed
          ? _CondensedResult(event: event, mcc: mcc)
          : CaptureSheet(
              event: event,
              mcc: mcc,
              sourceLabel: sourceLabel,
              // `F-189`. Handed over now. `F-180` passed an empty map because
              // the brief layout does not render a field table and supplying
              // one would have been a silent claim that it does. The full
              // screen uses the ledger's layout, which does render it, and
              // withholding it there was the thing the owner crossed out.
              details: details,
              rawPayload: rawPayload,
              noCategoryTitle: noCategoryTitle,
              noCategoryBody: noCategoryBody,
              verdict: verdict,
              payeeKind: payeeKind,
              tier: tier,
              rupay: rupay,
              absence: absence,
              // The ledger's own layout — which is what the owner pointed at.
              layout: CaptureLayout.sheet,
              // Its primary button and "saved to your ledger" line are the
              // footer's job here. *View technical details* is no longer
              // bundled with them; see `capture_sheet.dart`.
              showFurniture: false,
            ),
    );
  }
}

/// `F-189` — the capture as **one dashboard row**, for the hovering card.
///
/// Literally [LedgerRow]: the same widget the dashboard's RECENT list and the
/// ledger both draw, not a copy of it that looks the same today. The owner
/// pointed at a row on the dashboard and said *that one*, and a second
/// implementation of it would answer the request on the day it was written and
/// drift by the round after — the same argument `docs/32` §10 makes for
/// hovering the real scanner rather than writing a native twin.
///
/// It is not tappable. Every route out of this sheet is in the footer, and a
/// row that highlights under a finger and then does nothing is worse than a
/// row that does not react.
class _CondensedResult extends StatelessWidget {
  const _CondensedResult({required this.event, required this.mcc});

  final CaptureEvent event;
  final Mcc? mcc;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            SwipSpace.gutter, SwipSpace.md, SwipSpace.gutter, 0),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: SwipRadius.cardAll,
            border: SwipElevation.e1,
          ),
          clipBehavior: Clip.antiAlias,
          child: LedgerRow(event: event, mcc: mcc),
        ),
      );
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
    this.payUri,
    this.payeeLabel,
  });

  final bool known;
  final VoidCallback? onViewAll;
  final String? posLabel;
  final VoidCallback? onPos;

  /// `F-194` — the scanned code, forwarded unchanged, or null when this
  /// capture cannot be paid from here.
  ///
  /// **Null is the common case and it renders nothing**, which is the point.
  /// A POS tap has no payee address (`docs/47`), and a QR that is not a UPI
  /// code has none either. A *Continue payment* button that appeared on every
  /// capture and failed on most of them would be worse than no button, because
  /// the failure would arrive after the tap, at a counter, with somebody
  /// waiting.
  final String? payUri;
  final String? payeeLabel;

  @override
  Widget build(BuildContext context) {
    // `F-194`. When *Continue payment* is on screen it is the only filled
    // button. Two filled buttons is not a stronger call to action, it is an
    // absent one — the whole information carried by a filled button is that
    // the others are not it.
    final hasPay = payUri != null;

    final viewAll = _Action(
      label: 'View all',
      // `F-180`. An arrow that leaves, not a chevron that unfolds. The label
      // is the same two words it always was and the button now does something
      // else entirely, so the icon is the only thing on the row that can say
      // so before it is pressed.
      icon: Icons.north_east_rounded,
      filled: known && !hasPay,
      onPressed: onViewAll,
    );

    final uri = payUri;
    final pay = uri == null
        ? null
        : SizedBox(
            height: 52,
            width: double.infinity,
            child: FilledButton(
              onPressed: () => PayWithSheet.open(
                context,
                payUri: uri,
                payeeLabel: payeeLabel ?? 'this shop',
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_outward_rounded, size: 18),
                  SizedBox(width: SwipSpace.sm),
                  Flexible(
                    child: Text('Continue payment',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
          );

    final pos = posLabel == null
        ? null
        : _Action(
            label: posLabel!,
            icon: Icons.contactless_outlined,
            filled: !known && !hasPay,
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
          // `F-194`. Full width and above the pair, not a third seat on the
          // row. Three buttons across a phone at a large text scale is the
          // overflow `F-174` already paid for once — and the hierarchy is
          // real rather than cosmetic: *View all* and *Tap POS* are about the
          // category, and this one is about the thing the user actually came
          // to the counter to do.
          if (pay != null) ...[
            pay,
            const SizedBox(height: SwipSpace.md),
          ],
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
