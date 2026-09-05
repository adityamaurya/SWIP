import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/location/capture_location.dart';
import '../../core/onboarding/primers.dart';
import '../../core/settings/home_market.dart';
import '../../core/theme/swip_tokens.dart';
import '../../data/repositories/capture_repository.dart';
import '../../data/sources/ledger_seal.dart';
import '../bubble/bubble_settings.dart';
import '../onboarding/home_market_page.dart';
import '../support/support_section.dart';

/// `S-12` — Settings.
///
/// Backup is the headline. SWIP has no server and no account of yours, so the
/// only way your history survives a lost phone is a file you own. That file is
/// plain, readable JSON — not an opaque blob — so it stays useful even if SWIP
/// stops existing.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(captureCountProvider).valueOrNull ?? 0;
    final home = ref.watch(homeMarketProvider).valueOrNull;
    final locationOn = ref.watch(locationEnabledProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: SwipSpace.sm),
        children: [
          _header('Where you are'),

          // `F-15`. Changeable, because people move — and because a wrong
          // answer here silently mislabels every capture as domestic.
          ListTile(
            leading: Text(home?.flag ?? '🏳️',
                style: const TextStyle(fontSize: 24)),
            title: const Text('Home country'),
            subtitle: Text(
              home == null
                  ? 'Not set - captures cannot be marked domestic or '
                      'international'
                  : '${home.displayName} · ${home.currency}',
              style: SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  HomeMarketPage(initial: home, isOnboarding: false),
            )),
          ),

          // `F-40`. Off by default and asked for here, not at first run. An app
          // that wants your location before it has shown you anything useful
          // gets denied for ever — and SWIP is completely usable without it.
          SwitchListTile(
            secondary: const Icon(Icons.place_outlined),
            value: locationOn,
            title: const Text('Remember where a capture happened'),
            subtitle: Text(
              locationOn
                  ? 'Stored as a ~1 km area, never exact coordinates'
                  : 'Off. Categories work exactly the same without it',
              style: SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
            ),
            activeThumbColor: SwipColors.gold500,
            activeTrackColor: SwipColors.gold900,
            onChanged: (want) => _setLocation(context, ref, want),
          ),

          // `F-107`. "Learn from a bank statement" is removed for now, at your
          // request. The parser stays — `statement_parser.dart` and its tests
          // are untouched, and the share-a-statement route still works — but
          // the screen is gone from Settings until it earns its place.
          const Divider(height: SwipSpace.xxl),
          _header('Your data'),

          ListTile(
            leading: const Icon(Icons.download_rounded),
            title: const Text('Export ledger'),
            subtitle: Text(
              count == 0
                  ? 'Nothing captured yet'
                  : 'Save all $count captures as a file you own',
              style: SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
            ),
            onTap: count == 0 ? null : () => _export(context, ref),
          ),

          ListTile(
            leading: const Icon(Icons.upload_rounded),
            title: const Text('Import a backup'),
            subtitle: Text(
              'Merges by capture id, so importing twice is safe',
              style: SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
            ),
            onTap: () => _import(context, ref),
          ),

          const Divider(height: SwipSpace.xxl),
          _header('Scanning'),

          // `F-131`. Its own screen rather than a switch here, because the
          // permission behind it can only be granted in Android's Settings and
          // you get exactly one attempt at asking. See `bubble_settings.dart`.
          ListTile(
            leading: const Icon(Icons.blur_circular_rounded),
            title: const Text('Scan from anywhere'),
            subtitle: Text(
              'A floating button over other apps, so you can check a code '
              'without leaving the checkout',
              style: SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const BubbleSettingsPage(),
            )),
          ),

          const Divider(height: SwipSpace.xxl),
          _header('Explanations'),

          ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('Show all explanations again'),
            subtitle: Text(
              'Brings back every "Don\'t show this again" you have ticked',
              style: SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
            ),
            onTap: () async {
              final service = await ref.read(primerServiceProvider.future);
              await service.resetAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Explanations will show again')));
              }
            },
          ),

          const Divider(height: SwipSpace.xxl),
          _header('Danger zone'),

          ListTile(
            leading: const Icon(Icons.delete_outline_rounded,
                color: SwipColors.dangerOnInk),
            title: Text('Delete everything',
                style: SwipType.bodyL
                    .copyWith(color: SwipColors.dangerOnInk)),
            subtitle: Text(
              'Cannot be undone. Export first.',
              style: SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
            ),
            onTap: () => _confirmWipe(context, ref),
          ),

          const SizedBox(height: SwipSpace.xxl),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SwipSpace.gutter),
            child: Text(
              'SWIP keeps everything on this phone. There is no account and no '
              'server - nothing is uploaded unless you export it yourself.',
              style: SwipType.bodyS.copyWith(color: SwipColors.textTertiary),
            ),
          ),

          const SizedBox(height: SwipSpace.giant),
          const _Colophon(),

          // `F-111`. Below the signature, closed, and it stays closed unless
          // someone opens it.
          const SupportSection(),
          const SizedBox(height: SwipSpace.xxxl),
        ],
      ),
    );
  }

  Widget _header(String s) => Padding(
        padding: const EdgeInsets.fromLTRB(
            SwipSpace.gutter, SwipSpace.lg, SwipSpace.gutter, SwipSpace.sm),
        child: Text(s.toUpperCase(),
            style: SwipType.labelS.copyWith(color: SwipColors.textTertiary)),
      );

  /// `F-40`. Turning it on asks for the permission as part of the same gesture.
  ///
  /// The toggle reflects what the system actually granted, not what we asked
  /// for: a switch that stays on after the user tapped "Deny" is a lie, and it
  /// is the kind of lie that gets noticed.
  Future<void> _setLocation(
      BuildContext context, WidgetRef ref, bool want) async {
    final service = await ref.read(locationServiceProvider.future);

    if (!want) {
      await service.disable();
      ref.read(locationRevisionProvider.notifier).state++;
      return;
    }

    final granted = await service.enable();
    ref.read(locationRevisionProvider.notifier).state++;

    if (!granted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
          'Location stayed off - Android did not grant it. You can allow it '
          'in your phone\'s app settings.',
        ),
      ));
    }
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final db = await ref.read(databaseProvider.future);
    final rows = await db.exportRows();

    // `F-127`. Seal the rows before writing them: each record carries the hash
    // of the one before it, so a file edited anywhere fails verification from
    // that point on. See `ledger_seal.dart` for what this does and does not
    // claim.
    final sealed = LedgerSeal.seal(rows);
    final sealHash = LedgerSeal.sealHashOf(sealed);

    // `F-128`. A serial that increases for the life of the install, so two
    // exports taken in the same second are still distinguishable and a folder
    // of backups sorts into the order they were actually taken.
    final serial = await _nextExportSerial();
    final now = DateTime.now();

    final payload = <String, Object?>{
      'format': 'swip.ledger',
      'version': 1,
      'sealVersion': LedgerSeal.version,
      'sealHash': sealHash,
      'exportSerial': serial,
      'exportedAt': now.toUtc().toIso8601String(),
      'exportedAtLocal': _stamp(now),
      'captureCount': sealed.length,
      'captures': sealed,
    };

    final dir = await getTemporaryDirectory();
    // `F-128`. Readable at a glance in a Downloads folder six months from now:
    //     SWIP_Ledger_2026-09-05_14-32-07_no-0007_142-captures.json
    // Date and time are **local**, because the person reading the filename is
    // in a timezone, not in UTC. The UTC instant is inside the file.
    final name = 'SWIP_Ledger_${_stamp(now)}'
        '_no-${serial.toString().padLeft(4, '0')}'
        '_${sealed.length}-captures.json';
    final file = File('${dir.path}/$name');
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload));

    if (!context.mounted) return;
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'SWIP ledger backup $name',
      text: 'Your SWIP ledger - ${sealed.length} captures, export '
          'no. $serial, taken ${_stamp(now)}.\n'
          'Seal ${sealHash.substring(0, 12)}… - SWIP checks this on import and '
          'tells you if the file changed.\n'
          'Save it to Google Drive, then import it on a new phone.',
    );
  }


  /// `F-128`. `2026-09-05_14-32-07`, local time, sortable, no colons — colons
  /// are illegal in filenames on Windows and get silently rewritten by some
  /// Android file pickers, which is how a backup ends up named `swip-ledger-`.
  static String _stamp(DateTime t) {
    String p(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${p(t.month)}-${p(t.day)}_'
        '${p(t.hour)}-${p(t.minute)}-${p(t.second)}';
  }

  /// A per-install counter. Stored next to the other preferences; if it is ever
  /// lost the worst case is a repeated number in a filename, so it deliberately
  /// does not fail the export.
  static Future<int> _nextExportSerial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final next = (prefs.getInt(_exportSerialKey) ?? 0) + 1;
      await prefs.setInt(_exportSerialKey, next);
      return next;
    } catch (_) {
      return 1;
    }
  }

  static const _exportSerialKey = 'swip.export.serial';

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;

    try {
      final text = await File(path).readAsString();
      final decoded = jsonDecode(text);

      if (decoded is! Map || decoded['format'] != 'swip.ledger') {
        throw const FormatException(
            'That file is not a SWIP ledger export.');
      }

      final rows = (decoded['captures'] as List)
          .cast<Map<String, Object?>>();

      // `F-127`. Check the seal **before** writing anything. An export made by
      // an older build carries no seal at all, which is not a failure and must
      // not be reported as one - it is simply a file from before this existed.
      final sealed = decoded['sealHash'] as String?;
      final SealCheck? check = sealed == null
          ? null
          : LedgerSeal.verify(rows, declaredSealHash: sealed);

      if (check != null && !check.intact) {
        // Not refused. The user's own backup is theirs, and a corrupted
        // record is still better than no record - but they are told plainly,
        // and told *where*, before it goes in.
        final proceed = await _confirmBrokenSeal(context, check);
        if (proceed != true) return;
      }

      final db = await ref.read(databaseProvider.future);
      final added = await db.importRows(rows);
      ref.read(ledgerRevisionProvider.notifier).state++;

      if (!context.mounted) return;
      final sealNote = check == null
          ? ''
          : check.intact
              ? ' · seal verified'
              : ' · seal did not match';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(added == 0
            ? 'Already up to date - nothing new in that file$sealNote'
            : 'Restored $added captures$sealNote'),
      ));
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not import: $e')));
    }
  }


  /// `F-127`. The seal did not verify. Say what that means without making the
  /// person feel accused of anything - the overwhelmingly likely cause is a
  /// cloud sync that rewrote the file, not tampering.
  static Future<bool?> _confirmBrokenSeal(
      BuildContext context, SealCheck check) {
    if (!context.mounted) return Future.value(false);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SwipColors.surfaceRaised,
        title: const Text('This backup has changed'),
        content: Text(
          '${check.summary}\n\n'
          'Usually that means the file was edited, or something in transit '
          'rewrote it. The captures can still be imported - SWIP is telling '
          'you first rather than after.',
          style: SwipType.bodyM.copyWith(color: SwipColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Import anyway'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmWipe(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SwipColors.surfaceRaised,
        title: const Text('Delete everything?'),
        content: const Text(
            'Every capture and everything SWIP has learned about merchants '
            'will be removed from this phone. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: SwipType.label
                    .copyWith(color: SwipColors.dangerOnInk)),
          ),
        ],
      ),
    );

    if (ok != true) return;
    final repo = await ref.read(captureRepositoryProvider.future);
    await repo.clear();
    ref.read(ledgerRevisionProvider.notifier).state++;

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Everything deleted')));
  }
}

/// `F-108`, `F-122` — the colophon at the foot of Settings.
///
/// The mark, then who made it. Deliberately at the very bottom and deliberately
/// quiet: a colophon is a signature on the last page, not a banner.
///
/// ## One line, not a card
///
/// It was a 34 px avatar in a two-line block, which is a *profile*, and a
/// profile at the foot of a settings screen is somebody introducing themselves
/// when nobody asked. It is now a single sentence with the heart and the face
/// set **inline**, at the size of the surrounding text — a signature reads as a
/// signature only when it is the same size as the writing.
///
/// Built with [WidgetSpan]s rather than a `Row` for exactly that reason: a
/// span is laid out by the text engine, so the avatar tracks the reader's font
/// scale and wraps with the sentence instead of pushing it off the screen at
/// 1.6×.
///
/// ## The photograph
///
/// It looks for `assets/brand/avatar.jpg` and falls back to the monogram if it
/// is not there — which it is not, yet. A LinkedIn profile picture sits behind
/// an authentication wall and cannot be fetched by a build; drop the file into
/// the top-level `brand/` directory (**not** `app/assets/brand/`, which is
/// generated and gitignored — see `tool/bootstrap.sh`) and it appears with no
/// code change at all.
class _Colophon extends StatelessWidget {
  const _Colophon();

  static const _linkedIn = 'https://www.linkedin.com/in/adityamaurya/';

  /// `F-122`. The name, as asked for. Everywhere the app signs itself.
  static const _signature = 'a.r.my.';

  @override
  Widget build(BuildContext context) {
    // Sized off the type scale rather than a constant, so the face stays the
    // height of a lowercase line at any accessibility setting.
    final avatar = MediaQuery.textScalerOf(context).scale(18).clamp(14.0, 40.0);

    return Column(
      children: [
        SvgPicture.asset('assets/brand/swip-slash-wordmark.svg',
            height: 26, semanticsLabel: 'SW/P'),
        const SizedBox(height: SwipSpace.lg),
        InkWell(
          borderRadius: SwipRadius.pillAll,
          onTap: () =>
              Clipboard.setData(const ClipboardData(text: _linkedIn)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: SwipSpace.md, vertical: SwipSpace.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Made with '),
                      const WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Icon(Icons.favorite_rounded,
                            size: 12, color: SwipColors.gold500),
                      ),
                      const TextSpan(text: ' by '),
                      TextSpan(
                        text: _signature,
                        style: SwipType.bodyS
                            .copyWith(color: SwipColors.textPrimary),
                      ),
                      const TextSpan(text: ' '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: _Avatar(size: avatar),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: SwipType.bodyS
                      .copyWith(color: SwipColors.textSecondary),
                  // The whole line is one thing to a screen reader; the heart
                  // and the face are decoration and would otherwise be read
                  // out as two unlabelled images.
                  semanticsLabel: 'Made with love by $_signature',
                ),
                const SizedBox(height: SwipSpace.xxs),
                Text('Tap to copy the LinkedIn link',
                    style: SwipType.labelS
                        .copyWith(color: SwipColors.textTertiary)),
              ],
            ),
          ),
        ),
        const SizedBox(height: SwipSpace.md),
        Text('Check, pay, get rewarded.',
            style: SwipType.labelS.copyWith(color: SwipColors.gold500)),
        const SizedBox(height: SwipSpace.xs),
        Text('Built on a four-hour daily commute.',
            style: SwipType.bodyS.copyWith(color: SwipColors.textTertiary)),
      ],
    );
  }
}

/// The face. A photograph if one has been dropped in, the monogram otherwise.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: SwipColors.surfaceRaised2,
          border: Border.all(color: SwipColors.gold700),
        ),
        clipBehavior: Clip.antiAlias,
        // jpg, then png, then the monogram. No file, no crash - which is the
        // whole reason the photograph can be added later without a code change.
        child: _tryAsset(
          'assets/brand/avatar.jpg',
          fallback: _tryAsset(
            'assets/brand/avatar.png',
            fallback: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Text('am',
                    style: SwipType.labelS.copyWith(
                        color: SwipColors.gold300, letterSpacing: 0)),
              ),
            ),
          ),
        ),
      );

  Widget _tryAsset(String path, {required Widget fallback}) => Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      );
}
