import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/swip_tokens.dart';
import '../features/paywall/raw_data_entitlement.dart';
import '../features/paywall/raw_data_purchase.dart';

/// `F-146` — the raw payload, behind the unlock.
///
/// ## Why the locked state shows the shape and not a blur
///
/// The obvious locked state is the payload with a blur over it and a padlock.
/// It is also the wrong one, twice over.
///
/// A blur is **not redaction**. A `ImageFiltered` blur on live text is a
/// rendering effect over a widget that still holds the string, and a
/// screenshot at the right moment, a text-scaling change, or an accessibility
/// reader can all recover it. If the payload is worth charging for, it must
/// not be in the tree at all when the view is locked — so it is not. The
/// locked widget never receives the string.
///
/// And a blurred block of text is a **tease**, which is the worst register to
/// use on someone who has already given you their data. What is shown instead
/// is the honest thing: exactly what is in there, described, so the decision
/// to pay is an informed one rather than a curiosity tax. The shape of a
/// payload is not the payload — "72 characters, 6 fields" tells you what you
/// would get and lets you reconstruct nothing.
class RawDataLock extends ConsumerWidget {
  const RawDataLock({super.key, required this.raw});

  final String raw;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(rawDataUnlockedProvider);
    return unlocked ? _Unlocked(raw: raw) : _Locked(shape: _Shape.of(raw));
  }
}

/// What can be said about a payload without disclosing it.
///
/// Every field here is a count or a classification. None of them can be
/// inverted back into the string, which is the test each one had to pass
/// before it was allowed on the locked screen.
class _Shape {
  const _Shape({
    required this.characters,
    required this.fields,
    required this.kind,
  });

  final int characters;
  final int fields;
  final String kind;

  static _Shape of(String raw) {
    final s = raw.trim();

    // A POS exchange, not a code: the APDU trace SWIP logs line by line.
    if (s.startsWith('<<') || s.contains('\n<< ')) {
      final lines = '\n$s'.split('\n<< ').length - 1;
      return _Shape(
        characters: s.length,
        fields: lines,
        kind: 'EMV terminal exchange',
      );
    }

    if (s.startsWith('upi://')) {
      final q = s.contains('?') ? s.split('?').last : '';
      return _Shape(
        characters: s.length,
        fields: q.isEmpty ? 0 : q.split('&').where((e) => e.isNotEmpty).length,
        kind: 'UPI payment code',
      );
    }

    // EMVCo merchant QR — the BharatQR / static-TLV form.
    if (RegExp(r'^0002\d{2}').hasMatch(s)) {
      return _Shape(
        characters: s.length,
        fields: _countEmvTags(s),
        kind: 'EMVCo merchant QR',
      );
    }

    return _Shape(characters: s.length, fields: 0, kind: 'Scanned code');
  }

  /// Walks the TLV without keeping a single value. Bails on anything
  /// malformed rather than guessing, because an inflated count would be a
  /// claim about content the user is being asked to pay to see.
  static int _countEmvTags(String s) {
    var i = 0, n = 0;
    while (i + 4 <= s.length) {
      final len = int.tryParse(s.substring(i + 2, i + 4));
      if (len == null) break;
      i += 4 + len;
      n++;
      if (i > s.length) return n - 1;
    }
    return n;
  }
}

class _Locked extends ConsumerWidget {
  const _Locked({required this.shape});

  final _Shape shape;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchase = ref.watch(rawDataPurchaseProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(SwipSpace.lg),
      decoration: BoxDecoration(
        color: SwipColors.surfaceRaised2,
        borderRadius: SwipRadius.inputAll,
        border: Border.all(color: SwipColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline_rounded,
                  size: 15, color: SwipColors.textTertiary),
              const SizedBox(width: SwipSpace.sm),
              Expanded(
                child: Text('RAW PAYLOAD',
                    style: SwipType.labelS
                        .copyWith(color: SwipColors.textTertiary)),
              ),
            ],
          ),
          const SizedBox(height: SwipSpace.md),

          // ── what is in there, without being what is in there ──
          Text(
            '${shape.kind} · ${shape.characters} characters'
            '${shape.fields > 0 ? ' · ${shape.fields} fields' : ''}',
            style: SwipType.bodyM.copyWith(color: SwipColors.textPrimary),
          ),
          const SizedBox(height: SwipSpace.xs),
          Text(
            'The verbatim string this capture came from. SWIP has already '
            'read everything it can out of it — the category, the merchant '
            'and the card verdict above are all from this — so unlocking it '
            'tells you nothing new about this shop. It is here for people who '
            'want to check SWIP\'s working, or keep the original.',
            style: SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
          ),
          const SizedBox(height: SwipSpace.md),

          // ── the part that must not be buried ──
          //
          // A paywall that does not say what is still free reads as a paywall
          // on everything. This one is on a view, and the sentence below is
          // the difference between that and holding a user's data hostage.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_outline_rounded,
                  size: 14, color: SwipColors.textTertiary),
              const SizedBox(width: SwipSpace.sm),
              Expanded(
                child: Text(
                  'Your backup already contains this payload in full, and '
                  'always will. Exporting is free and needs no unlock.',
                  style: SwipType.bodyS
                      .copyWith(color: SwipColors.textTertiary),
                ),
              ),
            ],
          ),
          const SizedBox(height: SwipSpace.lg),

          if (purchase.error != null) ...[
            Text(purchase.error!,
                style: SwipType.bodyS.copyWith(color: SwipColors.danger)),
            const SizedBox(height: SwipSpace.sm),
          ],

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: purchase.busy
                  ? null
                  : () => ref
                      .read(rawDataPurchaseProvider.notifier)
                      .buy(context),
              icon: purchase.busy
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_open_rounded, size: 16),
              label: Text(purchase.busy
                  ? 'Opening Google Play…'
                  : 'Unlock raw data · ${purchase.priceLabel}'),
            ),
          ),
          const SizedBox(height: SwipSpace.xs),
          Center(
            child: TextButton(
              onPressed: purchase.busy
                  ? null
                  : () =>
                      ref.read(rawDataPurchaseProvider.notifier).restore(),
              child: Text('Already paid? Restore',
                  style: SwipType.bodyS
                      .copyWith(color: SwipColors.textSecondary)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Unlocked extends StatelessWidget {
  const _Unlocked({required this.raw});

  final String raw;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_open_rounded,
                  size: 15, color: SwipColors.textTertiary),
              const SizedBox(width: SwipSpace.sm),
              Expanded(
                child: Text('RAW PAYLOAD',
                    style: SwipType.labelS
                        .copyWith(color: SwipColors.textTertiary)),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 16),
                color: SwipColors.textSecondary,
                tooltip: 'Copy',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: raw));
                  HapticFeedback.selectionClick();
                },
              ),
            ],
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(SwipSpace.md),
            decoration: BoxDecoration(
              color: SwipColors.surfaceRaised2,
              borderRadius: SwipRadius.inputAll,
            ),
            child: SelectableText(
              raw,
              style:
                  SwipType.mono.copyWith(color: SwipColors.textSecondary),
            ),
          ),
        ],
      );
}
