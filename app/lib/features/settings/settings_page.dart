import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/onboarding/primers.dart';
import '../../core/theme/swip_tokens.dart';
import '../../data/repositories/capture_repository.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: SwipSpace.sm),
        children: [
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
              'server — nothing is uploaded unless you export it yourself.',
              style: SwipType.bodyS.copyWith(color: SwipColors.textTertiary),
            ),
          ),
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
      text: 'Your SWIP ledger — ${rows.length} captures. '
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
            ? 'Already up to date — nothing new in that file'
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
