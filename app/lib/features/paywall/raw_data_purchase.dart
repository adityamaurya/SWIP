import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'raw_data_entitlement.dart';

/// `F-146` — the purchase flow for the raw-data unlock.
///
/// ## The shape of the problem
///
/// Billing is the one part of this app that talks to something outside the
/// phone, and it is the one part that cannot be made to work by writing better
/// Dart: it needs a product created in the Play Console, a signed build, and
/// an account that is allowed to buy it. **None of those exist yet.** This
/// project has never produced anything but a debug APK
/// (`docs/30-PRE-LAUNCH-PARAMETERS` §4.2).
///
/// So the question this file has to answer is not "how do I charge someone",
/// it is **"what does the app do for the months before any of that is true"**.
/// The answer is: say so, in a sentence, and change nothing else. Every failure
/// mode below ends in a plain sentence on screen and a working app.
///
/// | Situation | What the user sees |
/// |---|---|
/// | Store unreachable (no Play Services, debug build, no network) | "Google Play is not available on this device" |
/// | Product not created in the Console yet | "This unlock is not on sale yet" |
/// | User cancels the sheet | Nothing. A cancel is not an error |
/// | Payment declined | Play's own message |
/// | Bought, verified | Unlocked, permanently, on this device |
///
/// ## Verification, and its honest limit
///
/// Google's guidance is to verify a purchase on a trusted server. **SWIP has
/// no server, by design, and that is the product's main security claim.** So
/// verification here is what a client-only app can actually do: the plugin
/// hands back a purchase whose status came from Play Billing, and that is
/// taken at face value.
///
/// What that means concretely is that a determined, technical user on a rooted
/// phone can fake this unlock. That is accepted for the same reason the
/// `SharedPreferences` flag is accepted in [RawDataEntitlement] — the
/// alternative is an account system, and an account system would cost more
/// than this feature is worth. It is written down here rather than discovered
/// later.
class RawDataPurchaseState {
  const RawDataPurchaseState({
    this.busy = false,
    this.error,
    this.priceLabel = '',
    this.available = false,
  });

  /// A store round-trip is in flight. The buttons are disabled while true, so
  /// a double tap cannot open two checkout sheets.
  final bool busy;

  /// A sentence to show the user. Never a code, never an exception's
  /// `toString`.
  final String? error;

  /// The price **as Play reports it**, in the user's own currency and
  /// formatting.
  ///
  /// This is why the constant in [kRawDataPriceLabel] is only a fallback: a
  /// hard-coded "₹5,000" shown to someone whose Play account bills in dirhams
  /// is simply a wrong number on a checkout button.
  final String priceLabel;

  /// Whether the product was actually found in the store.
  final bool available;

  RawDataPurchaseState copyWith({
    bool? busy,
    String? error,
    bool clearError = false,
    String? priceLabel,
    bool? available,
  }) =>
      RawDataPurchaseState(
        busy: busy ?? this.busy,
        error: clearError ? null : (error ?? this.error),
        priceLabel: priceLabel ?? this.priceLabel,
        available: available ?? this.available,
      );
}

class RawDataPurchaseNotifier extends StateNotifier<RawDataPurchaseState> {
  RawDataPurchaseNotifier(this._ref)
      : super(RawDataPurchaseState(priceLabel: kRawDataPriceLabel)) {
    _listen();
  }

  final Ref _ref;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  InAppPurchase get _iap => InAppPurchase.instance;

  /// The purchase stream is live for the lifetime of the app, not just while
  /// the paywall is on screen.
  ///
  /// This matters for one specific case that is easy to get wrong: a purchase
  /// that completes **after** the user has navigated away — a slow card
  /// authorisation, or one that finishes while the app is backgrounded —
  /// arrives on this stream whenever it lands. A listener scoped to the widget
  /// would have been disposed by then, and the user would have paid for
  /// nothing.
  void _listen() {
    _sub = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object e) => state = state.copyWith(
        busy: false,
        error: 'Google Play reported a problem. Nothing has been charged.',
      ),
    );
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != kRawDataProductId) continue;

      switch (p.status) {
        case PurchaseStatus.pending:
          state = state.copyWith(busy: true, clearError: true);

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final granted =
              await _ref.read(rawDataUnlockedProvider.notifier).grant();
          state = state.copyWith(
            busy: false,
            clearError: true,
            error: granted
                ? null
                // Preferences had not loaded. Rare, recoverable, and far
                // better said out loud than silently dropped.
                : 'Purchase complete, but SWIP could not save it yet. '
                    'Reopen the app and tap Restore.',
          );

        case PurchaseStatus.error:
          state = state.copyWith(
            busy: false,
            error: p.error?.message ??
                'That did not go through. Nothing has been charged.',
          );

        case PurchaseStatus.canceled:
          // Not an error. Somebody looked at the price and decided not to,
          // which is a perfectly good outcome and must not be dressed up as a
          // failure.
          state = state.copyWith(busy: false, clearError: true);
      }

      // Required by both stores, and required even for a purchase that
      // errored: an unacknowledged purchase is automatically refunded by
      // Google after three days, which would take the unlock away from
      // somebody who paid.
      if (p.pendingCompletePurchase) {
        await _iap.completePurchase(p);
      }
    }
  }

  /// Open the store sheet.
  Future<void> buy(BuildContext context) async {
    state = state.copyWith(busy: true, clearError: true);

    if (!await _iap.isAvailable()) {
      state = state.copyWith(
        busy: false,
        error: 'Google Play billing is not available on this device. On a '
            'debug build it never is — this unlock needs a Play Store '
            'install.',
      );
      return;
    }

    final response =
        await _iap.queryProductDetails({kRawDataProductId});

    if (response.productDetails.isEmpty) {
      state = state.copyWith(
        busy: false,
        available: false,
        error: 'This unlock is not on sale yet. Everything else in SWIP '
            'works without it.',
      );
      return;
    }

    final product = response.productDetails.first;
    state = state.copyWith(priceLabel: product.price, available: true);

    // A non-consumable: bought once, owned forever, never re-purchasable.
    await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: product),
    );
    // The result arrives on the stream, not here.
  }

  /// Re-deliver a purchase made on another device or before a reinstall.
  ///
  /// There is nothing to query against without an account, so this is Play's
  /// own restore: it replays owned purchases onto [purchaseStream], where
  /// [_onPurchases] treats `restored` exactly like `purchased`.
  Future<void> restore() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      if (!await _iap.isAvailable()) {
        state = state.copyWith(
          busy: false,
          error: 'Google Play is not available on this device.',
        );
        return;
      }
      await _iap.restorePurchases();
      // If nothing comes back the stream stays silent, so the spinner has to
      // be stopped here rather than waiting for an event that will not arrive.
      state = state.copyWith(busy: false);
    } on Exception {
      state = state.copyWith(
        busy: false,
        error: 'Could not reach Google Play to check for a previous purchase.',
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final rawDataPurchaseProvider =
    StateNotifierProvider<RawDataPurchaseNotifier, RawDataPurchaseState>(
  RawDataPurchaseNotifier.new,
);
