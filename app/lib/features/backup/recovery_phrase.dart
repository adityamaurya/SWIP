/// `F-148` — where the recovery phrase lives, and the edge case it exists for.
///
/// > *"You need to figure out a way where, in an edge case, if he uninstalls
/// > and the key resets for the user, he could have maybe a phrase to get it
/// > unlocked."*
///
/// That edge case is the whole design problem, and it is worth stating
/// precisely because it rules out the obvious answer.
///
/// ## Why the key cannot simply live on the device
///
/// The obvious design is a random key in `SharedPreferences` or the Android
/// Keystore, used to encrypt every backup. It is also useless, for exactly the
/// scenario the owner named: **uninstalling the app destroys that key**, and
/// with it every backup ever made. The user would be holding a folder of files
/// that nothing on earth can open — which is worse than no encryption at all,
/// because they would have believed they had a backup.
///
/// Android's `allowBackup` and Keystore both make this worse rather than
/// better: Keystore keys are explicitly non-exportable and are destroyed on
/// uninstall, by design.
///
/// So the key is derived from something the **user** holds, not something the
/// device holds. The phrase below is that thing. It is generated once, stored
/// here for convenience, and **shown to the user with an instruction to write
/// it down**, because this copy is the one that disappears on uninstall and
/// theirs is the one that does not.
///
/// ## Why one phrase rather than one per backup
///
/// A fresh phrase per export would be marginally safer and completely
/// unusable: twelve words to record every single time, and a folder of
/// backups where the user has to remember which phrase goes with which file.
/// One phrase per install, written down once, opens every backup that install
/// ever made. The salt in each file's header still differs, so two backups
/// never share a key — see `black_box.dart`.
///
/// ## What this store is not
///
/// It is **not** a security boundary. Anything that can read this app's
/// preferences can read the phrase, and could equally read the SQLite ledger
/// directly. It is a convenience so the user is not retyping twelve words on
/// every export. The security boundary is the file that leaves the phone, and
/// that one is only as safe as the copy the user wrote down.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/settings/prefs.dart';
import '../../data/sources/black_box.dart';

const _kPhraseKey = 'swip.backup.recoveryPhrase';

/// Whether the user has confirmed they wrote the phrase down.
///
/// Tracked separately from the phrase itself so the "write this down" screen
/// can be shown again on the next export if they backed out of it — a phrase
/// that exists but has never been seen is the same as no phrase at all, and
/// silently letting the first backup complete would hide that.
const _kAcknowledgedKey = 'swip.backup.phraseAcknowledged';

class RecoveryPhraseStore {
  const RecoveryPhraseStore(this._prefs);

  final SharedPreferences? _prefs;

  bool get isReady => _prefs != null;

  /// The phrase for this install, creating one the first time.
  ///
  /// Returns null only when preferences are unavailable, in which case the
  /// caller must not proceed with an encrypted export — a backup sealed under
  /// a phrase that was never persisted and never shown is unopenable.
  Future<String?> phrase() async {
    final p = _prefs;
    if (p == null) return null;

    final existing = p.getString(_kPhraseKey);
    if (existing != null && BlackBox.isValidPhrase(existing)) return existing;

    final fresh = BlackBox.newRecoveryPhrase();
    await p.setString(_kPhraseKey, fresh);
    // A newly minted phrase has by definition not been written down.
    await p.setBool(_kAcknowledgedKey, false);
    return fresh;
  }

  /// Whether the user has seen the phrase and said they recorded it.
  bool get acknowledged => _prefs?.getBool(_kAcknowledgedKey) ?? false;

  Future<void> acknowledge() async =>
      _prefs?.setBool(_kAcknowledgedKey, true);

  /// Replace the phrase.
  ///
  /// **Every existing backup stops being openable by the app's stored copy.**
  /// Old files still open with the old phrase — the key is derived from the
  /// phrase and the file's own salt, so nothing about an existing file
  /// changes — but the user has to still have those words. The UI says this in
  /// full before calling it.
  Future<String?> regenerate() async {
    final p = _prefs;
    if (p == null) return null;
    final fresh = BlackBox.newRecoveryPhrase();
    await p.setString(_kPhraseKey, fresh);
    await p.setBool(_kAcknowledgedKey, false);
    return fresh;
  }
}

final recoveryPhraseStoreProvider = Provider<RecoveryPhraseStore>(
  (ref) => RecoveryPhraseStore(
    ref.watch(sharedPreferencesProvider).valueOrNull,
  ),
);
