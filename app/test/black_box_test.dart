import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:swip/data/sources/black_box.dart';

/// `F-147`, `F-148` — the encrypted backup.
///
/// The owner's requirement was one sentence and it is unusually strict:
///
/// > *"It should be compatible with our app to read, and it should never, ever
/// > fail on import."*
///
/// "Never fails" is not a thing you can assert by reading code. The last group
/// in this file is therefore a fuzzer: it takes a real black box and throws a
/// few thousand truncations, bit-flips, splices and random byte strings at
/// [BlackBox.inspect] and [BlackBox.open], and asserts that **not one of them
/// throws**. Every possible input has to come back as a sentence.
void main() {
  Map<String, dynamic> ledgerOf(int n) => {
        'exportedAt': '2026-09-14T00:00:00.000Z',
        'sealHash': 'abc123',
        'captures': [
          for (var i = 0; i < n; i++)
            {
              'id': 'cap-$i',
              'mcc': i.isEven ? '5912' : null,
              'merchant_name': 'SHOP $i',
              'raw_payload': 'upi://pay?pa=shop$i@ybl&mc=5912',
              'captured_at': '2026-09-0${(i % 9) + 1}T10:00:00.000Z',
            },
        ],
      };

  group('the recovery phrase', () {
    test('is twelve words and validates', () {
      final p = BlackBox.newRecoveryPhrase();
      expect(p.split(' ').length, 12);
      expect(BlackBox.isValidPhrase(p), isTrue);
    });

    test('two phrases are never the same', () {
      final seen = {for (var i = 0; i < 50; i++) BlackBox.newRecoveryPhrase()};
      expect(seen.length, 50);
    });

    test('a mistyped word is caught by the checksum, not by a failed decrypt',
        () {
      // This is the whole reason BIP-39 was borrowed. Without the checksum the
      // only way to learn a word is wrong is to derive a key, fail to decrypt,
      // and then be unable to say whether the file or the phrase was at fault.
      const wrong = 'abandon abandon abandon abandon abandon abandon '
          'abandon abandon abandon abandon abandon abandon';
      expect(BlackBox.isValidPhrase(wrong), isFalse);
    });

    test('capitals and stray spacing still open the same backup', () async {
      // People write these down by hand. A phrase that only works from a
      // copy-paste is not a recovery phrase.
      final phrase = BlackBox.newRecoveryPhrase();
      final file = await BlackBox.seal(
        ledger: ledgerOf(3),
        phrase: phrase,
        captures: 3,
      );

      final messy = '  ${phrase.toUpperCase().replaceAll(' ', '   ')}  ';
      final opened = await BlackBox.open(
        reading: BlackBox.inspect(file),
        phrase: messy,
      );

      expect(opened.ok, isTrue, reason: opened.problem);
      expect(opened.rows.length, 3);
    });
  });

  group('a sealed backup', () {
    test('round-trips every row', () async {
      final phrase = BlackBox.newRecoveryPhrase();
      final file = await BlackBox.seal(
        ledger: ledgerOf(85),
        phrase: phrase,
        captures: 85,
        sealHash: 'deadbeef',
      );

      final reading = BlackBox.inspect(file);
      expect(reading.format, BlackBoxFormat.blackBox);
      expect(reading.captures, 85);
      expect(reading.sealHash, 'deadbeef');
      expect(reading.problem, isNull);
      expect(reading.needsPhrase, isTrue);

      final opened = await BlackBox.open(reading: reading, phrase: phrase);
      expect(opened.ok, isTrue, reason: opened.problem);
      expect(opened.rows.length, 85);
      expect(opened.rows.first['id'], 'cap-0');
      expect(opened.rows.first['raw_payload'], 'upi://pay?pa=shop0@ybl&mc=5912');
    });

    test('is genuinely unreadable without the phrase', () async {
      final file = await BlackBox.seal(
        ledger: ledgerOf(5),
        phrase: BlackBox.newRecoveryPhrase(),
        captures: 5,
      );

      // The headline claim: none of the ledger's contents survive into the
      // file in readable form. If this ever fails, the encryption is not
      // doing the one thing it is there for.
      expect(file, isNot(contains('SHOP 0')));
      expect(file, isNot(contains('upi://')));
      expect(file, isNot(contains('5912')));
      expect(file, isNot(contains('@ybl')));
    });

    test('the header is readable on purpose, and says nothing private',
        () async {
      final file = await BlackBox.seal(
        ledger: ledgerOf(7),
        phrase: BlackBox.newRecoveryPhrase(),
        captures: 7,
      );
      final header = jsonDecode(file) as Map<String, dynamic>;

      // Readable: the things that let the app explain itself before it has a
      // key.
      expect(header['format'], 'swip.blackbox');
      expect(header['version'], 1);
      expect(header['captures'], 7);
      expect(header['createdAt'], isA<String>());
      expect(header['readMe'], contains('recovery phrase'));

      // Not readable: anything about a shop.
      expect(jsonEncode(header['kdf']), isNot(contains('SHOP')));
      expect(header.keys, isNot(contains('merchants')));
    });

    test('the same ledger and the same phrase produce different files',
        () async {
      // A fresh salt and nonce per export. Without this, two backups taken a
      // week apart would be byte-identical whenever nothing had changed,
      // which leaks "nothing happened this week" to anyone holding both.
      final phrase = BlackBox.newRecoveryPhrase();
      final a =
          await BlackBox.seal(ledger: ledgerOf(3), phrase: phrase, captures: 3);
      final b =
          await BlackBox.seal(ledger: ledgerOf(3), phrase: phrase, captures: 3);
      expect(a, isNot(equals(b)));

      // …and both still open.
      for (final f in [a, b]) {
        final o =
            await BlackBox.open(reading: BlackBox.inspect(f), phrase: phrase);
        expect(o.ok, isTrue, reason: o.problem);
      }
    });

    test('a wrong phrase is reported as a wrong phrase, not a broken file',
        () async {
      // The distinction this test pins is the difference between "check your
      // words" and "your records are gone". Getting it wrong would be the
      // cruellest bug in the app.
      final file = await BlackBox.seal(
        ledger: ledgerOf(4),
        phrase: BlackBox.newRecoveryPhrase(),
        captures: 4,
      );
      final other = BlackBox.newRecoveryPhrase();

      final opened =
          await BlackBox.open(reading: BlackBox.inspect(file), phrase: other);

      expect(opened.ok, isFalse);
      expect(opened.wrongPhrase, isTrue);
      expect(opened.problem, contains('file itself is fine'));
      expect(opened.problem!.toLowerCase(), isNot(contains('corrupt')));
    });
  });

  group('older plain exports still import', () {
    test('a pre-blackbox export is recognised and read', () async {
      // The owner has real exports on disk from before this format existed. A
      // backup format that cannot read the backups you already have is not a
      // backup format.
      final old = jsonEncode(ledgerOf(12));
      final reading = BlackBox.inspect(old);

      expect(reading.format, BlackBoxFormat.plainLedger);
      expect(reading.captures, 12);
      expect(reading.needsPhrase, isFalse);
      expect(reading.isImportable, isTrue);

      final opened = await BlackBox.open(reading: reading, phrase: '');
      expect(opened.ok, isTrue);
      expect(opened.rows.length, 12);
    });
  });

  group('every failure is a sentence', () {
    test('empty', () {
      final r = BlackBox.inspect('');
      expect(r.format, BlackBoxFormat.damaged);
      expect(r.problem, isNotNull);
    });

    test('not JSON', () {
      final r = BlackBox.inspect('this is just some text');
      expect(r.format, BlackBoxFormat.damaged);
      expect(r.problem, contains('not readable as JSON'));
    });

    test('JSON, but somebody else\'s', () {
      final r = BlackBox.inspect('{"hello":"world"}');
      expect(r.format, BlackBoxFormat.notSwip);
      expect(r.problem, isNotNull);
    });

    test('a JSON array rather than an object', () {
      final r = BlackBox.inspect('[1,2,3]');
      expect(r.format, BlackBoxFormat.notSwip);
      expect(r.problem, isNotNull);
    });

    test('a black box from a future version says to update, not that it broke',
        () {
      final r = BlackBox.inspect(
          jsonEncode({'format': 'swip.blackbox', 'version': 99}));
      expect(r.format, BlackBoxFormat.blackBox);
      expect(r.problem, contains('newer version'));
      expect(r.problem, contains('file itself is fine'));
    });

    test('a black box with its crypto header removed', () async {
      final file = await BlackBox.seal(
        ledger: ledgerOf(2),
        phrase: BlackBox.newRecoveryPhrase(),
        captures: 2,
      );
      final body = jsonDecode(file) as Map<String, dynamic>;
      body.remove('kdf');

      final opened = await BlackBox.open(
        reading: BlackBox.inspect(jsonEncode(body)),
        phrase: BlackBox.newRecoveryPhrase(),
      );
      expect(opened.ok, isFalse);
      expect(opened.problem, isNotNull);
    });

    test('a truncated payload reads as damage in transit, not as a bad phrase',
        () async {
      final phrase = BlackBox.newRecoveryPhrase();
      final file = await BlackBox.seal(
        ledger: ledgerOf(20),
        phrase: phrase,
        captures: 20,
      );
      final body = jsonDecode(file) as Map<String, dynamic>;
      final p = body['payload'] as String;
      body['payload'] = p.substring(0, p.length ~/ 2);

      final opened = await BlackBox.open(
        reading: BlackBox.inspect(jsonEncode(body)),
        phrase: phrase,
      );
      expect(opened.ok, isFalse);
      // The phrase was right. Saying otherwise would send the user hunting for
      // a typo that is not there.
      expect(opened.wrongPhrase, isFalse);
      expect(opened.problem, isNotNull);
    });
  });

  // ───────────────────────────────────────────────────────────────────────
  // "It should never, ever fail on import."
  // ───────────────────────────────────────────────────────────────────────
  //
  // Everything above tests inputs somebody thought of. This tests the ones
  // nobody did. A fixed seed so a failure is reproducible from the output.
  group('the fuzzer', () {
    // `inspect` touches no crypto, so it can be hammered. This is the call
    // that decides what the app *says* about a file, and it is the one a
    // user actually reaches by picking the wrong thing out of their Downloads
    // folder.
    test('no input, however mangled, makes inspect throw', () async {
      final rng = Random(20260914);
      final good = await BlackBox.seal(
        ledger: ledgerOf(30),
        phrase: BlackBox.newRecoveryPhrase(),
        captures: 30,
      );

      final corpus = <String>[
        good,
        jsonEncode(ledgerOf(3)),
        '',
        '   ',
        'null',
        'true',
        '0',
        '"a string"',
        '{',
        '[[[[[[',
        '{"format":"swip.blackbox"}',
        '{"format":"swip.blackbox","version":1}',
        '{"captures":"not a list"}',
        '{"captures":[1,2,3]}',
        '{"captures":[{"id":null}]}',
        String.fromCharCodes([0xFF, 0xFE, 0x00, 0x01]),
      ];

      var checked = 0;
      for (final seed in corpus) {
        for (var i = 0; i < 140; i++) {
          final mutated = _mutate(seed, rng);
          // The contract, stated as plainly as it can be: this call does not
          // throw. Not for malformed JSON, not for a half-downloaded file,
          // not for random bytes with a .json extension.
          expect(
            () => BlackBox.inspect(mutated),
            returnsNormally,
            reason: 'inspect threw on: ${_excerpt(mutated)}',
          );
          checked++;
        }
      }
      expect(checked, greaterThan(2000));
    });

    // `open` runs 210,000 rounds of PBKDF2 — about a second here and several
    // on a phone — so it is fuzzed over a small, deliberately chosen sample
    // rather than thousands of mutations. Hammering it would take ninety
    // minutes and prove nothing the shapes below do not.
    test('no mangled file makes open throw either', () async {
      final rng = Random(4242);
      final phrase = BlackBox.newRecoveryPhrase();
      final good = await BlackBox.seal(
        ledger: ledgerOf(10),
        phrase: phrase,
        captures: 10,
      );
      final body = jsonDecode(good) as Map<String, dynamic>;

      // Each of these has broken a real decryption path at some point in some
      // codebase: a field emptied, a field retyped, a field removed, base64
      // that is not base64, and the payload cut in half by a chat app.
      final broken = <String>[
        good,
        jsonEncode({...body, 'payload': ''}),
        jsonEncode({...body, 'payload': 'not base64 at all!!'}),
        jsonEncode({...body, 'payload': 42}),
        jsonEncode({...body, 'cipher': null}),
        jsonEncode({...body, 'cipher': {'algorithm': 'aes-256-gcm'}}),
        jsonEncode({...body, 'kdf': {'salt': '!!!', 'iterations': 'lots'}}),
        jsonEncode({...body, 'check': 'AAAAAAAAAAA='}),
        jsonEncode({...body, 'check': 999}),
        jsonEncode({...body}..remove('payload')),
        jsonEncode({...body}..remove('check')),
        for (var i = 0; i < 6; i++) _mutate(good, rng),
      ];

      for (final file in broken) {
        final r = BlackBox.inspect(file);
        for (final p in [phrase, 'not a phrase at all', '']) {
          late BlackBoxOpening opened;
          expect(
            () async => opened = await BlackBox.open(reading: r, phrase: p),
            returnsNormally,
            reason: 'open threw on: ${_excerpt(file)}',
          );
          opened = await BlackBox.open(reading: r, phrase: p);
          // Either it opened, or it explained itself. Never neither, and
          // never an exception.
          expect(opened.ok || opened.problem != null, isTrue,
              reason: 'open returned neither rows nor a problem for: '
                  '${_excerpt(file)}');
        }
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

String _excerpt(String s) =>
    s.length <= 90 ? s : '${s.substring(0, 90)}… (${s.length} chars)';

/// One random act of vandalism against a string.
String _mutate(String s, Random rng) {
  if (s.isEmpty) return s;
  switch (rng.nextInt(6)) {
    case 0: // truncate — the chat-app and cloud-sync failure
      return s.substring(0, rng.nextInt(s.length));
    case 1: // flip a character
      final i = rng.nextInt(s.length);
      return s.replaceRange(i, i + 1, String.fromCharCode(rng.nextInt(128)));
    case 2: // splice something in
      final i = rng.nextInt(s.length);
      return '${s.substring(0, i)}${' !{}[]",:'}${s.substring(i)}';
    case 3: // drop a run
      final i = rng.nextInt(s.length);
      final j = min(s.length, i + rng.nextInt(40));
      return s.replaceRange(i, j, '');
    case 4: // pure noise
      return String.fromCharCodes(
          [for (var i = 0; i < rng.nextInt(200); i++) rng.nextInt(256)]);
    default: // leave it alone — the control case
      return s;
  }
}
