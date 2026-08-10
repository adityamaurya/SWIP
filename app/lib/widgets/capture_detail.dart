import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/settings/home_market.dart';
import '../core/theme/swip_tokens.dart';
import '../data/models/capture_event.dart';
import '../data/repositories/capture_repository.dart';
import '../data/sources/capture_resolver.dart';
import '../data/sources/merchant_identity.dart';
import 'capture_sheet.dart';

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
    builder: (_) => CaptureSheet(
      event: event,
      mcc: repo.lookup(event.mcc),
      sourceLabel: resolved?.sourceLabel ?? event.vector.longLabel,
      rawPayload: event.rawPayload,
      verdict: home?.verdictFor(event.countryCode,
          deviceCountry: event.placeCountry),
      payeeKind: resolved?.payeeKind ?? PayeeKind.undetermined,
      tier: resolved?.tier ?? MerchantTier.unknown,
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
  );
}
