import 'dart:convert';
import 'dart:io';

import 'merchant_directory.dart';

/// `F-160` — **the one place in SWIP where an HTTP request is made.**
///
/// ## Read this before touching the file
///
/// SWIP's core claim is that it has no server and nothing leaves the phone.
/// [`docs/30`](../../../../docs/30-PRE-LAUNCH-PARAMETERS.md) §1 greps the
/// whole of `lib/` for `package:http/`, `package:dio/` and `HttpClient(`
/// before every build and fails it if one appears, precisely so that a network
/// client cannot arrive by accident — pulled in by a well-meaning refactor, or
/// by somebody reaching for the obvious tool.
///
/// **That check still runs. This file is its single named exception**, by
/// exact path, so a client appearing anywhere else still stops the build. The
/// exception is the point: an accidental network client and a deliberate one
/// are different things, and the check was only ever meant to catch the first.
///
/// ## Why `dart:io` and not `package:http`
///
/// Because `package:http` would be a new dependency on the pubspec of an app
/// whose entire argument is that it does not talk to anything, and because
/// `HttpClient` is in the SDK and does everything needed here. One fewer
/// package is one fewer thing that can start making requests of its own.
///
/// ## What it will and will not send
///
/// One field: the payment address. No capture, no amount, no location, no
/// device or install identifier, nothing about the ledger. There is a test in
/// `merchant_directory_test.dart` asserting the request body has exactly one
/// key, and it exists so that growing this by accident is impossible.
class RealDirectoryTransport {
  RealDirectoryTransport({this.timeout = const Duration(seconds: 6)});

  /// Short on purpose. This runs while somebody is standing at a counter with
  /// a phone in their hand; a merchant name that arrives after they have paid
  /// is worth nothing, and a spinner that outlives their patience is worse
  /// than no answer.
  final Duration timeout;

  Future<DirectoryResponse> send(DirectoryRequest request) async {
    // Constructed per call rather than held open. A long-lived client in an
    // app that makes a handful of requests a week is a socket kept alive for
    // nothing, and `close()` in a `finally` is the only way to be sure a
    // failure part-way through does not leak one.
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final uri = Uri.parse(request.url);
      final req = await client.postUrl(uri).timeout(timeout);
      request.headers.forEach(req.headers.set);
      req.write(request.body);

      final res = await req.close().timeout(timeout);
      final body = await res.transform(utf8.decoder).join().timeout(timeout);
      return DirectoryResponse(statusCode: res.statusCode, body: body);
    } finally {
      client.close(force: true);
    }
  }
}
