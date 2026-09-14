/// `F-138` — **is this card terminal actually provisioned?**
///
/// ## What the ledger showed
///
/// The owner's export contained two NFC taps. One worked and one did not, and
/// the difference is not subtle once the hex is decoded:
///
/// | | Merchant ID (`9F16`) | as ASCII | Category |
/// |---|---|---|---|
/// | The one that worked | `0FBD963894435423…` | binary, not text | **5411** |
/// | The one that failed | `313132323333…3738` | **`112233445566778`** | none |
///
/// And its terminal ID (`9F1C`) was `3132333435363738` — ASCII **`12345678`**.
///
/// Those are **factory placeholder values**. That terminal was never
/// provisioned with real merchant data, which is precisely why it has no
/// category either. The two facts have one cause.
///
/// ## Why this matters more than it looks
///
/// SWIP's message for that tap was *"The terminal did not give a category …
/// That is the shop's bank not filling it in."* True, and unfalsifiable, and
/// unhelpful — it reads as SWIP shrugging.
///
/// **"This terminal is running on factory settings"** is a different sentence
/// entirely. It is checkable, it explains why every card will behave oddly
/// there, and it tells the cashier something they can act on. Same tap, same
/// bytes, and the difference is only whether anybody decoded the hex.
///
/// ## What is deliberately not claimed
///
/// A real merchant ID that happens to look tidy is not a placeholder. The
/// patterns below are narrow: repeated ascending pairs, sequential digits, all
/// one character, or all zeros. A terminal whose MID is a plain number is left
/// alone, because being wrong here would accuse a working shop of running a
/// broken machine.
library;

import 'dart:convert';

/// What the terminal's identity fields say about it.
enum TerminalHealth {
  /// Real, provisioned values.
  provisioned,

  /// Identity fields hold factory or demo data.
  placeholder,

  /// Fields absent or empty — the terminal answered but told us nothing.
  silent,
}

class TerminalReading {
  const TerminalReading({
    required this.health,
    this.merchantIdAscii,
    this.terminalIdAscii,
    this.note,
  });

  final TerminalHealth health;

  /// The decoded text, when the hex turned out to *be* text. Shown in the
  /// technical detail, because "112233445566778" explains itself and
  /// "313132323333343435353636373738" does not.
  final String? merchantIdAscii;
  final String? terminalIdAscii;

  /// The sentence to show. `null` for a healthy terminal — a working machine
  /// needs no commentary.
  final String? note;
}

abstract final class TerminalDoctor {
  /// Placeholder shapes, once decoded to text.
  ///
  /// Every one of these is a value a technician types to prove the hardware
  /// works, and none of them is a merchant ID anybody was issued.
  static final _placeholders = <RegExp>[
    RegExp(r'^(?:12){3,}\d?$'), // 121212…
    RegExp(r'^(\d)\1{5,}$'), // 000000, 111111, 999999
    RegExp(r'^(?:TEST|DEMO|DUMMY|SAMPLE)[\s._-]*\w*$', caseSensitive: false),
    RegExp(r'^(?:ABCDEF|XXXXXX)\w*$', caseSensitive: false),
  ];

  /// Straight counting: `12345678`, `123456`, `456789`. Checked rather than
  /// pattern-matched, because a regex for this is either wrong at one length
  /// or unreadable at all of them — the first attempt here missed `12345678`,
  /// which is the exact terminal ID in the export.
  static bool _isSequential(String s) {
    if (s.length < 6 || !RegExp(r'^\d+$').hasMatch(s)) return false;
    for (var i = 1; i < s.length; i++) {
      if (int.parse(s[i]) != (int.parse(s[i - 1]) + 1) % 10) return false;
    }
    return true;
  }

  /// Ascending runs like `1122334455667788` — pairs that climb by one.
  static bool _isAscendingPairs(String s) {
    if (s.length < 8 || s.length.isOdd && s.length < 9) return false;
    if (!RegExp(r'^\d+$').hasMatch(s)) return false;
    for (var i = 0; i + 1 < s.length - 1; i += 2) {
      if (s[i] != s[i + 1]) return false;
      final next = i + 2;
      if (next < s.length &&
          int.parse(s[next]) != (int.parse(s[i]) % 10) + 1) {
        return false;
      }
    }
    return true;
  }

  /// Hex → text, but only when the result is plausibly text. A binary
  /// merchant ID decodes to control characters, and reporting that as a
  /// "name" would be worse than saying nothing.
  static String? asAscii(String? hex) {
    final h = hex?.trim();
    if (h == null || h.isEmpty || h.length.isOdd) return null;
    if (!RegExp(r'^[0-9A-Fa-f]+$').hasMatch(h)) return null;
    try {
      final bytes = <int>[
        for (var i = 0; i + 1 < h.length; i += 2)
          int.parse(h.substring(i, i + 2), radix: 16),
      ];
      // Printable ASCII only, and at least four characters of it.
      if (bytes.length < 4) return null;
      if (bytes.any((b) => b < 0x20 || b > 0x7E)) return null;
      return ascii.decode(bytes).trim();
    } catch (_) {
      return null;
    }
  }

  static bool _looksPlaceholder(String? text) {
    if (text == null || text.isEmpty) return false;
    final t = text.trim();
    if (_isAscendingPairs(t) || _isSequential(t)) return true;
    return _placeholders.any((p) => p.hasMatch(t));
  }

  /// Examine a terminal's identity fields.
  ///
  /// [merchantIdHex] is EMV `9F16`, [terminalIdHex] is `9F1C`, both as the hex
  /// strings the HCE service reports.
  static TerminalReading examine({
    String? merchantIdHex,
    String? terminalIdHex,
  }) {
    final mid = merchantIdHex?.trim();
    final tid = terminalIdHex?.trim();

    if ((mid == null || mid.isEmpty) && (tid == null || tid.isEmpty)) {
      return const TerminalReading(
        health: TerminalHealth.silent,
        note: 'This machine answered but did not identify itself, so there is '
            'nothing to remember it by. Scanning the shop\'s QR usually works '
            'where this does not.',
      );
    }

    final midText = asAscii(mid);
    final tidText = asAscii(tid);

    // All-zero fields are the other way a terminal says "not provisioned".
    final zeroed = (mid != null && RegExp(r'^0+$').hasMatch(mid)) ||
        (tid != null && RegExp(r'^0+$').hasMatch(tid));

    if (_looksPlaceholder(midText) ||
        _looksPlaceholder(tidText) ||
        zeroed) {
      return TerminalReading(
        health: TerminalHealth.placeholder,
        merchantIdAscii: midText,
        terminalIdAscii: tidText,
        note: 'This terminal is still on its factory settings. Its merchant '
            'and terminal numbers are the demo values a technician types to '
            'test the hardware'
            '${midText == null ? '' : ' - it reported "$midText"'}'
            '. That is why it has no category either: nobody finished setting '
            'it up. Nothing is wrong with your phone or your card.',
      );
    }

    return TerminalReading(
      health: TerminalHealth.provisioned,
      merchantIdAscii: midText,
      terminalIdAscii: tidText,
    );
  }
}

/// `F-143` — **how far the tap actually got.**
///
/// ## The complaint this exists to answer
///
/// > *"There were multiple POS fails wherein what happened was I tried to go
/// > ahead near the POS, but the pop-up did not happen at all."*
///
/// [TerminalHealth] above answers *"the terminal talked to us and said
/// nothing useful"*. This answers the question underneath it, which is
/// different and was never asked in code: **did the terminal talk to us at
/// all?**
///
/// Until `F-143` the HCE service broadcast only on a successful
/// `GET PROCESSING OPTIONS`. Every other ending — and there are two of them —
/// produced no broadcast, so no sheet, no ledger row and no explanation. The
/// app was not failing to read the category; it was failing to say that a tap
/// had happened. From the user's side of the counter those look identical, and
/// only one of them is a bug.
///
/// ## The three endings
///
/// | Outcome | What happened | Whose problem |
/// |---|---|---|
/// | [read] | Selected, PDOL answered. There may or may not be a `9F15` in it | Nobody's — this is the feature working |
/// | [noGpo] | The terminal selected SWIP, read the PDOL, and stopped | The terminal's kernel |
/// | [noSelect] | The field opened and closed without a SELECT reaching us | Routing — usually another wallet holds the field |
///
/// [noSelect] is the important one, because it is the only ending that is
/// usually **fixable by the user**, and for four months it was also the one
/// that produced complete silence. See `docs/34` §2.
enum TapOutcome {
  /// The exchange completed. Read [TerminalHealth] for what was in it.
  read,

  /// SWIP was selected but the terminal never asked for processing options.
  noGpo,

  /// Nothing ever selected SWIP.
  noSelect;

  /// Parse the string the platform channel sends. Anything unrecognised is
  /// treated as [read], because an unknown reason arriving alongside real TLV
  /// data must not throw away the data.
  static TapOutcome parse(String? s) => switch (s) {
        'no_gpo' => TapOutcome.noGpo,
        'no_select' => TapOutcome.noSelect,
        _ => TapOutcome.read,
      };

  /// The headline. Never "error", never "failed" — each of these is a specific,
  /// true statement about a machine, and two of them are not SWIP's fault in
  /// any sense the user can act on.
  String get title => switch (this) {
        TapOutcome.read => 'The terminal did not give a category',
        TapOutcome.noGpo => 'This terminal stopped halfway',
        TapOutcome.noSelect => 'The terminal never reached SWIP',
      };

  /// The explanation, written to be actionable where action exists and honest
  /// where it does not.
  String get body => switch (this) {
        TapOutcome.read =>
          'SWIP asked and this machine returned nothing in the category '
              'field. That is the shop\'s bank not filling it in — not '
              'something SWIP or the cashier can change. Scanning the shop\'s '
              'QR often works when the terminal will not.',
        TapOutcome.noGpo =>
          'The terminal recognised SWIP and read its request, then ended the '
              'exchange before answering it. Some payment terminals refuse an '
              'application until an amount has been keyed in; others are set '
              'to require a chip-and-PIN fallback. Ask the cashier to enter '
              'the amount first, then tap again.',
        TapOutcome.noSelect =>
          'The terminal opened its field but never asked SWIP for anything, '
              'which almost always means another app holds the contactless '
              'slot on this phone. Set SWIP as the default payment app — or '
              'keep this screen open while you tap, which routes the field '
              'here for as long as you are looking at it.',
      };

  /// Whether this ending is worth keeping in the ledger as its own row.
  ///
  /// All three are. A ledger that records only successes cannot answer "how
  /// often does this actually work", which is the single most important
  /// unknown in the product — see the field-test note on `SwipListenService`.
  bool get isCapture => true;
}
