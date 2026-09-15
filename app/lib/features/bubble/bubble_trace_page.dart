import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/swip_tokens.dart';

/// `F-176` — **the bubble's flight recorder, on screen. Temporary.**
///
/// > *"can we temporarily inject a detailed tracker into the app build… so
/// > that each time I give you an exported tracker/log file, we can analyze
/// > exactly what happened before, during, and after the launcher
/// > disappeared."*
///
/// ## Why this screen can only exist in a debug build
///
/// Everything here goes through [traceEnabled], which asks the platform
/// whether the running APK is debuggable. It is not a preference and not a
/// constant somebody has to remember to flip: a Play Store build answers
/// `false`, the row in Settings is never drawn, and `BubbleTrace` on the
/// Kotlin side records nothing regardless of what is called.
///
/// So the honest version of *"removed before the public build"* is that it
/// **cannot reach one**. It still gets deleted once the cause is found —
/// [`docs/38`](../../../../docs/38-BUBBLE-TRACE.md) carries the removal
/// list — but nothing depends on anyone remembering.
///
/// ## What is in the file
///
/// Lifecycle only: when the service started, when the window was added, every
/// change in the visibility decision and which of the four reasons caused it,
/// which component reported SWIP as foreground, snoozes, shakes, taps, boots.
///
/// **No captures.** No payloads, no merchant names, no VPAs, no amounts, no
/// location. That is stated on the screen as well as here, because this file
/// leaves the phone by design — and a debug log that quietly carried ledger
/// data would be a privacy hole opened for convenience, in the one app whose
/// whole claim is that nothing leaves the phone.
class BubbleTracePage extends StatefulWidget {
  const BubbleTracePage({super.key});

  static const _channel = MethodChannel('in.swip.app/nfc');

  /// Whether the running build records anything at all.
  ///
  /// Timed out like every other platform read in this project — `CLAUDE.md`:
  /// a `MethodChannel` future completes when the platform replies and never
  /// completes if it does not, and a Settings screen that hangs while deciding
  /// whether to draw a debug row would be a worse bug than the one being
  /// chased.
  static Future<bool> traceEnabled() async {
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
  State<BubbleTracePage> createState() => _BubbleTracePageState();
}

class _BubbleTracePageState extends State<BubbleTracePage> {
  static const _channel = MethodChannel('in.swip.app/nfc');

  List<String> _lines = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    var text = '';
    try {
      text = await _channel
              .invokeMethod<String>('traceDump')
              .timeout(const Duration(seconds: 4)) ??
          '';
    } catch (_) {
      text = '';
    }
    if (!mounted) return;
    setState(() {
      // Newest first. The question this file answers is always "what happened
      // just before it vanished", and that is the *end* of an append-only
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
    var text = '';
    try {
      text = await _channel
              .invokeMethod<String>('traceDump')
              .timeout(const Duration(seconds: 4)) ??
          '';
    } catch (_) {
      text = '';
    }
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
    final file = File('${dir.path}/SWIP_BubbleTrace_$stamp.jsonl');
    await file.writeAsString(text);

    if (!mounted) return;
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'SWIP bubble trace $stamp',
      text: 'Floating-button lifecycle log. No captures, no merchant data — '
          'window and service events only.',
    );
  }

  Future<void> _clear() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear the trace?'),
        content: const Text(
          'Start a fresh recording. Do this just before you try to reproduce '
          'the disappearance — a short file with the problem in it is far '
          'easier to read than a long one.',
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
    try {
      await _channel
          .invokeMethod<bool>('traceClear')
          .timeout(const Duration(seconds: 3));
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
        title: const Text('Bubble trace'),
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
          const _Preamble(),
          Divider(height: 1, color: SwipColors.hairline),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _lines.isEmpty
                    ? const _Empty()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            vertical: SwipSpace.sm),
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
  const _Preamble();

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
              'Every time the floating button appears or disappears, this '
              'records which of the four reasons caused it. Clear it, '
              'reproduce the problem, then export.\n\n'
              'It contains window and service events only — no captures, no '
              'merchant names, no payment addresses, no location.',
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
            'Nothing recorded yet.\n\nTurn the button on, leave SWIP, and come '
            'back — the first events arrive as soon as the service starts.',
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
    final why = _field('why');
    final visible = _field('visible');

    final bad = event.contains('Failed') || event == 'service.destroy';
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
                  style: SwipType.bodyS
                      .copyWith(color: SwipColors.textTertiary)),
            ],
          ),
          if (why != null) ...[
            const SizedBox(height: 2),
            Text(
              visible == 'true' ? 'shown' : 'hidden — $why',
              style: SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
