import 'dart:async';

import 'package:flutter/services.dart';

import 'blackbox_page.dart';

/// `F-195` — **one file instead of three.**
///
/// > *"Sometimes, if I want to keep a master, can you help me create a master
/// > export file for all the types of exports about this system whenever I
/// > upload, so that you have a mega export file? … Have it in the build debug
/// > APK at the very end, at the very lowest part of it."* — prompt 54
///
/// ## The friction this removes, which is real and recurring
///
/// Every round for the last five, the owner has exported three separate JSONL
/// files, found them in three places, and attached all three. Prompt 51 did it
/// with the bubble trace, the POS trace and the battery trace; prompt 50 did
/// it with two. Three exports is three chances to forget one, and the round
/// where the missing one was the interesting one is a round spent guessing.
///
/// ## What is in it, and the line that is deliberately not crossed
///
/// **In:** all three recorders, plus an environment block — device, Android
/// version, app build, and the four platform facts that decide whether any of
/// this works at all (NFC present, NFC on, HCE supported, and **whether SWIP
/// holds the default contactless payment slot**, which `docs/45` names as the
/// single most common reason a tap reads as broken).
///
/// **Out: the ledger.** Not an oversight — a decision, and the reason is worth
/// keeping.
///
/// The three recorders were each designed from the first line to be exported
/// and sent to somebody. `TapTrace.tagFields` *cannot* emit a value because it
/// is never handed one, and there is a test that proves it by feeding
/// real-looking hex in and asserting none comes out (`F-187`). Their privacy
/// is a property of their signatures rather than of anybody's restraint.
///
/// The ledger is the opposite. It is the user's own shop history, and it
/// already has two exports: a plain list with the identifying columns stripped,
/// and an encrypted backup that opens only with a twelve-word phrase. Folding
/// either into a diagnostics bundle would silently undo the decision that
/// encrypted one of them — and a "master export" that quietly carries more
/// than its name suggests is exactly the kind of file somebody forwards
/// without thinking.
///
/// So the ledger contributes **one integer** — how many captures exist — which
/// is the only thing about it a diagnostic needs.
class MasterExport {
  const MasterExport._();

  static const _channel = MethodChannel('in.swip.app/nfc');

  /// Build the bundle. Never throws: a recorder that cannot be read contributes
  /// a note saying so, because a master export that fails because one of four
  /// sources is missing is a master export nobody can produce on the day it
  /// matters.
  static Future<String> compose({
    required int captureCount,
    DateTime? now,
    Future<String> Function(Blackbox box)? dump,
    Future<Map<String, Object?>> Function()? environment,
  }) async {
    final at = now ?? DateTime.now();
    final read = dump ?? _dumpOf;
    // Same reasoning as the per-box guard below: an environment block that
    // cannot be read is a line in the file, not a failed export.
    Map<String, Object?> env;
    try {
      env = await (environment ?? _environment)();
    } catch (e) {
      env = {'environment': 'could not be read: $e'};
    }

    final b = StringBuffer()
      ..writeln('SWIP MASTER EXPORT')
      ..writeln('Taken ${at.toUtc().toIso8601String()} (UTC)')
      ..writeln('Captures in the ledger: $captureCount')
      ..writeln()
      ..writeln('This file contains SWIP\'s three flight recorders and the '
          'phone they ran on.')
      ..writeln('It contains NO captures: no payment addresses, no merchant '
          'names, no amounts,')
      ..writeln('no locations and no raw payloads. Those live in the ledger, '
          'which has its own')
      ..writeln('two exports and is deliberately not bundled here.')
      ..writeln();

    _section(b, 'ENVIRONMENT');
    for (final e in env.entries) {
      b.writeln('${e.key.padRight(22)} ${e.value}');
    }
    b.writeln();

    for (final box in Blackbox.values) {
      _section(b, box.title.toUpperCase());
      b
        ..writeln('# ${box.contains}')
        ..writeln();
      // Per box, not around the loop. One wedged channel must cost its own
      // section and nothing else — the day this matters is the day a recorder
      // is broken and the export is the only way to find out why, which is
      // exactly the day an exception here would make the instrument
      // unavailable.
      String text;
      try {
        text = await read(box);
      } catch (e) {
        b
          ..writeln('(could not be read: $e)')
          ..writeln();
        continue;
      }

      final lines =
          text.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) {
        // Said out loud rather than left as a blank gap. "Nothing recorded"
        // and "this section failed to read" look identical in an empty file,
        // and they are completely different findings.
        b.writeln('(nothing recorded)');
      } else {
        // Oldest first here, unlike the on-screen view. A file being read
        // start to finish wants the order things happened in; the screen
        // reverses it because the interesting part is always the end and
        // that is the wrong end of a scroll view to land on.
        b
          ..writeln('${lines.length} lines')
          ..writeln()
          ..writeAll(lines, '\n')
          ..writeln();
      }
      b.writeln();
    }

    _section(b, 'END');
    return b.toString();
  }

  static void _section(StringBuffer b, String title) {
    b
      ..writeln('=' * 64)
      ..writeln(title)
      ..writeln('=' * 64);
  }

  /// The literals stay at the call site in a `switch`, and that is a
  /// constraint rather than clumsiness — `check_wiring.py` matches channel
  /// names against `MainActivity.kt` by finding them written out, and `F-187`
  /// records the round where moving them into an enum field made six live
  /// handlers read as dead platform code.
  static Future<String> _dumpOf(Blackbox box) async {
    try {
      final call = switch (box) {
        Blackbox.bubble => _channel.invokeMethod<String>('traceDump'),
        Blackbox.tap => _channel.invokeMethod<String>('tapTraceDump'),
        Blackbox.power => _channel.invokeMethod<String>('powerTraceDump'),
      };
      return await call.timeout(const Duration(seconds: 4)) ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Device, build, and the four facts that decide whether a tap can work.
  ///
  /// Two platform reads, both timed out, and a failure in either leaves its
  /// keys out rather than failing the export. `CLAUDE.md`: a `MethodChannel`
  /// future completes when the platform replies and **never completes if it
  /// does not**.
  static Future<Map<String, Object?>> _environment() async {
    final out = <String, Object?>{};

    try {
      final d = await _channel
          .invokeMapMethod<String, Object?>('deviceReport')
          .timeout(const Duration(seconds: 3));
      if (d != null) out.addAll(d);
    } catch (_) {
      out['device'] = 'unavailable';
    }

    try {
      final s = await _channel
          .invokeMapMethod<String, Object?>('status')
          .timeout(const Duration(seconds: 3));
      if (s != null) {
        out['nfcPresent'] = s['hasNfc'];
        out['nfcEnabled'] = s['enabled'];
        out['hceSupported'] = s['hasHce'];
        // The one that explains most POS failures. `docs/45` failure #3:
        // Android routes the whole contactless field to whichever app holds
        // this slot, and on any phone with Google Wallet set up that is
        // Wallet — so SWIP never sees a byte, and the tap reads as broken.
        out['isDefaultPayment'] = s['isDefaultPayment'];
      }
    } catch (_) {
      out['nfcStatus'] = 'unavailable';
    }

    return out;
  }
}
