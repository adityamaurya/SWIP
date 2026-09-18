import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/diagnostics/scan_trace.dart';
import '../../core/theme/swip_tokens.dart';

/// `F-187`, `F-188` — **one screen for all three black boxes. Temporary.**
///
/// > *"We'll have a ritual between us where I'll give you: an export of JSONL
/// > for the bubble chat, a black box export for the POS failures, battery
/// > usage export logs."*
///
/// `F-176` built this screen for the floating button and hard-coded one
/// channel method into it. Three recorders now want the same screen, and the
/// alternative is three copies of the load, the export, the clear dialog and
/// the crude line renderer.
///
/// ## Why this can only exist in a debug build
///
/// Everything goes through [available], which asks the platform whether the
/// running APK is debuggable. It is not a preference and not a constant
/// somebody has to remember to flip: a Play Store build answers `false`, the
/// rows in Settings are never drawn, and `Blackbox` on the Kotlin side records
/// nothing regardless of what is called.
///
/// ## What is in the files
///
/// Lifecycle and outcomes. **No captures** — no payloads, no merchant names,
/// no VPAs, no amounts, no location. The POS recorder is the strict one: an
/// APDU exchange is the one place a merchant identifier genuinely lives, so it
/// records tag *names* and value *lengths* and never values.
///
/// That is stated on the screen as well as here, because these files leave the
/// phone by design.
enum Blackbox {
  /// `F-176`. The floating button's lifecycle.
  bubble(
    title: 'Bubble trace',
    blurb:
        'Every time the floating button appears or disappears, this records '
        'which of the four reasons caused it. Clear it, reproduce the '
        'problem, then export.',
    contains: 'Window and service events only — no captures, no merchant '
        'names, no payment addresses, no location.',
  ),

  /// `F-187`. Every tap on a card machine.
  tap(
    title: 'POS tap black box',
    blurb: 'Every tap on a card machine: whether NFC was on, whether SWIP was '
        'the default payment app, what the terminal sent, how far the '
        'exchange got and exactly where it stopped.\n\n'
        'Tap a machine two or three times, then export — a failure next to a '
        'success is worth far more than a failure on its own.',
    contains: 'Command shapes and outcomes only. Tag names and value lengths, '
        'never values — nothing that could identify the shop.',
  ),

  /// `F-188`. Which subsystem was awake, and for how long.
  power(
    title: 'Battery black box',
    blurb: 'How long each part of SWIP was awake — the overlay window, the '
        'accelerometer, the camera, the NFC reader, the hovering card\'s '
        'engine — with the battery level either side.\n\n'
        'It cannot measure milliamps; no app can measure its own power draw. '
        'It measures duration, which is what actually costs a battery.',
    contains: 'Subsystem names and durations. Nothing about what was captured '
        'while they were awake.',
  ),

  /// `F-197`. Every time the viewfinder was opened, and what happened next.
  scan(
    title: 'Scan black box',
    blurb: 'Every time the scanner was opened: how long until a code was '
        'read, whether the torch was reached for, whether the "having '
        'trouble" message appeared, and whether the scanner was closed with '
        'nothing read at all.\n\n'
        'The ledger already records what was FOUND. This records what was '
        'LOOKED AT — which is the only way "it should zoom like Google Pay" '
        'and "the glare beats it" become numbers rather than arguments.',
    contains: 'Timings, outcomes, and the payment company a code belonged to '
        '(Paytm, PhonePe, Google Pay) — never the code, the shop or the '
        'address.',
  );

  const Blackbox({
    required this.title,
    required this.blurb,
    required this.contains,
  });

  final String title;

  final String blurb;
  final String contains;

  /// The filename stem of an export. Dated by the exporter.
  String get slug => switch (this) {
        Blackbox.bubble => 'BubbleTrace',
        Blackbox.tap => 'PosTrace',
        Blackbox.power => 'PowerTrace',
        Blackbox.scan => 'ScanTrace',
      };
}

/// One black box, on screen.
class BlackboxPage extends StatefulWidget {
  const BlackboxPage({super.key, required this.box});

  final Blackbox box;

  static const _channel = MethodChannel('in.swip.app/nfc');

  /// Whether the running build records anything at all.
  ///
  /// Asks `blackboxEnabled`, **not** `traceEnabled`, and the difference is the
  /// whole reason the method exists. Both are `FLAG_DEBUGGABLE` and both
  /// return the same answer today — but `traceEnabled` is deleted along with
  /// `BubbleTrace` (`docs/38` §4), and this screen outlives it. Reusing it
  /// would have meant that deletion quietly took the POS and battery boxes off
  /// the Settings screen: the future resolves false, the section stops
  /// drawing, and nothing fails anywhere.
  ///
  /// Timed out like every other platform read in this project — `CLAUDE.md`:
  /// a `MethodChannel` future completes when the platform replies and never
  /// completes if it does not, and a Settings screen that hangs while deciding
  /// whether to draw a debug row would be a worse bug than the one being
  /// chased.
  static Future<bool> available() async {
    try {
      final on = await _channel
          .invokeMethod<bool>('blackboxEnabled')
          .timeout(const Duration(seconds: 2));
      return on ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  /// Whether the **temporary** bubble trace is recording.
  ///
  /// Separate from [available] and asking a separate channel method, because
  /// the two answers have separate lifetimes: this one and everything it
  /// gates disappear when `BubbleTrace` does (`docs/38` §4 steps 4 and 5),
  /// and [available] must not. Today both come from `FLAG_DEBUGGABLE` and
  /// always agree — which is exactly why folding them into one call would have
  /// looked like a tidy-up and been a time bomb.
  static Future<bool> bubbleTraceAvailable() async {
    try {
      final on = await _channel
          .invokeMethod<bool>('traceEnabled')
          .timeout(const Duration(seconds: 2));
      return on ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  @override
  State<BlackboxPage> createState() => _BlackboxPageState();
}

class _BlackboxPageState extends State<BlackboxPage> {
  static const _channel = MethodChannel('in.swip.app/nfc');

  List<String> _lines = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// The channel names are **literals, one branch each**, and that is
  /// deliberate rather than clumsy.
  ///
  /// `tool/check_wiring.py` matches method names between here and
  /// `MainActivity.kt` in both directions, and it only sees a plain literal at
  /// the call site. Holding the names in the enum instead compiled perfectly
  /// and made all six invisible to the check — which the check caught, by
  /// reporting six handlers as dead platform code.
  ///
  /// Its own note argues for keeping that constraint rather than regexing
  /// around it: a method name hidden inside an expression is one a grep cannot
  /// find, and so is one a person reading the file cannot find either.
  Future<String> _dump() async {
    try {
      // `F-197`. The scan box is the one recorder that is not behind the
      // channel — it watches a Flutter widget, so it lives in Dart. Returned
      // before the switch rather than as a case in it, because there is no
      // `Future<String?>` from a channel to await.
      if (widget.box == Blackbox.scan) return ScanTrace.dump();

      final call = switch (widget.box) {
        Blackbox.bubble => _channel.invokeMethod<String>('traceDump'),
        Blackbox.tap => _channel.invokeMethod<String>('tapTraceDump'),
        Blackbox.power => _channel.invokeMethod<String>('powerTraceDump'),
        // Unreachable — returned above. Kept so the switch stays exhaustive
        // and a fifth recorder cannot be added without deciding this.
        Blackbox.scan => Future<String?>.value(''),
      };
      return await call.timeout(const Duration(seconds: 4)) ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final text = await _dump();
    if (!mounted) return;
    setState(() {
      // Newest first. The question these files answer is always "what happened
      // just before it went wrong", and that is the *end* of an append-only
      // log — which is the wrong end of a scroll view to land on.
      _lines = text
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList()
          .reversed
          .toList();
      _loading = false;
    });
  }

  Future<void> _export() async {
    final text = await _dump();
    if (text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing recorded yet.')),
      );
      return;
    }

    final now = DateTime.now();
    final stamp = '${now.year}-${_two(now.month)}-${_two(now.day)}'
        '_${_two(now.hour)}-${_two(now.minute)}-${_two(now.second)}';
    // The temporary directory, like both real exports, because that is where
    // `share_plus` can hand a file to another app without a content provider
    // of our own.
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/SWIP_${widget.box.slug}_$stamp.jsonl');
    await file.writeAsString(text);

    if (!mounted) return;
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'SWIP ${widget.box.title} $stamp',
      text: widget.box.contains,
    );
  }

  Future<void> _clear() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Clear the ${widget.box.title.toLowerCase()}?'),
        content: const Text(
          'Start a fresh recording. Do this just before you try to reproduce '
          'the problem — a short file with the fault in it is far easier to '
          'read than a long one.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (yes != true) return;
    // `F-197`. Same split as `_dump`: the scan box is in Dart, so there is no
    // channel call to make. Cleared and reloaded here, before the switch.
    if (widget.box == Blackbox.scan) {
      await ScanTrace.clear();
      if (mounted) await _load();
      return;
    }
    try {
      final call = switch (widget.box) {
        Blackbox.bubble => _channel.invokeMethod<bool>('traceClear'),
        Blackbox.tap => _channel.invokeMethod<bool>('tapTraceClear'),
        Blackbox.power => _channel.invokeMethod<bool>('powerTraceClear'),
        // Unreachable — handled above. Kept so the switch stays exhaustive.
        Blackbox.scan => Future<bool?>.value(true),
      };
      await call.timeout(const Duration(seconds: 3));
    } catch (_) {
      // Nothing to say: the reload below shows whether it worked.
    }
    await _load();
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.box.title),
        actions: [
          IconButton(
            tooltip: 'Reload',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _Preamble(box: widget.box),
          Divider(height: 1, color: SwipColors.hairline),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _lines.isEmpty
                    ? const _Empty()
                    : ListView.separated(
                        padding:
                            const EdgeInsets.symmetric(vertical: SwipSpace.sm),
                        itemCount: _lines.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: SwipColors.hairline),
                        itemBuilder: (_, i) => _Line(_lines[i]),
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(SwipSpace.gutter),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clear,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: SwipSpace.md),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _export,
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: const Text('Export'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the file is, and what it is not, said on the screen that exports it.
class _Preamble extends StatelessWidget {
  const _Preamble({required this.box});

  final Blackbox box;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(SwipSpace.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bug_report_outlined,
                    size: 18, color: SwipColors.warning),
                const SizedBox(width: SwipSpace.sm),
                Text('Debug build only',
                    style: SwipType.label
                        .copyWith(color: SwipColors.textPrimary)),
              ],
            ),
            const SizedBox(height: SwipSpace.sm),
            Text(
              '${box.blurb}\n\n${box.contains}',
              style: SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
            ),
          ],
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(SwipSpace.xxl),
          child: Text(
            'Nothing recorded yet.\n\nUse the feature this watches, then come '
            'back.',
            textAlign: TextAlign.center,
            style: SwipType.bodyM.copyWith(color: SwipColors.textTertiary),
          ),
        ),
      );
}

/// One event, rendered so a person can scan a column rather than read JSON.
///
/// The raw line is still what gets exported and what I read; this is only so
/// the owner can tell at a glance on the phone whether the moment they were
/// trying to reproduce actually landed in the file.
class _Line extends StatelessWidget {
  const _Line(this.raw);

  final String raw;

  /// Pull one value out without a JSON parser.
  ///
  /// Deliberately crude. This is a debug view of a file whose authoritative
  /// reader is a text editor, and a parser here would be a second place for
  /// the format to be got wrong.
  String? _field(String key) {
    final at = raw.indexOf('"$key":');
    if (at < 0) return null;
    var i = at + key.length + 3;
    if (i >= raw.length) return null;
    if (raw[i] == '"') {
      final end = raw.indexOf('"', i + 1);
      return end < 0 ? null : raw.substring(i + 1, end);
    }
    final end = raw.indexOf(RegExp('[,}]'), i);
    return end < 0 ? null : raw.substring(i, end);
  }

  @override
  Widget build(BuildContext context) {
    final event = _field('e') ?? '?';
    final time = (_field('t') ?? '').split('T').last.split('+').first;

    // The one field worth pulling out per recorder. `why` covers the bubble's
    // visibility reason and a tap's ending; `what` covers a power span.
    final detail = _field('why') ??
        _field('outcome') ??
        _field('what') ??
        _field('tags');
    final visible = _field('visible');

    final bad = event.contains('Failed') ||
        event == 'service.destroy' ||
        event.endsWith('.empty') ||
        event.endsWith('.short');
    final hidden = visible == 'false';

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: SwipSpace.gutter, vertical: SwipSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  event,
                  style: SwipType.label.copyWith(
                    color: bad
                        ? SwipColors.danger
                        : hidden
                            ? SwipColors.warning
                            : SwipColors.textPrimary,
                  ),
                ),
              ),
              Text(time,
                  style:
                      SwipType.bodyS.copyWith(color: SwipColors.textTertiary)),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: 2),
            Text(
              visible == 'true' ? 'shown' : detail,
              style: SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
