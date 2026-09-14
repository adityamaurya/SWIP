import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:swip/data/sources/swip_chain.dart';

/// `F-156` — the blockchain.
///
/// Most of this file is adversarial: it builds a valid chain and then tries to
/// cheat it in every way somebody holding the file could. A blockchain that
/// has not been attacked in its own test suite is a data structure with a
/// marketing name.
void main() {
  List<Map<String, Object?>> ledger(int n) => [
        for (var i = 0; i < n; i++)
          {
            'id': 'cap-$i',
            'mcc': i.isEven ? '5912' : null,
            'merchant_name': 'SHOP $i',
            'amount': i * 10.0,
            'captured_at': '2026-09-0${(i % 9) + 1}T10:00:00.000Z',
          },
      ];

  final seed = SwipChain.seedFromPhrase(
      'abandon ability able about above absent absorb abstract absurd abuse '
      'access accident');

  group('canonical encoding', () {
    test('key order does not change a hash', () {
      // Without this the root depends on Map iteration order, and a chain that
      // validates on the device that wrote it and nowhere else is worse than
      // no chain at all.
      final a = <String, Object?>{'b': 2, 'a': 1, 'c': null};
      final b = <String, Object?>{'c': null, 'a': 1, 'b': 2};
      expect(Merkle.canonical(a), Merkle.canonical(b));
      expect(Merkle.leaf(a), Merkle.leaf(b));
    });

    test('nested maps and lists are canonical too', () {
      final a = {
        'x': [
          {'q': 1, 'p': 2}
        ]
      };
      final b = {
        'x': [
          {'p': 2, 'q': 1}
        ]
      };
      expect(Merkle.canonical(a), Merkle.canonical(b));
    });
  });

  group('merkle', () {
    test('a root over one leaf is that leaf', () {
      expect(Merkle.root(['aa']), 'aa');
    });

    test('changing any leaf changes the root', () {
      final leaves = [for (var i = 0; i < 9; i++) Merkle.leaf({'i': i})];
      final before = Merkle.root(leaves);
      for (var i = 0; i < leaves.length; i++) {
        final mutated = [...leaves]..[i] = Merkle.leaf({'i': 999});
        expect(Merkle.root(mutated), isNot(before), reason: 'leaf $i');
      }
    });

    test('every leaf has a path that reaches the root', () {
      // Odd counts exercise the duplicate-last-leaf case, which is where a
      // hand-rolled Merkle implementation almost always goes wrong.
      for (final n in [1, 2, 3, 5, 8, 9, 17, 32]) {
        final leaves = [for (var i = 0; i < n; i++) Merkle.leaf({'i': i})];
        final root = Merkle.root(leaves);
        for (var i = 0; i < n; i++) {
          expect(
            Merkle.verifyPath(
              leafHash: leaves[i],
              path: Merkle.path(leaves, i),
              expectedRoot: root,
            ),
            isTrue,
            reason: 'n=$n leaf=$i',
          );
        }
      }
    });

    test('a path does not verify a leaf that is not in the tree', () {
      final leaves = [for (var i = 0; i < 8; i++) Merkle.leaf({'i': i})];
      expect(
        Merkle.verifyPath(
          leafHash: Merkle.leaf({'i': 'forged'}),
          path: Merkle.path(leaves, 3),
          expectedRoot: Merkle.root(leaves),
        ),
        isFalse,
      );
    });
  });

  group('a built chain', () {
    test('links, mines and signs every block', () async {
      final captures = ledger(70); // three blocks at 32
      final blocks = await SwipChain.build(captures: captures, seed: seed);

      expect(blocks.length, 3);
      expect(blocks.first.previousHash, kGenesisPrevious);
      for (var i = 0; i < blocks.length; i++) {
        expect(blocks[i].index, i);
        expect(blocks[i].meetsDifficulty, isTrue,
            reason: 'block $i was not mined');
        expect(blocks[i].signature, isNotNull);
        if (i > 0) {
          expect(blocks[i].previousHash, blocks[i - 1].hash);
        }
      }

      final v = await SwipChain.verify(
        rawBlocks: blocks.map((b) => b.toJson()).toList(),
        captures: captures,
      );
      expect(v.valid, isTrue, reason: v.summary);
      expect(v.signed, isTrue);
      expect(v.captures, 70);
    });

    test('an empty ledger is still a valid chain of one block', () async {
      final blocks = await SwipChain.build(captures: const [], seed: seed);
      expect(blocks.length, 1);
      final v = await SwipChain.verify(
          rawBlocks: blocks.map((b) => b.toJson()).toList(), captures: const []);
      expect(v.valid, isTrue, reason: v.summary);
    });

    test('the same phrase always produces the same identity', () async {
      // This is what lets a reinstall keep appending to an existing chain
      // instead of forking a new one.
      final a = await SwipChain.build(captures: ledger(3), seed: seed);
      final b = await SwipChain.build(captures: ledger(3), seed: seed);
      expect(a.first.publicKey, b.first.publicKey);
      expect(a.first.publicKey, isNotNull);
    });

    test('a different phrase is a different identity', () async {
      final other = SwipChain.seedFromPhrase('a completely different phrase');
      final a = await SwipChain.build(captures: ledger(3), seed: seed);
      final b = await SwipChain.build(captures: ledger(3), seed: other);
      expect(a.first.publicKey, isNot(b.first.publicKey));
    });
  });

  group('trying to cheat it', () {
    late List<Map<String, Object?>> captures;
    late List<SwipBlock> blocks;

    setUp(() async {
      captures = ledger(40); // two blocks
      blocks = await SwipChain.build(captures: captures, seed: seed);
    });

    test('editing a capture is caught, and the block is named', () async {
      final tampered = [...captures];
      tampered[5] = {...tampered[5], 'mcc': '7995'}; // gambling, for effect

      final v = await SwipChain.verify(
        rawBlocks: blocks.map((b) => b.toJson()).toList(),
        captures: tampered,
      );
      expect(v.valid, isFalse);
      expect(v.brokenAt, 0);
      expect(v.summary, contains('Block 0'));
      expect(v.summary, contains('Everything before it is intact'));
    });

    test('editing a capture in a later block names that later block',
        () async {
      final tampered = [...captures];
      tampered[35] = {...tampered[35], 'merchant_name': 'SOMEWHERE ELSE'};
      final v = await SwipChain.verify(
        rawBlocks: blocks.map((b) => b.toJson()).toList(),
        captures: tampered,
      );
      expect(v.valid, isFalse);
      expect(v.brokenAt, 1);
    });

    test('removing a capture is caught by the leaf count', () async {
      final short = [...captures]..removeAt(2);
      final v = await SwipChain.verify(
        rawBlocks: blocks.map((b) => b.toJson()).toList(),
        captures: short,
      );
      expect(v.valid, isFalse);
    });

    test('re-mining a block without the key does not save it', () async {
      // The realistic attack: edit a capture, recompute the merkle root, then
      // mine a fresh nonce so the proof of work holds again. Everything lines
      // up — except the signature, which cannot be reproduced.
      final tampered = [...captures];
      tampered[1] = {...tampered[1], 'amount': 999999.0};

      final leaves =
          tampered.take(32).map(Merkle.leaf).toList();
      final root = Merkle.root(leaves);

      var nonce = 0;
      String hash;
      while (true) {
        hash = SwipBlock.hashOf(
          index: 0,
          timestamp: blocks[0].timestamp,
          previousHash: kGenesisPrevious,
          merkleRoot: root,
          leafCount: leaves.length,
          difficulty: blocks[0].difficulty,
          nonce: nonce,
        );
        if (hash.startsWith('0' * blocks[0].difficulty)) break;
        nonce++;
      }

      final forged = SwipBlock(
        index: 0,
        timestamp: blocks[0].timestamp,
        previousHash: kGenesisPrevious,
        merkleRoot: root,
        leafCount: leaves.length,
        difficulty: blocks[0].difficulty,
        nonce: nonce,
        hash: hash,
        // The old signature, which was over the old header.
        signature: blocks[0].signature,
        publicKey: blocks[0].publicKey,
      );

      final v = await SwipChain.verify(
        rawBlocks: [forged.toJson(), blocks[1].toJson()],
        captures: tampered,
      );
      expect(v.valid, isFalse);
      expect(v.brokenAt, 0);
      expect(v.problem, contains('signature'));
    });

    test('signing the forgery with a different key is caught too', () async {
      // So the attacker signs with their own key. Now block 0 verifies on its
      // own — and is signed by a key the rest of the chain was not.
      final theirs = SwipChain.seedFromPhrase('attacker phrase');
      final tampered = [...captures];
      tampered[1] = {...tampered[1], 'amount': 999999.0};

      final forgedChain =
          await SwipChain.build(captures: tampered, seed: theirs);

      final v = await SwipChain.verify(
        rawBlocks: [forgedChain[0].toJson(), blocks[1].toJson()],
        captures: tampered,
      );
      expect(v.valid, isFalse);
    });

    test('a block with the proof of work stripped is caught', () async {
      final b = blocks[0];
      final weak = SwipBlock(
        index: b.index,
        timestamp: b.timestamp,
        previousHash: b.previousHash,
        merkleRoot: b.merkleRoot,
        leafCount: b.leafCount,
        difficulty: b.difficulty,
        nonce: b.nonce + 1, // breaks the hash
        hash: b.hash,
        signature: b.signature,
        publicKey: b.publicKey,
      );
      final v = await SwipChain.verify(
        rawBlocks: [weak.toJson(), blocks[1].toJson()],
        captures: captures,
      );
      expect(v.valid, isFalse);
      expect(v.brokenAt, 0);
    });

    test('reordering blocks is caught', () async {
      final v = await SwipChain.verify(
        rawBlocks: [blocks[1].toJson(), blocks[0].toJson()],
        captures: captures,
      );
      expect(v.valid, isFalse);
      expect(v.brokenAt, 0);
    });

    test('verification never throws, whatever it is handed', () async {
      final junk = <List<Object?>>[
        [],
        [null],
        ['a string'],
        [42],
        [<String, Object?>{}],
        [
          {'index': 'not a number'}
        ],
        [
          {'index': 0, 'timestamp': 'not a date'}
        ],
        <Object?>[...blocks.map((b) => b.toJson()), 'garbage'],
      ];
      for (final raw in junk) {
        final v = await SwipChain.verify(rawBlocks: raw, captures: captures);
        expect(v.valid, isFalse, reason: '$raw');
        expect(v.summary, isNotEmpty, reason: '$raw');
      }
    });
  });

  group('`F-156` selective disclosure — the point of the merkle tree', () {
    test('one capture can be proved without revealing the other 39', () async {
      final captures = ledger(40);
      final blocks = await SwipChain.build(captures: captures, seed: seed);

      final receipt = SwipChain.receiptFor(
        blocks: blocks,
        captures: captures,
        captureIndex: 7,
      );
      expect(receipt, isNotNull);
      expect(await SwipChain.checkReceipt(receipt!), isTrue);

      // The whole point: the receipt is small, and it contains exactly one
      // capture. An accountant can be handed this and learn nothing about the
      // other thirty-nine.
      final json = jsonEncode(receipt.toJson());
      expect(json, contains('SHOP 7'));
      for (final other in [0, 1, 5, 12, 30, 39]) {
        expect(json, isNot(contains('SHOP $other')), reason: 'leaked SHOP $other');
      }
      expect(json.length, lessThan(3000),
          reason: 'a receipt has to be small enough to paste');
    });

    test('a receipt survives a round trip through JSON', () async {
      final captures = ledger(20);
      final blocks = await SwipChain.build(captures: captures, seed: seed);
      final r = SwipChain.receiptFor(
          blocks: blocks, captures: captures, captureIndex: 11)!;

      final back = ChainReceipt.fromJson(
          jsonDecode(jsonEncode(r.toJson())) as Map<String, Object?>);
      expect(back, isNotNull);
      expect(await SwipChain.checkReceipt(back!), isTrue);
    });

    test('a receipt for an edited capture does not check out', () async {
      final captures = ledger(20);
      final blocks = await SwipChain.build(captures: captures, seed: seed);
      final r = SwipChain.receiptFor(
          blocks: blocks, captures: captures, captureIndex: 3)!;

      final forged = ChainReceipt(
        capture: {...r.capture, 'mcc': '0000'},
        path: r.path,
        block: r.block,
      );
      expect(await SwipChain.checkReceipt(forged), isFalse);
    });

    test('a receipt whose block signature was swapped does not check out',
        () async {
      final captures = ledger(20);
      final blocks = await SwipChain.build(captures: captures, seed: seed);
      final other = await SwipChain.build(
          captures: ledger(20), seed: SwipChain.seedFromPhrase('someone else'));

      final r = SwipChain.receiptFor(
          blocks: blocks, captures: captures, captureIndex: 3)!;
      final forged = ChainReceipt(
        capture: r.capture,
        path: r.path,
        block: SwipBlock(
          index: r.block.index,
          timestamp: r.block.timestamp,
          previousHash: r.block.previousHash,
          merkleRoot: r.block.merkleRoot,
          leafCount: r.block.leafCount,
          difficulty: r.block.difficulty,
          nonce: r.block.nonce,
          hash: r.block.hash,
          signature: other.first.signature,
          publicKey: other.first.publicKey,
        ),
      );
      expect(await SwipChain.checkReceipt(forged), isFalse);
    });

    test('an out-of-range index gives null rather than throwing', () async {
      final captures = ledger(5);
      final blocks = await SwipChain.build(captures: captures, seed: seed);
      expect(
          SwipChain.receiptFor(
              blocks: blocks, captures: captures, captureIndex: 99),
          isNull);
      expect(
          SwipChain.receiptFor(
              blocks: blocks, captures: captures, captureIndex: -1),
          isNull);
    });
  });
}
