/// What a scanned payload actually *is*, in language a person understands.
///
/// `F-19`–`F-22`. People point a scanner at everything: wifi cards, contact
/// codes, posters, a friend's GPay code. Telling them "unrecognised" is
/// technically true and useless. Every branch here names the thing and says why
/// there is no category, without jargon.
///
/// This deliberately sits beside [CaptureResolver] rather than inside it: the
/// resolver decides what SWIP can *capture*, this decides what SWIP should
/// *say*. Keeping them apart means the copy can be reworked without touching
/// parsing that has tests against it.
library;

enum PayloadKind {
  merchantQr,
  personalUpi,
  paymentLink,
  webLink,
  wifi,
  contact,
  phone,
  sms,
  location,
  appStore,
  crypto,
  plainText,
  damaged,
  empty;

  /// Whether a category could ever exist for this. Drives whether the sheet
  /// leads with digits or with an explanation.
  bool get couldHaveCategory =>
      this == merchantQr || this == paymentLink;
}

/// The classification, plus everything the sheet needs to explain itself.
class PayloadExplanation {
  const PayloadExplanation({
    required this.kind,
    required this.badge,
    required this.title,
    required this.body,
  });

  final PayloadKind kind;

  /// Top-right of the sheet — `F-17`. Three or four characters, no more.
  final String badge;

  /// The headline when there is no MCC to show.
  final String title;

  /// One or two plain sentences. No tag numbers, no acronyms.
  final String body;

  static PayloadExplanation of(String raw, {required bool hasMcc}) {
    final s = raw.trim();
    final lower = s.toLowerCase();

    if (s.isEmpty) {
      return const PayloadExplanation(
        kind: PayloadKind.empty,
        badge: 'EMPTY',
        title: 'Nothing in this code',
        body: 'The code scanned, but there was nothing inside it.',
      );
    }

    // ── UPI ──
    // The distinction that matters most in India: a shop's code carries a
    // category, a person's code cannot. Both look identical to a human.
    if (lower.startsWith('upi:') ||
        lower.startsWith('paytmmp:') ||
        lower.startsWith('phonepe:') ||
        lower.startsWith('gpay:') ||
        lower.startsWith('bhim:')) {
      if (hasMcc) {
        return const PayloadExplanation(
          kind: PayloadKind.merchantQr,
          badge: 'UPI',
          title: 'Merchant UPI code',
          body: 'A registered shop. Its category came with the code.',
        );
      }
      return const PayloadExplanation(
        kind: PayloadKind.personalUpi,
        badge: 'UPI',
        title: 'A personal UPI code, not a shop',
        body: 'This is someone paying as a person, not a registered business. '
            'Personal codes never carry a category - so there is nothing for '
            'your card to earn on here.',
      );
    }

    // ── Non-payment QR types, in rough order of how often they turn up ──
    if (lower.startsWith('wifi:')) {
      return const PayloadExplanation(
        kind: PayloadKind.wifi,
        badge: 'WIFI',
        title: 'A wifi code',
        body: 'This joins a wifi network. Nothing to do with a payment.',
      );
    }
    if (lower.startsWith('begin:vcard') || lower.startsWith('mecard:')) {
      return const PayloadExplanation(
        kind: PayloadKind.contact,
        badge: 'CARD',
        title: 'A contact card',
        body: 'Someone\'s phone number and details. Not a payment.',
      );
    }
    if (lower.startsWith('tel:')) {
      return const PayloadExplanation(
        kind: PayloadKind.phone,
        badge: 'TEL',
        title: 'A phone number',
        body: 'This code dials a number. Not a payment.',
      );
    }
    if (lower.startsWith('smsto:') || lower.startsWith('sms:')) {
      return const PayloadExplanation(
        kind: PayloadKind.sms,
        badge: 'SMS',
        title: 'A text message',
        body: 'This code writes a text message. Not a payment.',
      );
    }
    if (lower.startsWith('geo:')) {
      return const PayloadExplanation(
        kind: PayloadKind.location,
        badge: 'MAP',
        title: 'A map pin',
        body: 'This code opens a place on a map. Not a payment.',
      );
    }
    if (lower.startsWith('bitcoin:') ||
        lower.startsWith('ethereum:') ||
        lower.startsWith('litecoin:')) {
      return const PayloadExplanation(
        kind: PayloadKind.crypto,
        badge: 'CRYPTO',
        title: 'A crypto address',
        body: 'Crypto payments do not go through card networks, so they have '
            'no merchant category.',
      );
    }

    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      if (lower.contains('play.google.com') ||
          lower.contains('apps.apple.com')) {
        return const PayloadExplanation(
          kind: PayloadKind.appStore,
          badge: 'APP',
          title: 'An app download link',
          body: 'This opens an app store page. Not a payment.',
        );
      }
      return const PayloadExplanation(
        kind: PayloadKind.webLink,
        badge: 'WEB',
        title: 'A website, not a payment code',
        body: 'This is an ordinary web address. If it turns out to be a '
            'payment page, open it and SWIP will read it as a link instead.',
      );
    }

    // Looks like a payment QR but failed its own checksum.
    if (s.startsWith('0002')) {
      return const PayloadExplanation(
        kind: PayloadKind.damaged,
        badge: 'DAMAGED',
        title: 'This code is damaged',
        body: 'It looks like a payment code, but the built-in check failed - '
            'so anything read from it could be wrong. Better to show nothing '
            'than something invented. Try scanning again, or move closer.',
      );
    }

    return const PayloadExplanation(
      kind: PayloadKind.plainText,
      badge: 'TEXT',
      title: 'Just text',
      body: 'This code holds plain text, not payment details.',
    );
  }
}
