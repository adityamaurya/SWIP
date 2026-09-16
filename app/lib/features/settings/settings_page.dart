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
import '../../core/theme/theme_setting.dart';
import '../../core/theme/swip_tokens.dart';
import '../../data/models/capture_event.dart';
import '../../data/repositories/capture_repository.dart';
import '../../data/sources/black_box.dart';
import '../../data/sources/swip_chain.dart';
import '../../data/sources/export_narrative.dart';
import '../../data/sources/ledger_lines.dart';
import '../../data/sources/ledger_seal.dart';
import '../backup/recovery_phrase.dart';
import '../backup/recovery_phrase_page.dart';
import '../bubble/bubble_settings.dart';
import '../bubble/bubble_wizard.dart';
import '../lookup/lookup_settings_page.dart';
import '../lookup/lookup_wizard.dart';
import '../onboarding/home_market_page.dart';
import '../support/support_section.dart';

/// `S-12` — Settings.
///
/// Backup is the headline. SWIP has no server and no account of yours, so the
/// only way your history survives a lost phone is a file you own.
///
/// `F-147`, `F-149`. There are now **two** of those files and they are not
/// alternatives:
///
/// | | For | Readable by |
/// |---|---|---|
/// | The backup | Restoring onto another phone | SWIP, with the recovery phrase |
/// | The list | Reading, checking, pasting into a message | A person, in any text app |
///
/// The backup used to be plain JSON, and the argument for that was that it
/// *"stays useful even if SWIP stops existing"*. That argument lost to a
/// stronger one: a plain ledger of every shop you have paid, every amount and
/// every location, sitting in a Downloads folder and synced to a cloud, is the
/// most sensitive artefact this app produces. It is now encrypted, and the
/// plain list — which carries no payloads, no handles and no coordinates —
/// takes over the job of being readable forever.
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

          // `F-147`. The sealed backup.
          ListTile(
            leading: const Icon(Icons.lock_outline_rounded),
            title: const Text('Back up, encrypted'),
            subtitle: Text(
              count == 0
                  ? 'Nothing captured yet'
                  : 'All $count captures, sealed with your recovery phrase',
              style: SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
            ),
            onTap: count == 0 ? null : () => _export(context, ref),
          ),

          // `F-149`. The readable one. Listed **second** and described by what
          // it is for rather than by what it lacks, because these are two
          // tools and not a full version and a lite version.
          ListTile(
            leading: const Icon(Icons.list_alt_rounded),
            title: const Text('Export a plain list'),
            subtitle: Text(
              count == 0
                  ? 'Nothing captured yet'
                  : 'One line per capture, newest first — readable anywhere',
              style: SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
            ),
            onTap: count == 0 ? null : () => _exportLines(context, ref),
          ),

          ListTile(
            leading: const Icon(Icons.upload_rounded),
            title: const Text('Restore a backup'),
            subtitle: Text(
              'Merges by capture id, so importing twice is safe',
              style: SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
            ),
            onTap: () => _import(context, ref),
          ),

          // `F-148`. Reachable **before** anything goes wrong.
          //
          // A recovery phrase that can only be found inside the export flow is
          // a recovery phrase people meet once, in a hurry, on the way to
          // doing something else. This row is the one that lets somebody go
          // and write it down properly on a quiet evening.
          ListTile(
            leading: const Icon(Icons.key_outlined),
            title: const Text('Your recovery phrase'),
            subtitle: Text(
              'The twelve words that open your backups. Nobody can reset them',
              style: SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showPhrase(context, ref),
          ),

          const Divider(height: SwipSpace.xxl),
          _header('Appearance'),

          // `F-155`. Three options, and the default follows the phone.
          //
          // Rendered as three rows rather than a switch because there are
          // three states and a switch can only carry two — and the third,
          // "match my phone", is the one most people want and the one a
          // two-state control has to hide.
          //
          // Plain `ListTile`s with a check rather than `RadioListTile`:
          // Material deprecated `groupValue`/`onChanged` in favour of a
          // `RadioGroup` ancestor after 3.32, and a check mark is the shape
          // every reference screenshot in the PDF uses for a chosen option
          // anyway.
          for (final choice in SwipThemeChoice.values)
            ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: SwipSpace.gutter),
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(themeSettingProvider.notifier).choose(choice);
              },
              title: Text(choice.label,
                  style:
                      SwipType.bodyL.copyWith(color: SwipColors.textPrimary)),
              subtitle: Text(
                choice.note,
                style:
                    SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
              ),
              trailing: ref.watch(themeSettingProvider) == choice
                  ? Icon(Icons.check_rounded,
                      size: 20, color: SwipColors.gold500)
                  : const SizedBox(width: 20),
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
            // `F-159`. The wizard the first time, the settings screen after.
            //
            // A switch was tried twice and reported broken twice — once
            // because it did nothing, once because it worked and the bubble
            // was invisible for a reason nothing on screen explained. Four
            // prerequisites and one counter-intuitive behaviour do not fit in
            // a subtitle, so the first run gets five screens.
            onTap: () => _openBubble(context),
          ),

          // `F-160`. Its own screen, and placed after the bubble rather
          // than among the privacy rows, because it is the only feature in
          // SWIP that contacts anything and it deserves to be found rather
          // than stumbled into.
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Merchant names'),
            subtitle: Text(
              'Resolve a shop\'s real name the way CRED does. Off until you '
              'add a key — this is the one thing SWIP sends off your phone',
              style: SwipType.bodyS.copyWith(color: SwipColors.textSecondary),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            // `F-181`. The walkthrough the first time, the settings screen
            // after — the same shape as the bubble row above, and for the same
            // reason. The owner could not tell from the settings screen what
            // the feature was for, and he commissioned it.
            onTap: () => _openLookup(context),
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
            leading: Icon(Icons.delete_outline_rounded,
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

  /// `F-159` — the wizard on first run, the settings screen afterwards.
  ///
  /// "Afterwards" is deliberately keyed on **having been through it**, not on
  /// the permission being granted. Somebody who ran the wizard and chose "Not
  /// now" has seen the explanation; dropping them back into five screens
  /// every time they open Settings would be nagging. The settings screen they
  /// land on instead has its own route back here.
  Future<void> _openBubble(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(BubbleWizard.seenKey) ?? false;
    if (!context.mounted) return;

    if (seen) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const BubbleSettingsPage(),
      ));
      return;
    }

    // Marked before the push rather than after. If it were written on the way
    // out, a user who backed out of the wizard with the system gesture would
    // meet it again on their next visit to Settings, forever.
    await prefs.setBool(BubbleWizard.seenKey, true);
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const BubbleWizard(),
    ));
  }

  /// `F-181`. Identical gating to [_openBubble], including the part that is
  /// easy to get wrong: the flag is written **before** the push, so somebody
  /// who backs out of the walkthrough with the system gesture does not meet it
  /// again on every future visit to Settings.
  Future<void> _openLookup(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(LookupWizard.seenKey) ?? false;
    if (!context.mounted) return;

    if (seen) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const LookupSettingsPage(),
      ));
      return;
    }

    await prefs.setBool(LookupWizard.seenKey, true);
    if (!context.mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const LookupWizard(),
    ));
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

    // `F-135`. Each row gets a `provenance` block: what was found, how it was
    // read, where you were, who the merchant is, and - when there is no
    // category - why not and what would find one. Derived at export time from
    // the payload already in the row, so it can never drift out of step with
    // the record it describes.
    //
    // Added **before** the seal on purpose: the narrative is part of what the
    // hash covers, so an edited story fails verification exactly like an edited
    // category would.
    final described = [
      for (final r in rows) {...r, 'provenance': ExportNarrative.of(r)},
    ];

    // `F-127`. Seal the rows before writing them: each record carries the hash
    // of the one before it, so a file edited anywhere fails verification from
    // that point on. See `ledger_seal.dart` for what this does and does not
    // claim.
    final sealed = LedgerSeal.seal(described);
    final sealHash = LedgerSeal.sealHashOf(sealed);

    // `F-128`. A serial that increases for the life of the install, so two
    // exports taken in the same second are still distinguishable and a folder
    // of backups sorts into the order they were actually taken.
    final serial = await _nextExportSerial();
    final now = DateTime.now();

    final payload = <String, Object?>{
      'format': 'swip.ledger',
      'version': 1,
      // A note to whoever opens this file in six months, including you.
      'readMe': 'Every capture below carries a `provenance` block: what was '
          'found, how it was read, where you were, and - when no category was '
          'published - why not. `sealHash` is a SHA-256 chain over the whole '
          'list; SWIP recomputes it on import and names the first record that '
          'does not match. It proves the file has not changed since export. It '
          'does not prove who made it.',
      'sealVersion': LedgerSeal.version,
      'sealHash': sealHash,
      'exportSerial': serial,
      'exportedAt': now.toUtc().toIso8601String(),
      'exportedAtLocal': _stamp(now),
      'captureCount': sealed.length,
      'captures': sealed,
    };

    // ── `F-147`. The phrase, and the screen that makes sure it is recorded ──
    //
    // This happens **before** anything is written. A backup sealed under a
    // phrase the user has never seen is a file nobody can ever open, and
    // producing one silently would be the worst bug this app could ship.
    final store = ref.read(recoveryPhraseStoreProvider);
    final phrase = await store.phrase();

    if (phrase == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'SWIP could not reach its settings store, so it cannot make a '
            'sealed backup safely. Try again in a moment.'),
      ));
      return;
    }

    if (!store.acknowledged) {
      if (!context.mounted) return;
      final done = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => RecoveryPhrasePage(phrase: phrase),
      ));
      // Backed out without recording the words. No file is written, because a
      // file they cannot open is worse than no file.
      if (done != true) return;
      await store.acknowledge();
    }

    final sealedFile = await BlackBox.seal(
      ledger: payload,
      phrase: phrase,
      captures: sealed.length,
      sealHash: sealHash,
      now: now.toUtc(),
    );

    final dir = await getTemporaryDirectory();
    // `F-128`. Readable at a glance in a Downloads folder six months from now:
    //     SWIP_Backup_2026-09-05_14-32-07_no-0007_142-captures.swipbox.json
    // Date and time are **local**, because the person reading the filename is
    // in a timezone, not in UTC. The UTC instant is inside the file.
    //
    // `.swipbox.json` keeps the `.json` so every file picker, mail client and
    // chat app still handles it as text — a novel extension is how an
    // attachment gets refused — while `.swipbox` says at a glance which of the
    // two exports this is.
    final name = 'SWIP_Backup_${_stamp(now)}'
        '_no-${serial.toString().padLeft(4, '0')}'
        '_${sealed.length}-captures.swipbox.json';
    final file = File('${dir.path}/$name');
    await file.writeAsString(sealedFile);

    if (!context.mounted) return;
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'SWIP encrypted backup $name',
      // Deliberately says nothing about what is inside. This text travels into
      // a chat window or an email subject line, where it is readable by
      // whatever is scanning that inbox — which is precisely what encrypting
      // the file was for.
      text: 'An encrypted SWIP backup - ${sealed.length} captures, export '
          'no. $serial, taken ${_stamp(now)}.\n'
          'It opens only with your twelve-word recovery phrase. Save it to '
          'Google Drive; without the phrase nobody can read it, including us.',
    );
  }

  /// `F-149` — the readable export.
  ///
  /// > *"Also, include a very simple line… in a rich text file format, with
  /// > the date in descending order."*
  ///
  /// Note what this file does **not** contain, because it is the reason it can
  /// be unencrypted while the backup cannot: no raw payloads, no payee
  /// handles, no geohashes, no terminal identifiers. Four columns, all of them
  /// things the user already knows about places they already went.
  Future<void> _exportLines(BuildContext context, WidgetRef ref) async {
    final db = await ref.read(databaseProvider.future);
    final rows = await db.exportRows();
    final events = [
      for (final r in rows) CaptureEvent.fromRow(r),
    ];

    final now = DateTime.now();
    final text = LedgerLines.render(events, now: now);

    final dir = await getTemporaryDirectory();
    final name = 'SWIP_List_${_stamp(now)}_${events.length}-captures.txt';
    final file = File('${dir.path}/$name');
    await file.writeAsString(text);

    if (!context.mounted) return;
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'SWIP - your captures',
      text: '${events.length} captures, newest first.',
    );
  }

  /// `F-148` — look the phrase up on a quiet evening rather than mid-export.
  Future<void> _showPhrase(BuildContext context, WidgetRef ref) async {
    final store = ref.read(recoveryPhraseStoreProvider);
    final phrase = await store.phrase();
    if (phrase == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('SWIP could not reach its settings store.'),
      ));
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => RecoveryPhrasePage(
        phrase: phrase,
        isFirstTime: !store.acknowledged,
      ),
    ));
    if (!store.acknowledged) await store.acknowledge();
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

  /// `F-147` — restore.
  ///
  /// ## The shape of this function is the promise
  ///
  /// > *"It should never, ever fail on import."*
  ///
  /// The old version was a `try` around `jsonDecode` with a `catch` that
  /// printed the exception: `Could not import: FormatException: Unexpected
  /// character (at character 1)`. That is a true sentence and a useless one —
  /// it does not tell the user whether they picked the wrong file, whether it
  /// arrived damaged, or whether SWIP is broken.
  ///
  /// So nothing here throws. [BlackBox.inspect] classifies the file without a
  /// key and hands back a sentence; [BlackBox.open] does the same for the
  /// decryption. Every branch below ends in something a person can act on.
  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final picked = await FilePicker.platform.pickFiles(
      // `F-147`. Not restricted to `.json` any more. A backup that has been
      // through Drive, a chat app and a download folder comes back with all
      // sorts of extensions — and a picker that will not show the user their
      // own file is its own kind of import failure.
      type: FileType.any,
    );
    final path = picked?.files.single.path;
    if (path == null) return;

    String text;
    try {
      text = await File(path).readAsString();
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('SWIP could not read that file. If it is on Drive or '
            'another cloud, download it to the phone first.'),
      ));
      return;
    }

    final reading = BlackBox.inspect(text);

    if (!reading.isImportable || reading.problem != null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(reading.problem ?? 'That is not a SWIP backup.'),
        duration: const Duration(seconds: 6),
      ));
      return;
    }

    // ── the phrase, if this file needs one ──
    //
    // Looped rather than one-shot: a mistyped word is the single most likely
    // thing to happen on this screen, and throwing the user back to the file
    // picker to start again for a typo would be gratuitous.
    var rows = <Map<String, dynamic>>[];
    ChainVerdict? chainVerdict;
    if (reading.needsPhrase) {
      final store = ref.read(recoveryPhraseStoreProvider);
      final onThisPhone = await store.phrase();
      String? problem;

      while (true) {
        if (!context.mounted) return;
        final entered = await showDialog<String>(
          context: context,
          builder: (_) => RecoveryPhrasePrompt(
            problem: problem,
            suggested: onThisPhone,
          ),
        );
        if (entered == null) return; // cancelled

        final opened =
            await BlackBox.open(reading: reading, phrase: entered);
        if (opened.ok) {
          rows = opened.rows;
          chainVerdict = opened.chain;
          break;
        }

        problem = opened.problem;
        // Only a wrong phrase is worth another go round the loop. A damaged
        // file will be just as damaged the second time, and asking again
        // would imply the user could fix it by typing harder.
        if (!opened.wrongPhrase) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(problem ?? 'That backup could not be opened.'),
            duration: const Duration(seconds: 6),
          ));
          return;
        }
      }
    } else {
      final opened = await BlackBox.open(reading: reading, phrase: '');
      rows = opened.rows;
      chainVerdict = opened.chain;
    }

    // ── `F-156`. The blockchain's verdict, before anything is written ──
    //
    // Not a refusal. These are the user's own records and a suspect record
    // beats no record — but the chain names the *block*, so the dialog can say
    // "block 3 of 12, everything before it is intact" rather than the useless
    // "this file may have been modified".
    if (chainVerdict != null && !chainVerdict.valid) {
      if (!context.mounted) return;
      final proceed = await _confirmBrokenChain(context, chainVerdict);
      if (proceed != true) return;
    }

    // ── `F-127`. The seal, checked before anything is written ──
    //
    // Independent of the encryption, and deliberately so: decrypting proves
    // the file came from somebody holding the phrase, and the chain proves the
    // rows have not been reordered or edited since export. A plain ledger from
    // before `F-147` carries a chain and no encryption; both are checked the
    // same way.
    final typed = [for (final r in rows) r.cast<String, Object?>()];
    final declared = reading.sealHash;
    final SealCheck? check = declared == null
        ? null
        : LedgerSeal.verify(typed, declaredSealHash: declared);

    if (check != null && !check.intact) {
      if (!context.mounted) return;
      // Not refused. The user's own backup is theirs, and a corrupted record
      // is still better than no record — but they are told plainly, and told
      // *where*, before it goes in.
      final proceed = await _confirmBrokenSeal(context, check);
      if (proceed != true) return;
    }

    try {
      final db = await ref.read(databaseProvider.future);
      final added = await db.importRows(typed);
      ref.read(ledgerRevisionProvider.notifier).state++;

      if (!context.mounted) return;
      final sealNote = chainVerdict != null
          ? (chainVerdict.valid
              ? ' · ${chainVerdict.blocks} blocks verified'
              : ' · chain did not verify')
          : check == null
              ? ''
              : check.intact
                  ? ' · seal verified'
                  : ' · seal did not match';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(added == 0
            ? 'Already up to date — nothing new in that file$sealNote'
            : 'Restored $added captures$sealNote'),
      ));
    } on Object {
      // `F-136` filters rows to real columns, so this should be unreachable.
      // It is here because "should be unreachable" is what was believed about
      // the import that would have thrown on the first new-format file.
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('SWIP opened that backup but could not write it to the '
            'ledger. Nothing was changed.'),
      ));
    }
  }

  /// `F-156`. The blockchain did not verify.
  ///
  /// Separate from [_confirmBrokenSeal] because it can say strictly more: the
  /// chain knows **which block** failed and therefore how much of the ledger
  /// is still provably untouched. "Everything before block 7 is intact" is a
  /// materially different message from "this file has changed".
  static Future<bool?> _confirmBrokenChain(
      BuildContext context, ChainVerdict verdict) {
    if (!context.mounted) return Future.value(false);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SwipColors.surfaceRaised,
        title: const Text('This backup has been changed'),
        content: Text(
          '${verdict.summary}\n\n'
          'The blockchain in this file did not check out. Usually that means '
          'something rewrote the file in transit — a cloud sync, or a chat '
          'app. The captures can still be imported; SWIP is telling you '
          'first rather than afterwards.',
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
                      WidgetSpan(
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
