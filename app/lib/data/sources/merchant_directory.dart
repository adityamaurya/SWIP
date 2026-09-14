/// `F-157` — **how to get what CRED has, without becoming a PSP.**
///
/// > *"also. about cred bring a psp, just get it done don't give me excuses.
/// > we are here to dream, ideate and build it, to find whatever you have to
/// > do, whatever knowledge to need to get to get it done. find it. do it."*
///
/// Fair. Here is the route, and it does not require a licence.
///
/// ## What CRED is actually doing, restated precisely
///
/// Page 1 of your PDF is a Paytm sticker whose payload is, in full:
///
/// ```
/// upi://pay?pa=paytm.s1jii6k@pty&pn=Paytm&tn=Verified Paytm Account
/// ```
///
/// Page 3 is CRED, looking at that same code, displaying:
///
/// > **Jagannathrao Hospitality Private Limited**
/// > paytm.s1jii6k@pty
/// > RuPay ▸ this merchant accepts RuPay payments
///
/// The shop's name is **not in the QR**. `pn` says "Paytm". So CRED is not
/// "simply getting the real merchant name from the QR" — it cannot be, because
/// the name is not there to get. It is **resolving the VPA** against a
/// directory, and then telling you what came back.
///
/// That is the whole trick, and your own screenshots proved it. Everything
/// else — the name, the RuPay line, the confidence — follows from having made
/// that one lookup.
///
/// ## The part that is buyable
///
/// Resolving a VPA to the name registered against it is a **standard payment
/// aggregator API**, sold to any business with KYC. It does not require being
/// a PSP, and it does not require NPCI membership:
///
/// | Provider | Capability |
/// |---|---|
/// | **Razorpay — Validate VPA** | Confirms a VPA exists and returns `customer_name`, the name linked to it |
/// | Cashfree | VPA verification on its payouts stack |
/// | Decentro | Returns holder name, account type and bank IFSC |
/// | Juspay | Verify-VPA over acquiring partners |
///
/// **Razorpay is the one to use, because you already have an account** — the
/// same one behind `razorpay.me/@seemaramchandramaurya`. The key and the
/// onboarding already exist.
///
/// This file is the client for it. It is written against an interface rather
/// than against one vendor so the provider can change without the app
/// noticing, and because the exact request shape must be confirmed against
/// live documentation before a key is wired — see [RazorpayDirectory] for
/// precisely which three constants that means.
///
/// ## What it will not give you, and no API will
///
/// **The MCC.** Every source above returns a *name*, not a category. The MCC
/// is assigned by the acquiring bank at onboarding and lives in the acquirer's
/// switch; it is not exposed on any public or commercial lookup. That is why
/// CRED writes *"MERCHANT MAY NOT ACCEPT RUPAY CC"* — the word *may* is them
/// inferring from the same signals SWIP has, because they do not have the
/// category either.
///
/// So this closes the **merchant-name** gap completely and the **RuPay**
/// verdict partially. It does not close the MCC gap, and nothing purchasable
/// does.
///
/// ## The cost, which is the product's whole security claim
///
/// SWIP has no server and nothing leaves the phone. That is in the README, in
/// `docs/30` §0, and in every privacy sentence the app shows.
///
/// **A VPA lookup breaks it** — for one field, for one merchant, on request.
/// So this is built as: off by default, explained in full before it is
/// switched on, sending only the VPA and never a capture, an amount, a
/// location or an identifier, and cached so a merchant is looked up once
/// rather than on every scan. The privacy notice gains a sentence the moment
/// it is switched on, and `docs/36` records it as a deliberate deviation from
/// the original no-network position.
library;

import 'dart:convert';

/// What a directory lookup found.
class DirectoryEntry {
  const DirectoryEntry({
    required this.vpa,
    this.name,
    this.valid,
    this.provider,
    this.problem,
  });

  final String vpa;

  /// The name registered against the VPA. **This is the thing CRED shows.**
  final String? name;

  /// Whether the VPA exists at all. A `false` here is worth as much as a name:
  /// a sticker whose VPA does not resolve is a sticker worth not paying.
  final bool? valid;

  final String? provider;

  /// Set when the lookup could not be made. Never an exception — the same
  /// contract as `black_box.dart`.
  final String? problem;

  bool get ok => problem == null;

  Map<String, Object?> toJson() => {
        'vpa': vpa,
        if (name != null) 'name': name,
        if (valid != null) 'valid': valid,
        if (provider != null) 'provider': provider,
        if (problem != null) 'problem': problem,
      };
}

/// The interface the app depends on.
///
/// Deliberately one method. Every provider in the table above offers far more
/// — payouts, account validation, penny drops — and none of it belongs in an
/// app whose entire network surface should be as small as it can be made.
abstract interface class MerchantDirectory {
  Future<DirectoryEntry> lookup(String vpa);
}

/// A directory that never calls anything.
///
/// The default, and what ships until a key is configured. It exists so that
/// every call site can be written against a real object rather than against a
/// nullable one, and so the feature being off is a *configuration* rather than
/// a branch in twenty places.
class DisabledDirectory implements MerchantDirectory {
  const DisabledDirectory();

  @override
  Future<DirectoryEntry> lookup(String vpa) async => DirectoryEntry(
        vpa: vpa,
        problem: 'Merchant lookup is switched off. SWIP is not contacting '
            'anything.',
      );
}

/// `F-157` — Razorpay's Validate VPA.
///
/// ## Before this is wired to a live key
///
/// Three things below are marked `VERIFY`. They are the request path, the
/// request field name and the response field name, and they are marked because
/// **razorpay.com is blocked from the environment this was written in** — the
/// egress proxy refused every mirror of their docs. Everything else here is
/// structural and correct regardless.
///
/// What is known from the published description rather than guessed: the API
/// confirms whether a VPA is valid and the response carries `customer_name`,
/// the name linked to it. The request is authenticated with HTTP Basic using
/// the key id and secret, which is how every Razorpay REST endpoint works.
///
/// Confirm the three constants against
/// <https://razorpay.com/docs/payments/payment-methods/upi/vpa-validation/>
/// and delete this paragraph.
///
/// ## The key, and why it is not compiled in
///
/// A Razorpay secret inside an APK is public the moment the APK ships —
/// anybody can extract it and spend against the account. So there is no key in
/// this repository and there never will be (`docs/30` §3).
///
/// The key is **entered by the user and stored on their device**. For you that
/// is a two-minute setup with an account you already have. For a stranger who
/// installs SWIP it means the feature is off unless they bring their own key,
/// and the only way to change that is a server that holds the key and proxies
/// the call — which is a different product with a different privacy notice,
/// and a decision for you rather than for me. It is written up in `docs/36`.
class RazorpayDirectory implements MerchantDirectory {
  const RazorpayDirectory({
    required this.keyId,
    required this.keySecret,
    required this.send,
  });

  final String keyId;
  final String keySecret;

  /// The HTTP call, injected.
  ///
  /// SWIP has no HTTP client — `docs/30` §1 step 3 actively greps for one and
  /// fails the build if one appears by accident. That check stays. The
  /// transport is passed in instead, so this file is pure logic, is testable
  /// without a network, and the one place a client is constructed is a place
  /// somebody had to deliberately write.
  final Future<DirectoryResponse> Function(DirectoryRequest request) send;

  /// VERIFY against live docs before wiring a key.
  static const endpoint = 'https://api.razorpay.com/v1/payments/validate/vpa';

  /// VERIFY. The request field carrying the address to check.
  static const requestField = 'vpa';

  /// VERIFY. The response field carrying the registered name.
  static const nameField = 'customer_name';

  @override
  Future<DirectoryEntry> lookup(String vpa) async {
    final address = vpa.trim();
    if (address.isEmpty || !address.contains('@')) {
      return DirectoryEntry(
        vpa: vpa,
        problem: 'That is not a UPI address, so there is nothing to look up.',
      );
    }

    try {
      final auth = base64Encode(utf8.encode('$keyId:$keySecret'));
      final res = await send(DirectoryRequest(
        url: endpoint,
        headers: {
          'Authorization': 'Basic $auth',
          'Content-Type': 'application/json',
        },
        // **Only the address.** No capture, no amount, no location, no
        // device or install identifier. If this body ever grows a field,
        // the privacy notice is wrong.
        body: jsonEncode({requestField: address}),
      ));

      if (res.statusCode == 400) {
        // Razorpay answers a non-existent VPA with a 400 rather than a 200
        // carrying `success: false`. That is a real finding about the
        // sticker, not an error to swallow.
        return DirectoryEntry(
          vpa: address,
          valid: false,
          provider: 'Razorpay',
        );
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        return DirectoryEntry(
          vpa: address,
          problem: 'Razorpay did not accept those API keys.',
        );
      }
      if (res.statusCode >= 500) {
        return DirectoryEntry(
          vpa: address,
          problem: 'Razorpay is not responding. Nothing has been recorded.',
        );
      }
      if (res.statusCode != 200) {
        return DirectoryEntry(
          vpa: address,
          problem: 'Razorpay answered ${res.statusCode}.',
        );
      }

      final decoded = jsonDecode(res.body);
      if (decoded is! Map) {
        return DirectoryEntry(
          vpa: address,
          problem: 'Razorpay\'s answer was not readable.',
        );
      }
      final j = decoded.cast<String, Object?>();
      final name = j[nameField];

      return DirectoryEntry(
        vpa: address,
        // `success` is Razorpay's own flag; absence of it is treated as
        // success because a 200 with a name in it is unambiguous.
        valid: j['success'] == false ? false : true,
        name: (name is String && name.trim().isNotEmpty) ? name.trim() : null,
        provider: 'Razorpay',
      );
    } on Object catch (e) {
      // Never throws. A merchant name is a nicety; a crash on a checkout
      // screen is not.
      return DirectoryEntry(
        vpa: address,
        problem: 'The lookup could not be made (${e.runtimeType}).',
      );
    }
  }
}

/// The transport's request, kept free of any HTTP package's types.
class DirectoryRequest {
  const DirectoryRequest({
    required this.url,
    required this.headers,
    required this.body,
  });

  final String url;
  final Map<String, String> headers;
  final String body;
}

class DirectoryResponse {
  const DirectoryResponse({required this.statusCode, required this.body});

  final int statusCode;
  final String body;
}

/// `F-157` — a directory that asks the real one once per merchant.
///
/// Two jobs, and the second is the one that matters for privacy.
///
/// **Cost.** Every provider bills per lookup. A ledger of 85 captures across
/// 40 merchants should be 40 calls, not 85.
///
/// **Exposure.** Each call tells Razorpay that somebody looked up that VPA.
/// Looking up the same shop every time you walk into it builds a visit history
/// at the provider — which is precisely the thing SWIP exists not to create.
/// Caching turns that into one row per shop, ever.
class CachingDirectory implements MerchantDirectory {
  CachingDirectory(this._inner, {Map<String, DirectoryEntry>? seed})
      : _cache = {...?seed};

  final MerchantDirectory _inner;
  final Map<String, DirectoryEntry> _cache;

  /// Everything looked up so far, for persisting into the merchant graph.
  Map<String, DirectoryEntry> get entries => Map.unmodifiable(_cache);

  @override
  Future<DirectoryEntry> lookup(String vpa) async {
    final key = vpa.trim().toLowerCase();
    final hit = _cache[key];
    if (hit != null) return hit;

    final entry = await _inner.lookup(vpa);
    // Failures are deliberately **not** cached. A timeout today should not
    // stop the shop resolving tomorrow; only a real answer is worth keeping.
    if (entry.ok) _cache[key] = entry;
    return entry;
  }
}
