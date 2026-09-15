import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/swip_tokens.dart';
import 'bubble_trace_page.dart';
import 'bubble_wizard.dart';

/// `F-131` — the floating scan bubble, and the permission it needs.
///
/// ## Why this screen exists rather than a switch
///
/// `SYSTEM_ALERT_WINDOW` is a **special permission**. It cannot be granted by a
/// runtime dialog: the only way to get it is to send the user into Settings and
/// have them find a switch. That has one consequence that governs the entire
/// design of this screen — **you get one attempt.** A user dropped into an
/// Android settings page with no idea why does not grant it, and does not come
/// back.
///
/// So: explain, *then* send. Which is exactly the pattern Wispr Flow uses, and
/// the reason their screenshots show a dedicated card reading "To use Flow in
/// any app, allow Display over other apps via Settings" with a single **Go to
/// Settings** button.
///
/// ## What SWIP promises here, and means
///
/// The disclosure below is not decoration and not legal cover. As of `F-158`
/// every line of it is enforced somewhere you can go and read:
///
///   * hides for 90 seconds after SWIP hands off a payment —
///     `MainActivity`'s `forwardUpiIntent` and `openExternal` both signal
///     `ACTION_PAYMENT_STARTED`, and `SwipBubbleService.applyVisibility`
///     honours it;
///   * hides while the screen is locked — `ACTION_SCREEN_OFF` in the same
///     receiver;
///   * hides while SWIP itself is in front — `MainActivity.onResume`.
///
/// Two lines were removed in `F-159` rather than left unkept. One of them —
/// "one flick sends it away for the rest of the day" — came back in `F-167`,
/// because the flick was built. The other, "size and see-through-ness are
/// yours to set", is still gone: there are no such controls, and a promise on
/// a privacy disclosure that the code does not keep is worse than no promise.
///
/// And one line is true by construction rather than by promise: **SWIP does not
/// request an Accessibility Service.** Wispr Flow does — their screenshots show
/// Android's full "Allow full control of your device?" warning — because they
/// have to type into other apps. SWIP only draws a circle and opens its own
/// camera. It never reads another app's screen, because it has no mechanism to.
///
/// That difference is worth stating plainly on this screen: it is the reason a
/// cautious person should be more willing to grant this than the app they are
/// comparing it to.
class BubbleSettingsPage extends StatefulWidget {
  const BubbleSettingsPage({super.key});

  /// `F-131`'s storage, kept **only** to be migrated away from.
  ///
  /// This key is the fault this round was reported as. `F-131` wrote the
  /// user's wish here and nothing anywhere read it, so the switch went on and
  /// no bubble appeared. The wish now lives with the service that draws the
  /// window — see `SwipBubbleService.isWanted` — and this is read exactly once,
  /// by [_BubbleSettingsPageState._migrateLegacyWish], then deleted.
  static const prefKey = 'swip.bubble.enabled';

  @override
  State<BubbleSettingsPage> createState() => _BubbleSettingsPageState();
}

class _BubbleSettingsPageState extends State<BubbleSettingsPage>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('in.swip.app/nfc');

  /// How long to wait for Android before giving up on it.
  ///
  /// **A `MethodChannel` future completes when the platform replies, and if
  /// the platform never replies it never completes.** There is no built-in
  /// timeout. `_loading` is only cleared at the end of [_refresh], so a single
  /// unanswered call leaves this screen on its spinner forever, with no way
  /// out but force-quitting the app.
  ///
  /// That is not hypothetical — it is how the test for this screen first
  /// failed. In a widget test there is no engine to answer a channel at all,
  /// so `invokeMethod` hung and `pumpAndSettle` timed out. A real iOS build
  /// answers immediately with `MissingPluginException`; a real Android build
  /// answers unless `MainActivity` is wedged. The test was a harsher platform
  /// than either, and it found something worth fixing.
  ///
  /// Three seconds because this screen has nothing to show until the answer
  /// arrives, and a spinner is worse than a switch that says "off".
  static const _patience = Duration(seconds: 3);

  bool _granted = false;
  bool _wanted = false;
  bool _running = false;

  /// `F-167`. When the bubble wakes, or null if it is awake.
  ///
  /// Held as the deadline rather than a boolean so this screen can say *when*
  /// it comes back. "Asleep" with no end is indistinguishable from broken, and
  /// this feature has already been reported as broken twice.
  DateTime? _asleepUntil;
  bool _loading = true;

  /// True between "the user tapped the switch on" and "we found out whether
  /// Android let them".
  ///
  /// The permission lives in Android Settings, in another app, so the tap and
  /// the answer are separated by SWIP being backgrounded. Without this the
  /// intent is lost across that gap: the user taps the switch, grants the
  /// permission, comes back — **and the switch is still off**, because all
  /// SWIP learned on resume is that the permission exists, not that anybody
  /// wanted it.
  ///
  /// They then have to tap the same switch a second time. Which looks exactly
  /// like the bug this whole round is about, and would have been reported as
  /// it. One tap meant one thing; this is what carries it across.
  bool _askedFor = false;

  /// `F-176`. Whether this APK records a bubble trace at all.
  ///
  /// **Starts false, and the default is the point.** The platform is asked
  /// once on open; until it answers, and forever on a release build, the debug
  /// row is simply not in the tree. A debug entry point that flashes on for a
  /// frame in a shipped app would be worse than one that never existed.
  bool _traceAvailable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The permission is granted in Settings, in another app, so the only moment
  /// SWIP can learn about it is when it comes back to the foreground. Without
  /// this the screen would still say "not allowed" after the user had just
  /// allowed it — which reads as the app being broken, and is the exact
  /// complaint that was raised about the NFC toggle in `F-40`.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  /// Honour a tap that was interrupted by a trip to Android Settings.
  ///
  /// Deliberately **one-shot**: cleared whether or not the permission was
  /// granted. A user who taps the switch, thinks better of it in Settings and
  /// comes back without granting must not have a bubble appear the next time
  /// they happen to grant that permission for some other reason.
  Future<bool> _resumePendingWish(bool granted) async {
    if (!_askedFor) return false;
    _askedFor = false;
    if (!granted) return false;
    await _ask(() => _channel.invokeMethod<bool>('startBubble'));
    return true;
  }

  /// One question to Android, with a deadline and no way to throw.
  ///
  /// `PlatformException` (the Activity reported a problem),
  /// `MissingPluginException` (iOS, or an Activity older than these methods)
  /// and `TimeoutException` (nothing answered) all mean the same thing to this
  /// screen — assume there is no bubble — so they are caught together rather
  /// than as three branches that do the same thing.
  Future<T?> _ask<T>(Future<T?> Function() call) async {
    try {
      return await call().timeout(_patience);
    } on Object {
      return null;
    }
  }

  /// `F-158` — **ask Android, do not remember.**
  ///
  /// This method used to read a `SharedPreferences` boolean that this screen
  /// had written itself, and that was most of why the feature looked broken:
  /// Dart owned a flag, Android owned the window, and the two were never
  /// compared. The switch could say ON with nothing on screen forever.
  ///
  /// Now there are three facts and all three come from the platform:
  ///
  ///   * `granted` — does SWIP hold the overlay permission *right now*. It can
  ///     be revoked in Settings at any time, without SWIP running.
  ///   * `wanted`  — what the user last asked for, stored by the service.
  ///   * `running` — whether a window actually exists.
  ///
  /// The switch shows `wanted && granted`, because those are the only
  /// circumstances under which a bubble can be there. `running` is used for
  /// the one sentence underneath, which is the only place in the app that can
  /// tell the user the truth when those two disagree.
  Future<void> _refresh() async {
    final granted =
        await _ask(() => _channel.invokeMethod<bool>('canDrawOverlays')) ??
            false;

    // Migration runs BEFORE the status read, not after. It can start the
    // service, and reading `running` first would leave this screen saying
    // "it comes back next time you open SWIP" about a bubble already on
    // screen. Ask once, after everything that could change the answer.
    if (granted) await _migrateLegacyWish();

    // Before the status read, for the same reason the migration is: it can
    // start the service, and `running` must be read after everything that
    // could change it.
    await _resumePendingWish(granted);

    final status = await _ask(
        () => _channel.invokeMapMethod<String, dynamic>('bubbleStatus'));
    final wanted = status?['wanted'] == true;
    final running = status?['running'] == true;
    final snoozeMs = status?['snoozedUntil'];
    final asleepUntil = snoozeMs is int && snoozeMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(snoozeMs)
        : null;

    // `F-176`. Asked here rather than in `initState` so it is re-checked on
    // every resume along with everything else on this screen — one place that
    // reads the world, which is the same rule `applyVisibility` follows on the
    // Kotlin side.
    final trace = await BubbleTracePage.traceEnabled();

    if (!mounted) return;
    setState(() {
      _granted = granted;
      _wanted = wanted;
      _running = running;
      _asleepUntil = asleepUntil;
      _traceAvailable = trace;
      _loading = false;
    });
  }

  /// One-time rescue of the switch that never did anything.
  ///
  /// `F-131` stored the wish under `swip.bubble.enabled` and nothing read it.
  /// Anyone who turned the bubble on in that build — which is the report that
  /// started this round — has a `true` sitting in preferences and no bubble.
  /// Rather than make them find the switch and discover it now works, the flag
  /// is honoured once and then cleared, so the wish is carried across exactly
  /// one time and this branch can eventually be deleted.
  Future<void> _migrateLegacyWish() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getBool(BubbleSettingsPage.prefKey);
    if (legacy == null) return;
    // Cleared whether or not it is acted on, so this can only ever fire once
    // and the branch can be deleted in a later round.
    await prefs.remove(BubbleSettingsPage.prefKey);
    if (!legacy) return;
    // Safe to call even if the service is already up — `ACTION_START` is
    // idempotent and simply re-shows the bubble. The status read that follows
    // reports what actually happened, so nothing is assumed here.
    await _ask(() => _channel.invokeMethod<bool>('startBubble'));
  }

  /// `F-167`. End a snooze early.
  Future<void> _wake() async {
    await _ask(() => _channel.invokeMethod<bool>('wakeBubble'));
    await _refresh();
  }

  /// Turn the bubble on or off for real.
  ///
  /// The order matters and is the whole lesson of `F-131`: **the permission
  /// comes first and nothing is recorded until it is held.** Writing the wish
  /// and then asking is how the old screen ended up showing a switch that was
  /// on while Android had refused.
  Future<void> _setWanted(bool on) async {
    if (on && !_granted) {
      // Remember the tap. Nothing is *recorded* — no preference is written and
      // no service is started until Android actually allows it — but the
      // intent has to survive the trip to Settings or the user comes back to
      // the switch they just moved, sitting in the off position.
      _askedFor = true;
      await _ask(() => _channel.invokeMethod<bool>('requestOverlayPermission'));
      return; // `didChangeAppLifecycleState` picks up the result.
    }

    // An explicit off cancels any pending wish. Otherwise a tap-on,
    // tap-off before Settings ever opened would still turn it on.
    _askedFor = false;

    // `startBubble` returns false if Android refuses, and the state is read
    // back afterwards rather than assumed. A switch is allowed to stay off; a
    // switch that lies is what brought us here.
    //
    // Two branches rather than one ternary on purpose: `tool/check_wiring.py`
    // pairs every channel name in Dart against a handler in `MainActivity.kt`,
    // and it can only do that for names that are literals at the call site.
    // A method name buried in an expression is one a grep cannot find — and
    // so is one a person cannot find either.
    if (on) {
      await _ask(() => _channel.invokeMethod<bool>('startBubble'));
    } else {
      await _ask(() => _channel.invokeMethod<bool>('stopBubble'));
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan from anywhere')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: SwipSpace.sm),
              children: [
                Padding(
                  padding:
                      const EdgeInsets.all(SwipSpace.gutter),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('A button that follows you',
                          style: SwipType.titleL
                              .copyWith(color: SwipColors.textPrimary)),
                      const SizedBox(height: SwipSpace.md),
                      Text(
                        'SWIP can float a small button over whatever you are '
                        'doing. Tap it and a camera window opens right there, '
                        'reads the shop\'s code, and tells you the category - '
                        'without leaving the app you were in.\n\n'
                        'That is the whole point of SWIP, and it does not work '
                        'if you have to switch away from the counter to use it.',
                        style: SwipType.bodyM
                            .copyWith(color: SwipColors.textSecondary),
                      ),
                    ],
                  ),
                ),

                SwitchListTile(
                  value: _wanted && _granted,
                  onChanged: _setWanted,
                  title: const Text('Show the scan button'),
                  // `F-158`. Three states, not two, because the switch and the
                  // screen can genuinely disagree — the permission is revocable
                  // from Android Settings while SWIP is not running, and the
                  // service is killable under memory pressure. This is the one
                  // place in the app that can say so, and the old version of
                  // this line could only ever claim success.
                  subtitle: Text(
                    !_granted
                        ? 'Android needs you to allow this in Settings first'
                        : !_wanted
                            ? 'Drag it anywhere. It snaps to the nearest edge.'
                            : _running
                                ? 'On. It stays hidden while you are inside '
                                    'SWIP — leave the app and it appears. '
                                    'Drag it; it snaps to the nearest edge.'
                                : 'Switched on. It comes back the next time '
                                    'you open SWIP.',
                    style: SwipType.bodyS
                        .copyWith(color: SwipColors.textSecondary),
                  ),
                  secondary: Icon(
                    _wanted && _granted && _running
                        ? Icons.blur_on_rounded
                        : Icons.blur_circular_rounded,
                  ),
                ),

                if (!_granted)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(SwipSpace.gutter, 0,
                        SwipSpace.gutter, SwipSpace.lg),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(SwipSpace.lg),
                      decoration: BoxDecoration(
                        color: SwipColors.surfaceRaised,
                        borderRadius: SwipRadius.cardAll,
                        border: Border.all(color: SwipColors.hairline),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('One switch, in Android Settings',
                              style: SwipType.label
                                  .copyWith(color: SwipColors.textPrimary)),
                          const SizedBox(height: SwipSpace.xs),
                          Text(
                            'Android calls it "Display over other apps". It '
                            'cannot be granted from inside an app - the switch '
                            'only exists in Settings.',
                            style: SwipType.bodyS
                                .copyWith(color: SwipColors.textSecondary),
                          ),
                          const SizedBox(height: SwipSpace.md),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () => _setWanted(true),
                              child: const Text('Go to Settings'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // `F-167`. Only while it is actually asleep. A permanent row
                // saying "not snoozed" is a row nobody ever needs.
                if (_asleepUntil != null)
                  ListTile(
                    leading: Icon(Icons.bedtime_outlined,
                        color: SwipColors.warning),
                    title: const Text('Sleeping'),
                    subtitle: Text(
                      'Back at ${_clock(_asleepUntil!)}, or the moment you '
                      'shake your phone. Dragging the button onto the moon '
                      'sends it away for ten minutes; the notice in your '
                      'shade can send it away for an hour.',
                      style: SwipType.bodyS
                          .copyWith(color: SwipColors.textSecondary),
                    ),
                    trailing: TextButton(
                      onPressed: _wake,
                      child: const Text('Wake it'),
                    ),
                  ),

                // `F-159`. The way back into the wizard.
                //
                // Without this the five screens are a one-shot: a user who
                // skipped the permission on first run, or whose phone ate the
                // service, has the explanation and the Settings deep-links
                // nowhere to hand. This is also the row to point somebody at
                // when they say the button has stopped appearing.
                ListTile(
                  leading: const Icon(Icons.auto_awesome_outlined),
                  title: const Text('Set it up step by step'),
                  subtitle: Text(
                    _granted
                        ? 'The five-screen walkthrough, including what can '
                            'take the button away'
                        : 'Walks you through the Android settings this needs',
                    style: SwipType.bodyS
                        .copyWith(color: SwipColors.textSecondary),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const BubbleWizard(),
                    ));
                    await _refresh();
                  },
                ),

                const Divider(height: SwipSpace.xxl),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: SwipSpace.gutter),
                  child: Text('WHAT IT WILL NEVER DO',
                      style: SwipType.labelS
                          .copyWith(color: SwipColors.textTertiary)),
                ),
                const SizedBox(height: SwipSpace.md),

                // The promises. Each one is enforced somewhere, and the ones
                // that are structural rather than behavioural say so — a
                // promise the code *cannot* break is worth more than one it
                // merely does not.
                const _Promise(
                  icon: Icons.visibility_off_outlined,
                  text: 'It never appears over a payment. SWIP hides the '
                      'button for 90 seconds after it hands a payment to '
                      'another app, and whenever your screen is locked.',
                ),
                const _Promise(
                  icon: Icons.lock_outline_rounded,
                  text: 'It cannot read your screen. SWIP does not use an '
                      'Accessibility Service at all - it has no way to see '
                      'what any other app is showing.',
                ),
                const _Promise(
                  icon: Icons.videocam_off_outlined,
                  text: 'The camera only runs while the window is open, and '
                      'no frame is ever saved.',
                ),
                const _Promise(
                  icon: Icons.notifications_none_rounded,
                  text: 'While it is on, Android shows a silent notice in your '
                      'shade. That is required — no app can draw over another '
                      'quietly — and it carries a Turn off button.',
                ),
                // `F-167`. This line was deleted in `F-159` because it was not
                // true — the screen had promised a flick-away that did not
                // exist. It is back because the feature is.
                const _Promise(
                  icon: Icons.bedtime_outlined,
                  text: 'Drag the button down onto the moon to send it away '
                      'for ten minutes — shake your phone to bring it back '
                      'sooner. Sleeping is not the same as off: it comes back '
                      'on its own either way.',
                ),
                // `F-173`. **This line said the opposite of what the app
                // does**, and had done since `F-162`.
                //
                // It was written in `F-159`, when declining to ask for
                // `RECEIVE_BOOT_COMPLETED` was the right call and the sentence
                // was true. The owner then asked for omnipresence explicitly,
                // `F-162` added the receiver, and this promise was not
                // revisited — so the one screen whose entire job is to tell
                // the truth about a permission has been telling people SWIP
                // does not hold one that it does.
                //
                // Found while updating the snooze copy beside it. Worth its
                // own note: a screen full of promises needs re-reading in full
                // whenever any of them stops being true, because nothing fails
                // when a sentence quietly goes stale.
                const _Promise(
                  icon: Icons.restart_alt_rounded,
                  text: 'It comes back on its own after you restart your '
                      'phone. That needs a start-on-boot permission, which '
                      'SWIP asks for and uses for nothing else.',
                ),

                // `F-176`. **The temporary trace, and it draws only on a
                // debug build.**
                //
                // `_traceAvailable` is answered by the platform asking whether
                // this APK is debuggable — not a preference, not a constant
                // anyone has to remember to flip. On a Play Store build the
                // future resolves false and this row does not exist.
                //
                // Delete this block, `bubble_trace_page.dart`, `BubbleTrace.kt`
                // and the three channel cases in `MainActivity` and the feature
                // is gone. `docs/38` has the list.
                if (_traceAvailable) ...[
                  const SizedBox(height: SwipSpace.xxl),
                  ListTile(
                    leading: Icon(Icons.bug_report_outlined,
                        color: SwipColors.warning),
                    title: const Text('Bubble trace'),
                    subtitle: Text(
                      'Debug build only. Records why the button appeared or '
                      'disappeared, so a report can be read rather than '
                      'guessed at.',
                      style: SwipType.bodyS
                          .copyWith(color: SwipColors.textSecondary),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const BubbleTracePage()),
                    ),
                  ),
                ],

                const SizedBox(height: SwipSpace.xxl),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: SwipSpace.gutter),
                  child: Text(
                    'This is an Android feature. iPhones do not let any app '
                    'draw over another, so SWIP cannot offer it there.',
                    style: SwipType.bodyS
                        .copyWith(color: SwipColors.textTertiary),
                  ),
                ),
                const SizedBox(height: SwipSpace.xxxl),
              ],
            ),
    );
  }
}

/// A 24-hour clock, and a date too when the snooze runs past midnight.
///
/// `intl` is not a dependency of this project and one date string is not a
/// reason to add one — but "back at 00:30" with no date, read at 23:00, is a
/// sentence that means the wrong thing.
String _clock(DateTime t) {
  final now = DateTime.now();
  final hhmm = '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';
  final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
  return sameDay ? hhmm : 'tomorrow, $hhmm';
}

class _Promise extends StatelessWidget {
  const _Promise({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
            SwipSpace.gutter, 0, SwipSpace.gutter, SwipSpace.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(icon, size: 17, color: SwipColors.textSecondary),
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
