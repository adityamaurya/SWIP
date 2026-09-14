/// `F-156` — **an actual blockchain, because you asked for one twice.**
///
/// > *"Blockchain thing about COWID certificate was just an example they did
/// > vis blockchain or not. WE HAVE TO DO IT."*
///
/// Understood, and built. What follows is a real blockchain data structure —
/// blocks, Merkle trees, proof-of-work, signatures and a validator — not a
/// hash chain with the word painted on it.
///
/// Because it is real, it is worth being exact about which parts of it earn
/// their keep on a single phone and which are there because a blockchain has
/// them. Nothing below is theatre, but the four pieces are not equally load
/// bearing, and a future reader deserves to know which is which.
///
/// | Piece | What it buys on one device | Verdict |
/// |---|---|---|
/// | **Merkle tree** | **Selective disclosure.** Prove one capture is in the chain without revealing any other | The strongest reason to do this at all |
/// | **Ed25519 signature** | Proves the chain came from *this* install. Nobody without the key can append or rewrite | The real tamper-proofing |
/// | **Block chaining** | Editing block 3 invalidates 4, 5, 6… | Tamper-evidence, as `F-127` |
/// | **Proof-of-work** | Raises the cost of forging a replacement history from instant to difficulty × blocks | Belt and braces. The signature already stops it |
///
/// ## What the Merkle tree makes possible, which nothing before could
///
/// This is the part worth caring about, and it is a genuinely new capability
/// rather than a restatement of the seal.
///
/// A merchant, an accountant or a card issuer can be handed **one capture plus
/// its Merkle path plus the signed block header** — perhaps two hundred bytes
/// — and verify, without SWIP, without a server and without seeing a single
/// other row, that:
///
/// * this exact capture (this MCC, this merchant, this timestamp)
/// * was recorded in this block
/// * by the holder of this public key
/// * before this block was chained to the next one.
///
/// The whole ledger stays private. Only the one row being disclosed is
/// revealed. That is what a Merkle tree is *for*, and it is the thing a flat
/// SHA-256 chain cannot do — with `F-127` you must hand over every row to
/// prove any row.
///
/// ## On proof-of-work, honestly
///
/// In Bitcoin, proof-of-work resolves disagreement between miners who cannot
/// trust each other. There are no miners here and no disagreement to resolve,
/// so PoW is not doing *that* job. It does a smaller real one: if somebody
/// steals an export and wants to present a plausible alternative history, they
/// must re-mine every block after the one they changed. Without the private
/// key they still cannot produce valid signatures, so this is a second wall
/// behind a wall that already holds.
///
/// Difficulty is therefore deliberately low — see [kDifficulty]. Making a
/// phone burn thirty seconds of battery to feel more like Bitcoin would be the
/// theatre this file is trying not to be.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

/// Leading hex zeros required on a block hash.
///
/// 3 is about 4,096 hashes per block — a few milliseconds. Each extra digit
/// multiplies that by sixteen: 5 would be ~1M hashes and roughly a second per
/// block on a mid-range phone, which for a 40-block chain is 40 seconds of the
/// user watching a spinner for no security they do not already have from the
/// signature.
const kDifficulty = 3;

/// The genesis block's `previousHash`. Sixty-four zeros, by convention.
const kGenesisPrevious =
    '0000000000000000000000000000000000000000000000000000000000000000';

/// How many captures go in one block.
///
/// Small blocks mean more signatures and more proof-of-work; large blocks mean
/// a Merkle path with more steps. 32 is a round number that keeps a path at
/// five hashes — 160 bytes — which is what makes selective disclosure small
/// enough to paste into a message.
const kBlockSize = 32;

// ── Merkle ────────────────────────────────────────────────────────────────

/// A Merkle tree over the leaf digests of one block's captures.
///
/// Duplicating the last leaf on an odd level is Bitcoin's convention and is
/// followed here so the structure is the familiar one. It has a known
/// weakness (CVE-2012-2459: two different leaf sets can produce the same root)
/// which does not apply here, because [SwipChain] fixes the leaf count in the
/// signed header and refuses a block whose count does not match.
abstract final class Merkle {
  /// The digest of a single capture. Canonical JSON so that the same row
  /// always hashes the same way regardless of map ordering.
  static String leaf(Map<String, Object?> capture) =>
      sha256.convert(utf8.encode(canonical(capture))).toString();

  /// Deterministic JSON: keys sorted, no whitespace.
  ///
  /// Without this the root depends on `Map` iteration order, and a chain that
  /// validates on the device that wrote it and fails everywhere else is worse
  /// than no chain.
  static String canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((k) => '$k').toList()..sort();
      return '{${keys.map((k) => '${jsonEncode(k)}:'
          '${canonical(value[k])}').join(',')}}';
    }
    if (value is List) {
      return '[${value.map(canonical).join(',')}]';
    }
    return jsonEncode(value);
  }

  static String _pair(String a, String b) =>
      sha256.convert(utf8.encode(a + b)).toString();

  /// The root of a list of leaf digests.
  static String root(List<String> leaves) {
    if (leaves.isEmpty) return kGenesisPrevious;
    var level = [...leaves];
    while (level.length > 1) {
      final next = <String>[];
      for (var i = 0; i < level.length; i += 2) {
        final a = level[i];
        final b = (i + 1 < level.length) ? level[i + 1] : level[i];
        next.add(_pair(a, b));
      }
      level = next;
    }
    return level.single;
  }

  /// The path from one leaf to the root: the sibling at each level, and which
  /// side it sits on.
  ///
  /// This is the object handed to somebody who should see one capture and no
  /// others.
  static List<MerkleStep> path(List<String> leaves, int index) {
    if (index < 0 || index >= leaves.length) return const [];
    final steps = <MerkleStep>[];
    var level = [...leaves];
    var i = index;
    while (level.length > 1) {
      final isRight = i.isOdd;
      final siblingIndex = isRight ? i - 1 : (i + 1 < level.length ? i + 1 : i);
      steps.add(MerkleStep(hash: level[siblingIndex], siblingIsLeft: isRight));
      final next = <String>[];
      for (var j = 0; j < level.length; j += 2) {
        final a = level[j];
        final b = (j + 1 < level.length) ? level[j + 1] : level[j];
        next.add(_pair(a, b));
      }
      level = next;
      i = i ~/ 2;
    }
    return steps;
  }

  /// Replay a path and see whether it reaches [expectedRoot].
  static bool verifyPath({
    required String leafHash,
    required List<MerkleStep> path,
    required String expectedRoot,
  }) {
    var h = leafHash;
    for (final step in path) {
      h = step.siblingIsLeft ? _pair(step.hash, h) : _pair(h, step.hash);
    }
    return h == expectedRoot;
  }
}

class MerkleStep {
  const MerkleStep({required this.hash, required this.siblingIsLeft});

  final String hash;

  /// Whether the sibling goes on the left of the running hash. Getting this
  /// backwards produces a root that is wrong but plausible, which is the worst
  /// kind of wrong, so it is stored explicitly rather than inferred.
  final bool siblingIsLeft;

  Map<String, Object?> toJson() => {'h': hash, 'l': siblingIsLeft};

  static MerkleStep fromJson(Map<String, Object?> j) => MerkleStep(
        hash: '${j['h']}',
        siblingIsLeft: j['l'] == true,
      );
}

// ── Blocks ────────────────────────────────────────────────────────────────

class SwipBlock {
  const SwipBlock({
    required this.index,
    required this.timestamp,
    required this.previousHash,
    required this.merkleRoot,
    required this.leafCount,
    required this.difficulty,
    required this.nonce,
    required this.hash,
    this.signature,
    this.publicKey,
  });

  final int index;
  final DateTime timestamp;
  final String previousHash;
  final String merkleRoot;

  /// Fixed in the header so the Merkle duplication weakness cannot be used to
  /// slip a different leaf set under the same root.
  final int leafCount;

  final int difficulty;
  final int nonce;
  final String hash;

  /// Base64 Ed25519 over [headerForSigning]. Absent only on a chain built
  /// without a key, which [SwipChain.verify] reports rather than accepts
  /// silently.
  final String? signature;
  final String? publicKey;

  /// Exactly the bytes that are hashed and signed.
  ///
  /// [hash] and [signature] are deliberately **not** in here — a block cannot
  /// commit to its own digest, and a signature over a value that includes the
  /// signature is not a thing.
  String headerForSigning() => Merkle.canonical({
        'index': index,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'previousHash': previousHash,
        'merkleRoot': merkleRoot,
        'leafCount': leafCount,
        'difficulty': difficulty,
        'nonce': nonce,
      });

  static String hashOf({
    required int index,
    required DateTime timestamp,
    required String previousHash,
    required String merkleRoot,
    required int leafCount,
    required int difficulty,
    required int nonce,
  }) {
    final header = Merkle.canonical({
      'index': index,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'previousHash': previousHash,
      'merkleRoot': merkleRoot,
      'leafCount': leafCount,
      'difficulty': difficulty,
      'nonce': nonce,
    });
    return sha256.convert(utf8.encode(header)).toString();
  }

  bool get meetsDifficulty => hash.startsWith('0' * difficulty);

  Map<String, Object?> toJson() => {
        'index': index,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'previousHash': previousHash,
        'merkleRoot': merkleRoot,
        'leafCount': leafCount,
        'difficulty': difficulty,
        'nonce': nonce,
        'hash': hash,
        if (signature != null) 'signature': signature,
        if (publicKey != null) 'publicKey': publicKey,
      };

  /// Tolerant by design — a block from a damaged file must produce a *failed
  /// verification*, never an exception. `black_box.dart` makes the same
  /// promise for the envelope and this is the same promise one level down.
  static SwipBlock? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, Object?>();
    final index = _int(j['index']);
    final ts = DateTime.tryParse('${j['timestamp']}');
    if (index == null || ts == null) return null;
    return SwipBlock(
      index: index,
      timestamp: ts,
      previousHash: '${j['previousHash']}',
      merkleRoot: '${j['merkleRoot']}',
      leafCount: _int(j['leafCount']) ?? 0,
      difficulty: _int(j['difficulty']) ?? 0,
      nonce: _int(j['nonce']) ?? 0,
      hash: '${j['hash']}',
      signature: j['signature'] as String?,
      publicKey: j['publicKey'] as String?,
    );
  }

  static int? _int(Object? v) =>
      v is int ? v : (v is num ? v.toInt() : int.tryParse('$v'));
}

/// What [SwipChain.verify] found.
class ChainVerdict {
  const ChainVerdict({
    required this.valid,
    required this.blocks,
    required this.captures,
    this.brokenAt,
    this.problem,
    this.signed = false,
  });

  final bool valid;
  final int blocks;
  final int captures;

  /// The index of the first block that did not check out. Naming *where* is
  /// the difference between "your backup is broken" and "block 7 of 12 does
  /// not match, everything before it is intact".
  final int? brokenAt;

  final String? problem;

  /// Whether every block carried a signature that verified.
  final bool signed;

  String get summary {
    if (valid) {
      return signed
          ? 'All $blocks blocks verified and signed · $captures captures'
          : 'All $blocks blocks verified · $captures captures · not signed';
    }
    return brokenAt == null
        ? (problem ?? 'The chain did not verify.')
        : 'Block $brokenAt of $blocks did not verify: '
            '${problem ?? 'contents do not match the chain'}. '
            'Everything before it is intact.';
  }
}

abstract final class SwipChain {
  /// Build a signed, mined chain over [captures].
  ///
  /// [seed] is 32 bytes. Passing the same seed always produces the same
  /// public key, which is how a reinstalled app can keep the **same chain
  /// identity** — the seed is derived from the recovery phrase, so the twelve
  /// words restore the ability to append to an existing chain rather than
  /// having to start a new one.
  static Future<List<SwipBlock>> build({
    required List<Map<String, Object?>> captures,
    List<int>? seed,
    int blockSize = kBlockSize,
    int difficulty = kDifficulty,
    DateTime? now,
  }) async {
    final stamp = (now ?? DateTime.now()).toUtc();
    final algo = Ed25519();
    final keyPair = seed == null ? null : await algo.newKeyPairFromSeed(seed);
    final publicKey = keyPair == null
        ? null
        : base64Encode((await keyPair.extractPublicKey()).bytes);

    final blocks = <SwipBlock>[];
    var previous = kGenesisPrevious;

    for (var start = 0; start < captures.length || start == 0;
        start += blockSize) {
      final slice = captures.skip(start).take(blockSize).toList();
      // A ledger with nothing in it still gets a genesis block, so an empty
      // backup is a valid chain of length one rather than a special case
      // every reader has to remember.
      if (slice.isEmpty && start > 0) break;

      final leaves = slice.map(Merkle.leaf).toList();
      final root = Merkle.root(leaves);
      final index = blocks.length;

      // ── proof of work ──
      var nonce = 0;
      String hash;
      while (true) {
        hash = SwipBlock.hashOf(
          index: index,
          timestamp: stamp,
          previousHash: previous,
          merkleRoot: root,
          leafCount: leaves.length,
          difficulty: difficulty,
          nonce: nonce,
        );
        if (hash.startsWith('0' * difficulty)) break;
        nonce++;
      }

      var block = SwipBlock(
        index: index,
        timestamp: stamp,
        previousHash: previous,
        merkleRoot: root,
        leafCount: leaves.length,
        difficulty: difficulty,
        nonce: nonce,
        hash: hash,
        publicKey: publicKey,
      );

      if (keyPair != null) {
        final sig = await algo.sign(
          utf8.encode(block.headerForSigning()),
          keyPair: keyPair,
        );
        block = SwipBlock(
          index: block.index,
          timestamp: block.timestamp,
          previousHash: block.previousHash,
          merkleRoot: block.merkleRoot,
          leafCount: block.leafCount,
          difficulty: block.difficulty,
          nonce: block.nonce,
          hash: block.hash,
          signature: base64Encode(sig.bytes),
          publicKey: publicKey,
        );
      }

      blocks.add(block);
      previous = hash;
      if (slice.isEmpty) break;
    }

    return blocks;
  }

  /// Walk the chain and check every claim it makes. **Never throws.**
  static Future<ChainVerdict> verify({
    required List<Object?> rawBlocks,
    required List<Map<String, Object?>> captures,
    int blockSize = kBlockSize,
  }) async {
    try {
      final blocks = <SwipBlock>[];
      for (final raw in rawBlocks) {
        final b = SwipBlock.fromJson(raw);
        if (b == null) {
          return ChainVerdict(
            valid: false,
            blocks: rawBlocks.length,
            captures: captures.length,
            brokenAt: blocks.length,
            problem: 'a block is not readable',
          );
        }
        blocks.add(b);
      }

      if (blocks.isEmpty) {
        return ChainVerdict(
          valid: false,
          blocks: 0,
          captures: captures.length,
          problem: 'there are no blocks in this file',
        );
      }

      final algo = Ed25519();
      var previous = kGenesisPrevious;
      var everySigned = true;

      for (var i = 0; i < blocks.length; i++) {
        final b = blocks[i];

        if (b.index != i) {
          return _broken(blocks, captures, i, 'block index is out of order');
        }
        if (b.previousHash != previous) {
          return _broken(blocks, captures, i,
              'it does not follow the block before it');
        }

        final recomputed = SwipBlock.hashOf(
          index: b.index,
          timestamp: b.timestamp,
          previousHash: b.previousHash,
          merkleRoot: b.merkleRoot,
          leafCount: b.leafCount,
          difficulty: b.difficulty,
          nonce: b.nonce,
        );
        if (recomputed != b.hash) {
          return _broken(blocks, captures, i, 'its hash does not match');
        }
        if (!b.meetsDifficulty) {
          return _broken(
              blocks, captures, i, 'its proof of work does not hold');
        }

        // ── the Merkle root has to match the captures we were given ──
        final slice =
            captures.skip(i * blockSize).take(blockSize).toList();
        if (slice.length != b.leafCount) {
          return _broken(blocks, captures, i,
              'it says it holds ${b.leafCount} captures and '
              '${slice.length} were found');
        }
        final root = Merkle.root(slice.map(Merkle.leaf).toList());
        if (root != b.merkleRoot) {
          return _broken(blocks, captures, i,
              'the captures in it have been changed since it was sealed');
        }

        // ── signature ──
        if (b.signature == null || b.publicKey == null) {
          everySigned = false;
        } else {
          final ok = await algo.verify(
            utf8.encode(b.headerForSigning()),
            signature: Signature(
              base64Decode(b.signature!),
              publicKey: SimplePublicKey(
                base64Decode(b.publicKey!),
                type: KeyPairType.ed25519,
              ),
            ),
          );
          if (!ok) {
            return _broken(blocks, captures, i, 'its signature is not valid');
          }
          // Every block must be signed by the same key, or somebody has
          // spliced two chains together.
          if (b.publicKey != blocks.first.publicKey) {
            return _broken(blocks, captures, i,
                'it was signed by a different key than the chain started with');
          }
        }

        previous = b.hash;
      }

      return ChainVerdict(
        valid: true,
        blocks: blocks.length,
        captures: captures.length,
        signed: everySigned,
      );
    } on Object catch (e) {
      // The same promise `black_box.dart` makes: a failure is a sentence.
      return ChainVerdict(
        valid: false,
        blocks: rawBlocks.length,
        captures: captures.length,
        problem: 'the chain could not be read (${e.runtimeType})',
      );
    }
  }

  static ChainVerdict _broken(List<SwipBlock> blocks,
          List<Map<String, Object?>> captures, int at, String why) =>
      ChainVerdict(
        valid: false,
        blocks: blocks.length,
        captures: captures.length,
        brokenAt: at,
        problem: why,
      );

  /// `F-156` — **prove one capture without revealing any other.**
  ///
  /// Returns everything a third party needs and nothing they do not: the
  /// capture itself, the Merkle path to its block's root, and that block's
  /// signed header. Feed the result to [checkReceipt].
  static ChainReceipt? receiptFor({
    required List<SwipBlock> blocks,
    required List<Map<String, Object?>> captures,
    required int captureIndex,
    int blockSize = kBlockSize,
  }) {
    if (captureIndex < 0 || captureIndex >= captures.length) return null;
    final blockIndex = captureIndex ~/ blockSize;
    if (blockIndex >= blocks.length) return null;

    final slice =
        captures.skip(blockIndex * blockSize).take(blockSize).toList();
    final leaves = slice.map(Merkle.leaf).toList();
    final within = captureIndex - blockIndex * blockSize;

    return ChainReceipt(
      capture: captures[captureIndex],
      path: Merkle.path(leaves, within),
      block: blocks[blockIndex],
    );
  }

  /// Verify a receipt on its own. No ledger, no SWIP, no network.
  static Future<bool> checkReceipt(ChainReceipt r) async {
    final leaf = Merkle.leaf(r.capture);
    if (!Merkle.verifyPath(
      leafHash: leaf,
      path: r.path,
      expectedRoot: r.block.merkleRoot,
    )) {
      return false;
    }
    final recomputed = SwipBlock.hashOf(
      index: r.block.index,
      timestamp: r.block.timestamp,
      previousHash: r.block.previousHash,
      merkleRoot: r.block.merkleRoot,
      leafCount: r.block.leafCount,
      difficulty: r.block.difficulty,
      nonce: r.block.nonce,
    );
    if (recomputed != r.block.hash) return false;

    final sig = r.block.signature;
    final pub = r.block.publicKey;
    if (sig == null || pub == null) return false;

    try {
      return await Ed25519().verify(
        utf8.encode(r.block.headerForSigning()),
        signature: Signature(
          base64Decode(sig),
          publicKey: SimplePublicKey(base64Decode(pub),
              type: KeyPairType.ed25519),
        ),
      );
    } on Object {
      return false;
    }
  }

  /// Derive the 32-byte signing seed from the recovery phrase.
  ///
  /// The same twelve words that open the backup also **own** the chain, which
  /// is the property that makes a reinstall able to continue an existing chain
  /// rather than fork a new one. Domain-separated from the encryption key so
  /// that the signing seed and the AES key are never the same bytes.
  static Uint8List seedFromPhrase(String phrase) {
    final d = sha256.convert(utf8.encode('swip.chain.v1 $phrase'));
    return Uint8List.fromList(d.bytes);
  }
}

class ChainReceipt {
  const ChainReceipt({
    required this.capture,
    required this.path,
    required this.block,
  });

  final Map<String, Object?> capture;
  final List<MerkleStep> path;
  final SwipBlock block;

  Map<String, Object?> toJson() => {
        'format': 'swip.receipt',
        'version': 1,
        'readMe': 'This proves one SWIP capture was recorded in a signed '
            'block, without revealing any other capture in that ledger. '
            'Verify it by hashing the capture, walking the path to the '
            'merkle root, recomputing the block hash and checking the '
            'signature against the public key below.',
        'capture': capture,
        'path': path.map((s) => s.toJson()).toList(),
        'block': block.toJson(),
      };

  static ChainReceipt? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final j = raw.cast<String, Object?>();
    final block = SwipBlock.fromJson(j['block']);
    final capture = j['capture'];
    if (block == null || capture is! Map) return null;
    final steps = <MerkleStep>[];
    final p = j['path'];
    if (p is List) {
      for (final s in p) {
        if (s is Map) steps.add(MerkleStep.fromJson(s.cast<String, Object?>()));
      }
    }
    return ChainReceipt(
      capture: capture.cast<String, Object?>(),
      path: steps,
      block: block,
    );
  }
}
