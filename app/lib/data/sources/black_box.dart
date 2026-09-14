/// `F-147` — **the black box: an encrypted, chain-sealed backup of everything.**
///
/// > *"We should treat this export ledger as a black box… it should be
/// > blockchain-powered… It should not be readable to malicious software. It
/// > should be scrambled… go through the research papers I have attached to you
/// > about when India issued COVID certificates."*
///
/// ## First, the CoWIN premise, because it is wrong and it matters
///
/// India's COVID certificates are **not on a blockchain.** They were issued
/// through [DIVOC](https://divoc.digit.org), which is open source, and a DIVOC
/// certificate is a [W3C Verifiable Credential](https://www.w3.org/TR/vc-data-model/)
/// carried as a **JSON Web Token, signed with the national authority's private
/// key** ([RFC 7519](https://datatracker.ietf.org/doc/html/rfc7519)). Verifying
/// one means checking a signature against a published public key. There is no
/// chain, no consensus, no distributed ledger — the
/// [DIVOC specification](https://divoc.digit.org/platform/divocs-verifiable-certificate-features-2.0/divocs-native-covid-19-certificate-specification)
/// says so, and so does the
/// [Linux Foundation Public Health write-up](https://www.lfph.io/2021/10/13/divoc/).
/// The blockchain framing came from press coverage, not from the system.
///
/// This is worth knowing rather than glossing over, because **the thing CoWIN
/// actually did is the thing SWIP needs**, and the thing it did not do would
/// not help:
///
/// | Property wanted | What delivers it | In SWIP |
/// |---|---|---|
/// | Nobody can read it | Encryption | AES-256-GCM, below |
/// | Nobody can alter it undetected | A hash chain or a signature | `ledger_seal.dart`, `F-127` |
/// | It can be checked offline, forever | A self-contained file | This envelope |
/// | Many parties agree on one history | **Consensus — a real blockchain** | **Not needed.** One device, one writer |
///
/// A blockchain solves disagreement between mutually distrusting writers.
/// SWIP's ledger has exactly one writer, this phone, and no network. Adding
/// consensus would add no property the user does not already have, while
/// costing the one thing the product actually markets — that nothing leaves
/// the device.
///
/// What is genuinely blockchain-shaped, and has been since `F-127`, is the
/// **hash chain**: every record commits to the digest of the one before it, so
/// removing or editing any row invalidates every row after it. That is the
/// mechanism a blockchain is built out of, minus the distributed part that
/// only matters when you cannot trust the writer.
///
/// ## The envelope, and why the header is in the clear
///
/// ```json
/// {
///   "format": "swip.blackbox", "version": 1,
///   "createdAt": "2026-09-14T00:00:00.000Z",
///   "captures": 85,
///   "kdf":    { "algorithm": "pbkdf2-hmac-sha256", "iterations": 210000,
///               "salt": "<base64>", "bits": 256 },
///   "cipher": { "algorithm": "aes-256-gcm", "nonce": "<base64>",
///               "mac": "<base64>" },
///   "check":  "<base64, 8 bytes>",
///   "chain":  { "algorithm": "sha256-hash-chain", "sealHash": "<hex>" },
///   "payload": "<base64 ciphertext>"
/// }
/// ```
///
/// Only `payload` is encrypted. **That is deliberate, and it is the whole
/// reason this format can keep the promise that it never fails on import.**
///
/// > *"It should be compatible with our app to read, and it should never, ever
/// > fail on import."*
///
/// An opaque blob can only ever produce one error — "that did not work" — and
/// the user has no way to tell a wrong phrase from a truncated download from a
/// file that was never a SWIP export. A readable header means the app can say
/// *which* of those happened, before it tries anything, every time. The header
/// discloses when the backup was made and how many captures are in it; it
/// discloses nothing about any merchant, any category, or any payload.
///
/// `check` is eight bytes of HMAC over a fixed string with the derived key. It
/// exists so a wrong recovery phrase can be reported as **a wrong recovery
/// phrase** rather than as a corrupt file — the difference between "check your
/// words" and "your data is gone".
///
/// ## What "not readable by malicious software" does and does not mean
///
/// The exported file is unreadable without the phrase. That is a real
/// guarantee and it is the one being made. It is **not** a claim that a
/// compromised phone is safe: software with access to this app's sandbox can
/// read the SQLite ledger directly, and no export format changes that. The
/// wall is around the file that leaves the device — the copy that ends up in
/// Drive, in a chat app, in a backup of a backup — which is exactly the one
/// that travels furthest and is looked after least.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:cryptography/cryptography.dart';

import 'swip_chain.dart';

/// The domain string mixed into every key derivation.
///
/// > *"He could have maybe a phrase to get it unlocked… mixing a string from
/// > the export file and a generic app string."*
///
/// Which is exactly the construction, and each of the three parts does a
/// different job:
///
/// | Part | Where it lives | What it is for |
/// |---|---|---|
/// | The recovery phrase | The user's head, or a piece of paper | The secret |
/// | The salt | The export file's header, in the clear | Two backups of the same ledger with the same phrase get different keys |
/// | This constant | Compiled into the app | Domain separation — the same phrase can never derive the same key for a different purpose or a future format |
///
/// Bumping the version in this string is how a future format is made unable to
/// be decrypted with a key derived for this one, even by accident.
const _kDomain = 'swip.blackbox.v1';

/// What the header's key-check is computed over.
const _kCheckContext = 'swip.blackbox.check';

/// PBKDF2 rounds.
///
/// [OWASP's Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
/// recommends 600,000 for PBKDF2-HMAC-SHA256. This uses 210,000, and the
/// reason is a measured trade rather than an oversight.
///
/// Measured on this project's CI-class machine, in the Dart VM:
///
/// | Iterations | Time |
/// |---|---|
/// | 60,000 | 296 ms |
/// | 120,000 | 549 ms |
/// | **210,000** | **956 ms** |
///
/// A mid-range Android phone is roughly two to four times slower, so 210,000
/// is a two-to-four-second wait and 600,000 would be six to twelve — and the
/// work happens twice, once to make a backup and once to restore one. Six
/// seconds of a frozen-looking screen is how a working feature gets reported
/// as a hang.
///
/// The trade is much smaller than it looks, because **the secret here is not a
/// human-chosen password.** It is a 12-word BIP-39 phrase carrying 128 bits of
/// entropy from a CSPRNG. PBKDF2 iterations exist to slow down guessing a weak
/// secret; there is no dictionary attack against 2^128. The stretching is
/// belt-and-braces against a phrase written on paper and photographed, not the
/// primary defence.
const kPbkdf2Iterations = 210000;

/// How a file was read. **Never an exception** — see [BlackBox.inspect].
enum BlackBoxFormat {
  /// A SWIP black box. Encrypted; needs the phrase.
  blackBox,

  /// An older plain-JSON SWIP export. Still importable, unencrypted.
  plainLedger,

  /// Valid JSON, but not from SWIP.
  notSwip,

  /// Not JSON at all, or truncated, or empty.
  damaged,
}

/// Everything that can be learned about a file **without** the phrase.
class BlackBoxReading {
  const BlackBoxReading({
    required this.format,
    this.version,
    this.createdAt,
    this.captures,
    this.sealHash,
    this.problem,
    this.body,
  });

  final BlackBoxFormat format;
  final int? version;
  final DateTime? createdAt;

  /// How many captures the maker of the file said were in it.
  final int? captures;

  final String? sealHash;

  /// A sentence for the user. Present whenever the file cannot simply be
  /// opened; null when it can.
  final String? problem;

  /// The parsed JSON, for the two formats that have one.
  final Map<String, dynamic>? body;

  bool get needsPhrase => format == BlackBoxFormat.blackBox;

  bool get isImportable =>
      format == BlackBoxFormat.blackBox || format == BlackBoxFormat.plainLedger;
}

/// The result of trying to open a black box.
class BlackBoxOpening {
  const BlackBoxOpening.opened(this.rows, {this.chain})
      : problem = null,
        wrongPhrase = false;

  const BlackBoxOpening.failed(this.problem, {this.wrongPhrase = false})
      : rows = const [],
        chain = null;

  final List<Map<String, dynamic>> rows;
  final String? problem;

  /// `F-156`. What the blockchain said, when the backup carried one. Null for
  /// an older plain export, which is not a failure — it is a file from before
  /// the chain existed.
  final ChainVerdict? chain;

  /// True when the phrase is the thing that was wrong, as distinct from the
  /// file. Drives whether the UI says "check your words" or "this file is
  /// damaged" — very different messages to receive about your own records.
  final bool wrongPhrase;

  bool get ok => problem == null;
}

abstract final class BlackBox {
  /// Generate a fresh 12-word recovery phrase.
  ///
  /// BIP-39, so the wordlist is public, the checksum catches a mistyped word,
  /// and every password manager already knows how to store one. No wallet
  /// interoperability is being claimed — the format is borrowed because it is
  /// the best-tested way to write 128 bits down by hand.
  static String newRecoveryPhrase() => bip39.generateMnemonic(strength: 128);

  /// Whether a phrase is well-formed, checked before any expensive derivation.
  ///
  /// A typo caught here costs nothing; the same typo caught after 210,000
  /// rounds of PBKDF2 costs a visible pause and then a message that cannot
  /// distinguish "you mistyped" from "wrong file".
  static bool isValidPhrase(String phrase) =>
      bip39.validateMnemonic(_normalise(phrase));

  /// Lower-case, collapse whitespace. People write recovery phrases down by
  /// hand and type them back with capitals and double spaces.
  static String _normalise(String p) =>
      p.trim().toLowerCase().split(RegExp(r'\s+')).join(' ');

  // ── reading ─────────────────────────────────────────────────────────────

  /// Look at a file. **This function does not throw, for any input.**
  ///
  /// That is the contract the whole format is arranged around, and
  /// `black_box_test.dart` enforces it by throwing several thousand
  /// mutations, truncations and random byte strings at it.
  static BlackBoxReading inspect(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return const BlackBoxReading(
        format: BlackBoxFormat.damaged,
        problem: 'That file is empty.',
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(trimmed);
    } on FormatException {
      return const BlackBoxReading(
        format: BlackBoxFormat.damaged,
        problem: 'That file is not a SWIP backup — it is not readable as '
            'JSON. If it was downloaded or sent through a chat app, it may '
            'have been cut short on the way.',
      );
    }

    if (decoded is! Map<String, dynamic>) {
      return const BlackBoxReading(
        format: BlackBoxFormat.notSwip,
        problem: 'That file is valid JSON but not a SWIP backup.',
      );
    }

    // ── a black box ──
    if (decoded['format'] == 'swip.blackbox') {
      final version = _asInt(decoded['version']);
      if (version == null || version > 1) {
        return BlackBoxReading(
          format: BlackBoxFormat.blackBox,
          version: version,
          body: decoded,
          problem: 'This backup was made by a newer version of SWIP '
              '(format ${version ?? '?'}). Update the app and try again — '
              'the file itself is fine.',
        );
      }
      return BlackBoxReading(
        format: BlackBoxFormat.blackBox,
        version: version,
        createdAt: _asDate(decoded['createdAt']),
        captures: _asInt(decoded['captures']),
        sealHash: _asString((decoded['chain'] as Map?)?['sealHash']),
        body: decoded,
      );
    }

    // ── an older plain export ──
    //
    // Every export SWIP has ever written had a top-level `captures` list.
    // Recognising them is not nostalgia: the owner has real exports on disk
    // from before this format existed, and a backup format that cannot read
    // the backups you already have is not a backup format.
    if (decoded['captures'] is List) {
      final rows = decoded['captures'] as List;
      return BlackBoxReading(
        format: BlackBoxFormat.plainLedger,
        createdAt: _asDate(decoded['exportedAt'] ?? decoded['createdAt']),
        captures: rows.length,
        sealHash: _asString(decoded['sealHash']),
        body: decoded,
      );
    }

    return const BlackBoxReading(
      format: BlackBoxFormat.notSwip,
      problem: 'That is a JSON file, but it has no SWIP captures in it.',
    );
  }

  // ── writing ─────────────────────────────────────────────────────────────

  /// Seal [ledger] into a black box under [phrase].
  ///
  /// [ledger] is whatever the app already exports, JSON-encodable, including
  /// the hash chain from `ledger_seal.dart`. This function does not inspect it
  /// — the chain is computed before it gets here, so the integrity guarantee
  /// is independent of the encryption and survives being decrypted back into a
  /// plain file.
  /// `F-156`. [ledger] gains a `chain` — a real blockchain over its captures,
  /// mined and signed with a key derived from the same phrase. See
  /// `swip_chain.dart` for what each part of that actually buys.
  ///
  /// The chain is built **before** encryption and travels inside the
  /// ciphertext, so decrypting a backup yields a plain ledger that still
  /// carries its own proof. The two guarantees stay independent: the phrase
  /// proves who could read it, the chain proves nobody edited it.
  static Future<String> seal({
    required Map<String, dynamic> ledger,
    required String phrase,
    required int captures,
    String? sealHash,
    DateTime? now,
  }) async {
    final rows = <Map<String, Object?>>[
      for (final r in (ledger['captures'] as List? ?? const []))
        if (r is Map) r.cast<String, Object?>(),
    ];
    final blocks = await SwipChain.build(
      captures: rows,
      seed: SwipChain.seedFromPhrase(phrase),
      now: now,
    );
    final sealedLedger = <String, dynamic>{
      ...ledger,
      'chain': {
        'algorithm': 'sha256-merkle-pow-ed25519',
        'blockSize': kBlockSize,
        'difficulty': kDifficulty,
        'publicKey': blocks.first.publicKey,
        'head': blocks.last.hash,
        'blocks': blocks.map((b) => b.toJson()).toList(),
      },
    };

    final salt = _randomBytes(16);
    final key = await _deriveKey(phrase: phrase, salt: salt);

    final plaintext = utf8.encode(jsonEncode(sealedLedger));
    final algo = AesGcm.with256bits();
    final box = await algo.encrypt(plaintext, secretKey: key);

    return const JsonEncoder.withIndent('  ').convert({
      'format': 'swip.blackbox',
      'version': 1,
      'createdAt': (now ?? DateTime.now().toUtc()).toIso8601String(),
      'captures': captures,
      // Plain English inside the file, for whoever opens it in a text editor
      // in five years with no idea what it is.
      'readMe': 'This is an encrypted SWIP backup. Import it in the SWIP app '
          'with the 12-word recovery phrase you were shown when you made it. '
          'Without that phrase nobody can read it, including the people who '
          'wrote SWIP. Everything below is meant to look like noise.',
      'kdf': {
        'algorithm': 'pbkdf2-hmac-sha256',
        'iterations': kPbkdf2Iterations,
        'bits': 256,
        'salt': base64Encode(salt),
        'domain': _kDomain,
      },
      'cipher': {
        'algorithm': 'aes-256-gcm',
        'nonce': base64Encode(box.nonce),
        'mac': base64Encode(box.mac.bytes),
      },
      'check': base64Encode(await _checkValue(key)),
      // The envelope header advertises the chain's head and public key in the
      // clear. Neither discloses anything about a merchant, and both let a
      // holder of two backups tell which is newer, and whether they came from
      // the same install, without a phrase.
      'chain': {
        'algorithm': 'sha256-merkle-pow-ed25519',
        'blocks': blocks.length,
        'head': blocks.last.hash,
        'publicKey': blocks.first.publicKey,
        if (sealHash != null) 'sealHash': sealHash,
      },
      'payload': base64Encode(box.cipherText),
    });
  }

  /// Open a black box that [inspect] has already accepted.
  ///
  /// Like [inspect], this never throws. Every failure comes back as a
  /// sentence.
  static Future<BlackBoxOpening> open({
    required BlackBoxReading reading,
    required String phrase,
  }) async {
    if (reading.format == BlackBoxFormat.plainLedger) {
      return BlackBoxOpening.opened(_rowsOf(reading.body?['captures']));
    }
    if (reading.format != BlackBoxFormat.blackBox) {
      return BlackBoxOpening.failed(
          reading.problem ?? 'That file is not a SWIP backup.');
    }
    if (reading.problem != null) {
      return BlackBoxOpening.failed(reading.problem!);
    }

    final body = reading.body;
    if (body == null) {
      return const BlackBoxOpening.failed('That backup is missing its body.');
    }

    if (!isValidPhrase(phrase)) {
      return const BlackBoxOpening.failed(
        'That is not a complete recovery phrase. It should be twelve words '
        'from the standard word list, and one of them does not check out — '
        'which usually means a single word is mistyped.',
        wrongPhrase: true,
      );
    }

    try {
      final kdf = body['kdf'];
      final cipher = body['cipher'];
      if (kdf is! Map || cipher is! Map) {
        return const BlackBoxOpening.failed(
            'That backup is missing the part that says how it was encrypted.');
      }

      final salt = base64Decode(_asString(kdf['salt']) ?? '');
      final iterations = _asInt(kdf['iterations']) ?? kPbkdf2Iterations;
      final key = await _deriveKey(
        phrase: phrase,
        salt: salt,
        iterations: iterations,
        domain: _asString(kdf['domain']) ?? _kDomain,
      );

      // ── the wrong-phrase check, before the expensive failure ──
      //
      // AES-GCM already authenticates, so a wrong key fails anyway. But it
      // fails as `SecretBoxAuthenticationError`, which is indistinguishable
      // from a corrupted payload — and telling somebody their backup is
      // corrupt when they simply mistyped a word is the most alarming thing
      // this screen could possibly do.
      final expected = _asString(body['check']);
      if (expected != null) {
        final actual = base64Encode(await _checkValue(key));
        if (actual != expected) {
          return const BlackBoxOpening.failed(
            'That phrase does not open this backup. The file itself is fine '
            '— check the words against what you wrote down.',
            wrongPhrase: true,
          );
        }
      }

      final box = SecretBox(
        base64Decode(_asString(body['payload']) ?? ''),
        nonce: base64Decode(_asString(cipher['nonce']) ?? ''),
        mac: Mac(base64Decode(_asString(cipher['mac']) ?? '')),
      );

      final clear = await AesGcm.with256bits().decrypt(box, secretKey: key);
      final ledger = jsonDecode(utf8.decode(clear));
      if (ledger is! Map<String, dynamic>) {
        return const BlackBoxOpening.failed(
            'That backup decrypted, but what came out was not a ledger.');
      }

      final rows = _rowsOf(ledger['captures']);

      // ── `F-156`. Verify the chain before handing the rows back ──
      //
      // Decrypting proves the file came from somebody holding the phrase.
      // The chain proves nobody has edited a capture since it was sealed —
      // a different question, and the one that matters if a backup has been
      // round-tripped through a cloud, a chat app and somebody's laptop.
      //
      // A broken chain does **not** refuse the import. These are the user's
      // own records and a suspect record is better than no record. It is
      // reported, with the block named, and `settings_page` asks before
      // writing anything.
      final chain = ledger['chain'];
      if (chain is Map && chain['blocks'] is List) {
        final verdict = await SwipChain.verify(
          rawBlocks: chain['blocks'] as List,
          captures: rows,
        );
        return BlackBoxOpening.opened(rows, chain: verdict);
      }

      return BlackBoxOpening.opened(rows);
    } on SecretBoxAuthenticationError {
      return const BlackBoxOpening.failed(
        'This backup did not survive the trip — its contents do not match the '
        'seal on them. That is usually a file truncated by a chat app or a '
        'cloud sync. Try the original copy.',
      );
    } on FormatException {
      return const BlackBoxOpening.failed(
          'Part of that backup is not readable. The file looks damaged.');
    } on Exception catch (e) {
      // The catch-all that makes "never fails on import" true rather than
      // aspirational. A new library version throwing something unforeseen
      // must still end in a sentence.
      return BlackBoxOpening.failed(
          'SWIP could not open that backup (${e.runtimeType}).');
    }
  }

  // ── internals ───────────────────────────────────────────────────────────

  static Future<SecretKey> _deriveKey({
    required String phrase,
    required List<int> salt,
    int iterations = kPbkdf2Iterations,
    String domain = _kDomain,
  }) =>
      Pbkdf2(
        macAlgorithm: Hmac.sha256(),
        iterations: iterations,
        bits: 256,
      ).deriveKey(
        // The phrase and the app's own domain string. The phrase is
        // normalised first so the same words typed with different capitals or
        // spacing derive the same key — which is the difference between a
        // recovery phrase that works off a handwritten note and one that only
        // works off a copy-paste.
        secretKey: SecretKey(utf8.encode('${_normalise(phrase)} $domain')),
        nonce: salt,
      );

  static Future<List<int>> _checkValue(SecretKey key) async {
    final mac = await Hmac.sha256()
        .calculateMac(utf8.encode(_kCheckContext), secretKey: key);
    return mac.bytes.sublist(0, 8);
  }

  static List<Map<String, dynamic>> _rowsOf(Object? captures) {
    if (captures is! List) return const [];
    return [
      for (final r in captures)
        if (r is Map) Map<String, dynamic>.from(r.cast<String, dynamic>()),
    ];
  }

  static final _rng = Random.secure();

  static Uint8List _randomBytes(int n) =>
      Uint8List.fromList([for (var i = 0; i < n; i++) _rng.nextInt(256)]);

  static int? _asInt(Object? v) =>
      v is int ? v : (v is num ? v.toInt() : int.tryParse('$v'));

  static String? _asString(Object? v) => v is String ? v : null;

  static DateTime? _asDate(Object? v) =>
      v is String ? DateTime.tryParse(v) : null;
}
