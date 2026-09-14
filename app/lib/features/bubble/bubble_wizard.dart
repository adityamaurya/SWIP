import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/swip_tokens.dart';

/// `F-159` — **the one-time wizard that turns the floating button on.**
///
/// > *"have a shortcut fully proper wizard flow once to enable the shortcut
/// > for this app floater"*
///
/// ## Why a wizard and not a switch
///
/// Because the switch was tried, twice, and both times the report came back as
/// "the floater is not working".
///
/// The first time it genuinely did nothing — `F-131` wrote a preference no
/// code read. The second time it worked and the user still could not see a
/// bubble, because SWIP hides it while SWIP itself is on screen, and nothing
/// on that screen said so. A switch has one line of subtitle to explain a
/// feature with four prerequisites and one deeply counter-intuitive
/// behaviour. It is the wrong instrument.
///
/// ## The structure is Wispr Flow's, deliberately
///
/// The owner supplied twenty-three screenshots of Wispr Flow's onboarding and
/// asked for exactly that flow. It is worth copying because it solves the
/// hardest problem in this space — **getting a person through an Android
/// Settings screen they have never seen, without losing them** — and it solves
/// it in a way most apps do not:
///
///   * a progress bar, so a five-step permission flow has a visible end;
///   * one serif headline per screen, one idea per screen;
///   * numbered steps that **show a picture of the actual control** the user
///     is about to hunt for, so they are matching shapes rather than reading
///     instructions (their page 12);
///   * a single button at the bottom, always;
///   * and a final screen that sets expectations — *"You won't see the Flow
///     Bubble right away"* (their page 23). That screen is the reason their
///     users do not report the bubble as broken, and its absence is why ours
///     was.
///
/// ## Where SWIP's flow differs, and why
///
/// Wispr Flow's central step is an **Accessibility Service**, and page 12 of
/// the owner's PDF tells the user in so many words: *"Don't turn the shortcut
/// on!"* — because the "Wispr Flow shortcut" toggle on that Settings page is
/// Android's accessibility shortcut, the hold-both-volume-keys chord, and
/// having it fire their dictation service is not what anyone wants.
///
/// **SWIP has no accessibility service, so it has no such toggle and no such
/// warning to give.** It does not need one: Wispr Flow reads the focused text
/// field in other apps and types into it, which is impossible without one.
/// SWIP draws a circle and opens its own camera. Every capability it needs is
/// covered by `SYSTEM_ALERT_WINDOW` and a foreground service.
///
/// That difference is the single strongest privacy claim SWIP has, it is
/// stated on `BubbleSettingsPage`, and it would be thrown away by copying this
/// flow too literally.
class BubbleWizard extends StatefulWidget {
  const BubbleWizard({super.key});

  /// Shown once. After that the Settings row opens [BubbleSettingsPage].
  static const seenKey = 'swip.bubble.wizardSeen';

  @override
  State<BubbleWizard> createState() => _BubbleWizardState();
}

class _BubbleWizardState extends State<BubbleWizard>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('in.swip.app/nfc');
  static const _patience = Duration(seconds: 3);

  final _pages = PageController();
  int _step = 0;

  bool _overlayGranted = false;
  bool _notificationsGranted = false;
  bool _running = false;

  /// Total screens. Named rather than counted from a list so the progress bar
  /// and the page view cannot disagree.
  static const _steps = 5;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pages.dispose();
    super.dispose();
  }

  /// Both permissions are granted in another app, so returning to the
  /// foreground is the only moment SWIP can learn the answer.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  /// Never throws, and always finishes.
  ///
  /// A `MethodChannel` future completes when the platform replies and never
  /// completes if it does not — there is no built-in timeout — so a wizard
  /// that awaited one without a deadline could sit on a dead screen forever.
  Future<T?> _ask<T>(Future<T?> Function() call) async {
    try {
      return await call().timeout(_patience);
    } on Object {
      return null;
    }
  }

  Future<void> _refresh() async {
    final overlay =
        await _ask(() => _channel.invokeMethod<bool>('canDrawOverlays')) ??
            false;
    final notes = await _ask(
            () => _channel.invokeMethod<bool>('notificationsAllowed')) ??
        false;
    final status = await _ask(
        () => _channel.invokeMapMethod<String, dynamic>('bubbleStatus'));

    if (!mounted) return;
    setState(() {
      _overlayGranted = overlay;
      _notificationsGranted = notes;
      _running = status?['running'] == true;
    });

    // The moment the overlay permission lands, start the bubble. The user
    // came into a wizard called "turn the button on"; making them find a
    // separate switch afterwards is how the last two rounds went wrong.
    if (overlay && status?['wanted'] != true) {
      await _ask(() => _channel.invokeMethod<bool>('startBubble'));
      final after = await _ask(
          () => _channel.invokeMapMethod<String, dynamic>('bubbleStatus'));
      if (!mounted) return;
      setState(() => _running = after?['running'] == true);
    }
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

  Future<void> _openOverlaySettings() async {
    await _ask(() => _channel.invokeMethod<bool>('requestOverlayPermission'));
  }

  Future<void> _requestNotifications() async {
    final ok =
        await _ask(() => _channel.invokeMethod<bool>('requestNotifications')) ??
            false;
    if (!mounted) return;
    setState(() => _notificationsGranted = ok);
    _go(_step + 1);
  }

  Future<void> _openAppSettings() async {
    await _ask(() => _channel.invokeMethod<bool>('openThisAppSettings'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SwipColors.bg,
      appBar: AppBar(
        backgroundColor: SwipColors.bg,
        elevation: 0,
        leading: _step == 0
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => _go(_step - 1),
              ),
        title: _Progress(step: _step, total: _steps),
        titleSpacing: 0,
      ),
      body: PageView(
        controller: _pages,
        // Driven by the buttons, not by swiping: a permission flow where you
        // can skip past the step that does the work is a permission flow that
        // ends with nothing granted.
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _WhatItIs(onNext: () => _go(1)),
          _OverlayStep(
            granted: _overlayGranted,
            onOpen: _openOverlaySettings,
            onNext: () => _go(2),
          ),
          _NotificationStep(
            granted: _notificationsGranted,
            onAllow: _requestNotifications,
            onSkip: () => _go(3),
          ),
          _KeepItRunningStep(
            onOpen: _openAppSettings,
            onNext: () => _go(4),
          ),
          _AllSetStep(
            running: _running,
            overlayGranted: _overlayGranted,
            onFinish: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }
}

/// The segmented bar from the top of every Wispr Flow screen.
///
/// It is doing real work rather than decoration: a permission flow that sends
/// you into Android Settings twice feels unbounded, and people abandon
/// unbounded flows. Five filled segments are a promise that this ends.
class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) => Row(
        children: List.generate(total, (i) {
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: i <= step ? SwipColors.gold500 : SwipColors.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      );
}

/// One screen: headline, scrollable body, and a button stuck to the bottom.
///
/// The button does not scroll. On a 5-inch phone with the text scale turned
/// up, a "Continue" that has scrolled off the end of a permission explanation
/// is a flow that dead-ends, and the user has no way to know there was ever a
/// button there.
class _Screen extends StatelessWidget {
  const _Screen({
    required this.title,
    required this.body,
    required this.action,
    this.secondary,
  });

  final String title;

  /// Named `body` rather than `children` deliberately. `children` is a widget
  /// slot name, and the analyzer's `sort_child_properties_last` insists it be
  /// the final argument — which would put the page's content *after* the
  /// button that ends the page, in every one of these five constructors.
  /// Renaming is the honest fix; suppressing the lint would not be.
  final List<Widget> body;
  final Widget action;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  SwipSpace.gutter, SwipSpace.xxl, SwipSpace.gutter, 0),
              children: [
                Text(title,
                    style: SwipType.display
                        .copyWith(color: SwipColors.textPrimary)),
                const SizedBox(height: SwipSpace.xl),
                ...body,
                const SizedBox(height: SwipSpace.xxxl),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(SwipSpace.gutter, SwipSpace.md,
                SwipSpace.gutter, SwipSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                action,
                if (secondary != null) ...[
                  const SizedBox(height: SwipSpace.sm),
                  secondary!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A numbered step whose payload is a **picture of the control** the user is
/// about to look for.
///
/// This is the single most useful idea on page 12 of the owner's PDF. Written
/// instructions make somebody parse a sentence and then search a screen;
/// a picture of the row makes them match a shape. It is the difference
/// between a flow people finish and one they abandon in Settings.
class _NumberedStep extends StatelessWidget {
  const _NumberedStep({
    required this.n,
    required this.text,
    this.mock,
    this.warn = false,
  });

  final int n;
  final String text;
  final Widget? mock;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SwipSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Text('$n.',
                    style: SwipType.bodyM
                        .copyWith(color: SwipColors.textSecondary)),
              ),
              Expanded(
                child: Text(
                  text,
                  style: SwipType.bodyM.copyWith(
                    color: warn ? SwipColors.danger : SwipColors.textPrimary,
                    fontWeight: warn ? FontWeight.w600 : null,
                  ),
                ),
              ),
            ],
          ),
          if (mock != null)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: SwipSpace.md),
              child: mock,
            ),
        ],
      ),
    );
  }
}

/// A drawing of an Android Settings row, as the user will see it.
class _SettingsRowMock extends StatelessWidget {
  const _SettingsRowMock({
    required this.label,
    this.value,
    this.on,
    this.crossedOut = false,
  });

  final String label;
  final String? value;
  final bool? on;
  final bool crossedOut;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      padding: const EdgeInsets.symmetric(
          horizontal: SwipSpace.lg, vertical: SwipSpace.md),
      decoration: BoxDecoration(
        color: SwipColors.surfaceRaised,
        borderRadius: SwipRadius.inputAll,
        border: Border.all(color: SwipColors.hairline),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: SwipType.bodyM
                        .copyWith(color: SwipColors.textPrimary)),
                if (value != null)
                  Text(value!,
                      style: SwipType.bodyS
                          .copyWith(color: SwipColors.textTertiary)),
              ],
            ),
          ),
          if (on != null)
            // Not a real Switch: this is a drawing of someone else's UI, and a
            // live control here would invite a tap that does nothing.
            Container(
              width: 40,
              height: 22,
              decoration: BoxDecoration(
                color: on! ? SwipColors.success : SwipColors.hairline,
                borderRadius: SwipRadius.pillAll,
              ),
              alignment: on! ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );

    if (!crossedOut) return row;
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        Opacity(opacity: 0.55, child: row),
        Padding(
          padding: const EdgeInsets.only(right: SwipSpace.md),
          child: Icon(Icons.close_rounded,
              size: 34, color: SwipColors.danger),
        ),
      ],
    );
  }
}

/// A small note in a tinted box. Used for the things that are true and
/// unwelcome, which are the ones most worth putting on the screen.
class _Note extends StatelessWidget {
  const _Note({required this.text, this.icon = Icons.info_outline_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(SwipSpace.lg),
        decoration: BoxDecoration(
          color: SwipColors.surfaceRaised,
          borderRadius: SwipRadius.cardAll,
          border: Border.all(color: SwipColors.hairline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child:
                  Icon(icon, size: 17, color: SwipColors.textSecondary),
            ),
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

/// A green tick / grey ring that says whether a step is already done.
class _DoneChip extends StatelessWidget {
  const _DoneChip({required this.done, required this.doneText, required this.todoText});

  final bool done;
  final String doneText;
  final String todoText;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 18,
            color: done ? SwipColors.success : SwipColors.textTertiary,
          ),
          const SizedBox(width: SwipSpace.sm),
          Expanded(
            child: Text(
              done ? doneText : todoText,
              style: SwipType.bodyS.copyWith(
                color: done ? SwipColors.success : SwipColors.textTertiary,
              ),
            ),
          ),
        ],
      );
}

// ── 1 ────────────────────────────────────────────────────────────────────

class _WhatItIs extends StatelessWidget {
  const _WhatItIs({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => _Screen(
        title: 'SWIP, on top of\nevery app',
        body: [
          Text(
            'A small button floats over whatever you are doing. Tap it at a '
            'counter and SWIP opens straight into the scanner — no hunting '
            'for the app while somebody waits for you to pay.',
            style:
                SwipType.bodyL.copyWith(color: SwipColors.textSecondary),
          ),
          const SizedBox(height: SwipSpace.xl),
          const _BubblePreview(),
          const SizedBox(height: SwipSpace.xl),
          Text(
            'Android calls this "display over other apps". It is the most '
            'serious permission Android hands out, so the next screens say '
            'exactly what SWIP does with it — and what it will never do.',
            style:
                SwipType.bodyM.copyWith(color: SwipColors.textSecondary),
          ),
          const SizedBox(height: SwipSpace.xl),
          const _Note(
            icon: Icons.lock_outline_rounded,
            text: 'SWIP does not use an Accessibility Service. It has no way '
                'to see what any other app is showing — not because it '
                'promises not to, but because it never asks for the '
                'mechanism.',
          ),
        ],
        action: FilledButton(onPressed: onNext, child: const Text('Next')),
      );
}

/// A drawing of the bubble at rest, so the first screen shows the thing it is
/// talking about rather than describing it.
class _BubblePreview extends StatelessWidget {
  const _BubblePreview();

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          height: 48,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF060507),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x33C9A227)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFC9A227),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Transform.rotate(
                  angle: 0.32,
                  child: Container(
                    width: 4,
                    height: 17,
                    color: const Color(0xFF060507),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              const Text('Scanning…',
                  style: TextStyle(color: Color(0xFFF2EFE9), fontSize: 12)),
              const SizedBox(width: 3),
            ],
          ),
        ),
      );
}

// ── 2 ────────────────────────────────────────────────────────────────────

class _OverlayStep extends StatelessWidget {
  const _OverlayStep({
    required this.granted,
    required this.onOpen,
    required this.onNext,
  });

  final bool granted;
  final Future<void> Function() onOpen;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => _Screen(
        title: 'Allow SWIP to draw\nover other apps',
        body: [
          const _NumberedStep(
            n: 1,
            text: 'Find SWIP in the list of apps',
            mock: _SettingsRowMock(label: 'SWIP', value: 'Not allowed'),
          ),
          const _NumberedStep(
            n: 2,
            text: 'Turn this on',
            mock: _SettingsRowMock(
                label: 'Allow display over other apps', on: true),
          ),
          const _NumberedStep(
            n: 3,
            text: 'Come back here. SWIP picks it up on its own.',
          ),
          _DoneChip(
            done: granted,
            doneText: 'Allowed. The button is on.',
            todoText: 'Not allowed yet',
          ),
          const SizedBox(height: SwipSpace.xl),
          const _Note(
            icon: Icons.visibility_off_outlined,
            text: 'SWIP hides the button for 90 seconds whenever it hands a '
                'payment to another app, and the whole time your screen is '
                'locked. It will never be over a PIN pad.',
          ),
        ],
        action: granted
            ? FilledButton(onPressed: onNext, child: const Text('Next'))
            : FilledButton(
                onPressed: onOpen, child: const Text('Open settings')),
        secondary: granted
            ? null
            : TextButton(onPressed: onNext, child: const Text('Not now')),
      );
}

// ── 3 ────────────────────────────────────────────────────────────────────

class _NotificationStep extends StatelessWidget {
  const _NotificationStep({
    required this.granted,
    required this.onAllow,
    required this.onSkip,
  });

  final bool granted;
  final Future<void> Function() onAllow;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) => _Screen(
        title: 'The notice in\nyour shade',
        body: [
          Text(
            'While the button is floating, Android requires SWIP to show an '
            'ongoing notice. That is not SWIP\'s choice and it is not '
            'negotiable — no app is allowed to draw over other apps quietly, '
            'and it would be a bad thing if one could.',
            style:
                SwipType.bodyL.copyWith(color: SwipColors.textSecondary),
          ),
          const SizedBox(height: SwipSpace.xl),
          const _SettingsRowMock(
            label: 'SWIP is one tap away',
            value: 'Tap the floating button to read a shop\'s code.',
          ),
          const SizedBox(height: SwipSpace.xl),
          Text(
            'It never makes a sound and sits at the bottom of the shade. It '
            'also carries a Turn off button, which is the fastest way to '
            'dismiss the floating button for good.',
            style:
                SwipType.bodyM.copyWith(color: SwipColors.textSecondary),
          ),
          const SizedBox(height: SwipSpace.xl),
          _DoneChip(
            done: granted,
            doneText: 'Notifications allowed',
            todoText: 'Not allowed yet',
          ),
          const SizedBox(height: SwipSpace.lg),
          const _Note(
            text: 'If you say no, the button still works. You just lose the '
                'notice and the Turn off button with it.',
          ),
        ],
        action: granted
            ? FilledButton(onPressed: onSkip, child: const Text('Next'))
            : FilledButton(
                onPressed: onAllow,
                child: const Text('Allow notifications')),
        secondary:
            granted ? null : TextButton(onPressed: onSkip, child: const Text('Skip')),
      );
}

// ── 4 ────────────────────────────────────────────────────────────────────

class _KeepItRunningStep extends StatelessWidget {
  const _KeepItRunningStep({required this.onOpen, required this.onNext});

  final Future<void> Function() onOpen;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => _Screen(
        title: 'Keeping it there,\nall day',
        body: [
          Text(
            'SWIP brings the button back by itself after a restart and after '
            'an app update. Three things can still take it away, and it is '
            'better to know them now than to find one at a counter.',
            style:
                SwipType.bodyL.copyWith(color: SwipColors.textSecondary),
          ),
          const SizedBox(height: SwipSpace.xl),
          const _NumberedStep(
            n: 1,
            text: 'Battery saving. Some phones — Xiaomi, Oppo, Vivo, '
                'realme, Samsung — stop background apps hard. Find SWIP '
                'below and set battery to Unrestricted, and turn Autostart '
                'on if your phone has it.',
            mock: _SettingsRowMock(
                label: 'Battery', value: 'Unrestricted'),
          ),
          // The one place SWIP has the same thing page 12 of the owner's PDF
          // warns about — a control on an Android settings screen that
          // silently kills the feature. Wispr Flow's is the accessibility
          // shortcut; SWIP's is Force stop. Same red X, same reason: a person
          // scanning this page will see the crossed-out row before they read
          // a word of it.
          const _NumberedStep(
            n: 2,
            warn: true,
            text: 'Do not use Force stop.',
            mock: _SettingsRowMock(label: 'Force stop', crossedOut: true),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 22, bottom: SwipSpace.xl),
            child: Text(
              'Force-stopping SWIP puts it in a state where Android delivers '
              'it nothing at all — not even the signal that your phone has '
              'restarted. The button stays gone until you open SWIP once by '
              'hand. No permission changes this, and any app claiming '
              'otherwise on a stock phone is mistaken.',
              style: SwipType.bodyS
                  .copyWith(color: SwipColors.textSecondary),
            ),
          ),
          const _NumberedStep(
            n: 3,
            text: 'Turning the permission off. The button disappears the '
                'moment "display over other apps" is switched off.',
          ),
          const _Note(
            icon: Icons.layers_outlined,
            text: 'Other floating apps do NOT switch SWIP off. Android lets '
                'several apps float at once and simply stacks them — the '
                'newest sits on top. If SWIP\'s button is hidden behind '
                'another app\'s, drag it somewhere else.',
          ),
          const SizedBox(height: SwipSpace.lg),
          const _Note(
            icon: Icons.accessibility_new_rounded,
            text: 'The one place Android really does allow only one app at a '
                'time is the accessibility shortcut — holding both volume '
                'keys. SWIP does not use it, so nothing can take SWIP\'s '
                'place there and SWIP can never take anyone else\'s.',
          ),
        ],
        action: FilledButton(
            onPressed: onOpen, child: const Text('Open SWIP\'s app settings')),
        secondary:
            TextButton(onPressed: onNext, child: const Text('Skip for now')),
      );
}

// ── 5 ────────────────────────────────────────────────────────────────────

class _AllSetStep extends StatelessWidget {
  const _AllSetStep({
    required this.running,
    required this.overlayGranted,
    required this.onFinish,
  });

  final bool running;
  final bool overlayGranted;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    // The whole reason this screen exists. Wispr Flow's page 23 opens with
    // "You won't see the Flow Bubble right away", and that one sentence is
    // what stops their users reporting the bubble as broken. SWIP's version
    // of the same surprise is stronger — the bubble is hidden while SWIP
    // itself is on screen, which is *exactly where the user is standing when
    // they finish this wizard*.
    if (!overlayGranted) {
      return _Screen(
        title: 'Not turned on yet',
        body: [
          Text(
            'SWIP still does not have permission to draw over other apps, so '
            'there is no floating button. Everything else in SWIP works '
            'normally — scan, tap and the ledger are all unaffected.',
            style:
                SwipType.bodyL.copyWith(color: SwipColors.textSecondary),
          ),
          const SizedBox(height: SwipSpace.xl),
          const _Note(
            text: 'You can turn it on any time from Settings → Scan from '
                'anywhere.',
          ),
        ],
        action: FilledButton(onPressed: onFinish, child: const Text('Done')),
      );
    }

    return _Screen(
      title: 'You\'re all set',
      body: [
        Text('Here is what to expect.',
            style: SwipType.bodyL.copyWith(color: SwipColors.textSecondary)),
        const SizedBox(height: SwipSpace.xl),
        _Expect(
          n: 1,
          rich: 'You will not see the button right now.',
          detail: 'SWIP hides it while you are inside SWIP. A button floating '
              'over the app it belongs to is just a smudge on the screen.',
        ),
        _Expect(
          n: 2,
          rich: 'Leave SWIP and it appears.',
          detail: 'Press home. It parks against the edge of the screen, over '
              'whatever you are doing.',
        ),
        _Expect(
          n: 3,
          rich: 'Drag it anywhere.',
          detail: 'It snaps to the nearest side. Tap it to open the scanner.',
        ),
        const SizedBox(height: SwipSpace.md),
        _DoneChip(
          done: running,
          doneText: 'Running now',
          todoText: 'Starting…',
        ),
      ],
      action: FilledButton(onPressed: onFinish, child: const Text('Finish')),
    );
  }
}

class _Expect extends StatelessWidget {
  const _Expect({required this.n, required this.rich, required this.detail});

  final int n;
  final String rich;
  final String detail;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: SwipSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 22,
                  child: Text('$n.',
                      style: SwipType.bodyM
                          .copyWith(color: SwipColors.textSecondary)),
                ),
                Expanded(
                  child: Text(rich,
                      style: SwipType.titleS
                          .copyWith(color: SwipColors.textPrimary)),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 22, top: SwipSpace.xs),
              child: Text(detail,
                  style: SwipType.bodyS
                      .copyWith(color: SwipColors.textSecondary)),
            ),
          ],
        ),
      );
}
