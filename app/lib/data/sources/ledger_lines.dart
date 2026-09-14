/// `F-149` — **the plain export: one capture, one line, newest first.**
///
/// > *"Also, include a very simple line… in a rich text file format, with the
/// > date in descending order… 1. MCC 2. the name of the merchant, exactly
/// > captured 3. [amount] if captured, and fourth would be the date."*
///
/// ## Why this exists next to the black box
///
/// [BlackBox] is for SWIP: encrypted, complete, and worthless to a human with
/// a text editor. That is the right shape for a backup and the wrong shape for
/// every other reason somebody wants their data — pasting a month into a
/// message, checking a figure against a card statement, or simply looking at
/// what they have.
///
/// So there are two exports and they are not competing. One is for the app to
/// read and nobody else; this one is for a person to read and no app. Neither
/// is behind the `F-146` paywall, because both are the user's own records.
///
/// ## "Exactly captured" — the part that needed a decision
///
/// The column asked for is *the name of the merchant, exactly captured*, and
/// SWIP's stored `merchant_name` is deliberately **not** that. It is the
/// cleaned name: `F-42` drops `pn=Paytm` because Paytm is the payment company
/// rather than the shop, and `F-139` drops `pn=SVCMERC00306934` because a
/// merchant reference number is not a name. Both of those are right on a
/// capture screen, where a wrong name is worse than none.
///
/// An export is a different job. So this file goes back to the **raw payload**
/// and pulls out the verbatim `pn=` that the QR actually carried, which is
/// what "exactly captured" means and what makes a line checkable against the
/// sticker on the counter. Where the two differ, both are shown — the verbatim
/// name in the column, and SWIP's reading beside it in brackets. Neither is
/// hidden, because the difference between them is the single most common
/// question this ledger produces.
library;

import '../models/capture_event.dart';

/// One line of the plain export.
class LedgerLine {
  const LedgerLine({
    required this.mcc,
    required this.merchant,
    required this.amount,
    required this.date,
    this.swipReading,
  });

  /// Four digits, or null. Rendered as `—`, never as a blank or a dash that
  /// could be mistaken for a minus sign next to an amount.
  final String? mcc;

  /// The name exactly as the code carried it.
  final String? merchant;

  /// With its currency symbol where one is known.
  final String? amount;

  final DateTime date;

  /// SWIP's own reading, when it differs from [merchant]. Null when they
  /// agree, which is most of the time.
  final String? swipReading;
}

abstract final class LedgerLines {
  /// `—`, an em dash. Deliberately not `-`: in an amount column a hyphen reads
  /// as a negative number, and this file is going to be read next to a card
  /// statement.
  static const _none = '—';

  /// Build the lines, newest first.
  static List<LedgerLine> of(List<CaptureEvent> events) {
    final sorted = [...events]
      ..sort((a, b) => b.capturedAt.compareTo(a.capturedAt));

    return [
      for (final e in sorted)
        LedgerLine(
          mcc: e.mcc,
          merchant: capturedName(e),
          amount: _amount(e),
          date: e.capturedAt,
          swipReading: _differingReading(e),
        ),
    ];
  }

  /// The merchant name **exactly as the payload carried it**.
  ///
  /// Order of preference:
  ///
  /// 1. the verbatim `pn=` out of the raw payload — the thing the QR said;
  /// 2. SWIP's cleaned name, when there is no raw payload to go back to (a
  ///    POS tap, a statement import, a manual entry);
  /// 3. the payee handle, which is at least checkable against the sticker;
  /// 4. nothing.
  static String? capturedName(CaptureEvent e) =>
      _payeeNameIn(e.rawPayload) ?? e.merchantName ?? e.merchantHandle;

  /// SWIP's reading, but only when it is genuinely different from the
  /// verbatim name — so the bracketed note appears on the rows where it says
  /// something and nowhere else.
  static String? _differingReading(CaptureEvent e) {
    final verbatim = _payeeNameIn(e.rawPayload);
    if (verbatim == null) return null;
    final swip = e.merchantName;
    if (swip == null) {
      // SWIP rejected the name the code carried. That is `F-42` and `F-139`
      // doing their job, and it is the most interesting thing that can happen
      // on a row — so it is said, rather than left as a silent disagreement.
      return 'SWIP does not treat this as a shop name';
    }
    return swip.trim().toLowerCase() == verbatim.trim().toLowerCase()
        ? null
        : swip;
  }

  /// Pull `pn=` out of a `upi://` payload without parsing the whole URI.
  ///
  /// Deliberately tolerant. This runs over payloads that are already in the
  /// ledger — including malformed ones, EMV TLV strings, APDU traces and the
  /// five rows in the owner's export that were never payment codes at all —
  /// and an export that throws on row 61 of 85 is worse than one that leaves
  /// a cell empty.
  static String? _payeeNameIn(String? raw) {
    if (raw == null || !raw.contains('pn=')) return null;
    try {
      final match = RegExp(r'[?&]pn=([^&\s]*)').firstMatch(raw);
      final encoded = match?.group(1);
      if (encoded == null || encoded.isEmpty) return null;
      final decoded = Uri.decodeComponent(encoded.replaceAll('+', ' ')).trim();
      return decoded.isEmpty ? null : decoded;
    } on ArgumentError {
      // A percent sign that is not an escape. Happens in the wild.
      return null;
    } on FormatException {
      return null;
    }
  }

  static String? _amount(CaptureEvent e) {
    final a = e.amount;
    if (a == null) return null;

    // Two decimal places, always. A QR that says `am=76.6` and one that says
    // `am=76.60` are the same money, and a column where one row has two
    // decimals and the next has one does not line up — which is the entire
    // point of having an amount column.
    //
    // Whole rupees keep their `.00` for the same reason: 5 above 76.66 with
    // the decimal points in different places is worse than a little noise.
    final text = a.toStringAsFixed(2);

    final c = e.currency;
    if (c == null || c.isEmpty) return text;
    return c.toUpperCase() == 'INR' ? '₹$text' : '$c $text';
  }

  // ── rendering ───────────────────────────────────────────────────────────

  /// The whole file, as text.
  ///
  /// Fixed-width columns rather than CSV, and that is the request being
  /// followed rather than a preference: *"a very simple line… in a rich text
  /// file format"*. A CSV is for a spreadsheet; this is meant to be opened,
  /// read, and pasted into a message. Every phone on earth can display it and
  /// nothing has to be installed.
  ///
  /// Columns are measured against the actual content rather than fixed, so a
  /// ledger of short names does not carry forty spaces of padding on every
  /// line.
  static String render(
    List<CaptureEvent> events, {
    DateTime? now,
  }) {
    final lines = of(events);
    final stamp = now ?? DateTime.now();

    if (lines.isEmpty) {
      return 'SWIP — your captures\n'
          'Nothing captured yet.\n'
          '\n'
          'Exported ${_dateTime(stamp)}\n';
    }

    final rows = [
      for (final l in lines)
        [
          l.mcc ?? _none,
          _merchantCell(l),
          l.amount ?? _none,
          _dateTime(l.date),
        ],
    ];

    const headers = ['MCC', 'MERCHANT (AS CAPTURED)', 'AMOUNT', 'DATE'];
    final widths = [
      for (var c = 0; c < headers.length; c++)
        [headers[c].length, ...rows.map((r) => r[c].length)]
            .reduce((a, b) => a > b ? a : b),
    ];

    String line(List<String> cells) => [
          for (var c = 0; c < cells.length; c++)
            // The amount is right-aligned so the figures line up under each
            // other; everything else is left-aligned. A column of money that
            // does not align on the decimal point is unreadable, and this file
            // exists to be read beside a statement.
            c == 2
                ? cells[c].padLeft(widths[c])
                : cells[c].padRight(widths[c]),
        ].join('  ').trimRight();

    final withCategory = lines.where((l) => l.mcc != null).length;

    return [
      'SWIP — your captures',
      '${lines.length} ${lines.length == 1 ? 'capture' : 'captures'}, '
          '$withCategory with a category. Newest first.',
      'Exported ${_dateTime(stamp)}',
      '',
      // Said once, at the top, because the column heading cannot carry it and
      // a reader comparing this against the app will otherwise find the
      // difference on their own and mistrust both.
      'MERCHANT is the name the code itself carried, verbatim. Where SWIP',
      'reads it differently — a payment company, or a reference number rather',
      'than a shop — its reading follows in brackets.',
      '',
      line(headers),
      line([for (final w in widths) '─' * w]),
      for (final r in rows) line(r),
      '',
    ].join('\n');
  }

  static String _merchantCell(LedgerLine l) {
    final name = l.merchant ?? _none;
    return l.swipReading == null ? name : '$name  [${l.swipReading}]';
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// `05 Sep 2026 14:32`. Local time, 24-hour, day first.
  ///
  /// Not ISO-8601: this file is for a person, and `2026-09-05T14:32:00.000Z`
  /// is for a machine. Not 12-hour either — an am/pm column is two more
  /// characters on every line and ambiguous at noon.
  static String _dateTime(DateTime d) {
    final l = d.toLocal();
    return '${_two(l.day)} ${_months[l.month - 1]} ${l.year} '
        '${_two(l.hour)}:${_two(l.minute)}';
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}
