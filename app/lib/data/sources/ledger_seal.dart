/// `F-127` — a tamper-evident seal on the ledger, without a blockchain.
///
/// ## What was asked for, and what this is
///
/// > *"can we some how make this app data complaint … if possible even make it
/// > secure using blockchain technology like India did when they were issuing
/// > covid vaccine certification"*
///
/// The two papers behind that request — Madhwal, Yanovich & Chumakov on
/// blockchain vaccine-certificate supply, and Hasan et al. on blockchain
/// COVID-19 immunity certificates — both use a distributed ledger for one
/// specific reason: **the issuer and the verifier do not trust each other.** A
/// clinic issues a certificate, a restaurant checks it, and neither will accept
/// the other's word, so the proof is put somewhere neither controls.
///
/// SWIP does not have that problem, and pretending it does would make the app
/// worse in three concrete ways:
///
///   1. **There is no second party.** You are the issuer and the verifier. A
///      consensus network exists to settle disagreements between parties; with
///      one party it is an expensive way to write to a file.
///   2. **It would publish your spending.** Every capture is a merchant, a
///      category and a time. On any public chain that is permanent and
///      world-readable. The single best property SWIP has is that nothing
///      leaves the phone; a chain would trade that away for a property nobody
///      asked for.
///   3. **It needs a network.** SWIP works on a plane, in a basement, at a
///      counter with no signal. That is not an accident.
///
/// So this takes **the mechanism those papers actually rely on** — the
/// cryptographic part, not the network part — and keeps everything else.
///
/// > *"Creating a chain of blocks connected by cryptographic constructs
/// > (hashes) makes it very difficult to tamper the records, as it would cost
/// > the rework from the genesis to the latest transaction in blocks."*
/// > — Hasan et al., §I
///
/// That sentence describes a **hash chain**. A hash chain does not require a
/// network, a consensus algorithm, a token, or a single byte of your data
/// leaving the device. It is the part that does the work.
///
/// ## What it gives you
///
/// Each record carries the hash of the record before it, so altering capture
/// #4 in a 900-capture export invalidates #4 and every one of the 896 after
/// it. The export carries the final `sealHash`, which is a single 64-character
/// value that fixes the entire file. On import, SWIP recomputes the chain and
/// tells you whether the file is exactly what left your phone — and if it is
/// not, **which record is the first one that does not match**.
///
/// That is genuinely useful for the thing you are actually worried about: a
/// backup that was edited, corrupted in transit, or silently truncated by a
/// cloud sync. It is a real integrity guarantee, and it is honest about its
/// limits, which are below.
///
/// ## What it is not, said plainly
///
/// This is **tamper-evident, not tamper-proof**. Anyone holding the file can
/// rewrite every record and recompute the whole chain, and the result will
/// verify. Detecting *that* requires a signature over the seal with a key the
/// holder does not have, or a timestamp published somewhere they do not
/// control — which is where a real notary or a real chain would come in.
///
/// The app must never claim more than it delivers, so the words used in the UI
/// are "sealed" and "unchanged since export", never "blockchain-secured".
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// The result of checking an imported file against its seal.
class SealCheck {
  const SealCheck({
    required this.intact,
    required this.recordCount,
    this.firstBrokenIndex,
    this.expected,
    this.actual,
  });

  final bool intact;
  final int recordCount;

  /// Index of the first record whose link does not match — the earliest point
  /// at which the file stopped being what it was. `null` when intact.
  final int? firstBrokenIndex;

  final String? expected;
  final String? actual;

  String get summary {
    if (intact) {
      return 'Verified. All $recordCount records are exactly as exported.';
    }
    if (firstBrokenIndex != null) {
      return 'This file has changed since it was exported. The first record '
          'that does not match is number ${firstBrokenIndex! + 1} of '
          '$recordCount.';
    }
    return 'This file has changed since it was exported.';
  }
}

/// Builds and verifies the chain.
abstract final class LedgerSeal {
  /// Bumped if the canonical form ever changes, so an old export is reported as
  /// "sealed by an older version" rather than as tampered with. Getting this
  /// wrong would accuse the user of forging their own backup.
  static const version = 1;

  /// The first link. A fixed, published starting value, exactly as a genesis
  /// block is in the papers.
  static const genesis =
      '0000000000000000000000000000000000000000000000000000000000000000';

  /// **Canonical form is the whole game.** Two devices must serialise the same
  /// record to the same bytes or the hashes differ for no reason: keys are
  /// sorted, nulls are dropped, and everything is UTF-8 JSON with no spaces.
  static String canonical(Map<String, Object?> row) {
    final keys = row.keys.where((k) => row[k] != null).toList()..sort();
    return jsonEncode({for (final k in keys) k: row[k]});
  }

  static String _link(String previous, Map<String, Object?> row) =>
      sha256.convert(utf8.encode('$previous|${canonical(row)}')).toString();

  /// Returns each row with its `_seal` link added, in order.
  static List<Map<String, Object?>> seal(List<Map<String, Object?>> rows) {
    var previous = genesis;
    final out = <Map<String, Object?>>[];
    for (final row in rows) {
      final clean = Map<String, Object?>.from(row)..remove('_seal');
      previous = _link(previous, clean);
      out.add({...clean, '_seal': previous});
    }
    return out;
  }

  /// The final link: one value that fixes the entire file.
  static String sealHashOf(List<Map<String, Object?>> sealedRows) =>
      sealedRows.isEmpty
          ? genesis
          : sealedRows.last['_seal'] as String? ?? genesis;

  /// Recompute the chain and say whether the file is unchanged.
  static SealCheck verify(
    List<Map<String, Object?>> sealedRows, {
    String? declaredSealHash,
  }) {
    var previous = genesis;
    for (var i = 0; i < sealedRows.length; i++) {
      final row = Map<String, Object?>.from(sealedRows[i]);
      final claimed = row.remove('_seal') as String?;
      final computed = _link(previous, row);
      if (claimed != computed) {
        return SealCheck(
          intact: false,
          recordCount: sealedRows.length,
          firstBrokenIndex: i,
          expected: computed,
          actual: claimed,
        );
      }
      previous = computed;
    }

    if (declaredSealHash != null && declaredSealHash != previous) {
      return SealCheck(
        intact: false,
        recordCount: sealedRows.length,
        expected: previous,
        actual: declaredSealHash,
      );
    }

    return SealCheck(intact: true, recordCount: sealedRows.length);
  }
}
