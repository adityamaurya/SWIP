import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The one `SharedPreferences` provider.
///
/// It lives here rather than next to its first consumer because two features
/// now need the same instance — the raw-data entitlement (`F-146`) and the
/// backup recovery phrase (`F-148`) — and a second `FutureProvider` wrapping
/// `SharedPreferences.getInstance()` would not be a second *instance* (the
/// plugin returns a singleton) but it would be a second cache, a second load
/// state, and two places for a future third consumer to pick the wrong one
/// from.
final sharedPreferencesProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
);
