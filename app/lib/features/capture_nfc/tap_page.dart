import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/onboarding/primers.dart';
import '../../core/theme/swip_tokens.dart';
import '../../data/models/capture_event.dart';
import '../../data/repositories/capture_repository.dart';
import '../../widgets/capture_sheet.dart';

/// `S-03` — Tap a POS terminal. Vector 2, `F-08`.
///
/// The Kotlin side has existed since the first commit and has never been
/// reachable, because nothing in Dart turned it on. This is that missing half:
/// capability check, the prompt to switch NFC on, preferred-service
/// registration while this screen is foreground, and the capture stream.
///
/// The honesty of this screen is the point. The terminal *will* show an error,
/// the merchant *will* see it, and if the user is not told that a second before
/// it happens the feature feels broken rather than deliberate.
class TapPage extends ConsumerStatefulWidget {
  const TapPage({super.key});

  @override
  ConsumerState<TapPage> createState() => _TapPageState();
}

class _TapPageState extends ConsumerState<TapPage> {
  static const _method = MethodChannel('in.swip.app/nfc');
  static const _events = EventChannel('in.swip.app/nfc/captures');

  StreamSubscription<dynamic>? _sub;
  _NfcState _state = _NfcState.checking;
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) await showPrimer(context, ref, SwipPrimer.tapPos);
      await _start();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    // Always hand NFC routing back. SWIP competes for the field only while
    // this screen is open; holding it in the background would be a real
    // problem for the user's actual wallet.
    unawaited(_stop());
    super.dispose();
  }

  Future<void> _stop() async {
    try {
      await _method.invokeMethod<void>('stopListening');
    } catch (_) {
      // The screen is already gone. Android releases the preferred service on
      // pause anyway, so there is nothing left to recover here.
    }
  }

  Future<void> _start() async {
    try {
      final status =
          await _method.invokeMapMethod<String, dynamic>('status');
      if (!mounted) return;

      if (status == null || status['hasNfc'] != true) {
        setState(() => _state = _NfcState.noHardware);
        return;
      }
      if (status['hasHce'] != true) {
        setState(() => _state = _NfcState.noHce);
        return;
      }
      if (status['enabled'] != true) {
        setState(() => _state = _NfcState.disabled);
        return;
      }

      await _method.invokeMethod<void>('startListening');
      _sub = _events.receiveBroadcastStream().listen(_onCapture);
      if (mounted) setState(() => _state = _NfcState.listening);
    } on PlatformException {
      if (mounted) setState(() => _state = _NfcState.noHardware);
    } on MissingPluginException {
      // iOS: Apple permits host card emulation for contactless payments in the
      // EEA only, and India is not included. S-22 explains this properly.
      if (mounted) setState(() => _state = _NfcState.unsupportedPlatform);
    }
  }

  Future<void> _onCapture(dynamic raw) async {
    if (_handling || raw is! Map) return;
    setState(() => _handling = true);

    try {
      final tlv = Map<String, String>.from(
          (raw['tlv'] as Map).map((k, v) => MapEntry('$k', '$v')));
      final trace = raw['trace'] as String?;

      // EMV tag 9F15 is the merchant category code, and its source is the
      // terminal. If the terminal's kernel has no value provisioned it returns
      // zeros — which is an absence, not a category.
      final mcc = tlv['9F15'];
      final country = _countryFromNumeric(tlv['9F1A']);
      final merchantId = tlv['9F16']?.trim();

      final repo = await ref.read(captureRepositoryProvider.future);
      final event = await repo.record(
        vector: CaptureVector.nfc,
        mcc: mcc,
        merchantName: tlv['9F4E']?.trim(),
        countryCode: country,
        merchantKey: merchantId == null || merchantId.isEmpty
            ? null
            : 'emv:${country ?? 'XX'}:$merchantId',
        terminalId: tlv['9F1C']?.trim(),
        rawPayload: trace,
      );

      ref.read(ledgerRevisionProvider.notifier).state++;
      if (!mounted) return;

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: SwipColors.surfaceRaised,
        builder: (_) => CaptureSheet(
          event: event,
          mcc: repo.lookup(event.mcc),
          sourceLabel: 'POS terminal',
          rawPayload: trace,
          noCategoryTitle: 'The terminal did not give a category',
          noCategoryBody:
              'SWIP asked and this machine returned nothing in the category '
              'field. That is the shop\'s bank not filling it in — it is not '
              'something SWIP or the cashier can change. Scanning the shop\'s '
              'QR often works when the terminal will not.',
          // The terminal's own field names, exactly as EMV labels them. This
          // audience does not trust a number it cannot check.
          details: {
            if (tlv['9F16'] != null) 'Merchant ID · 9F16': tlv['9F16']!,
            if (tlv['9F1C'] != null) 'Terminal · 9F1C': tlv['9F1C']!,
            if (tlv['9F1A'] != null)
              'Country · 9F1A': '${tlv['9F1A']}${country == null ? '' : ' · $country'}',
            if (tlv['5F2A'] != null) 'Currency · 5F2A': tlv['5F2A']!,
            if (tlv['9F02'] != null) 'Amount · 9F02': tlv['9F02']!,
            if (tlv['9F35'] != null) 'Terminal type · 9F35': tlv['9F35']!,
            'Result': 'Declined by SWIP · SW=6985',
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _handling = false);
    }
  }

  /// ISO 3166 numeric → alpha-2 for the countries a terminal is likely to be
  /// in. Unknown codes pass through as null rather than a wrong guess.
  static String? _countryFromNumeric(String? n) => const {
        '356': 'IN', '840': 'US', '826': 'GB', '702': 'SG', '784': 'AE',
        '458': 'MY', '764': 'TH', '360': 'ID', '392': 'JP', '036': 'AU',
        '124': 'CA', '250': 'FR', '276': 'DE', '380': 'IT', '724': 'ES',
        '710': 'ZA', '076': 'BR', '484': 'MX', '554': 'NZ', '410': 'KR',
      }[n?.trim()];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tap to read')),
        body: Padding(
          padding: const EdgeInsets.all(SwipSpace.xl),
          child: switch (_state) {
            _NfcState.checking => const Center(
                child: CircularProgressIndicator(
                    color: SwipColors.gold500, strokeWidth: 2)),
            _NfcState.listening => _listening(),
            _NfcState.disabled => _problem(
                icon: Icons.nfc_rounded,
                title: 'NFC is switched off',
                body: 'SWIP reads the terminal over NFC, so it needs to be on. '
                    'Turn it on and come back — nothing else changes.',
                actionLabel: 'Open NFC settings',
                onAction: () async {
                  await _method.invokeMethod<void>('openNfcSettings');
                  await _start();
                },
              ),
            _NfcState.noHardware => _problem(
                icon: Icons.no_cell_rounded,
                title: 'This phone has no NFC',
                body: 'Tapping a terminal needs NFC hardware. Scanning QR codes '
                    'and checking links work exactly as before.',
              ),
            _NfcState.noHce => _problem(
                icon: Icons.no_cell_rounded,
                title: 'This phone cannot emulate a card',
                body: 'It has NFC, but not the card-emulation feature SWIP uses '
                    'to ask a terminal for its category.',
              ),
            _NfcState.unsupportedPlatform => _problem(
                icon: Icons.phone_iphone_rounded,
                title: "Tap isn't available on iPhone",
                body: 'Apple only allows apps to emulate a card in the European '
                    'Economic Area, and India is not included. Scanning QR '
                    'codes and checking links work fully.',
              ),
          },
        ),
      );

  Widget _listening() => Column(
        children: [
          const Spacer(),
          Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: SwipColors.gold700),
            ),
            child: const Center(
              child: Icon(Icons.contactless_rounded,
                  size: 64, color: SwipColors.gold500),
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .scaleXY(
                  begin: .92,
                  end: 1.06,
                  duration: 1900.ms,
                  curve: Curves.easeInOut)
              .then()
              .scaleXY(
                  begin: 1.06,
                  end: .92,
                  duration: 1900.ms,
                  curve: Curves.easeInOut),
          const SizedBox(height: SwipSpace.xxxl),
          Text(
            _handling ? 'Reading…' : 'Hold your phone to the terminal',
            style: SwipType.titleM.copyWith(color: SwipColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: SwipSpace.md),
          Text(
            'Ask the cashier to start the payment, then tap your phone instead '
            'of your card.',
            style: SwipType.bodyM.copyWith(color: SwipColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
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
                  child: Text(
                    'The terminal will show an error and no payment will '
                    'happen. That is expected — SWIP reads the category and '
                    'stops.',
                    style: SwipType.bodyS
                        .copyWith(color: SwipColors.infoOnInk),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _problem({
    required IconData icon,
    required String title,
    required String body,
    String? actionLabel,
    VoidCallback? onAction,
  }) =>
      Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: SwipColors.textTertiary),
            const SizedBox(height: SwipSpace.lg),
            Text(title,
                style:
                    SwipType.titleM.copyWith(color: SwipColors.textPrimary),
                textAlign: TextAlign.center),
            const SizedBox(height: SwipSpace.sm),
            Text(body,
                style:
                    SwipType.bodyM.copyWith(color: SwipColors.textSecondary),
                textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: SwipSpace.xl),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      );
}

enum _NfcState {
  checking,
  listening,
  disabled,
  noHardware,
  noHce,
  unsupportedPlatform,
}
