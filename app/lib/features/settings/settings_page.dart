import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/location/capture_location.dart';
import '../../core/onboarding/primers.dart';
import '../../core/settings/home_market.dart';
import '../../core/theme/swip_tokens.dart';
import '../../data/repositories/capture_repository.dart';
import '../onboarding/home_market_page.dart';

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

    final payload = <String, Object?>{
      'format': 'swip.ledger',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'captureCount': rows.length,
      'captures': rows,
    };

    final dir = await getTemporaryDirectory();
    final stamp =
        DateTime.now().toIso8601String().split('T').first;
    final file = File('${dir.path}/swip-ledger-$stamp.json');
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(payload));

    if (!context.mounted) return;
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'SWIP ledger backup',
      text: 'Your SWIP ledger - ${rows.length} captures. '
          'Save this to Google Drive, then import it on a new phone.',
    );
  }

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

      final db = await ref.read(databaseProvider.future);
      final added = await db.importRows(rows);
      ref.read(ledgerRevisionProvider.notifier).state++;

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(added == 0
            ? 'Already up to date - nothing new in that file'
            : 'Restored $added captures'),
      ));
    } on Object catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not import: $e')));
    }
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

/// `F-108` — the colophon at the foot of Settings.
///
/// The mark, then who made it. Deliberately at the very bottom and deliberately
/// quiet: a colophon is a signature on the last page, not a banner.
///
/// The avatar is a monogram rather than a photograph, because a photograph would
/// have to be fetched from LinkedIn at build time and LinkedIn does not permit
/// that. Drop a `assets/brand/aditya.jpg` in and this swaps to it in one line -
/// see the note in `docs/25-PROMPT-27-PLAN.md`.
class _Colophon extends StatelessWidget {
  const _Colophon();

  static const _linkedIn = 'https://www.linkedin.com/in/adityamaurya/';

  @override
  Widget build(BuildContext context) => Column(
        children: [
          SvgPicture.asset('assets/brand/swip-slash-wordmark.svg',
              height: 26, semanticsLabel: 'SW/P'),
          const SizedBox(height: SwipSpace.lg),
          InkWell(
            borderRadius: SwipRadius.pillAll,
            onTap: () => Clipboard.setData(
                const ClipboardData(text: _linkedIn)),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: SwipSpace.md, vertical: SwipSpace.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: SwipColors.surfaceRaised2,
                      border: Border.all(color: SwipColors.gold700),
                    ),
                    child: Text('AM',
                        style: SwipType.labelS
                            .copyWith(color: SwipColors.gold300)),
                  ),
                  const SizedBox(width: SwipSpace.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Made with love by Aditya Maurya',
                          style: SwipType.bodyS
                              .copyWith(color: SwipColors.textSecondary)),
                      Text('Tap to copy the LinkedIn link',
                          style: SwipType.labelS
                              .copyWith(color: SwipColors.textTertiary)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SwipSpace.md),
          Text('Check, pay, get rewarded.',
              style: SwipType.labelS.copyWith(color: SwipColors.gold500)),
          const SizedBox(height: SwipSpace.xs),
          Text('Built on a four-hour daily commute.',
              style:
                  SwipType.bodyS.copyWith(color: SwipColors.textTertiary)),
        ],
      );
}
