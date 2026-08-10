import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/swip_tokens.dart';
import '../../data/repositories/capture_repository.dart';

/// `S-25` — teach SWIP from a bank statement. `F-50`.
///
/// ## Why this screen is the most valuable one in the app
///
/// Every other vector reads a category *before* a payment, from whatever the
/// merchant happened to publish. This one reads it *after*, from what the
/// acquirer actually posted — which is the settled truth rather than a
/// prediction, and which exists for **every** merchant, including the ones
/// whose QR carries nothing at all.
///
/// The line that makes it work:
///
/// ```
/// UPIOUT/658724829452/paytm.s233ffl@pty/Demo/5451
/// ```
///
/// The category and the payee handle are in the same line, and the handle is
/// the same string a QR scan produces. So SWIP never has to ask which shop a
/// row belongs to — and one paste back-fills every "Unknown category" capture
/// of that shop you already have.
class StatementImportPage extends ConsumerStatefulWidget {
  const StatementImportPage({super.key});

  @override
  ConsumerState<StatementImportPage> createState() =>
      _StatementImportPageState();
}

class _StatementImportPageState extends ConsumerState<StatementImportPage> {
  final _controller = TextEditingController();
  bool _busy = false;
  ({int learned, int backfilled})? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text != null && text.trim().isNotEmpty) {
      _controller.text = text;
      setState(() {});
    }
  }

  Future<void> _learn() async {
    if (_busy || _controller.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final repo = await ref.read(captureRepositoryProvider.future);
      final result = await repo.learnFromStatement(_controller.text);
      ref.read(ledgerRevisionProvider.notifier).state++;
      if (mounted) setState(() => _result = result);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Learn from a statement')),
        body: ListView(
          padding: const EdgeInsets.all(SwipSpace.xl),
          children: [
            Text(
              'Your bank already knows every category',
              style: SwipType.titleM.copyWith(color: SwipColors.textPrimary),
            ),
            const SizedBox(height: SwipSpace.sm),
            Text(
              'Some banks print the merchant category right in the statement '
              'line — Federal Bank does. Paste any part of a statement and SWIP '
              'reads the categories out of it.',
              style: SwipType.bodyM.copyWith(color: SwipColors.textSecondary),
            ),

            const SizedBox(height: SwipSpace.lg),
            _Example(),

            const SizedBox(height: SwipSpace.lg),
            TextField(
              controller: _controller,
              maxLines: 8,
              minLines: 4,
              autocorrect: false,
              onChanged: (_) => setState(() {}),
              style: SwipType.mono.copyWith(color: SwipColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'Paste statement lines here…',
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: SwipSpace.md),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _paste,
                  icon: const Icon(Icons.content_paste_rounded, size: 18),
                  label: const Text('Paste'),
                ),
              ),
              const SizedBox(width: SwipSpace.md),
              Expanded(
                child: FilledButton(
                  onPressed: _controller.text.trim().isEmpty || _busy
                      ? null
                      : _learn,
                  child: Text(_busy ? 'Reading…' : 'Learn from this'),
                ),
              ),
            ]),

            if (_result != null) ...[
              const SizedBox(height: SwipSpace.lg),
              _Result(result: _result!),
            ],

            const SizedBox(height: SwipSpace.xxl),
            _How(),
          ],
        ),
      );
}

class _Example extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(SwipSpace.md),
        decoration: BoxDecoration(
          color: SwipColors.surfaceRaised2,
          borderRadius: SwipRadius.inputAll,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A line SWIP can read',
                style:
                    SwipType.labelS.copyWith(color: SwipColors.textTertiary)),
            const SizedBox(height: SwipSpace.sm),
            SelectableText(
              'UPIOUT/658724829452/paytm.s233ffl@pty/Demo/5451',
              style: SwipType.mono.copyWith(color: SwipColors.gold500),
            ),
            const SizedBox(height: SwipSpace.sm),
            Text(
              'The shop is paytm.s233ffl@pty and the category is 5451 — dairy '
              'products. SWIP takes both.',
              style:
                  SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
            ),
          ],
        ),
      );
}

class _Result extends StatelessWidget {
  const _Result({required this.result});
  final ({int learned, int backfilled}) result;

  @override
  Widget build(BuildContext context) {
    final nothing = result.learned == 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SwipSpace.md),
      decoration: BoxDecoration(
        color: nothing ? SwipColors.warningFill : SwipColors.successFill,
        borderRadius: SwipRadius.inputAll,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            nothing ? Icons.info_outline_rounded : Icons.check_circle_rounded,
            size: 18,
            color: nothing
                ? SwipColors.warningOnInk
                : SwipConfidenceColors.verifiedOnInk,
          ),
          const SizedBox(width: SwipSpace.sm),
          Expanded(
            child: Text(
              nothing
                  ? 'No categories in that text. Your bank may not print them — '
                      'not every one does. Federal Bank is the one known to.'
                  : 'Learned ${result.learned} '
                      '${result.learned == 1 ? "merchant" : "merchants"}'
                      '${result.backfilled > 0 ? ", and filled in ${result.backfilled} past ${result.backfilled == 1 ? "capture" : "captures"}" : ""}. '
                      'Their QR codes will answer straight away from now on.',
              style: SwipType.bodyS.copyWith(
                color: nothing
                    ? SwipColors.warningOnInk
                    : SwipConfidenceColors.verifiedOnInk,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).moveY(begin: 8);
  }
}

class _How extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How to get the text',
              style: SwipType.label.copyWith(color: SwipColors.textSecondary)),
          const SizedBox(height: SwipSpace.sm),
          for (final (n, step) in const [
            (1, 'Open your bank statement PDF or your net-banking history.'),
            (2, 'Select the transaction lines and copy them.'),
            (3, 'Come back here and paste. You can also share the text '
                'straight to SWIP from any app.'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: SwipSpace.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$n.',
                      style: SwipType.bodyS
                          .copyWith(color: SwipColors.gold500)),
                  const SizedBox(width: SwipSpace.sm),
                  Expanded(
                    child: Text(step,
                        style: SwipType.bodyS
                            .copyWith(color: SwipColors.textSecondary)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: SwipSpace.md),
          Container(
            padding: const EdgeInsets.all(SwipSpace.md),
            decoration: BoxDecoration(
              color: SwipColors.infoFill,
              borderRadius: SwipRadius.inputAll,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 18, color: SwipColors.infoOnInk),
                const SizedBox(width: SwipSpace.sm),
                Expanded(
                  child: Text(
                    'This never leaves your phone. SWIP has no server — the '
                    'text is read on the device and only the merchant handle '
                    'and its category are kept. Amounts and balances are '
                    'ignored entirely.',
                    style: SwipType.bodyS
                        .copyWith(color: SwipColors.infoOnInk),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}
