import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../onboarding/primers.dart';

/// `F-40` — where a capture happened.
///
/// ## The privacy shape, which is the whole design
///
/// A ledger of every shop you have paid at, with coordinates, is one of the
/// more sensitive files a person can own — and SWIP's ledger is *exported to
/// the user's own Drive*, so it travels. Three rules follow, and they are not
/// negotiable inside this file:
///
///  1. **Off by default.** The permission is requested at the moment the user
///     turns it on in Settings, not at first run. An app that asks for location
///     before it has shown you anything useful gets denied for ever.
///  2. **Coarse only.** The manifest requests `ACCESS_COARSE_LOCATION` and
///     nothing else.
///  3. **The raw fix never reaches storage.** It is reduced to a 6-character
///     geohash — a cell roughly 1.2 km × 0.6 km — before anything is written.
///     That is enough to say *"this shop, this neighbourhood"* and to key the
///     merchant graph, and not enough to say which building.
///
/// The human-readable label ("Bandra, IN") is a separate, best-effort lookup.
/// It fails silently offline, which is correct: a missing label is a cosmetic
/// loss, and blocking a capture on a network call at a checkout counter would
/// be a real one.
class CaptureLocation {
  const CaptureLocation({required this.geohash, this.label, this.countryCode});

  /// 6 characters, ~1.2 km × 0.6 km.
  final String geohash;

  /// "Bandra, IN". Null when the lookup failed or was offline.
  final String? label;

  /// ISO 3166-1 alpha-2 as reported by the device's position. Distinct from the
  /// country in the payload — this is where *you* were, and when the two
  /// disagree the payload is describing the merchant's registration while this
  /// describes the counter you are standing at.
  final String? countryCode;
}

/// Reads the opt-in flag and, when it is on, produces a coarse fix.
class LocationService {
  LocationService(this._prefs);
  final SharedPreferences _prefs;

  static const _kEnabled = 'location_enabled';

  bool get isEnabled => _prefs.getBool(_kEnabled) ?? false;

  /// Turn the feature on, asking for the permission as part of the same
  /// gesture. Returns whether it actually ended up on — the user can still
  /// refuse at the system prompt, and the toggle must reflect reality rather
  /// than what we asked for.
  Future<bool> enable() async {
    final granted = await _ensurePermission();
    await _prefs.setBool(_kEnabled, granted);
    return granted;
  }

  Future<void> disable() async => _prefs.setBool(_kEnabled, false);

  /// A fix for one capture, or null.
  ///
  /// Null is an ordinary outcome — feature off, permission refused, location
  /// services disabled, indoors with no fix inside the timeout — and every
  /// caller treats it as "no location", never as an error worth interrupting a
  /// capture for.
  Future<CaptureLocation?> current() async {
    if (!isEnabled) return null;

    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      // Low accuracy on purpose — it matches what is stored, and it returns
      // far faster and on far less battery than a GPS lock the result would
      // only throw away.
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final hash = Geohash.encode(position.latitude, position.longitude);
      final place = await _describe(position.latitude, position.longitude);

      return CaptureLocation(
        geohash: hash,
        label: place?.$1,
        countryCode: place?.$2,
      );
    } catch (_) {
      // Timeout, no provider, a platform quirk. A capture must never fail
      // because of where it happened.
      return null;
    }
  }

  /// Best-effort reverse geocode. Returns (label, ISO country) or null.
  Future<(String, String?)?> _describe(double lat, double lon) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lon);
      if (marks.isEmpty) return null;
      final m = marks.first;

      final area = [m.subLocality, m.locality, m.administrativeArea]
          .where((s) => s != null && s.trim().isNotEmpty)
          .cast<String>()
          .toList();
      final country = m.isoCountryCode?.trim().toUpperCase();

      if (area.isEmpty && country == null) return null;
      final label = [if (area.isNotEmpty) area.first, if (country != null) country]
          .join(', ');
      return (label, country);
    } catch (_) {
      return null; // Offline, or no geocoder on the device. Cosmetic.
    }
  }

  Future<bool> _ensurePermission() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (_) {
      return false;
    }
  }
}

/// Geohash encoding, base-32, as described by Gustavo Niemeyer's original
/// scheme.
///
/// Hand-written rather than a dependency: it is thirty lines, it has no
/// platform surface, and the alternative is another package in the supply
/// chain of an app whose entire pitch is that it does not send your spending
/// anywhere.
abstract final class Geohash {
  static const _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Default precision 6 — about 1.2 km × 0.6 km. See the class doc on
  /// [CaptureLocation] for why this number and not a finer one.
  static String encode(double latitude, double longitude,
      {int precision = 6}) {
    var latMin = -90.0, latMax = 90.0;
    var lonMin = -180.0, lonMax = 180.0;

    final out = StringBuffer();
    var isLon = true;
    var bit = 0;
    var index = 0;

    while (out.length < precision) {
      if (isLon) {
        final mid = (lonMin + lonMax) / 2;
        if (longitude > mid) {
          index = index * 2 + 1;
          lonMin = mid;
        } else {
          index *= 2;
          lonMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (latitude > mid) {
          index = index * 2 + 1;
          latMin = mid;
        } else {
          index *= 2;
          latMax = mid;
        }
      }

      isLon = !isLon;
      if (++bit == 5) {
        out.write(_base32[index]);
        bit = 0;
        index = 0;
      }
    }

    return out.toString();
  }
}

final locationServiceProvider = FutureProvider<LocationService>((ref) async {
  return LocationService(await ref.watch(sharedPrefsProvider.future));
});

/// Bumped when the toggle changes so Settings re-reads it.
final locationRevisionProvider = StateProvider<int>((ref) => 0);

final locationEnabledProvider = FutureProvider<bool>((ref) async {
  ref.watch(locationRevisionProvider);
  final service = await ref.watch(locationServiceProvider.future);
  return service.isEnabled;
});
