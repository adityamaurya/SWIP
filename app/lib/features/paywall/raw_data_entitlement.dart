/// `F-146` — **the one thing in SWIP that is behind a payment.**
///
/// > *"We need to safeguard our data… someone might replicate our application,
/// > seeing the captured string from the POS, the URL… we show the raw data
/// > there, but we put up maybe a paywall of nearly 5,000 to unlock it."*
///
/// ## What is actually being protected, and what is not
///
/// This is worth stating precisely, because a paywall that is vague about its
/// own boundary is the kind of thing that gets an app removed.
///
/// **Behind the wall:** the verbatim payload — the full `upi://pay?…` query
/// string, and the full APDU trace of a POS exchange. That is the raw material
/// somebody would need to build a competing reader without doing the four
/// months of work that went into knowing what the bytes mean.
///
/// **Never behind the wall, and this is the important half:**
///
/// * the category code and its name;
/// * the merchant, the tier, the RuPay outlook, the reason a category is
///   missing, and every route to finding one;
/// * every capture in the ledger, and the plain-text export of all of it;
/// * the sealed backup, which contains everything including the raw payloads,
///   because **it is the user's own data and holding it hostage would be
///   indefensible**. The backup is encrypted to the user's own key, not to
///   SWIP's.
///
/// So the wall is around a *view*, not around the data. Nothing the user
/// captured stops being theirs, nothing stops being exportable, and uninstalling
/// does not cost them a record. What ₹5,000 buys is the ability to read the
/// payload **inside the app**, on screen, which is the surface a competitor
/// would actually use.
///
/// ## Why it is not a subscription
///
/// A subscription on a no-server app is a promise to keep doing something, and
/// there is no server here to keep doing it on. This is a one-time unlock of a
/// view that already exists on the device. That is the only shape that is
/// honest given the architecture.
///
/// ## The line this has to stay on the right side of
///
/// `support_story.dart` says, about donations: *"A contribution buys nothing.
/// No feature changes, nothing is unlocked, and no part of SWIP is behind
/// it."* That sentence is still true and must stay true — **a donation and
/// this purchase are different transactions and must never be merged.** If the
/// support section ever starts offering this unlock as a perk, that sentence
/// becomes a lie and the donation stops being a donation, with the GST
/// consequences set out in `docs/27-DONATIONS.md` §2.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/settings/prefs.dart';

/// The Play product this maps to. Created in the Play Console as a **one-time
/// managed product**, not a subscription.
///
/// Not yet created — see [RawDataEntitlement.storeReady]. Until it exists the
/// UI says so rather than opening a checkout that cannot complete.
const kRawDataProductId = 'swip_raw_data_unlock';

/// ₹5,000. Held as paise so no float ever touches a price.
///
/// The displayed price at checkout comes from Play, in the user's own
/// currency, and may differ. This constant is the *intent*, used for the copy
/// shown before the store sheet opens; it is never used to charge anything.
const kRawDataPricePaise = 500000;

/// `₹5,000`.
String get kRawDataPriceLabel =>
    '₹${(kRawDataPricePaise ~/ 100).toString().replaceAllMapped(
          // Indian grouping: the last three digits, then pairs.
          RegExp(r'(\d)(?=(\d\d)+\d$)'),
          (m) => '${m[1]},',
        )}';

/// Where the unlock is remembered.
///
/// `SharedPreferences` rather than the SQLite ledger on purpose: the ledger is
/// the user's *captures*, and a purchase is not a capture. Mixing them would
/// put an entitlement row inside every export, which is both meaningless to
/// import elsewhere and a small privacy leak in a file people are encouraged
/// to share.
const _kUnlockedKey = 'swip.rawData.unlocked';

/// Whether the raw-payload view is unlocked on this device.
///
/// ## On the obvious objection
///
/// A `SharedPreferences` boolean is trivially flippable on a rooted phone, and
/// no amount of obfuscation changes that on a client-only app. That is
/// accepted, deliberately, and it is not a security hole — it is the same
/// trade every offline app makes. The alternative is a server, an account and
/// a login, which would cost SWIP the one property it markets: that it has
/// none of those. Someone technical enough to flip this bit could read the
/// payload off their own screen anyway.
class RawDataEntitlement extends StateNotifier<bool> {
  RawDataEntitlement(this._prefs)
      : super(_prefs?.getBool(_kUnlockedKey) ?? false);

  /// Null until `SharedPreferences` has loaded.
  ///
  /// Nullable rather than a stand-in object, because the pre-load state has to
  /// behave differently in two ways and a null check says both of them in one
  /// line: reads are locked, and **writes are refused**. A grant that arrives
  /// before there is anywhere to persist it would set `state = true`, show the
  /// payload, and then be gone at the next launch — a purchase that silently
  /// did not stick.
  final SharedPreferences? _prefs;

  /// Whether a purchase can be recorded at all yet.
  bool get isReady => _prefs != null;

  /// Record a completed purchase. Called only from a verified purchase
  /// callback — never from the UI directly.
  ///
  /// Returns false if preferences have not loaded, so the caller can retry
  /// rather than assume it worked.
  Future<bool> grant() async {
    final p = _prefs;
    if (p == null) return false;
    await p.setBool(_kUnlockedKey, true);
    state = true;
    return true;
  }

  /// Used by the restore flow, and by nothing else. There is no "lock again"
  /// affordance in the UI: a purchase the user made does not get taken back
  /// because a query failed.
  Future<void> revoke() async {
    await _prefs?.remove(_kUnlockedKey);
    state = false;
  }
}

/// `false` until preferences have loaded, which is the safe default: a view
/// that flashes the payload for one frame before deciding it is locked has
/// already leaked it.
final rawDataUnlockedProvider =
    StateNotifierProvider<RawDataEntitlement, bool>(
  (ref) => RawDataEntitlement(
    ref.watch(sharedPreferencesProvider).valueOrNull,
  ),
);
