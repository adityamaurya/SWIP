import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/home_market.dart';
import '../core/theme/swip_tokens.dart';
import '../data/models/capture_event.dart';
import '../data/repositories/capture_repository.dart';
import '../data/sources/capture_resolver.dart';
import '../data/sources/merchant_identity.dart';
import 'capture_sheet.dart';
import 'capture_sheet_shell.dart';

/// Open the full detail sheet for a capture that already happened.
///
/// ## Why this is a function and not three copies
///
/// Tapping a row in the ledger, tapping a row on the dashboard, and tapping the
/// chevron on a condensed card are the same request — *show me everything you
/// know about this one*. They were not the same code, and one of them (the
/// ledger) was not wired up at all, which is why tapping a ledger row did
/// nothing.
///
/// One function means the three entry points cannot drift into describing the
/// same capture differently, which is the same rule the capture path already
/// follows through [CaptureResolver].
///
/// The stored [CaptureEvent] carries the resolved facts but not the *reading*
/// of them — payee kind, merchant tier, the source label — so the raw payload
/// is re-resolved here when there is one. That is deliberate: re-reading the
/// original bytes means an improvement to the resolver reaches captures that
/// were recorded before it, without a migration.
Future<void> showCaptureDetail(
  BuildContext context,
  WidgetRef ref,
  CaptureEvent event,
) async {
  final repo = await ref.read(captureRepositoryProvider.future);
  if (!context.mounted) return;

  final home = ref.read(homeMarketProvider).valueOrNull;
  final resolved = event.rawPayload == null
      ? null
      : CaptureResolver.resolve(event.rawPayload!);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SwipColors.surfaceRaised,
    // `F-174`. **The striped overflow bar the owner photographed was here.**
    //
    // `isScrollControlled: true` lets this sheet grow to the height of the
    // screen and no further, and `CaptureSheet` is a `Column` with no scroll
    // view in it — so a capture with enough content simply had nowhere to put
    // the excess and Flutter drew `BOTTOM OVERFLOWED BY 28 PIXELS`.
    //
    // It had been that way for a long time and only surfaced now because
    // `F-169` wired up the dashboard's MCC tap, which was itself a fix for a
    // callback nobody ever passed. Connecting something unreachable exposes
    // everything behind it for the first time.
    //
    // [CaptureSheetShell] caps the height and scrolls the content. It does
    // **not** draw a grabber — `F-180`; the theme's `showDragHandle` supplies
    // the one handle every sheet in the app gets. See its own notes for why
    // `Flexible` is the operative word.
    builder: (_) => CaptureSheetShell(
      child: CaptureSheet(
        event: event,
        mcc: repo.lookup(event.mcc),
        sourceLabel: resolved?.sourceLabel ?? event.vector.longLabel,
        rawPayload: event.rawPayload,
        verdict: home?.verdictFor(event.countryCode,
            deviceCountry: event.placeCountry),
        payeeKind: resolved?.payeeKind ?? PayeeKind.undetermined,
        tier: resolved?.tier ?? MerchantTier.unknown,
        // `F-124`, `F-125`. Re-derived from the stored payload, so a capture
        // opened from the ledger a week later says exactly what it said at the
        // counter. Nothing extra is persisted for this: the raw payload was
        // already being kept, and it is the only input.
        rupay: resolved?.rupay,
        absence: event.hasMcc ? null : resolved?.absence,
        details: {
          // The payment company lives here rather than in the row. On a ledger
          // line "Paytm" reads as the shop's name; here, under a label that says
          // what it is, it is the useful fact it actually is.
          if (event.acquirer != null) 'Payment company': event.acquirer!,
          if (event.merchantHandle != null) 'Pays to': event.merchantHandle!,
          if (event.merchantCity != null) 'City': event.merchantCity!,
          if (event.countryCode != null) 'Merchant country': event.countryCode!,
          if (event.placeLabel != null) 'Captured at': event.placeLabel!,
          if (event.amount != null)
            'Amount': '${event.currency ?? ''} ${event.amount}'.trim(),
          if (event.terminalId != null) 'Terminal': event.terminalId!,
          'How it was read': event.vector.longLabel,
        },
      ),
    ),
  );
}
