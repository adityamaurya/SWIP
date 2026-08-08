import 'package:flutter/foundation.dart';

/// Where a merchant category code definition is published.
///
/// Directly implements ideation `D-05`: you asked ledger column 2 to say whether
/// a code is published nationally, internationally, or by RuPay. That is the
/// right distinction and it is a real one — the same four digits can be defined
/// by ISO 18245, redefined by a card network, and treated differently again by
/// a domestic scheme. A code therefore carries a *set* of publications, not one.
enum MccPublication {
  /// The domestic scheme's list (NPCI / RuPay for India).
  national('NATIONAL'),

  /// ISO 18245 / Visa / Mastercard international lists.
  international('INTL'),

  /// Explicitly published by RuPay, possibly with a differing definition.
  rupay('RUPAY');

  const MccPublication(this.label);
  final String label;
}

/// How much SWIP trusts an MCC value.
///
/// Every MCC displayed anywhere in the app carries one of these. A number shown
/// with unearned certainty is a defect in a finance app.
enum MccConfidence {
  /// Captured live from the payload or the terminal this session, or agreed by
  /// five or more independent captures.
  verified,

  /// Inferred — a heuristic, or a single unconfirmed report.
  likely,

  /// No data. Say so plainly; never guess and hope.
  unknown,

  /// Sources disagree. Show every value, never silently pick one.
  conflict;

  bool get isTrustworthy => this == MccConfidence.verified;
}

/// The ISO 18245 top-level range a code falls in.
enum MccRange {
  agricultural(1, 1499, 'Agricultural services'),
  contracted(1500, 2999, 'Contracted services'),
  transportation(4000, 4799, 'Transportation services'),
  utility(4800, 4999, 'Utility services'),
  retail(5000, 5599, 'Retail outlet services'),
  clothing(5600, 5699, 'Clothing shops'),
  miscellaneous(5700, 7299, 'Miscellaneous shops & services'),
  business(7300, 7999, 'Business services'),
  professional(8000, 8999, 'Professional services & membership'),
  government(9000, 9999, 'Government services');

  const MccRange(this.start, this.end, this.label);
  final int start;
  final int end;
  final String label;

  static MccRange? forCode(String code) {
    final n = int.tryParse(code);
    if (n == null) return null;
    for (final r in MccRange.values) {
      if (n >= r.start && n <= r.end) return r;
    }
    return null; // 3000–3999 is the airline/hotel private-assignment block.
  }
}

/// One definition of a code by one publisher.
@immutable
class MccDefinition {
  const MccDefinition({
    required this.publication,
    required this.name,
    this.description,
  });

  final MccPublication publication;
  final String name;
  final String? description;

  factory MccDefinition.fromJson(Map<String, dynamic> j) => MccDefinition(
        publication: MccPublication.values.byName(j['publication'] as String),
        name: j['name'] as String,
        description: j['description'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'publication': publication.name,
        'name': name,
        if (description != null) 'description': description,
      };
}

/// A merchant category code and everything SWIP knows about it.
@immutable
class Mcc {
  const Mcc({required this.code, required this.definitions});

  /// Four digits. Kept as a string throughout — leading zeros are significant
  /// (`0742`, Veterinary Services) and an int would silently eat them.
  final String code;

  final List<MccDefinition> definitions;

  /// The name to show in a single line. Prefers the domestic definition,
  /// because the user is standing in their own country.
  String get displayName {
    if (definitions.isEmpty) return 'Unknown category';
    for (final p in [
      MccPublication.national,
      MccPublication.international,
      MccPublication.rupay,
    ]) {
      final d = definitions.where((d) => d.publication == p);
      if (d.isNotEmpty) return d.first.name;
    }
    return definitions.first.name;
  }

  Set<MccPublication> get publications =>
      definitions.map((d) => d.publication).toSet();

  MccRange? get range => MccRange.forCode(code);

  /// True when publishers give this code materially different names.
  ///
  /// When this is set the UI must show every definition side by side under a
  /// `conflict` header. Silently choosing one would be the single most damaging
  /// thing this app could do — it is the exact failure the product exists to fix.
  bool get hasConflict {
    if (definitions.length < 2) return false;
    final normalised = definitions
        .map((d) => d.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''))
        .toSet();
    return normalised.length > 1;
  }

  /// `0000` — explicitly unclassified, typically a personal handle.
  bool get isUnclassified => code == '0000';

  factory Mcc.fromJson(Map<String, dynamic> j) => Mcc(
        code: j['code'] as String,
        definitions: (j['definitions'] as List<dynamic>)
            .map((e) => MccDefinition.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
        'code': code,
        'definitions': definitions.map((d) => d.toJson()).toList(),
      };

  /// Placeholder for a code that parsed cleanly but is not in the table.
  /// Deliberately not an error: the code is real, we just lack a definition,
  /// and the honest answer is to show the digits and the ISO range.
  factory Mcc.unknown(String code) => Mcc(
        code: code,
        definitions: [
          MccDefinition(
            publication: MccPublication.international,
            name: MccRange.forCode(code)?.label ?? 'Unknown category',
          ),
        ],
      );

  @override
  bool operator ==(Object other) => other is Mcc && other.code == code;

  @override
  int get hashCode => code.hashCode;
}
