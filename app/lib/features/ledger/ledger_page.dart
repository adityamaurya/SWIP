import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/onboarding/primers.dart';
import '../../core/theme/swip_tokens.dart';
import '../../core/utils/swip_time.dart';
import '../../data/models/capture_event.dart';
import '../../data/repositories/capture_repository.dart';
import '../../widgets/ledger_row.dart';

/// `S-04` — the Ledger.
///
/// `D-01` simple · `D-02` every vector writes here · `D-04`–`D-10`.
class LedgerPage extends ConsumerStatefulWidget {
  const LedgerPage({super.key, required this.timeFormat, this.onToggleTime});

  final TimeFormatPref timeFormat;
  final VoidCallback? onToggleTime;

  @override
  ConsumerState<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends ConsumerState<LedgerPage> {
  CaptureVector? _filter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showPrimer(context, ref, SwipPrimer.ledger);
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(allCapturesProvider(_filter));
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

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: SwipSpace.gutter, vertical: SwipSpace.sm),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = events[i];
                    return LedgerRow(
                      event: e,
                      mcc: repo?.lookup(e.mcc),
                      timeFormat: widget.timeFormat,
                      onToggleTimeFormat: widget.onToggleTime,
                    )
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

  Widget _filters() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
            SwipSpace.gutter, 0, SwipSpace.gutter, SwipSpace.md),
        child: Row(
          children: [
            _chip('All', null),
            for (final v in [
              CaptureVector.qr,
              CaptureVector.nfc,
              CaptureVector.intent,
              CaptureVector.link,
              CaptureVector.manual,
            ])
              _chip(v.shortLabel, v),
          ],
        ),
      );

  Widget _chip(String label, CaptureVector? v) {
    final selected = _filter == v;
    return Padding(
      padding: const EdgeInsets.only(right: SwipSpace.sm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = v),
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
