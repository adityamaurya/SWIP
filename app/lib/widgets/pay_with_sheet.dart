import 'package:flutter/material.dart';

import '../core/pay/upi_handoff.dart';
import '../core/theme/swip_tokens.dart';

/// `F-194` — **the list of apps that can pay this code.**
///
/// > *"It gives an option of a list of apps which can make payment to this
/// > giver. This payment address will then be fetched into other apps when I
/// > click 'Choose' or 'Choose to pay with them'."* — prompt 54
///
/// ## Three states, and the middle one is the interesting one
///
///   * **Loading.** [UpiApps.list] is a platform read, so it is a future, so
///     there is a frame where nothing is known. It gets a spinner rather than
///     an empty list, because an empty list is also a real answer and the two
///     must not look alike.
///   * **Apps found.** The list, as rows with icons.
///   * **None found.** Not an error, and **not a dead end**: it falls straight
///     through to Android's own chooser. A phone can have a UPI app whose
///     manifest does not declare the `upi` scheme the way `<queries>` matches
///     on, and an emulator has none at all. The user gets a working hand-off
///     either way; what they lose is SWIP's styling of it.
///
/// That third state is why this sheet never renders "no apps found". There is
/// no such finding to report — only a route SWIP could not draw itself.
///
/// ## Why the rows are large and the icons are real
///
/// Because the user is at a counter, mid-checkout, choosing between things
/// they recognise by colour before they read them. A dense list of text labels
/// would be slower than the rescanning this feature replaces, which would make
/// the whole thing pointless. 56 px rows, 40 px icons, one line each.
class PayWithSheet extends StatefulWidget {
  const PayWithSheet({
    super.key,
    required this.payUri,
    required this.payeeLabel,
    this.list,
    this.pay,
    this.chooser,
  });

  /// The `upi://` string, forwarded unchanged — see [UpiHandoff].
  final String payUri;

  /// Who is being paid, shown once at the top. The user scanned this code
  /// seconds ago and is about to hand money to it; naming the payee is the
  /// one piece of confirmation this sheet owes them.
  final String payeeLabel;

  /// Injected for tests. `CLAUDE.md`, `F-158`: in a widget test there is **no
  /// engine at all**, so an un-mocked `MethodChannel` call hangs forever and
  /// the symptom is `pumpAndSettle timed out` rather than a failed assertion.
  /// Taking the three platform calls as parameters means the test asserts on
  /// what reaches the channel — which is the other standing rule, from the
  /// four months of a dead floating bubble.
  final Future<List<UpiApp>> Function()? list;
  final Future<bool> Function(String package, String uri)? pay;
  final Future<bool> Function(String uri)? chooser;

  static Future<void> open(
    BuildContext context, {
    required String payUri,
    required String payeeLabel,
    Future<List<UpiApp>> Function()? list,
    Future<bool> Function(String package, String uri)? pay,
    Future<bool> Function(String uri)? chooser,
  }) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: SwipColors.surfaceRaised,
        shape: const RoundedRectangleBorder(borderRadius: SwipRadius.sheetTop),
        builder: (_) => PayWithSheet(
          payUri: payUri,
          payeeLabel: payeeLabel,
          list: list,
          pay: pay,
          chooser: chooser,
        ),
      );

  @override
  State<PayWithSheet> createState() => _PayWithSheetState();
}

class _PayWithSheetState extends State<PayWithSheet> {
  late final Future<List<UpiApp>> _apps = (widget.list ?? UpiApps.list)();
  bool _handing = false;

  Future<void> _go(Future<bool> Function() run) async {
    // A second tap while the first is still opening an app would start two
    // payments. Guarded here rather than by disabling the rows, because a row
    // that greys out under the finger reads as a rejection.
    if (_handing) return;
    setState(() => _handing = true);
    final ok = await run();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _handing = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('That app could not be opened')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // `F-174`. `isScrollControlled` lets a sheet reach the screen height, and
    // a `Column` in one has nowhere to put overflow — release builds clip it
    // silently, so the content is simply gone with nothing failing. Capped,
    // and the list scrolls inside the cap.
    final cap = MediaQuery.sizeOf(context).height * 0.6;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: cap),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(SwipSpace.xl, SwipSpace.lg,
                  SwipSpace.xl, SwipSpace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pay with',
                      style: SwipType.titleS
                          .copyWith(color: SwipColors.textPrimary)),
                  const SizedBox(height: SwipSpace.xxs),
                  Text(
                    widget.payeeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwipType.bodyS
                        .copyWith(color: SwipColors.textTertiary),
                  ),
                ],
              ),
            ),
            // `Flexible`, not `Expanded` — `F-174` again. `Expanded` makes
            // every sheet fill its cap, so a phone with two UPI apps gets a
            // sheet two thirds of the screen tall holding two rows.
            Flexible(
              child: FutureBuilder<List<UpiApp>>(
                future: _apps,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(SwipSpace.xxl),
                      child: Center(
                          child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )),
                    );
                  }
                  final apps = snap.data ?? const <UpiApp>[];
                  if (apps.isEmpty) return _fallbackOnly();
                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: SwipSpace.sm),
                    itemCount: apps.length,
                    itemBuilder: (_, i) => _AppRow(
                      app: apps[i],
                      onTap: () => _go(() =>
                          (widget.pay ?? UpiApps.payWith)(
                              apps[i].package, widget.payUri)),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            // Always present, even when the list rendered. A user whose app is
            // missing from a list SWIP drew has no other way out, and "more
            // apps" is a smaller promise than the list itself.
            ListTile(
              leading: const Icon(Icons.apps_rounded),
              title: const Text('More payment apps'),
              onTap: () => _go(() =>
                  (widget.chooser ?? UpiApps.systemChooser)(widget.payUri)),
            ),
            const SizedBox(height: SwipSpace.sm),
          ],
        ),
      ),
    );
  }

  /// No list to draw. Say what will happen, in one line, and let them tap.
  Widget _fallbackOnly() => Padding(
        padding: const EdgeInsets.fromLTRB(
            SwipSpace.xl, SwipSpace.sm, SwipSpace.xl, SwipSpace.lg),
        child: Text(
          'SWIP could not read the list of payment apps on this phone. '
          'Android can still show it.',
          style: SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
        ),
      );
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.app, required this.onTap});

  final UpiApp app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = app.icon;
    return ListTile(
      minVerticalPadding: SwipSpace.md,
      leading: SizedBox(
        width: 40,
        height: 40,
        child: icon != null
            ? Image.memory(icon, gaplessPlayback: true)
            : _Monogram(label: app.label),
      ),
      title: Text(app.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: SwipType.bodyM.copyWith(color: SwipColors.textPrimary)),
      onTap: onTap,
    );
  }
}

/// The icon could not be loaded. A letter in a circle, which is the same
/// fallback the colophon uses for a missing avatar — better than a grey box,
/// and it still tells the two apps in the list apart.
class _Monogram extends StatelessWidget {
  const _Monogram({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: SwipColors.surface,
          border: Border.fromBorderSide(
              BorderSide(color: SwipColors.hairline)),
        ),
        alignment: Alignment.center,
        child: Text(
          label.isEmpty ? '?' : label[0].toUpperCase(),
          style: SwipType.label.copyWith(color: SwipColors.textSecondary),
        ),
      );
}
