import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../onboarding/primers.dart';

/// Where the user lives, and therefore what counts as "abroad" — `F-14`,
/// `F-15`, `F-16`.
///
/// Domestic vs international is not a property of a card or a merchant on its
/// own: it is a *comparison*. A 5411 in Mumbai and a 5411 in Lisbon earn
/// differently on the same card, and the only way to tell them apart is to know
/// where home is. Onboarding asks once, Settings can change it, and every
/// capture is then judged against it.
///
/// Deliberately **not** derived from the SIM or the locale. A traveller with an
/// Indian card and a Portuguese SIM would be told every purchase at home is
/// international. Asking is one screen and is right every time.
class HomeMarket {
  const HomeMarket({required this.countryCode, required this.currency});

  /// ISO 3166-1 alpha-2, upper case. `IN`.
  final String countryCode;

  /// ISO 4217 alpha, upper case. `INR`.
  final String currency;

  Country? get country => Countries.byCode(countryCode);
  String get displayName => country?.name ?? countryCode;
  String get flag => country?.flag ?? '🏳️';

  static const fallback = HomeMarket(countryCode: 'IN', currency: 'INR');

  /// The verdict for one capture. `null` when nothing said where it happened,
  /// which is common and must not be rendered as "domestic" by default —
  /// assuming home is how a foreign transaction fee arrives as a surprise.
  ///
  /// [deviceCountry] wins when both are present. `F-14` asks for a comparison
  /// against *where you are now*, and the two genuinely differ: a QR issued to
  /// a merchant registered in Singapore, scanned by you in Mumbai, carries
  /// `SG` in its payload while you are standing in India.
  MarketVerdict? verdictFor(String? captureCountry, {String? deviceCountry}) {
    final c = (_clean(deviceCountry) ?? _clean(captureCountry));
    if (c == null) return null;
    return c == countryCode
        ? MarketVerdict.domestic
        : MarketVerdict.international;
  }

  static String? _clean(String? v) {
    final c = v?.trim().toUpperCase();
    if (c == null || c.length != 2 || c == 'XX') return null;
    return c;
  }

  @override
  bool operator ==(Object other) =>
      other is HomeMarket &&
      other.countryCode == countryCode &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(countryCode, currency);
}

enum MarketVerdict {
  domestic('Domestic'),
  international('International');

  const MarketVerdict(this.label);
  final String label;

  bool get isInternational => this == MarketVerdict.international;
}

/// One country, its currency, and a flag that renders without an asset.
class Country {
  const Country(this.code, this.name, this.currency);

  final String code;
  final String name;
  final String currency;

  /// Regional-indicator pair. Works on every modern Android and iOS without
  /// shipping 200 images.
  String get flag {
    if (code.length != 2) return '🏳️';
    const base = 0x1F1E6;
    final a = code.codeUnitAt(0) - 0x41 + base;
    final b = code.codeUnitAt(1) - 0x41 + base;
    return String.fromCharCodes([a, b]);
  }
}

/// The countries SWIP offers at onboarding.
///
/// Not every country on earth — the list is searchable and covers every market
/// with a national QR scheme SWIP can read, plus the large card markets. An
/// unlisted country is still capturable; it just is not a pickable *home*, and
/// the search box takes a two-letter code for anyone in one.
abstract final class Countries {
  static const all = <Country>[
    Country('IN', 'India', 'INR'),
    Country('AE', 'United Arab Emirates', 'AED'),
    Country('AU', 'Australia', 'AUD'),
    Country('BD', 'Bangladesh', 'BDT'),
    Country('BR', 'Brazil', 'BRL'),
    Country('CA', 'Canada', 'CAD'),
    Country('CH', 'Switzerland', 'CHF'),
    Country('CN', 'China', 'CNY'),
    Country('DE', 'Germany', 'EUR'),
    Country('EG', 'Egypt', 'EGP'),
    Country('ES', 'Spain', 'EUR'),
    Country('FR', 'France', 'EUR'),
    Country('GB', 'United Kingdom', 'GBP'),
    Country('HK', 'Hong Kong', 'HKD'),
    Country('ID', 'Indonesia', 'IDR'),
    Country('IE', 'Ireland', 'EUR'),
    Country('IT', 'Italy', 'EUR'),
    Country('JP', 'Japan', 'JPY'),
    Country('KE', 'Kenya', 'KES'),
    Country('KR', 'South Korea', 'KRW'),
    Country('LK', 'Sri Lanka', 'LKR'),
    Country('MY', 'Malaysia', 'MYR'),
    Country('MX', 'Mexico', 'MXN'),
    Country('NG', 'Nigeria', 'NGN'),
    Country('NL', 'Netherlands', 'EUR'),
    Country('NP', 'Nepal', 'NPR'),
    Country('NZ', 'New Zealand', 'NZD'),
    Country('PH', 'Philippines', 'PHP'),
    Country('PK', 'Pakistan', 'PKR'),
    Country('PT', 'Portugal', 'EUR'),
    Country('QA', 'Qatar', 'QAR'),
    Country('SA', 'Saudi Arabia', 'SAR'),
    Country('SE', 'Sweden', 'SEK'),
    Country('SG', 'Singapore', 'SGD'),
    Country('TH', 'Thailand', 'THB'),
    Country('TR', 'Türkiye', 'TRY'),
    Country('US', 'United States', 'USD'),
    Country('VN', 'Vietnam', 'VND'),
    Country('ZA', 'South Africa', 'ZAR'),
  ];

  static Country? byCode(String? code) {
    final c = code?.trim().toUpperCase();
    if (c == null || c.length != 2) return null;
    for (final country in all) {
      if (country.code == c) return country;
    }
    return null;
  }

  static List<Country> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.code.toLowerCase() == q ||
            c.currency.toLowerCase() == q)
        .toList();
  }
}

/// Reads and writes the home market, plus the one flag that says whether
/// onboarding has ever been completed.
class HomeMarketService {
  HomeMarketService(this._prefs);
  final SharedPreferences _prefs;

  static const _kCountry = 'home_country';
  static const _kCurrency = 'home_currency';

  /// `null` until the user has chosen. `null` is what triggers onboarding, so
  /// it must not be conflated with the India default.
  HomeMarket? get value {
    final c = _prefs.getString(_kCountry);
    final cur = _prefs.getString(_kCurrency);
    if (c == null || cur == null) return null;
    return HomeMarket(countryCode: c, currency: cur);
  }

  /// What to compare against right now. Falls back to India rather than
  /// refusing to render — a wrong flag is recoverable, a blank screen is not.
  HomeMarket get effective => value ?? HomeMarket.fallback;

  bool get isSet => value != null;

  Future<void> set(HomeMarket market) async {
    await _prefs.setString(_kCountry, market.countryCode);
    await _prefs.setString(_kCurrency, market.currency);
  }

  Future<void> clear() async {
    await _prefs.remove(_kCountry);
    await _prefs.remove(_kCurrency);
  }
}

final homeMarketServiceProvider = FutureProvider<HomeMarketService>((ref) async {
  return HomeMarketService(await ref.watch(sharedPrefsProvider.future));
});

/// Bumped when the home market changes so every screen re-reads it.
final homeMarketRevisionProvider = StateProvider<int>((ref) => 0);

final homeMarketProvider = FutureProvider<HomeMarket>((ref) async {
  ref.watch(homeMarketRevisionProvider);
  final service = await ref.watch(homeMarketServiceProvider.future);
  return service.effective;
});

/// Whether onboarding still needs to run.
final needsHomeMarketProvider = FutureProvider<bool>((ref) async {
  ref.watch(homeMarketRevisionProvider);
  final service = await ref.watch(homeMarketServiceProvider.future);
  return !service.isSet;
});
