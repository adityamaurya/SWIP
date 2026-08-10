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
import 'data/sources/merchant_reconciler.dart';
import 'features/capture_intent/intent_capture.dart';
import 'features/capture_link/link_page.dart';
import 'features/capture_nfc/tap_page.dart';
import 'features/capture_qr/scan_page.dart';
import 'features/capture_share/share_capture.dart';
import 'features/dashboard/dashboard_page.dart';
import 'features/ledger/ledger_page.dart';
import 'features/onboarding/home_market_page.dart';
import 'features/settings/settings_page.dart';
import 'widgets/capture_detail.dart';
import 'widgets/scan_stack.dart';

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
        // Two ways a capture can arrive from outside SWIP: a merchant's
        // pay-by-app intent (Vector 7) and the share sheet (S-24). Both can
        // cold-start the app, so both wrap the shell rather than a screen.
        home: const IntentCaptureListener(
          child: ShareCaptureListener(child: SwipShell()),
        ),
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

  /// **The camera is a single, exclusive piece of hardware.**
  ///
  /// Pushing the full-screen scanner does not unmount the dashboard — the route
  /// sits on top and the dashboard's `IndexedStack` page stays alive. So the
  /// inline viewfinder kept its camera session open, the scanner's controller
  /// could not acquire the device, and the full-screen scanner showed a black
  /// rectangle for ever.
  ///
  /// This flag is the hand-off: the dashboard releases the camera before the
  /// scanner is pushed and takes it back when the scanner pops.
  bool _cameraHandedOver = false;

  /// `F-61`, `F-62`. Recent ambient scans, newest first, shown as a stack
  /// docked at the bottom of the screen instead of a modal.
  ///
  /// Pruned to the last minute on every render. The ledger keeps everything for
  /// ever; this is a toast, and a toast that never expires is a wall.
  final List<CaptureEvent> _flashes = [];

  static const _flashWindow = Duration(minutes: 1);

  /// `F-49`. Proposals the user has said no to. Kept in memory only — saying
  /// "different shops" once should not be permanent if the evidence changes,
  /// but it must not re-ask on the same screen.
  final Set<String> _dismissedLinks = {};

  List<CaptureEvent> get _liveFlashes {
    final cutoff = DateTime.now().toUtc().subtract(_flashWindow);
    return [
      for (final e in _flashes)
        if (e.capturedAt.isAfter(cutoff)) e,
    ];
  }

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

  /// F-08, F-09. The dashboard has always sent which tile was tapped; the
  /// shell used to throw it away and open the scanner regardless, which is
  /// why Tap and Link appeared to do nothing.
  Future<void> _openCapture(CaptureVector vector) async {
    final page = switch (vector) {
      CaptureVector.nfc => const TapPage(),
      CaptureVector.link => const LinkPage(),
      _ => const ScanPage(),
    };

    // Release the camera *before* pushing, and give the platform a frame to
    // actually let go. Handing over on the same frame as the push loses the
    // race about half the time on a real device.
    final needsCamera = vector == CaptureVector.qr;
    if (needsCamera) {
      setState(() => _cameraHandedOver = true);
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }

    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    // And take it back only once the scanner has let go. `ScanPage.dispose()`
    // releases the camera asynchronously and the Navigator does not wait for
    // it, so clearing this on the same frame as the pop had the dashboard ask
    // for a camera that was still claimed. The viewfinder retries anyway now,
    // but starting from a settled state means no visible stumble either.
    if (needsCamera) {
      await Future<void>.delayed(const Duration(milliseconds: 320));
    }
    if (mounted && needsCamera) setState(() => _cameraHandedOver = false);
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

      // `F-60`, `F-61`. No modal here. An ambient scan the user did not ask
      // for gets a quiet card under the camera; the full sheet is one tap
      // away on its chevron. The full-screen scanner still opens the sheet,
      // because there the scan was deliberate.
      setState(() {
        _flashes.insert(0, event);
        // Ten is more than anyone swipes through; beyond that the stack is
        // just memory being held for nothing.
        if (_flashes.length > 10) _flashes.removeRange(10, _flashes.length);
      });
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  /// `F-49`. Link two identities of one shop, and hand the category across.
  Future<void> _confirmLink(MerchantLinkProposal p) async {
    final repo = await ref.read(captureRepositoryProvider.future);
    final filled = await repo.confirmLink(p);
    ref.read(ledgerRevisionProvider.notifier).state++;
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(filled == 0
          ? 'Linked. That QR will answer ${p.mcc} from now on.'
          : 'Linked, and filled in $filled past '
              '${filled == 1 ? "capture" : "captures"}.'),
    ));
  }

  /// A tap on a condensed card, or on a row of the dashboard's recent list.
  ///
  /// Both go through [showCaptureDetail], which the Ledger now uses too — so
  /// the three places you can tap a capture cannot describe it differently.
  Future<void> _expandFlash(CaptureEvent event) =>
      showCaptureDetail(context, ref, event);

  @override
  Widget build(BuildContext context) {
    final recent = ref.watch(recentCapturesProvider);
    final repo = ref.watch(captureRepositoryProvider);
    final count = ref.watch(captureCountProvider).valueOrNull ?? 0;
    final home = ref.watch(homeMarketProvider).valueOrNull;
    final links = [
      for (final p
          in ref.watch(merchantLinkProposalsProvider).valueOrNull ?? const [])
        if (!_dismissedLinks.contains(p.aliasKey)) p,
    ];

    final pages = [
      recent.when(
        loading: () => const _Booting(),
        error: (e, _) => _Fatal(error: '$e'),
        data: (events) => DashboardPage(
          recent: events,
          mccFor: (code) => repo.valueOrNull?.lookup(code),
          timeFormat: _timeFormat,
          homeMarket: home,
          active: _index == 0 &&
              _resumed &&
              !_capturing &&
              !_cameraHandedOver,
          // Vector 2 is Android-only: Apple permits host card emulation for
          // contactless transactions in the EEA only, and India is not
          // included. The tile is dimmed and explained, never hidden.
          tapAvailable: Platform.isAndroid,
          onToggleTimeFormat: _toggleTime,
          onOpenLedger: () => setState(() => _index = 1),
          onOpenSettings: () => setState(() => _index = 2),
          onOpenCapture: _openCapture,
          onScanned: _onInlineScan,
          // `F-49`. At most one at a time: a dashboard that asks the same
          // question three times gets all three dismissed.
          linkProposal: links.isEmpty ? null : links.first,
          onConfirmLink: _confirmLink,
          onDismissLink: (p) =>
              setState(() => _dismissedLinks.add(p.aliasKey)),
        ),
      ),
      LedgerPage(timeFormat: _timeFormat, onToggleTime: _toggleTime),
      const SettingsPage(),
    ];

    final flashes = _liveFlashes;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _index, children: pages),

          // `F-62`. Docked at the bottom, over everything, like a condensed
          // music player: always the same place, nothing behind it moves when
          // it appears, one tap from the full thing.
          if (_index == 0 && flashes.isNotEmpty)
            Positioned(
              left: SwipSpace.gutter,
              right: SwipSpace.gutter,
              bottom: SwipSpace.sm,
              child: ScanStack(
                events: flashes,
                mccFor: (code) => repo.valueOrNull?.lookup(code),
                onExpand: _expandFlash,
                onDismiss: (e) =>
                    setState(() => _flashes.removeWhere((x) => x.id == e.id)),
                onOpenLedger: () => setState(() {
                  _flashes.clear();
                  _index = 1;
                }),
              ),
            ),
        ],
      ),
      // `F-82`. The Capture button is gone.
      //
      // It sat in the bottom-right corner, which is exactly where the condensed
      // scan cards dock — so the moment SWIP found something, the gold pill was
      // parked on top of the answer. A floating action button that covers the
      // result of the action is worse than no button.
      //
      // Nothing is lost with it: the dashboard's top band is a live camera that
      // is already scanning, double-tapping it opens the full scanner, and the
      // Scan QR tile does the same thing with a label on it. The button was a
      // fourth route to a screen that already had three.
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
