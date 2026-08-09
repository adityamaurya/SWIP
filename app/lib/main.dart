import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/swip_theme.dart';
import 'core/theme/swip_tokens.dart';
import 'core/utils/swip_time.dart';
import 'data/repositories/capture_repository.dart';
import 'features/capture_intent/intent_capture.dart';
import 'features/capture_qr/scan_page.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/ledger/ledger_page.dart';
import 'features/settings/settings_page.dart';

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

class _SwipShellState extends ConsumerState<SwipShell> {
  int _index = 0;

  /// `D-07`. Global and shared by every time cell in the app, so tapping one
  /// switches them all. Persisted in [SettingsPage].
  TimeFormatPref _timeFormat = TimeFormatPref.absolute;

  void _toggleTime() => setState(() {
        _timeFormat = _timeFormat == TimeFormatPref.absolute
            ? TimeFormatPref.relative
            : TimeFormatPref.absolute;
      });

  Future<void> _openScan() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ScanPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recent = ref.watch(recentCapturesProvider);
    final repo = ref.watch(captureRepositoryProvider);
    final count = ref.watch(captureCountProvider).valueOrNull ?? 0;

    final pages = [
      recent.when(
        loading: () => const _Booting(),
        error: (e, _) => _Fatal(error: '$e'),
        data: (events) => DashboardPage(
          recent: events,
          mccFor: (code) => repo.valueOrNull?.lookup(code),
          timeFormat: _timeFormat,
          // Vector 2 is Android-only: Apple permits host card emulation for
          // contactless transactions in the EEA only, and India is not
          // included. The tile is dimmed and explained, never hidden.
          tapAvailable: Platform.isAndroid,
          onToggleTimeFormat: _toggleTime,
          onOpenLedger: () => setState(() => _index = 1),
          onOpenSettings: () => setState(() => _index = 2),
          onOpenCapture: (_) => _openScan(),
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
