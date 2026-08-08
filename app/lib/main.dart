import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/swip_theme.dart';
import 'core/utils/swip_time.dart';
import 'data/models/capture_event.dart';
import 'data/models/mcc.dart';
import 'data/repositories/mcc_repository.dart';
import 'features/dashboard/dashboard_page.dart';

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
        theme: SwipTheme.light(),
        // Light only in v1, per ideation A-06.
        themeMode: ThemeMode.light,
        home: const _Home(),
      );
}

/// Temporary shell so `flutter run` shows a populated S-01 on the first build.
///
/// Replace with the go_router shell + Riverpod-backed repositories as the other
/// screens land — see docs/08-ARCHITECTURE.md and docs/10-ROADMAP.md. The seed
/// captures below are illustrative only; they are stripped in release builds so
/// a store binary can never ship fake ledger rows.
class _Home extends ConsumerStatefulWidget {
  const _Home();

  @override
  ConsumerState<_Home> createState() => _HomeState();
}

class _HomeState extends ConsumerState<_Home> {
  TimeFormatPref _timeFormat = TimeFormatPref.absolute;
  MccTable? _table;

  @override
  void initState() {
    super.initState();
    MccTable.load().then((t) {
      if (mounted) setState(() => _table = t);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_table == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return DashboardPage(
      recent: _seed,
      mccFor: (code) => code == null ? null : _table!.lookup(code),
      timeFormat: _timeFormat,
      // Vector 2 is Android-only: Apple permits HCE for contactless
      // transactions in the EEA only, and India is not included.
      // See docs/03-RESEARCH §3.5.
      tapAvailable: Platform.isAndroid,
      onToggleTimeFormat: () => setState(() {
        _timeFormat = _timeFormat == TimeFormatPref.absolute
            ? TimeFormatPref.relative
            : TimeFormatPref.absolute;
      }),
    );
  }
}

/// Debug-only seed data. Never rendered in a release build.
List<CaptureEvent> get _seed {
  const releaseMode = bool.fromEnvironment('dart.vm.product');
  if (releaseMode) return const [];

  final now = DateTime.now().toUtc();
  CaptureEvent e(
    String id,
    String mcc,
    CaptureVector v,
    MccConfidence c,
    Duration ago,
    String merchant,
    String? city,
  ) =>
      CaptureEvent(
        id: id,
        mcc: mcc,
        vector: v,
        confidence: c,
        capturedAt: now.subtract(ago),
        merchantName: merchant,
        merchantCity: city,
        countryCode: 'IN',
        currency: 'INR',
      );

  return [
    e('1', '5812', CaptureVector.nfc, MccConfidence.verified,
        const Duration(hours: 2), 'Blue Tokai Coffee', 'Powai'),
    e('2', '5541', CaptureVector.qr, MccConfidence.verified,
        const Duration(hours: 9), 'HP Petrol Pump', 'Andheri'),
    e('3', '6513', CaptureVector.link, MccConfidence.likely,
        const Duration(days: 1, hours: 3), 'rzp.io/l/rentpay', null),
    e('4', '4722', CaptureVector.qr, MccConfidence.verified,
        const Duration(days: 1, hours: 8), 'MakeMyTrip', null),
    e('5', '5411', CaptureVector.graph, MccConfidence.likely,
        const Duration(days: 2), 'DMart', 'Powai'),
  ];
}
