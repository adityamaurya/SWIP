import 'package:flutter_test/flutter_test.dart';
import 'package:swip/data/sources/ledger_seal.dart';

/// `F-127` — the hash chain, and honest limits on what it proves.
void main() {
  List<Map<String, Object?>> rows() => [
        {'id': 'a', 'mcc': '5912', 'at': '2026-09-01T10:00:00Z'},
        {'id': 'b', 'mcc': '5812', 'at': '2026-09-02T10:00:00Z'},
        {'id': 'c', 'mcc': null, 'at': '2026-09-03T10:00:00Z'},
      ];

  test('a sealed export verifies', () {
    final sealed = LedgerSeal.seal(rows());
    final check = LedgerSeal.verify(sealed,
        declaredSealHash: LedgerSeal.sealHashOf(sealed));
    expect(check.intact, isTrue);
    expect(check.recordCount, 3);
  });

  test('editing one record names that record, not a vague failure', () {
    final sealed = LedgerSeal.seal(rows());
    // Somebody changes the category on the second capture.
    sealed[1] = {...sealed[1], 'mcc': '7995'};

    final check = LedgerSeal.verify(sealed,
        declaredSealHash: LedgerSeal.sealHashOf(LedgerSeal.seal(rows())));
    expect(check.intact, isFalse);
    expect(check.firstBrokenIndex, 1);
    expect(check.summary, contains('number 2 of 3'));
  });

  test('deleting a record in the middle is caught', () {
    final sealed = LedgerSeal.seal(rows());
    final declared = LedgerSeal.sealHashOf(sealed);
    sealed.removeAt(1);
    expect(LedgerSeal.verify(sealed, declaredSealHash: declared).intact,
        isFalse);
  });

  test('key order and absent-vs-null cannot change the hash', () {
    // Canonicalisation is the whole game: two devices must serialise the same
    // record identically or exports fail to verify for no reason at all.
    final a = LedgerSeal.canonical({'b': 2, 'a': 1, 'z': null});
    final b = LedgerSeal.canonical({'a': 1, 'b': 2});
    expect(a, b);
  });

  test('an empty ledger seals to genesis rather than throwing', () {
    final sealed = LedgerSeal.seal([]);
    expect(LedgerSeal.sealHashOf(sealed), LedgerSeal.genesis);
    expect(LedgerSeal.verify(sealed).intact, isTrue);
  });

  test('a wholly re-sealed file verifies — tamper-EVIDENT, not tamper-proof',
      () {
    // This is the documented limit, asserted so nobody later mistakes the
    // seal for a signature. Anyone holding the file can rewrite every record
    // and recompute the chain; catching that needs a key they do not have.
    final forged = LedgerSeal.seal([
      {'id': 'a', 'mcc': '7995', 'at': '2026-09-01T10:00:00Z'},
    ]);
    expect(
      LedgerSeal.verify(forged,
              declaredSealHash: LedgerSeal.sealHashOf(forged))
          .intact,
      isTrue,
    );
  });
}
