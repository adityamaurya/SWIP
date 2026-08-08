import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/mcc.dart';

/// The bundled MCC table.
///
/// Ships **inside the binary**, not fetched. Ideation `C-02`: the user scans
/// "anywhere in the world", which includes on a plane, on roaming, and in the
/// basement of a mall with no signal. A lookup product that needs the network
/// to answer a lookup is not a lookup product.
///
/// Assembled from ISO 18245:2023 ranges plus the network and domestic lists.
/// Regenerate with `dart run tool/build_mcc_table.dart` — see
/// docs/09-BUILD-AND-RUN.md.
class MccTable {
  MccTable._(this._byCode);

  final Map<String, Mcc> _byCode;

  static MccTable? _cached;

  static Future<MccTable> load() async {
    if (_cached != null) return _cached!;
    final raw = await rootBundle.loadString('assets/mcc/mcc_table.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final codes = (json['codes'] as List<dynamic>)
        .map((e) => Mcc.fromJson(e as Map<String, dynamic>));
    return _cached = MccTable._({for (final m in codes) m.code: m});
  }

  /// Resolves a four-digit code.
  ///
  /// A code that is well-formed but absent from the table returns
  /// [Mcc.unknown] rather than `null` — the digits are real, we simply lack a
  /// definition, and the honest answer is to show the code and its ISO range
  /// rather than an error. Malformed input returns `null`.
  Mcc? lookup(String code) {
    final c = code.trim();
    if (c.length != 4 || int.tryParse(c) == null) return null;
    return _byCode[c] ?? Mcc.unknown(c);
  }

  /// Free-text search over code and every publication's name. Used by S-09.
  List<Mcc> search(String query, {int limit = 50}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    // A numeric query is almost always someone typing a code they saw.
    if (int.tryParse(q) != null) {
      return _byCode.entries
          .where((e) => e.key.startsWith(q))
          .map((e) => e.value)
          .take(limit)
          .toList();
    }

    final hits = <Mcc>[];
    for (final m in _byCode.values) {
      if (m.definitions.any((d) => d.name.toLowerCase().contains(q))) {
        hits.add(m);
        if (hits.length >= limit) break;
      }
    }
    return hits;
  }

  Iterable<Mcc> inRange(MccRange range) => _byCode.values
      .where((m) => m.range == range)
      .toList()
    ..sort((a, b) => a.code.compareTo(b.code));

  int get size => _byCode.length;
}
