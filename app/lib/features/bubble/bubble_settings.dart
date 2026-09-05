import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/swip_tokens.dart';

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
/// The disclosure below is not decoration and not legal cover. Two of its lines
/// are enforced in the service:
///
///   * the bubble hides for 90 seconds after SWIP hands off a payment intent;
///   * the bubble hides while the screen is locked.
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

  static const prefKey = 'swip.bubble.enabled';

  @override
  State<BubbleSettingsPage> createState() => _BubbleSettingsPageState();
}

class _BubbleSettingsPageState extends State<BubbleSettingsPage>
    with WidgetsBindingObserver {
  static const _channel = MethodChannel('in.swip.app/nfc');

  bool _granted = false;
  bool _wanted = false;
  bool _loading = true;

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

  Future<void> _refresh() async {
    final granted = await _channel
        .invokeMethod<bool>('canDrawOverlays')
        .catchError((_) => false) ??
        false;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _granted = granted;
      _wanted = prefs.getBool(BubbleSettingsPage.prefKey) ?? false;
      _loading = false;
    });
  }

  Future<void> _setWanted(bool on) async {
    if (on && !_granted) {
      await _channel
          .invokeMethod<bool>('requestOverlayPermission')
          .catchError((_) => false);
      return; // `didChangeAppLifecycleState` picks up the result.
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(BubbleSettingsPage.prefKey, on);
    if (mounted) setState(() => _wanted = on);
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
                  subtitle: Text(
                    _granted
                        ? 'Drag it anywhere. It snaps to the nearest edge.'
                        : 'Android needs you to allow this in Settings first',
                    style: SwipType.bodyS
                        .copyWith(color: SwipColors.textSecondary),
                  ),
                  secondary: const Icon(Icons.blur_circular_rounded),
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
                  icon: Icons.tune_rounded,
                  text: 'Size and see-through-ness are yours to set, and one '
                      'flick sends it away for the rest of the day.',
                ),

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
