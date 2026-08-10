/// `F-50`, and the answer to `F-48`. Reading the MCC out of a bank statement.
///
/// ## The line that changed the product
///
/// A Federal Bank statement narration for a ₹1 UPI payment to Snowberry:
///
/// ```
/// UPIOUT/658724829452/paytm.s233ffl@pty/Demo/5451
///   │         │              │           │     └── the MCC
///   │         │              │           └──────── the note you typed
///   │         │              └──────────────────── the payee VPA
///   │         └─────────────────────────────────── the UPI RRN
///   └───────────────────────────────────────────── outward UPI
/// ```
///
/// `5451` is Dairy Products Stores. Snowberry sells ice cream. It is correct.
///
/// **The MCC is not the important part of that line — the VPA next to it is.**
/// A category on its own is a fact about a payment. A category *paired with the
/// handle that was paid* is a fact about a **merchant**, and that is what the
/// merchant graph eats. It means SWIP never has to ask "which shop was this?":
/// the statement already says, in a form that matches the key a QR scan
/// produces exactly.
///
/// So one statement import teaches SWIP the true category of every UPI merchant
/// you have paid — and from then on their stickers answer the instant you point
/// a camera at them, including the Paytm ones that carry no `mc` at all.
///
/// No PSP membership, no permission, no network. Just text you already own.
///
/// ## Why this is deliberately format-tolerant
///
/// Indian banks write narrations differently and change them without notice.
/// Rather than a table of per-bank regexes that rots, this tokenises the line
/// and identifies each field **by shape**:
///
///   * a VPA looks like `something@handle`
///   * an RRN is exactly 12 digits
///   * an MCC is exactly 4 digits, and — the part that removes the ambiguity —
///     resolves to a real category in the offline table
///
/// A four-digit transaction note would otherwise be indistinguishable from a
/// category. Validating against the table is what makes this safe, and it is
/// why [parse] takes a validator rather than guessing.
library;

/// One narration, decoded.
class StatementEntry {
  const StatementEntry({
    required this.raw,
    this.vpa,
    this.mcc,
    this.rrn,
    this.note,
  });

  /// The line exactly as it appeared, kept so the user can check SWIP's working.
  final String raw;

  /// The payee handle — `paytm.s233ffl@pty`. Lower-cased, so it matches the
  /// merchant key a QR capture produces.
  final String? vpa;

  /// The four digits.
  final String? mcc;

  /// UPI Retrieval Reference Number, 12 digits. Not used for matching; kept so
  /// a user querying their bank has the reference to quote.
  final String? rrn;

  final String? note;

  /// Only a line with **both** halves teaches anything. A category with no
  /// merchant is trivia; a merchant with no category is what we already had.
  bool get isUsable => vpa != null && mcc != null;

  /// The merchant-graph key. Identical in form to what [CaptureResolver]
  /// produces for a UPI QR, which is the entire point — a statement line and a
  /// scan of the same shop's sticker must land on the same row.
  String? get merchantKey => vpa == null ? null : 'upi:$vpa';

  @override
  String toString() => 'StatementEntry($vpa → $mcc)';
}

abstract final class StatementParser {
  static final _vpa = RegExp(r'^[a-z0-9][a-z0-9._-]{1,60}@[a-z][a-z0-9.]{1,20}$');
  static final _digits = RegExp(r'^\d+$');

  /// Split on the separators Indian banks actually use. `/` dominates, but
  /// statements exported to CSV arrive comma- or tab-separated, and some banks
  /// use `-` between fields.
  static final _separators = RegExp(r'[\/|,\t]+');

  /// Decode one narration line.
  ///
  /// [isKnownMcc] decides whether a four-digit token is a category. Pass the
  /// offline MCC table's lookup. Without it, any four-digit note would be
  /// accepted as a category — which is exactly the kind of confident wrongness
  /// this app exists to remove.
  static StatementEntry parse(
    String line, {
    required bool Function(String) isKnownMcc,
  }) {
    final raw = line.trim();

    String? vpa;
    String? rrn;
    String? mcc;
    final plain = <String>[];

    // Two levels, and the nesting is the point.
    //
    // A real statement row is columnar — a date, the narration, a type, an
    // amount, a balance — and only the *narration* is slash-structured:
    //
    //   09/08/2026  UPIOUT/658724829452/paytm.s233ffl@pty/Demo/5451  TFR  1.00
    //
    // Splitting on whitespace alone destroys the slash structure; splitting on
    // slashes alone leaves "5451 TFR 1.00" as one token and the category is
    // never found. So: segment on the separators, then read words inside each
    // segment.
    for (final segment in raw.split(_separators)) {
      final words = [
        for (final w in segment.trim().split(RegExp(r'\s+')))
          if (w.isNotEmpty) w,
      ];
      if (words.isEmpty) continue;

      for (var i = 0; i < words.length; i++) {
        final word = words[i];
        final lower = word.toLowerCase();

        if (vpa == null && _vpa.hasMatch(lower)) {
          vpa = lower;
          continue;
        }
        if (rrn == null && word.length == 12 && _digits.hasMatch(word)) {
          rrn = word;
          continue;
        }

        // The category is **the first word of its own segment**, never a word
        // trailing inside one. That restriction is what stops an amount
        // printed without decimals — "TFR 5451" — being adopted as a category,
        // and it costs nothing: the MCC genuinely is its own slash-delimited
        // field in every narration that carries it.
        if (i == 0 &&
            word.length == 4 &&
            _digits.hasMatch(word) &&
            isKnownMcc(word)) {
          mcc = word;
          continue;
        }

        plain.add(word);
      }
    }

    // The note is whatever text is left that is not a bank's own marker.
    final note = plain
        .where((t) => !_markers.contains(t.toUpperCase()))
        .where((t) => !_digits.hasMatch(t))
        .join(' ')
        .trim();

    return StatementEntry(
      raw: raw,
      vpa: vpa,
      mcc: mcc,
      rrn: rrn,
      note: note.isEmpty ? null : note,
    );
  }

  /// Decode a whole pasted statement — or the two lines someone selected in a
  /// PDF viewer. Returns only the lines that teach something, de-duplicated by
  /// merchant so one import cannot inflate the graph's agreement count.
  static List<StatementEntry> parseAll(
    String text, {
    required bool Function(String) isKnownMcc,
  }) {
    final seen = <String, StatementEntry>{};

    for (final line in text.split(RegExp(r'[\r\n]+'))) {
      if (line.trim().isEmpty) continue;
      final entry = parse(line, isKnownMcc: isKnownMcc);
      if (!entry.isUsable) continue;

      // A shop paid twice in one statement is one lesson, not two. Later lines
      // win: a merchant's category genuinely can change, and the newer line is
      // further down the page.
      seen[entry.merchantKey!] = entry;
    }

    return seen.values.toList();
  }

  /// Bank markers that are never the note.
  static const _markers = {
    'UPIOUT', 'UPIIN', 'UPI', 'TFR', 'DR', 'CR', 'P2M', 'P2A', 'P2P',
    'NEFT', 'IMPS', 'RTGS', 'POS', 'ACH', 'PAYMENT', 'TRANSFER', 'TO',
    'FROM', 'BY', 'REF', 'TXN',
  };
}
