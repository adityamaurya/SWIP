import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/swip_tokens.dart';
import 'merchant_lookup.dart';

/// `F-160` — the screen that turns the merchant-name lookup on.
///
/// ## What this screen is actually asking for
///
/// Everything else in SWIP happens on the device. This is the one feature that
/// sends something off it, and the thing it sends is a payment address. The
/// screen is built so that nobody can switch it on without having been told
/// that, in those words, before the switch moves.
///
/// It is also asking for a **Razorpay secret key**, which is a much larger ask
/// than it looks. The same credentials that validate a VPA can create orders,
/// list every payment on the account and issue refunds. There is no read-only
/// scope. So the warning here is not boilerplate and it is not hedging: it is
/// the accurate description of what is being handed over, and the test-key
/// suggestion is a real way to see the feature work without that exposure.
class LookupSettingsPage extends ConsumerStatefulWidget {
  const LookupSettingsPage({super.key});

  @override
  ConsumerState<LookupSettingsPage> createState() => _LookupSettingsPageState();
}

class _LookupSettingsPageState extends ConsumerState<LookupSettingsPage> {
  final _keyId = TextEditingController();
  final _secret = TextEditingController();

  bool _enabled = false;
  bool _loading = true;
  bool _testing = false;
  String? _testResult;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keyId.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await MerchantLookupSettings.load();
    if (!mounted) return;
    setState(() {
      _enabled = s.enabled;
      _keyId.text = s.keyId;
      _secret.text = s.keySecret;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await MerchantLookupSettings(
      enabled: _enabled,
      keyId: _keyId.text,
      keySecret: _secret.text,
    ).save();
    // The directory caches answers in memory, so it has to be rebuilt when the
    // key changes — otherwise the old key's results outlive the old key.
    ref.invalidate(merchantLookupSettingsProvider);
    ref.invalidate(merchantDirectoryProvider);
  }

  /// One real lookup, against a VPA the owner already has in their PDF.
  ///
  /// A key field with no way to check the key is a field people fill in wrong
  /// and discover months later at a counter. This is the check, and it doubles
  /// as an honest demonstration: the name that comes back is the same name
  /// CRED shows for that sticker, which is the entire argument for the
  /// feature.
  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
      _testOk = false;
    });

    final dir = buildDirectory(MerchantLookupSettings(
      enabled: true,
      keyId: _keyId.text,
      keySecret: _secret.text,
    ));
    final entry = await dir.lookup('paytm.s1jii6k@pty');

    if (!mounted) return;
    setState(() {
      _testing = false;
      _testOk = entry.ok && entry.name != null;
      _testResult = entry.ok
          ? (entry.name != null
              ? 'Working. That address resolves to “${entry.name}”.'
              : entry.valid == false
                  ? 'The key works. That test address no longer resolves, '
                      'which is a fact about the address rather than a problem '
                      'with your key.'
                  : 'The key works, but no name came back.')
          : entry.problem;
    });
  }

  Future<void> _forget() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove the key?'),
        content: const Text(
          'SWIP will delete the key id and secret from this phone and switch '
          'the lookup off. Nothing else changes — every merchant name SWIP '
          'has already learned stays in the ledger.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (yes != true) return;

    await MerchantLookupSettings.forget();
    ref.invalidate(merchantLookupSettingsProvider);
    ref.invalidate(merchantDirectoryProvider);
    if (!mounted) return;
    setState(() {
      _enabled = false;
      _keyId.clear();
      _secret.clear();
      _testResult = null;
      _testOk = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Merchant names')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: SwipSpace.sm),
        children: [
          Padding(
            padding: const EdgeInsets.all(SwipSpace.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('The name CRED shows',
                    style: SwipType.titleL
                        .copyWith(color: SwipColors.textPrimary)),
                const SizedBox(height: SwipSpace.md),
                Text(
                  'A Paytm sticker carries “Paytm” as the payee name and '
                  'nothing else. CRED shows the shop\'s registered name for '
                  'that same code, because it asks a payment provider to '
                  'resolve the address. The name is not in the QR — no app '
                  'can read it out of one.\n\n'
                  'SWIP can make that same lookup, with your own Razorpay '
                  'account.',
                  style: SwipType.bodyM
                      .copyWith(color: SwipColors.textSecondary),
                ),
              ],
            ),
          ),

          // The disclosure sits ABOVE the switch, not below it. A privacy
          // notice you scroll past after acting is a receipt, not a notice.
          const _Warning(
            icon: Icons.wifi_tethering_rounded,
            title: 'This is the one thing SWIP sends off your phone',
            body: 'When it is on, and only when a shop\'s name is missing, '
                'SWIP sends that shop\'s payment address to Razorpay and asks '
                'who it belongs to. Never a capture, never an amount, never '
                'your location, never anything about your ledger. Each shop '
                'is looked up once, ever, and the answer is kept on the '
                'phone.',
          ),
          const _Warning(
            icon: Icons.key_off_rounded,
            title: 'A Razorpay key can do more than look up names',
            body: 'The same key pair that resolves an address can also create '
                'orders, list every payment on your account and issue '
                'refunds. Razorpay has no read-only key. Stored on a phone it '
                'is readable by anything with root, and it travels in device '
                'backups.\n\n'
                'If you only want to see this work, use a test key '
                '(rzp_test_…). It cannot move money.',
            danger: true,
          ),

          SwitchListTile(
            value: _enabled,
            onChanged: (v) async {
              setState(() => _enabled = v);
              await _save();
            },
            title: const Text('Look up merchant names'),
            subtitle: Text(
              _enabled
                  ? 'On. Only ever sends a payment address.'
                  : 'Off. SWIP is not contacting anything.',
              style:
                  SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
            ),
            secondary: const Icon(Icons.badge_outlined),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(SwipSpace.gutter, SwipSpace.md,
                SwipSpace.gutter, SwipSpace.sm),
            child: TextField(
              controller: _keyId,
              onChanged: (_) => _save(),
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Key id',
                hintText: 'rzp_test_… or rzp_live_…',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SwipSpace.gutter),
            child: TextField(
              controller: _secret,
              onChanged: (_) => _save(),
              // Obscured because this screen gets opened at a desk with
              // people around, and the secret is the half that matters.
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Key secret',
                border: OutlineInputBorder(),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(SwipSpace.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: _testing ? null : _test,
                  icon: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.wifi_find_outlined),
                  label: Text(_testing ? 'Asking Razorpay…' : 'Test the key'),
                ),
                if (_testResult != null) ...[
                  const SizedBox(height: SwipSpace.md),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _testOk
                            ? Icons.check_circle_rounded
                            : Icons.error_outline_rounded,
                        size: 18,
                        color: _testOk
                            ? SwipColors.success
                            : SwipColors.danger,
                      ),
                      const SizedBox(width: SwipSpace.sm),
                      Expanded(
                        child: Text(_testResult!,
                            style: SwipType.bodyS.copyWith(
                                color: SwipColors.textSecondary)),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: SwipSpace.lg),
                TextButton.icon(
                  onPressed: _forget,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Remove the key from this phone'),
                ),
              ],
            ),
          ),

          const _Warning(
            icon: Icons.category_outlined,
            title: 'It will not give you the category',
            body: 'No provider sells the MCC. It is assigned by the acquiring '
                'bank at onboarding and lives in that bank\'s switch. This is '
                'why CRED writes “merchant MAY not accept RuPay CC” — the '
                'word may is them inferring from the same signals SWIP has, '
                'because they do not have the category either.',
          ),
          const SizedBox(height: SwipSpace.xxxl),
        ],
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({
    required this.icon,
    required this.title,
    required this.body,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool danger;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            SwipSpace.gutter, 0, SwipSpace.gutter, SwipSpace.lg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(SwipSpace.lg),
          decoration: BoxDecoration(
            color: danger ? SwipColors.dangerBg : SwipColors.surfaceRaised,
            borderRadius: SwipRadius.cardAll,
            border: Border.all(
                color: danger ? SwipColors.danger : SwipColors.hairline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon,
                    size: 18,
                    color: danger
                        ? SwipColors.danger
                        : SwipColors.textSecondary),
              ),
              const SizedBox(width: SwipSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: SwipType.label.copyWith(
                            color: danger
                                ? SwipColors.danger
                                : SwipColors.textPrimary)),
                    const SizedBox(height: SwipSpace.xs),
                    Text(body,
                        style: SwipType.bodyS
                            .copyWith(color: SwipColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
