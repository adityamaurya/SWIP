import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/onboarding/primers.dart';
import '../../core/theme/swip_tokens.dart';
import '../../data/models/capture_event.dart';
import '../../data/repositories/capture_repository.dart';
import '../../widgets/capture_detail.dart';
import '../../widgets/ledger_row.dart';

/// `S-04` — the Ledger.
///
/// `D-01` simple · `D-02` every vector writes here · `D-04`–`D-10` ·
/// `F-06` the uncategorised filter · `F-07` collapsed rows shown, not vanished.
class LedgerPage extends ConsumerStatefulWidget {
  const LedgerPage({super.key});

  @override
  ConsumerState<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends ConsumerState<LedgerPage> {
  CaptureVector? _vector;
  bool _hideUncategorised = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showPrimer(context, ref, SwipPrimer.ledger);
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(allCapturesProvider(_vector));
    final repoAsync = ref.watch(captureRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ledger')),
      body: Column(
        children: [
          _filters(),
          Expanded(
            child: async.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: SwipColors.gold500, strokeWidth: 2)),
              error: (e, _) => _Message(
                title: 'Could not open the ledger',
                body: '$e',
              ),
              data: (events) {
                if (events.isEmpty) return const _EmptyLedger();
                final repo = repoAsync.valueOrNull;
                final rows = _rowsFor(events);

                if (rows.isEmpty) return const _AllHidden();

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: SwipSpace.gutter, vertical: SwipSpace.sm),
                  itemCount: rows.length,
                  separatorBuilder: (_, i) =>
                      rows[i] is _GapRow ? const SizedBox.shrink()
                          : const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final row = rows[i];

                    final child = switch (row) {
                      _GapRow(:final hidden) => _CollapsedBreak(
                          hidden: hidden,
                          onTap: () =>
                              setState(() => _hideUncategorised = false),
                        ),
                      _EventRow(:final event) => LedgerRow(
                          event: event,
                          mcc: repo?.lookup(event.mcc),
                          // `F-83`. Every row in the ledger opens the same
                          // sheet the capture showed when it happened. The row
                          // has always looked tappable — it is an `InkWell` and
                          // it ripples — but nothing was wired to `onTap`, so
                          // the ledger was a dead end with a hundred rows in it.
                          onTap: () =>
                              showCaptureDetail(context, ref, event),
                        ),
                    };

                    return child
                        .animate()
                        .fadeIn(
                            delay: (i.clamp(0, 12) * 28).ms, duration: 260.ms)
                        .moveY(begin: 8, curve: SwipMotion.standardCurve);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// `F-07`. Hiding rows must never make them *disappear* — a spreadsheet shows
  /// a break where rows are collapsed, and that break is how you know you are
  /// not looking at everything. Consecutive hidden captures collapse into one
  /// dotted row that names how many and is tappable to bring them back.
  List<_Row> _rowsFor(List<CaptureEvent> events) {
    if (!_hideUncategorised) {
      return [for (final e in events) _EventRow(e)];
    }

    final rows = <_Row>[];
    var run = 0;
    for (final e in events) {
      if (_isUncategorised(e)) {
        run++;
        continue;
      }
      if (run > 0) {
        rows.add(_GapRow(run));
        run = 0;
      }
      rows.add(_EventRow(e));
    }
    if (run > 0) rows.add(_GapRow(run));
    return rows;
  }

  /// Uncategorised means *no usable category*: no code at all, or the explicit
  /// `0000` that means "the bank never set one". A code SWIP simply does not
  /// have a name for is still a category and stays visible.
  static bool _isUncategorised(CaptureEvent e) =>
      e.mcc == null || e.isUnclassified;

  Widget _filters() => Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
                SwipSpace.gutter, 0, SwipSpace.gutter, SwipSpace.sm),
            child: Row(
              children: [
                _chip('All', null),
                // `F-89`. Link and Manual are gone. Link asked SWIP to guess a
                // category from a payment URL, which it cannot do — hand it a
                // Razorpay link and there is nothing in it to read. Manual was
                // the user typing a number SWIP was supposed to find for them.
                // A filter for a route that never produces rows is a filter
                // that always shows an empty list.
                for (final v in [
                  CaptureVector.qr,
                  CaptureVector.nfc,
                  CaptureVector.intent,
                ])
                  _chip(VectorTag.labelFor(v), v),
              ],
            ),
          ),
          // `F-06` — the one toggle that matters, given its own line so it is
          // never scrolled off the end of the vector chips.
          Padding(
            padding: const EdgeInsets.fromLTRB(
                SwipSpace.gutter, 0, SwipSpace.gutter, SwipSpace.md),
            child: Row(
              children: [
                // `F-94`. One label, fixed. The line used to be a sentence that
                // changed length with the switch — "Showing everything,
                // categorised or not" against "Showing only captures with a
                // category" — so flipping the toggle reflowed the row, moved
                // the switch under your thumb, and made a settled control look
                // like it was loading. The switch already says which way it is
                // set; the text only has to say what it does.
                Expanded(
                  child: Text(
                    'Hide uncategorised',
                    style: SwipType.bodyM
                        .copyWith(color: SwipColors.textSecondary),
                  ),
                ),
                Switch(
                  value: _hideUncategorised,
                  onChanged: (v) => setState(() => _hideUncategorised = v),
                  activeThumbColor: SwipColors.gold500,
                  activeTrackColor: SwipColors.gold900,
                ),
              ],
            ),
          ),
        ],
      );

  Widget _chip(String label, CaptureVector? v) {
    final selected = _vector == v;
    return Padding(
      padding: const EdgeInsets.only(right: SwipSpace.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _vector = v),
        showCheckmark: false,
        backgroundColor: SwipColors.surfaceRaised,
        selectedColor: SwipColors.gold900,
        side: BorderSide(
            color: selected ? SwipColors.gold700 : SwipColors.hairline),
        labelStyle: SwipType.label.copyWith(
          color: selected ? SwipColors.gold300 : SwipColors.textSecondary,
        ),
      ),
    );
  }
}

// ── row model ─────────────────────────────────────────────────────────

sealed class _Row {
  const _Row();
}

class _EventRow extends _Row {
  const _EventRow(this.event);
  final CaptureEvent event;
}

class _GapRow extends _Row {
  const _GapRow(this.hidden);
  final int hidden;
}

/// `F-07` — the dotted break. Deliberately looks like a torn edge rather than a
/// row: it is a statement that something is missing, not a thing to read.
class _CollapsedBreak extends StatelessWidget {
  const _CollapsedBreak({required this.hidden, this.onTap});
  final int hidden;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: SwipSpace.lg, vertical: SwipSpace.sm),
          child: Row(
            children: [
              const Expanded(child: _DottedRule()),
              const SizedBox(width: SwipSpace.sm),
              Text(
                hidden == 1 ? '1 hidden' : '$hidden hidden',
                style:
                    SwipType.bodyS.copyWith(color: SwipColors.textTertiary),
              ),
              const SizedBox(width: SwipSpace.xs),
              const Icon(Icons.unfold_more_rounded,
                  size: 14, color: SwipColors.textTertiary),
              const SizedBox(width: SwipSpace.sm),
              const Expanded(child: _DottedRule()),
            ],
          ),
        ),
      );
}

class _DottedRule extends StatelessWidget {
  const _DottedRule();

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _DottedPainter(),
        size: const Size(double.infinity, 1),
      );
}

class _DottedPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = SwipColors.hairline
      ..strokeWidth = 1;
    const dash = 3.0;
    const gap = 4.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), p);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DottedPainter oldDelegate) => false;
}

class _AllHidden extends StatelessWidget {
  const _AllHidden();

  @override
  Widget build(BuildContext context) => const _Message(
        title: 'Every capture here is uncategorised',
        body: 'Turn off "Hide uncategorised" to see them. They are not '
            'failures — most are shop stickers whose bank never wrote a '
            'category into the code.',
        icon: Icons.filter_alt_off_outlined,
      );
}

class _EmptyLedger extends StatelessWidget {
  const _EmptyLedger();

  @override
  Widget build(BuildContext context) => const _Message(
        title: 'Nothing captured yet',
        body: 'Scan any payment QR and you will see its category here — '
            'before you pay, not a month later on a statement.',
        icon: Icons.receipt_long_outlined,
      );
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.body, this.icon});
  final String title;
  final String body;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(SwipSpace.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon ?? Icons.error_outline_rounded,
                  size: 36, color: SwipColors.textTertiary),
              const SizedBox(height: SwipSpace.lg),
              Text(title,
                  textAlign: TextAlign.center,
                  style: SwipType.titleS
                      .copyWith(color: SwipColors.textPrimary)),
              const SizedBox(height: SwipSpace.sm),
              Text(body,
                  textAlign: TextAlign.center,
                  style: SwipType.bodyM
                      .copyWith(color: SwipColors.textSecondary)),
            ],
          ),
        ),
      );
}
