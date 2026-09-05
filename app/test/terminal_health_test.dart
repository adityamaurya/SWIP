import 'package:flutter_test/flutter_test.dart';
import 'package:swip/data/sources/terminal_health.dart';

/// `F-138` — the two real POS taps in the owner's export.
///
/// One worked, one did not, and the difference was sitting in the hex the whole
/// time. These tests are named after the actual bytes.
void main() {
  group('the tap that failed, from the export', () {
    // 9F16 = 313132323333343435353636373738
    // 9F1C = 3132333435363738
    const mid = '313132323333343435353636373738';
    const tid = '3132333435363738';

    test('the hex is text, and the text is a factory value', () {
      expect(TerminalDoctor.asAscii(mid), '112233445566778');
      expect(TerminalDoctor.asAscii(tid), '12345678');
    });

    test('so the terminal is reported as unprovisioned, not as a bank fault',
        () {
      final r = TerminalDoctor.examine(merchantIdHex: mid, terminalIdHex: tid);
      expect(r.health, TerminalHealth.placeholder);
      expect(r.note, contains('factory settings'));
      // The sentence must reassure: nothing is wrong with the phone.
      expect(r.note, contains('Nothing is wrong with your phone'));
    });
  });

  group('the tap that worked, from the export', () {
    // A real, binary merchant ID. It gave MCC 5411.
    const mid = '0FBD96389443542326810000000000';

    test('binary is not decoded into nonsense text', () {
      // 0x0F is a control character. Reporting it as a "name" would be worse
      // than reporting nothing.
      expect(TerminalDoctor.asAscii(mid), isNull);
    });

    test('and the terminal is left alone', () {
      final r = TerminalDoctor.examine(merchantIdHex: mid);
      expect(r.health, TerminalHealth.provisioned);
      expect(r.note, isNull, reason: 'a working machine needs no commentary');
    });
  });

  group('other placeholder shapes', () {
    for (final MapEntry(key: label, value: text) in const {
      'all zeros': '30303030303030',
      'sequential': '3132333435363738',
      'repeated digit': '393939393939393939',
    }.entries) {
      test('$label is caught', () {
        expect(TerminalDoctor.examine(merchantIdHex: text).health,
            TerminalHealth.placeholder);
      });
    }

    test('a zeroed field is caught even when it is not text', () {
      expect(TerminalDoctor.examine(merchantIdHex: '00000000000000').health,
          TerminalHealth.placeholder);
    });
  });

  group('what must NOT be called a placeholder', () {
    test('a tidy but real merchant number is left alone', () {
      // A shop whose MID happens to be a round number still runs a real
      // terminal. Accusing it of being broken is the failure mode here.
      for (final hex in const [
        '3830343132333435', // "80412345"
        '4D45524348303031', // "MERCH001"
        '3939383736353433', // "99876543"
      ]) {
        expect(TerminalDoctor.examine(merchantIdHex: hex).health,
            TerminalHealth.provisioned,
            reason: TerminalDoctor.asAscii(hex));
      }
    });
  });

  test('a terminal that says nothing at all gets its own sentence', () {
    final r = TerminalDoctor.examine();
    expect(r.health, TerminalHealth.silent);
    expect(r.note, contains('did not identify itself'));
  });

  test('malformed hex never throws', () {
    for (final bad in const ['ZZZZ', '1', '', 'abc']) {
      expect(() => TerminalDoctor.examine(merchantIdHex: bad),
          returnsNormally);
    }
  });
}
