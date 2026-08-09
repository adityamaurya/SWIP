import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/settings/home_market.dart';
import 'core/theme/swip_theme.dart';
import 'core/theme/swip_tokens.dart';
import 'core/utils/swip_time.dart';
import 'data/repositories/capture_repository.dart';
import 'data/models/capture_event.dart';
import 'data/sources/capture_resolver.dart';
import 'features/capture_intent/intent_capture.dart';
import 'features/capture_link/link_page.dart';
import 'features/capture_nfc/tap_page.dart';
import 'features/capture_qr/scan_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/ledger/ledger_page.dart';
import 'features/onboarding/home_market_page.dart';
import 'features/settings/settings_page.dart';
import 'widgets/capture_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SwipApp()));
}

class SwipApp extends StatelessWidget {
  const SwipApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'SWIP',
        debugShowCheckedModeBanner: false,
        theme: SwipTheme.dark(),
        darkTheme: SwipTheme.dark(),
        // Foil is the only look. Reverses A-06 — see
        // docs/14-VISUAL-DIRECTION-FOIL.md.
        themeMode: ThemeMode.dark,
        home: const IntentCaptureListener(child: SwipShell()),
      );
}

/// The app shell.
///
/// Three destinations and one action. The capture action sits in the middle of
/// the bar because it is the thing people open SWIP to do — burying it behind a
/// tab would cost a tap on the only interaction that matters.
class SwipShell extends ConsumerStatefulWidget {
  const SwipShell({super.key});

  @override
  ConsumerState<SwipShell> createState() => _SwipShellState();
}

class _SwipShellState extends ConsumerState<SwipShell>
    with WidgetsBindingObserver {
  int _index = 0;

  /// `F-01`. The dashboard's camera runs only when the app is resumed *and*
  /// Home is the visible tab. `IndexedStack` keeps every tab alive, so without
  /// this the viewfinder would hold the camera open behind the Ledger — a
  /// battery cost and, worse, a green privacy dot with no visible camera.
  bool _resumed = true;

  /// True while a capture sheet is open, so the inline viewfinder cannot stack
  /// a second sheet on top of the first.
  bool _capturing = false;

  /// `D-07`. Global and shared by every time cell in the app, so tapping one
  /// switches them all. Persisted in [SettingsPage].
  TimeFormatPref _timeFormat = TimeFormatPref.absolute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOnboard());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final resumed = state == AppLifecycleState.resumed;
    if (resumed != _resumed) setState(() => _resumed = resumed);
  }

  /// `F-15`. Asked once, before anything else, because every later
  /// domestic/international verdict is measured against the answer.
  Future<void> _maybeOnboard() async {
    final needs = await ref.read(needsHomeMarketProvider.future);
    if (!needs || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const HomeMarketPage(),
    ));
  }

  void _toggleTime() => setState(() {
        _timeFormat = _timeFormat == TimeFormatPref.absolute
            ? TimeFormatPref.relative
            : TimeFormatPref.absolute;
      });

  Future<void> _openScan() => _openCapture(CaptureVector.qr);

  /// F-08, F-09. The dashboard has always sent which tile was tapped; the
  /// shell used to throw it away and open the scanner regardless, which is
  /// why Tap and Link appeared to do nothing.
  Future<void> _openCapture(CaptureVector vector) async {
    final page = switch (vector) {
      CaptureVector.nfc => const TapPage(),
      CaptureVector.link => const LinkPage(),
      _ => const ScanPage(),
    };
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  /// `F-01`. A code read by the dashboard's inline viewfinder. Identical
  /// handling to the full-screen scanner — same resolver, same ledger write,
  /// same sheet — so the two paths can never describe the same sticker
  /// differently.
  Future<void> _onInlineScan(String raw) async {
    if (_capturing) return;
    setState(() => _capturing = true);

    try {
      final resolved = CaptureResolver.resolve(raw);
      final repo = await ref.read(captureRepositoryProvider.future);

      final event = await repo.record(
        vector: resolved.vector,
        mcc: resolved.mcc,
        merchantName: resolved.merchantName,
        merchantCity: resolved.merchantCity,
        countryCode: resolved.countryCode,
        merchantKey: resolved.merchantKey,
        amount: resolved.amount,
        currency: resolved.currency,
        terminalId: resolved.terminalId,
        acquirer: resolved.acquirer,
        rawPayload: resolved.rawPayload,
      );

      ref.read(ledgerRevisionProvider.notifier).state++;
      if (!mounted) return;

      final home = ref.read(homeMarketProvider).valueOrNull;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: SwipColors.surfaceRaised,
        builder: (_) => CaptureSheet(
          event: event,
          mcc: repo.lookup(event.mcc),
          sourceLabel: resolved.sourceLabel,
          rawPayload: raw,
          verdict: home?.verdictFor(resolved.countryCode),
          payeeKind: resolved.payeeKind,
          details: {
            if (resolved.acquirer != null)
              'Payment company': resolved.acquirer!,
            if (resolved.merchantHandle != null)
              'Pays to': resolved.merchantHandle!,
            if (resolved.merchantCity != null) 'City': resolved.merchantCity!,
            if (resolved.countryCode != null)
              'Country': resolved.countryCode!,
            if (resolved.amount != null)
              'Amount': '${resolved.currency ?? ''} ${resolved.amount}'.trim(),
            if (resolved.terminalId != null)
              'Terminal': resolved.terminalId!,
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recent = ref.watch(recentCapturesProvider);
    final repo = ref.watch(captureRepositoryProvider);
    final count = ref.watch(captureCountProvider).valueOrNull ?? 0;
    final home = ref.watch(homeMarketProvider).valueOrNull;

    final pages = [
      recent.when(
        loading: () => const _Booting(),
        error: (e, _) => _Fatal(error: '$e'),
        data: (events) => DashboardPage(
          recent: events,
          mccFor: (code) => repo.valueOrNull?.lookup(code),
          timeFormat: _timeFormat,
          homeMarket: home,
          active: _index == 0 && _resumed && !_capturing,
          // Vector 2 is Android-only: Apple permits host card emulation for
          // contactless transactions in the EEA only, and India is not
          // included. The tile is dimmed and explained, never hidden.
          tapAvailable: Platform.isAndroid,
          onToggleTimeFormat: _toggleTime,
          onOpenLedger: () => setState(() => _index = 1),
          onOpenSettings: () => setState(() => _index = 2),
          onOpenCapture: _openCapture,
          onScanned: _onInlineScan,
        ),
      ),
      LedgerPage(timeFormat: _timeFormat, onToggleTime: _toggleTime),
      const SettingsPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openScan,
        backgroundColor: SwipColors.gold500,
        foregroundColor: const Color(0xFF14100A),
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: Text('Capture', style: SwipType.label),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: count > 0,
              label: Text('$count'),
              backgroundColor: SwipColors.gold700,
              child: const Icon(Icons.receipt_long_outlined),
            ),
            selectedIcon: const Icon(Icons.receipt_long_rounded),
            label: 'Ledger',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _Booting extends StatelessWidget {
  const _Booting();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
              color: SwipColors.gold500, strokeWidth: 2),
        ),
      );
}

class _Fatal extends StatelessWidget {
  const _Fatal({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(SwipSpace.xxxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 36, color: SwipColors.dangerOnInk),
                const SizedBox(height: SwipSpace.lg),
                Text('SWIP could not open its local store',
                    textAlign: TextAlign.center,
                    style: SwipType.titleS
                        .copyWith(color: SwipColors.textPrimary)),
                const SizedBox(height: SwipSpace.sm),
                Text(error,
                    textAlign: TextAlign.center,
                    style: SwipType.bodyS
                        .copyWith(color: SwipColors.textSecondary)),
              ],
            ),
          ),
        ),
      );
}
