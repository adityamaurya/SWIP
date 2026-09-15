import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/settings/home_market.dart';
import 'core/theme/swip_theme.dart';
import 'core/theme/swip_tokens.dart';
import 'data/repositories/capture_repository.dart';
import 'data/models/capture_event.dart';
import 'data/sources/capture_resolver.dart';
import 'data/sources/merchant_reconciler.dart';
import 'features/capture_intent/intent_capture.dart';
import 'features/capture_nfc/tap_page.dart';
import 'features/capture_qr/scan_page.dart';
import 'features/bubble/hover_scan.dart';
import 'features/capture_share/share_capture.dart';
import 'features/dashboard/dashboard_page.dart';
import 'core/theme/swip_palette.dart';
import 'core/theme/theme_setting.dart';
import 'features/ledger/ledger_page.dart';
import 'features/onboarding/home_market_page.dart';
import 'features/settings/settings_page.dart';
import 'widgets/capture_detail.dart';
import 'widgets/capture_result_sheet.dart';
import 'widgets/scan_stack.dart';

/// `F-163`. **Two Activities, one entrypoint.**
///
/// `SwipHoverActivity` — the floating scanner the bubble opens — runs this
/// same `main()` in its own Flutter engine, and the *only* thing that
/// distinguishes it is the initial route Android launched it with.
/// `defaultRouteName` carries that across, so the branch below is what decides
/// whether this engine becomes the whole app or a single hovering card.
///
/// Read from `PlatformDispatcher` rather than from a `MaterialApp`'s routing,
/// because the decision has to be made *before* there is a `MaterialApp` — the
/// two roots are different widgets, not two routes inside one.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final launchedAs =
      WidgetsBinding.instance.platformDispatcher.defaultRouteName;

  runApp(ProviderScope(
    child: launchedAs == HoverScanApp.route
        ? const HoverScanApp()
        : const SwipApp(),
  ));
}

/// `F-155` — the one place [SwipPalette.active] is written.
///
/// ## Why the whole app is keyed on the choice
///
/// [SwipColors] reads a global, not an `InheritedWidget`, so nothing rebuilds
/// on its own when the palette changes — see `swip_palette.dart` for why that
/// trade was taken over 440 context lookups. The `key` on `MaterialApp` is
/// what closes that gap: changing it discards the entire element tree and
/// rebuilds from scratch, so every one of those 440 static reads is
/// re-evaluated exactly once, at the moment the user taps.
///
/// It is a heavy hammer, and it is the right one for a preference that changes
/// perhaps twice in the life of an install.
///
/// The palette is assigned **in `build`, before `MaterialApp` is
/// constructed**, so the first frame after a switch is already on the new
/// ground. Assigning it in a callback instead would paint one frame of the old
/// palette — a visible flash on the most visual setting in the app.
class SwipApp extends ConsumerWidget {
  const SwipApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choice = ref.watch(themeSettingProvider);

    // `platformBrightness` off the view rather than `MediaQuery`, because this
    // runs above the `MaterialApp` that would provide one.
    final platformIsDark =
        View.of(context).platformDispatcher.platformBrightness ==
            Brightness.dark;

    SwipPalette.active = choice.palette(platformIsDark: platformIsDark);

    return MaterialApp(
      key: ValueKey('${choice.name}/${SwipPalette.active.name}'),
      title: 'SWIP',
      debugShowCheckedModeBanner: false,
      theme: SwipTheme.dark(),
      darkTheme: SwipTheme.dark(),
      // Both slots hold the same `ThemeData` because the palette — not
      // Material's own light/dark switch — is what actually changed. The
      // mode is still passed so that Material's own defaults, and anything
      // asking `Theme.of(context).brightness`, agree with the ground.
      themeMode: choice.themeMode,
      // Two ways a capture can arrive from outside SWIP: a merchant's
      // pay-by-app intent (Vector 7) and the share sheet (S-24). Both can
      // cold-start the app, so both wrap the shell rather than a screen.
      home: const IntentCaptureListener(
        child: ShareCaptureListener(child: SwipShell()),
      ),
    );
  }
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

  /// `F-95`. How many captures the ledger has not been opened since.
  ///
  /// The badge used to show the *total* row count, which never went down — so
  /// it read as "97 unread" for ever and stopped meaning anything within a
  /// day. It now counts only what has arrived since the ledger was last looked
  /// at, and opening the ledger clears it.
  /// Null until the first count arrives — see the seeding note in `build`.
  int? _seenCount;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _maybeOnboard();
      await _maybeOpenFromTile();
    });
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
    // `F-115`. A second tile press while SWIP is already running arrives as a
    // resume, not a cold start, so the flag has to be re-read here too.
    if (resumed) unawaited(_maybeOpenFromTile());
  }

  /// `F-115`, widened by `F-175`. Opened at a capture surface rather than the
  /// dashboard, because something outside the app said which one.
  ///
  /// Two things ask for this. The Quick Settings tile means *the scanner* —
  /// someone who swiped down and pressed a tile called "Scan a shop code" is
  /// standing in front of a code, and landing them on the dashboard would make
  /// them take a second action to reach the thing the tile named. And the
  /// hovering card's *Tap POS* means *the POS reader*, because NFC cannot be
  /// read inside that window at all.
  ///
  /// The platform answers with a string rather than a boolean now. An
  /// unrecognised value is treated as nothing pending, so a typo on either
  /// side opens the dashboard rather than a screen nobody asked for.
  bool _openingFromTile = false;

  Future<void> _maybeOpenFromTile() async {
    if (_openingFromTile) return;
    try {
      final open = await const MethodChannel('in.swip.app/nfc')
          .invokeMethod<String>('consumeTileLaunch');
      // `F-180`. Not a capture vector — *View all*, pressed in the hovering
      // card, which cannot render the ledger itself. Handled before the switch
      // because it is the one answer that opens a tab rather than a scanner.
      if (open == 'ledger') {
        if (mounted) _openLedger();
        return;
      }
      final vector = switch (open) {
        'qr' => CaptureVector.qr,
        'nfc' => CaptureVector.nfc,
        _ => null,
      };
      if (vector == null || !mounted) return;
      _openingFromTile = true;
      await _openCapture(vector);
    } on PlatformException {
      // No tile on this platform build.
    } on MissingPluginException {
      // iOS.
    } finally {
      _openingFromTile = false;
    }
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

  /// F-08, F-09. The dashboard has always sent which tile was tapped; the
  /// shell used to throw it away and open the scanner regardless, which is
  /// why Tap and Link appeared to do nothing.
  Future<void> _openCapture(CaptureVector vector) async {
    final page = switch (vector) {
      CaptureVector.nfc => const TapPage(),
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
    // `F-180`. The push already returns a Future the shell awaits, so *View
    // all* travels back up it as a result rather than through a notifier or a
    // provider. The capture page pops itself with [CaptureExit.ledger] and the
    // camera is released on the way out, which is the whole reason this is a
    // pop and not a push of the ledger on top of a live scanner.
    final exit = await Navigator.of(context)
        .push<CaptureExit>(MaterialPageRoute<CaptureExit>(builder: (_) => page));

    // Before the camera handover below, not after: those delays exist to let
    // the platform settle and add up to half a second, and a tab switch that
    // lands half a second after the button was pressed reads as a stutter.
    if (mounted && exit == CaptureExit.ledger) _openLedger();

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

  /// `F-95`. Opening the ledger is what marks it read, so the badge clears.
  void _openLedger() {
    final seen = ref.read(captureCountProvider).valueOrNull ?? _seenCount ?? 0;
    setState(() {
      _index = 1;
      _seenCount = seen;
    });
  }

  @override
  Widget build(BuildContext context) {
    final recent = ref.watch(recentCapturesProvider);
    final repo = ref.watch(captureRepositoryProvider);
    final countAsync = ref.watch(captureCountProvider);
    final count = countAsync.valueOrNull ?? 0;

    // Seeded once, from whatever is already in the ledger when the app opens.
    // Without this every cold start would announce the entire history as new,
    // which is the same "97 for ever" badge in a different disguise.
    if (_seenCount == null && countAsync.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _seenCount == null) {
          setState(() => _seenCount = count);
        }
      });
    }
    final unread = _seenCount == null ? 0 : (count - _seenCount!).clamp(0, 999);
    final home = ref.watch(homeMarketProvider).valueOrNull;
    final links = [
      for (final p
          in ref.watch(merchantLinkProposalsProvider).valueOrNull ?? const [])
        if (!_dismissedLinks.contains(p.aliasKey)) p,
    ];

    final pages = [
      recent.when(
        // `F-116`. **The dashboard must not unmount when the ledger reloads.**
        //
        // Every capture bumps `ledgerRevisionProvider`, which re-runs this
        // provider. Riverpod treats a watched-dependency change as a *reload*,
        // and `when` shows `loading` on a reload by default - so the entire
        // DashboardPage was being replaced by a spinner after every single
        // scan. That tears down `LiveViewfinder`, which disposes the camera
        // controller, which disposes the process-wide scanner platform.
        //
        // That one default explains three separate reports at once: the ledger
        // "not updating until you switch tabs" (the list was rebuilding from
        // scratch), the camera dying mid-session, and needing a force-quit to
        // scan again. Keeping the previous data on screen during a reload keeps
        // the camera alive and the list continuous.
        skipLoadingOnReload: true,
        loading: () => const _Booting(),
        error: (e, _) => _Fatal(error: '$e'),
        data: (events) => DashboardPage(
          recent: events,
          mccFor: (code) => repo.valueOrNull?.lookup(code),
          homeMarket: home,
          // `F-117`. `_capturing` is deliberately NOT in this gate any more.
          //
          // It flips true for the length of one database write, and having it
          // here meant every ambient scan stopped and restarted the camera.
          // Against a platform singleton that holds one texture, a stop/start
          // per detection is exactly the churn that wedges it - and an ambient
          // scanner that stops the moment it finds something is a contradiction
          // in terms. Re-entrancy is already prevented by the `_capturing`
          // guard inside `_onInlineScan` and the refractory period in
          // `LiveViewfinder._onDetect`.
          active: _index == 0 && _resumed && !_cameraHandedOver,
          // Vector 2 is Android-only: Apple permits host card emulation for
          // contactless transactions in the EEA only, and India is not
          // included. The tile is dimmed and explained, never hidden.
          tapAvailable: Platform.isAndroid,
          onOpenLedger: _openLedger,
          // `F-169`. **This was declared, called, and never supplied.**
          //
          // `DashboardPage` takes an `onOpenEvent`, and both the hero capture
          // and every recent row call it on tap. Nothing passed one, so the
          // callback was null and tapping an MCC on the dashboard did
          // precisely nothing — while the identical row in the Ledger tab
          // opened the detail sheet, because `ledger_page.dart` wires it.
          //
          // Same shape as the dead floating bubble and the unimported
          // merchant directory: every piece present and correct, and no wire
          // between them. `tool/check_wiring.py` cannot see this one — it
          // checks files, channels and preferences, not widget callbacks that
          // are declared and never passed.
          onOpenEvent: (event) => showCaptureDetail(context, ref, event),
          onOpenSettings: () => setState(() => _index = 2),
          onOpenCapture: _openCapture,
          onScanned: _onInlineScan,
          // `F-49`. At most one at a time: a dashboard that asks the same
          // question three times gets all three dismissed.
          linkProposal: links.isEmpty ? null : links.first,
          onConfirmLink: _confirmLink,
          onDismissLink: (p) => setState(() => _dismissedLinks.add(p.aliasKey)),
        ),
      ),
      const LedgerPage(),
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
        onDestinationSelected: (i) {
          if (i == 1) {
            _openLedger();
          } else {
            setState(() => _index = i);
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Badge(
              // `F-95`. Only what has landed since the ledger was last opened.
              // A badge showing the lifetime total never goes down, and a count
              // that never goes down is not a notification — it is furniture.
              isLabelVisible: unread > 0,
              label: Text('$unread'),
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
  Widget build(BuildContext context) => Scaffold(
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
                Icon(Icons.error_outline_rounded,
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
