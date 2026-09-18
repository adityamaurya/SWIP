import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/sources/upi_uri_parser.dart';

/// `F-197` — **the fourth flight recorder, and the first one in Dart.**
///
/// > *"create an export log for the scans that we are doing… an exportable
/// > file"* — prompt 51, E5
///
/// ## The ledger records what was **found**. This records what was **looked
/// at**.
///
/// That distinction is the whole reason it is worth building. Every successful
/// scan already lands in the ledger, so the successes are covered. What no
/// instrument in SWIP can currently see is the **failures**:
///
///   * a viewfinder held on a code for eleven seconds that never decoded;
///   * a scanner opened and abandoned without a capture;
///   * the torch being reached for, which is a user saying *it is too dark*
///     with their thumb instead of their words.
///
/// Those three are exactly the complaints this project cannot presently answer.
/// *"It should zoom to the QR like Google Pay does"* and *"in low light there
/// is glare coming from the backside of the scanners"* are both claims about
/// **how often** and **how long**, and right now every answer to them would be
/// a guess. `docs/42` settled the QR question by counting 48 codes rather than
/// by reasoning; this is the same move applied to the camera.
///
/// ## Why it lives in Dart when the other three are Kotlin
///
/// Because the thing being watched is. QR decoding happens in `mobile_scanner`
/// behind a Dart API — there is no Kotlin moment where a scan succeeds or
/// fails, so a Kotlin recorder would have nothing to hook. The three existing
/// boxes watch Android subsystems; this one watches a Flutter widget.
///
/// It joins them in the export and in Settings regardless: `Blackbox.scan`
/// carries it, so the master export picks it up with no special case.
///
/// ## The privacy rule, enforced the way `TapTrace` enforces its own
///
/// `CLAUDE.md`: *a privacy rule enforced by a function signature survives a
/// hurried edit; one written in a comment does not.*
///
/// So [decoded] **cannot be handed a payload.** It does not take a `String`.
/// It takes [ScanShape], which is computed from the payload here in this file
/// and carries only counts and enums — a length, a boolean, a PSP family name
/// from a fixed list. There is no parameter through which a VPA, a merchant
/// name or a raw code could reach the file, however hurried the edit.
///
/// The test proves it by building a shape from a real payload and asserting
/// that none of that payload's identifying strings appear in the line.
enum ScanOutcome {
  /// A code was read and resolved.
  decoded,

  /// The scanner closed with nothing read. **The interesting one** — this is
  /// the number that says whether the camera is good enough.
  abandoned,
}

/// What a decoded payload *was*, with nothing that says *whose* it was.
///
/// Every field here is a count or a member of a closed set. That is not
/// stylistic: it is the mechanism that makes it impossible to log a payment
/// address through this recorder.
@immutable
class ScanShape {
  const ScanShape({
    required this.bytes,
    required this.kind,
    required this.pspFamily,
    required this.mccPublication,
  });

  /// Derive a shape from a payload. **The payload stops here** — it is read to
  /// produce the fields below and is never stored, returned or logged.
  factory ScanShape.of(String payload) {
    final upi = UpiUriParser.tryParse(payload);
    if (upi == null) {
      return ScanShape(
        bytes: payload.length,
        kind: 'other',
        pspFamily: null,
        mccPublication: null,
      );
    }
    return ScanShape(
      bytes: payload.length,
      kind: 'upi',
      pspFamily: _familyOf(upi.payeeAddress),
      mccPublication: upi.mccPublication.name,
    );
  }

  final int bytes;

  /// `upi` or `other`. Deliberately coarse.
  final String kind;

  /// The handle **family**, not the handle: `pty`, `ybl`, `okaxis` →
  /// `paytm`, `phonepe`, `googlepay`.
  ///
  /// This is the single most valuable field in the file, because `docs/42`'s
  /// finding is that **the acquirer decides** whether a category exists. A
  /// distribution of families against [mccPublication] is that finding
  /// extended from 48 codes to however many the owner scans.
  ///
  /// It is a family rather than a handle on purpose. `paytm.s27l8o9@pty`
  /// identifies one shop; `paytm` identifies a company with millions of them.
  final String? pspFamily;

  /// `published`, `blank`, `absent`, `unclassified`, `malformed` — the
  /// `MccPublication` name. The difference between *no category* and *a
  /// category left empty* is a `docs/42` finding and belongs in the data.
  final String? mccPublication;

  /// The handle families worth telling apart, from `docs/42`'s corpus.
  ///
  /// Anything unrecognised returns `other` rather than the handle itself —
  /// **that fallback is a privacy decision, not a tidiness one.** Returning an
  /// unknown handle would put a real, possibly shop-specific string into a file
  /// meant to be mailed.
  static String? _familyOf(String? vpa) {
    if (vpa == null) return null;
    final at = vpa.lastIndexOf('@');
    if (at < 0 || at == vpa.length - 1) return null;
    final h = vpa.substring(at + 1).toLowerCase();

    // `F-182`: a gap in the middle of a family is the kind nobody finds by
    // reading, so these are prefix matches over the families rather than a
    // list of every handle.
    if (h.startsWith('pt') || h == 'paytm') return 'paytm';
    if (h.startsWith('ybl') || h.startsWith('ibl') || h.startsWith('axl')) {
      return 'phonepe';
    }
    if (h.startsWith('ok') || h.startsWith('okbiz')) return 'googlepay';
    if (h.contains('bharatpe') || h.startsWith('yesbank')) return 'bharatpe';
    if (h.contains('bank') || h.startsWith('hdfc') || h.startsWith('icici')) {
      return 'bank';
    }
    return 'other';
  }

  Map<String, Object?> toJson() => {
        'bytes': bytes,
        'kind': kind,
        if (pspFamily != null) 'psp': pspFamily,
        if (mccPublication != null) 'mc': mccPublication,
      };
}

/// The recorder.
///
/// Persisted to `SharedPreferences` rather than a file, because it is small,
/// bounded, and needs no `path_provider` call on every line — and the three
/// Kotlin boxes already own the file-writing pattern for things that are not.
///
/// **Bounded at [maxLines]**, oldest dropped. `CLAUDE.md`, from `F-189`: *a
/// file nobody can bear to read is not a flight recorder.* A scanner opened
/// twenty times a day would otherwise grow without limit and be useless by the
/// time it was interesting.
class ScanTrace {
  const ScanTrace._();

  static const key = 'swip.scan.trace';
  static const maxLines = 400;

  /// Injected by tests. Production reads the real store.
  @visibleForTesting
  static SharedPreferences? testStore;

  static Future<SharedPreferences> _store() async =>
      testStore ?? await SharedPreferences.getInstance();

  /// A scanner opened. [surface] is `full` or `hover` — the two windows behave
  /// differently and their numbers must not be pooled.
  static Future<void> opened(String surface) =>
      _write('scan.open', {'surface': surface});

  /// A code was read. Takes a [ScanShape], **never a payload** — see the class
  /// note above; this signature is the privacy rule.
  static Future<void> decoded({
    required ScanShape shape,
    required int msSinceOpen,
    required bool torchOn,
  }) =>
      _write('scan.decoded', {
        ...shape.toJson(),
        'ms': msSinceOpen,
        'torch': torchOn,
      });

  /// The "having trouble?" timer fired — the viewfinder has been open this long
  /// with nothing read. **The low-light and glare signal**, and the reason E6
  /// becomes answerable.
  static Future<void> stuck({required int msSinceOpen, required bool torchOn}) =>
      _write('scan.stuck', {'ms': msSinceOpen, 'torch': torchOn});

  /// The torch was toggled. A user reaching for it is a user saying *it is too
  /// dark* with their thumb.
  static Future<void> torch({required bool on, required int msSinceOpen}) =>
      _write('scan.torch', {'on': on, 'ms': msSinceOpen});

  /// The scanner closed. [outcome] is the number that matters.
  static Future<void> closed({
    required ScanOutcome outcome,
    required int msOpen,
  }) =>
      _write('scan.close', {'outcome': outcome.name, 'ms': msOpen});

  /// Every line, oldest first, newline-separated. Empty when nothing is
  /// recorded — which callers must render as "nothing recorded" rather than as
  /// a blank, because the two are different findings.
  static Future<String> dump() async {
    final p = await _store();
    return (p.getStringList(key) ?? const <String>[]).join('\n');
  }

  static Future<void> clear() async {
    final p = await _store();
    await p.remove(key);
  }

  /// One JSON object per line, matching the Kotlin boxes' shape closely enough
  /// that one reader handles all four: a timestamp, an event name, and a `v`
  /// object of values.
  ///
  /// Never throws. A recorder that can break the thing it is recording is
  /// worse than no recorder — and this one sits in the scan path, which is the
  /// product.
  static Future<void> _write(String event, Map<String, Object?> values) async {
    try {
      final p = await _store();
      final lines = List<String>.from(p.getStringList(key) ?? const <String>[]);
      lines.add(jsonEncode({
        't': DateTime.now().toUtc().toIso8601String(),
        'e': event,
        'v': values,
      }));
      // Trim from the front: the end of a log is the part that explains what
      // just went wrong, which is the whole reason anyone opens one.
      if (lines.length > maxLines) {
        lines.removeRange(0, lines.length - maxLines);
      }
      await p.setStringList(key, lines);
    } catch (_) {
      // Swallowed on purpose. See the note above.
    }
  }
}
