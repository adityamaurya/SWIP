import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/swip_tokens.dart';
import '../../widgets/wizard_shell.dart';
import 'merchant_lookup.dart';

/// `F-181` — **the walkthrough for the merchant-name lookup.**
///
/// > *"What is that Razorpay thing section just below 'Scan me anywhere'
/// > telling me about? What is that feature going to need?… it is not even
/// > understandable for me and is understood by the other people as well.
/// > Since I am not able to understand, how would the users be able to
/// > understand that?"*
///
/// ## The diagnosis, which is not "add more copy"
///
/// The settings screen this replaces on a first run was not badly written. It
/// opened with an accurate paragraph about what CRED shows, then two warning
/// panels that are true and load-bearing, then a switch and two text fields.
/// Every sentence on it is correct.
///
/// **The problem is that it explains the feature to somebody who already knows
/// what it is.** It never says the three things a person actually needs in
/// order: *what will I get*, *what does it cost me*, and *where do I get the
/// thing you are asking me to paste*. The owner commissioned the feature and
/// could not answer any of the three from that screen, which is as clear a
/// verdict as this project has ever had.
///
/// So this is the same information, re-ordered into the sequence somebody
/// meets it in, with the last screen being the one that does the work. It is
/// `F-159`'s pattern, which was built for exactly this shape of problem — a
/// feature with prerequisites that do not fit in a subtitle.
///
/// ## Why the warnings did not get softer
///
/// They are the reason the feature is opt-in. A Razorpay key pair is **not
/// read-only** — Razorpay does not issue one — so the same credentials that
/// resolve a payment address can create orders, list every payment on the
/// account and issue refunds. Screen 3 says that in those words and recommends
/// a test key, which cannot move money.
///
/// What changed is where they sit. A risk disclosed *before* the field that
/// collects the credential is a notice. The same sentence below it is a
/// receipt.
class LookupWizard extends StatefulWidget {
  const LookupWizard({super.key});

  /// Shown once. After that the Settings row opens `LookupSettingsPage`.
  static const seenKey = 'swip.lookup.wizardSeen';

  static Future<bool> seen() async =>
      (await SharedPreferences.getInstance()).getBool(seenKey) ?? false;

  static Future<void> markSeen() async =>
      (await SharedPreferences.getInstance()).setBool(seenKey, true);

  @override
  State<LookupWizard> createState() => _LookupWizardState();
}

class _LookupWizardState extends State<LookupWizard> {
  final _pages = PageController();
  final _keyId = TextEditingController();
  final _secret = TextEditingController();

  int _step = 0;

  /// Total screens. Named rather than counted from a list, so the progress bar
  /// and the page view cannot disagree.
  static const _steps = 4;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  @override
  void dispose() {
    _pages.dispose();
    _keyId.dispose();
    _secret.dispose();
    super.dispose();
  }

  /// If a key is already stored, show it. Somebody re-running this walkthrough
  /// is usually here because the key stopped working, and making them find it
  /// again is a small cruelty.
  Future<void> _prefill() async {
    final s = await MerchantLookupSettings.load();
    if (!mounted) return;
    setState(() {
      _keyId.text = s.keyId;
      _secret.text = s.keySecret;
    });
  }

  void _go(int step) {
    final target = step.clamp(0, _steps - 1);
    setState(() => _step = target);
    _pages.animateToPage(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  /// Saves and closes. `enabled` is only turned on when both halves are
  /// present — `MerchantLookupSettings.usable` requires it anyway, and a
  /// switch that reads "on" while nothing can happen is the exact shape
  /// `CLAUDE.md` records as unfixable on screen.
  Future<void> _finish({required bool enable}) async {
    final id = _keyId.text.trim();
    final secret = _secret.text.trim();
    await MerchantLookupSettings(
      enabled: enable && id.isNotEmpty && secret.isNotEmpty,
      keyId: id,
      keySecret: secret,
    ).save();
    await LookupWizard.markSeen();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _step == 0
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => _go(_step - 1),
              ),
        title: WizardProgress(step: _step, total: _steps),
        titleSpacing: 0,
      ),
      body: PageView(
        controller: _pages,
        // Driven by the buttons, not by swiping. The last screen is the only
        // one that saves anything, and a flow you can swipe past is a flow
        // that ends with nothing stored and no sign of why.
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _WhatYouGet(onNext: () => _go(1)),
          _WhatLeaves(onNext: () => _go(2)),
          _TheRisk(onNext: () => _go(3)),
          _GetTheKey(
            keyId: _keyId,
            secret: _secret,
            onDone: () => _finish(enable: true),
            onSkip: () => _finish(enable: false),
          ),
        ],
      ),
    );
  }
}

// ── 1. what you get ─────────────────────────────────────────────────────────

class _WhatYouGet extends StatelessWidget {
  const _WhatYouGet({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => WizardScreen(
        title: 'Turn a payment address\ninto a shop name',
        body: [
          Text(
            'Scan a Paytm sticker and this is the whole code, in full:',
            style: SwipType.bodyM.copyWith(color: SwipColors.textSecondary),
          ),
          const SizedBox(height: SwipSpace.md),
          const _Payload('upi://pay?pa=paytm.s27l8o9@pty&pn=Paytm'),
          const SizedBox(height: SwipSpace.lg),
          Text(
            'The name field says "Paytm". Every Paytm sticker in India says '
            '"Paytm" — so on its own, SWIP can tell you this is a Paytm '
            'merchant and not which one.\n\n'
            'CRED shows the actual shop name for the same code. It is not '
            'reading it out of the QR, because the name is not in the QR. It '
            'asks a payment provider who owns the address.\n\n'
            'SWIP can make the same request. It needs an account to make it '
            'with, and since SWIP has no server, that account is yours.',
            style: SwipType.bodyM.copyWith(color: SwipColors.textSecondary),
          ),
          const SizedBox(height: SwipSpace.xl),
          const _Note(
            icon: Icons.info_outline_rounded,
            text: 'This does not find the category code. Nothing does, from a '
                'payment address — that comes from the QR itself or from the '
                'shop\'s card machine.',
          ),
        ],
        action: FilledButton(onPressed: onNext, child: const Text('Continue')),
      );
}

// ── 2. what leaves the phone ────────────────────────────────────────────────

class _WhatLeaves extends StatelessWidget {
  const _WhatLeaves({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => WizardScreen(
        title: 'The only thing SWIP\never sends anywhere',
        body: [
          Text(
            'Switched on, and only when a scanned shop has no name, SWIP '
            'sends one line:',
            style: SwipType.bodyM.copyWith(color: SwipColors.textSecondary),
          ),
          const SizedBox(height: SwipSpace.md),
          const _Payload('{ "vpa": "paytm.s27l8o9@pty" }'),
          const SizedBox(height: SwipSpace.lg),
          Text('Never sent',
              style: SwipType.label.copyWith(color: SwipColors.textPrimary)),
          const SizedBox(height: SwipSpace.sm),
          ...const [
            'Anything you have captured',
            'Any amount',
            'Your location',
            'Anything from your ledger',
            'Anything identifying you or your phone',
          ].map((t) => Padding(
                padding: const EdgeInsets.only(bottom: SwipSpace.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.close_rounded,
                        size: 16, color: SwipColors.danger),
                    const SizedBox(width: SwipSpace.sm),
                    Expanded(
                      child: Text(t,
                          style: SwipType.bodyM
                              .copyWith(color: SwipColors.textSecondary)),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: SwipSpace.lg),
          Text(
            'Each shop is looked up once, ever. The answer is kept on this '
            'phone, so walking past the same stall tomorrow sends nothing.',
            style: SwipType.bodyM.copyWith(color: SwipColors.textSecondary),
          ),
        ],
        action: FilledButton(onPressed: onNext, child: const Text('Continue')),
      );
}

// ── 3. the risk, before the field that collects it ──────────────────────────

class _TheRisk extends StatelessWidget {
  const _TheRisk({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => WizardScreen(
        title: 'Use a test key',
        body: [
          Text(
            'A Razorpay key pair is not read-only. Razorpay does not issue a '
            'read-only key. The same credentials that look up a name can '
            'also:',
            style: SwipType.bodyM.copyWith(color: SwipColors.textSecondary),
          ),
          const SizedBox(height: SwipSpace.md),
          const WizardStep(n: 1, text: 'Create orders', warn: true),
          const WizardStep(
              n: 2, text: 'List every payment on your account', warn: true),
          const WizardStep(n: 3, text: 'Issue refunds', warn: true),
          Text(
            'Stored on a phone, it is readable by anything with root, and it '
            'travels in device backups.\n\n'
            'So use a test key. It starts with rzp_test_ and it works against '
            'a sandbox — it cannot move money. That is what the next screen '
            'walks you through, and it is what SWIP recommends you leave in '
            'the app permanently.',
            style: SwipType.bodyM.copyWith(color: SwipColors.textSecondary),
          ),
          const SizedBox(height: SwipSpace.xl),
          const _Note(
            icon: Icons.lock_outline_rounded,
            text: 'The only design with no risk at all is a server holding the '
                'key. SWIP deliberately has no server — that is the trade, '
                'and it is worth knowing you are making it.',
          ),
        ],
        action: FilledButton(onPressed: onNext, child: const Text('Continue')),
      );
}

// ── 4. get the key, paste it, done ──────────────────────────────────────────

class _GetTheKey extends StatelessWidget {
  const _GetTheKey({
    required this.keyId,
    required this.secret,
    required this.onDone,
    required this.onSkip,
  });

  final TextEditingController keyId;
  final TextEditingController secret;
  final VoidCallback onDone;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => WizardScreen(
        title: 'Get your key',
        body: [
          const WizardStep(
            n: 1,
            text: 'Go to razorpay.com and create a free account. You do not '
                'need a business, and you do not need to take a payment.',
          ),
          const WizardStep(
            n: 2,
            text: 'Make sure the dashboard is in Test Mode — there is a '
                'switch at the top.',
          ),
          const WizardStep(
            n: 3,
            text: 'Account & Settings → API Keys → Generate Test Key.',
          ),
          const WizardStep(
            n: 4,
            text: 'Copy both halves. The secret is shown once and never '
                'again — if you lose it, generate a new pair.',
            warn: true,
          ),
          const SizedBox(height: SwipSpace.sm),
          TextField(
            controller: keyId,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Key id',
              hintText: 'rzp_test_…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: SwipSpace.md),
          TextField(
            controller: secret,
            // Obscured because this gets done at a desk with people around,
            // and the secret is the half that matters.
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Key secret',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: SwipSpace.lg),
          const _Note(
            icon: Icons.wifi_find_outlined,
            text: 'Next screen has a "Test the key" button. Press it — it asks '
                'Razorpay and shows you the reply, so you find out now rather '
                'than at a counter.',
          ),
        ],
        action: FilledButton(onPressed: onDone, child: const Text('Save and turn on')),
        secondary: TextButton(
          onPressed: onSkip,
          child: const Text('Skip — leave it off for now'),
        ),
      );
}

// ── small pieces ────────────────────────────────────────────────────────────

/// A payload, shown as the bytes it is.
///
/// Monospaced and selectable on purpose: the whole argument of screen 1 is
/// *look at what is actually in the code*, and a paraphrase would be asking
/// the reader to take it on trust — which is the thing this walkthrough exists
/// to stop doing.
class _Payload extends StatelessWidget {
  const _Payload(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(SwipSpace.md),
        decoration: BoxDecoration(
          color: SwipColors.surfaceSunken,
          borderRadius: SwipRadius.inputAll,
          border: Border.all(color: SwipColors.hairline),
        ),
        child: SelectableText(
          text,
          style: SwipType.bodyS.copyWith(
            color: SwipColors.textPrimary,
            fontFamily: 'monospace',
            height: 1.5,
          ),
        ),
      );
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(SwipSpace.md),
        decoration: BoxDecoration(
          color: SwipColors.surfaceSunken,
          borderRadius: SwipRadius.inputAll,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: SwipColors.textTertiary),
            const SizedBox(width: SwipSpace.md),
            Expanded(
              child: Text(text,
                  style: SwipType.bodyS
                      .copyWith(color: SwipColors.textSecondary)),
            ),
          ],
        ),
      );
}
