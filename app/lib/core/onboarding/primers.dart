import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/swip_tokens.dart';

/// Contextual onboarding.
///
/// Every feature explains itself **the moment it is first used**, not in a wall
/// of panels at install time that nobody reads. A primer appears *every time*
/// its feature is opened until the user ticks **"Don't show this again"** — so
/// it keeps teaching for as long as it is useful and stops the instant it is
/// not. The choice is per-primer, reversible in Settings, and stored locally.
///
/// This is deliberately not a one-shot: a person who taps a POS terminal twice
/// a month genuinely needs the "the terminal will show an error" reminder more
/// than once, and taking it away after the first view is why so many apps feel
/// like they abandoned you.
enum SwipPrimer {
  scanQr(
    key: 'primer_scan_qr',
    icon: Icons.qr_code_scanner_rounded,
    title: 'Point at any payment QR',
    body:
        'UPI, BharatQR, PIX, QRIS, PayNow, PromptPay and thirty more schemes. '
        'The merchant category is written inside the code itself, so SWIP reads '
        'it before a single rupee moves.',
    footnote: 'Nothing is paid. SWIP only reads the code.',
  ),

  tapPos(
    key: 'primer_tap_pos',
    icon: Icons.contactless_rounded,
    title: 'Tap the terminal instead of your card',
    body:
        'Ask the cashier to start the payment, then hold your phone to the '
        'machine. SWIP asks the terminal what kind of business it is, the '
        'terminal answers, and SWIP stops.',
    footnote:
        'The terminal will show an error and no payment will happen. '
        'That is expected — it is how SWIP stays out of your money.',
  ),

  checkLink(
    key: 'primer_check_link',
    icon: Icons.link_rounded,
    title: 'Paste a payment link',
    body:
        'Razorpay, Stripe, PayPal, Cashfree, Paytm and the rest. SWIP works out '
        'who the merchant is and what category they are most likely registered '
        'under.',
    footnote:
        'Links are the one vector SWIP has to infer rather than read, so these '
        'come back as "Likely" — never "Verified".',
  ),

  ledger(
    key: 'primer_ledger',
    icon: Icons.receipt_long_rounded,
    title: 'Everything you capture lands here',
    body:
        'Tap any row to see how SWIP worked it out, right down to the raw data '
        'the terminal sent. Tap the time on any row to switch the whole ledger '
        'between "08 Aug / 4:12 PM" and "2h ago".',
    footnote: 'Stored on your phone. Nothing leaves it unless you back it up.',
  ),

  backup(
    key: 'primer_backup',
    icon: Icons.cloud_upload_rounded,
    title: 'Your history, in your own Drive',
    body:
        'SWIP has no server and no account of yours. Sign in with Google and '
        'your ledger is written to your own Google Drive as a single file you '
        'can read, move, or delete.',
    footnote: 'Reinstall, import the file, and your history is back.',
  );

  const SwipPrimer({
    required this.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.footnote,
  });

  final String key;
  final IconData icon;
  final String title;
  final String body;
  final String footnote;
}

/// Reads and writes the "don't show again" flags.
class PrimerService {
  PrimerService(this._prefs);
  final SharedPreferences _prefs;

  bool isSuppressed(SwipPrimer p) => _prefs.getBool(p.key) ?? false;

  Future<void> setSuppressed(SwipPrimer p, bool value) async =>
      _prefs.setBool(p.key, value);

  /// Settings → "Show all explanations again".
  Future<void> resetAll() async {
    for (final p in SwipPrimer.values) {
      await _prefs.remove(p.key);
    }
  }

  int get suppressedCount =>
      SwipPrimer.values.where(isSuppressed).length;
}

final sharedPrefsProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

final primerServiceProvider = FutureProvider<PrimerService>((ref) async {
  return PrimerService(await ref.watch(sharedPrefsProvider.future));
});

/// Show [primer] unless the user has suppressed it. Returns when dismissed.
///
/// Call this *before* opening the feature, so the explanation arrives ahead of
/// the camera or the NFC prompt rather than on top of it.
Future<void> showPrimer(
  BuildContext context,
  WidgetRef ref,
  SwipPrimer primer,
) async {
  final service = await ref.read(primerServiceProvider.future);
  if (service.isSuppressed(primer)) return;
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: SwipColors.surfaceRaised,
    builder: (ctx) => _PrimerSheet(primer: primer, service: service),
  );
}

class _PrimerSheet extends StatefulWidget {
  const _PrimerSheet({required this.primer, required this.service});
  final SwipPrimer primer;
  final PrimerService service;

  @override
  State<_PrimerSheet> createState() => _PrimerSheetState();
}

class _PrimerSheetState extends State<_PrimerSheet> {
  bool _dontShow = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.primer;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            SwipSpace.xl, SwipSpace.sm, SwipSpace.xl, SwipSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(SwipSpace.md),
              decoration: BoxDecoration(
                color: SwipColors.gold900,
                borderRadius: SwipRadius.inputAll,
              ),
              child: Icon(p.icon, color: SwipColors.gold300, size: 26),
            )
                .animate()
                .fadeIn(duration: 260.ms)
                .scaleXY(begin: .82, curve: Curves.easeOutBack),

            const SizedBox(height: SwipSpace.lg),

            Text(p.title,
                    style: SwipType.titleM
                        .copyWith(color: SwipColors.textPrimary))
                .animate()
                .fadeIn(delay: 70.ms, duration: 320.ms)
                .moveY(begin: 12, curve: SwipMotion.captureCurve),

            const SizedBox(height: SwipSpace.sm),

            Text(p.body,
                    style: SwipType.bodyM
                        .copyWith(color: SwipColors.textSecondary))
                .animate()
                .fadeIn(delay: 130.ms, duration: 320.ms)
                .moveY(begin: 12, curve: SwipMotion.captureCurve),

            const SizedBox(height: SwipSpace.lg),

            Container(
              padding: const EdgeInsets.all(SwipSpace.md),
              decoration: BoxDecoration(
                color: SwipColors.infoFill,
                borderRadius: SwipRadius.inputAll,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 18, color: SwipColors.infoOnInk),
                  const SizedBox(width: SwipSpace.sm),
                  Expanded(
                    child: Text(p.footnote,
                        style: SwipType.bodyS
                            .copyWith(color: SwipColors.infoOnInk)),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: 190.ms, duration: 320.ms)
                .moveY(begin: 12, curve: SwipMotion.captureCurve),

            const SizedBox(height: SwipSpace.sm),

            CheckboxListTile(
              value: _dontShow,
              onChanged: (v) => setState(() => _dontShow = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: SwipColors.gold500,
              checkColor: const Color(0xFF14100A),
              title: Text("Don't show this again",
                  style: SwipType.bodyM
                      .copyWith(color: SwipColors.textSecondary)),
            ),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  if (_dontShow) {
                    await widget.service
                        .setSuppressed(widget.primer, true);
                  }
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Got it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
