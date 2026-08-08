import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:swip/data/sources/emv_qr_parser.dart';
import 'package:swip/data/sources/upi_uri_parser.dart';

/// Builds a conformant payload with a correct CRC, so fixtures stay readable
/// and a hand-typed checksum can never silently invalidate a test.
String buildQr(String body) {
  final withTag = '${body}6304';
  final crc = EmvQrParser.crc16ccitt(withTag)
      .toRadixString(16)
      .toUpperCase()
      .padLeft(4, '0');
  return '$withTag$crc';
}

/// Length is the UTF-8 **byte** count, as EMV requires — not `String.length`,
/// which counts UTF-16 code units and would produce a fixture that only looks
/// right in ASCII.
String tlv(String tag, String value) =>
    '$tag${utf8.encode(value).length.toString().padLeft(2, '0')}$value';

void main() {
  group('CRC-16/CCITT-FALSE', () {
    test('matches the published check value', () {
      // The standard check vector for CRC-16/CCITT-FALSE.
      expect(EmvQrParser.crc16ccitt('123456789'), 0x29B1);
    });
  });

  group('EMVCo MPM', () {
    final valid = buildQr(
      tlv('00', '01') +
          tlv('01', '11') +
          tlv('26', tlv('00', 'in.npci.upi') + tlv('01', 'bluetokai@hdfc')) +
          tlv('52', '5812') +
          tlv('53', '356') +
          tlv('58', 'IN') +
          tlv('59', 'Blue Tokai Coffee') +
          tlv('60', 'Mumbai'),
    );

    test('extracts the MCC from tag 52', () {
      expect(EmvQrParser.parse(valid).mcc, '5812');
    });

    test('extracts merchant, city, country and currency', () {
      final p = EmvQrParser.parse(valid);
      expect(p.merchantName, 'Blue Tokai Coffee');
      expect(p.merchantCity, 'Mumbai');
      expect(p.countryCode, 'IN');
      expect(p.currencyNumeric, '356');
      expect(p.isDynamic, isFalse);
    });

    test('recognises the domestic scheme template', () {
      expect(EmvQrParser.parse(valid).merchantAccounts.keys, contains('26'));
      expect(EmvQrParser.parse(valid).schemeHint, 'Domestic scheme');
    });

    test('rejects a payload whose CRC does not match', () {
      // Flip the last checksum digit. A corrupt payload must never surface an
      // MCC — showing a confidently wrong four digits is worse than nothing.
      final corrupt = valid.substring(0, valid.length - 1) +
          (valid.endsWith('0') ? '1' : '0');
      expect(
        () => EmvQrParser.parse(corrupt),
        throwsA(isA<EmvQrException>().having(
            (e) => e.failure, 'failure', EmvQrFailure.crcMismatch)),
      );
    });

    test('0000 is unclassified, not missing', () {
      final p = EmvQrParser.parse(buildQr(
          tlv('00', '01') + tlv('01', '11') + tlv('52', '0000')));
      expect(p.mcc, '0000');
      expect(p.isUnclassified, isTrue);
    });

    test('absent tag 52 yields a null MCC rather than throwing', () {
      final p = EmvQrParser.parse(
          buildQr(tlv('00', '01') + tlv('01', '11') + tlv('58', 'IN')));
      expect(p.mcc, isNull);
      expect(p.isUnclassified, isFalse);
    });

    test('a duplicated tag 52 cannot override the first', () {
      // Defence against an appended tag trying to shadow the real category.
      final p = EmvQrParser.parse(buildQr(
          tlv('00', '01') + tlv('52', '5812') + tlv('52', '4722')));
      expect(p.mcc, '5812');
    });

    test('a length that overruns the payload is malformed, not a crash', () {
      expect(
        () => EmvQrParser.parse('000201' '5299' '58', requireValidCrc: false),
        throwsA(isA<EmvQrException>().having(
            (e) => e.failure, 'failure', EmvQrFailure.malformed)),
      );
    });

    test('a non-payment QR is rejected as notEmvQr', () {
      expect(EmvQrParser.looksLikeEmvQr('https://example.com'), isFalse);
      expect(
        () => EmvQrParser.parse('https://example.com'),
        throwsA(isA<EmvQrException>()),
      );
    });

    test('non-ASCII merchant names still verify', () {
      // Tag 64 legitimately carries local script. CRC is over UTF-8 bytes, so
      // this fails if the implementation uses UTF-16 code units — and this is
      // exactly the case the "works in every country" promise depends on.
      final p = EmvQrParser.parse(buildQr(
          tlv('00', '01') + tlv('52', '5812') + tlv('59', 'ブルー トーカイ')));
      expect(p.crcValid, isTrue);
      expect(p.mcc, '5812');
    });
  });

  group('UPI intent URI', () {
    test('extracts mc as the MCC', () {
      final u = UpiUriParser.tryParse(
          'upi://pay?pa=bluetokai@hdfc&pn=Blue%20Tokai&mc=5812&cu=INR')!;
      expect(u.mcc, '5812');
      expect(u.payeeAddress, 'bluetokai@hdfc');
      expect(u.payeeName, 'Blue Tokai');
    });

    test('mc=0000 is unclassified', () {
      final u = UpiUriParser.tryParse('upi://pay?pa=someone@okaxis&mc=0000')!;
      expect(u.mcc, '0000');
      expect(u.isUnclassified, isTrue);
    });

    test('absent mc yields null', () {
      final u = UpiUriParser.tryParse('upi://pay?pa=someone@okaxis')!;
      expect(u.mcc, isNull);
      expect(u.hasMalformedMcc, isFalse);
    });

    test('a malformed mc is reported, not silently dropped', () {
      final u = UpiUriParser.tryParse('upi://pay?pa=x@y&mc=58')!;
      expect(u.mcc, isNull);
      expect(u.hasMalformedMcc, isTrue);
    });

    test('an unencoded & in pn does not lose mc', () {
      // Real-world QRs do this constantly. Uri.parse would mangle it, and
      // losing the category to a bad merchant name is undiagnosable for a user.
      final u = UpiUriParser.tryParse('upi://pay?pn=Tea & Co&pa=t@y&mc=5812')!;
      expect(u.mcc, '5812');
      expect(u.payeeAddress, 't@y');
    });

    test('rejects non-UPI schemes', () {
      expect(UpiUriParser.tryParse('https://example.com'), isNull);
    });
  });
}
