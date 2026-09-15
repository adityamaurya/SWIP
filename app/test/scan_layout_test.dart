import 'package:flutter_test/flutter_test.dart';
import 'package:swip/features/capture_qr/scan_page.dart';

/// `F-171` — does the aiming square leave room for everything around it?
///
/// ## Why this test exists
///
/// The reticle was a fixed 260 px square, which was correct for as long as
/// this screen was only ever full-screen. `F-163` put the same widget inside
/// the hovering card, whose height is clamped to a **minimum of 320 px** — and
/// 260 in 320 leaves 30 px above and below, so the wordmark at the top and the
/// two lines of copy at the bottom were drawn on top of the reticle.
///
/// Nothing overflowed and nothing threw. A `Stack` is entitled to overlap its
/// children, so there was no error to catch: it simply looked broken, on the
/// surface nobody was testing. That is the same shape as the bugs
/// `check_wiring.py` was written for — every piece correct, the relationship
/// between them wrong.
///
/// ## Why it is arithmetic rather than a rendered screen
///
/// `ScanPage` cannot be pumped. It builds a `MobileScanner`, and a widget test
/// has no engine behind that channel — `CLAUDE.md` records what happens when
/// you try: the call never completes and `pumpAndSettle` times out. The
/// reticle also animates on a repeat, so nothing would ever settle anyway.
///
/// So the layout decision was made a pure function and the function is tested.
/// It is less than a golden would prove and it is the part that was wrong.
void main() {
  /// The two surfaces this screen genuinely runs on.
  const phone = (width: 412.0, height: 915.0);
  const shortestCard = (width: 388.0, height: 320.0);
  const tallestCard = (width: 388.0, height: 620.0);

  test('full screen still gets the size that was always right', () {
    expect(scanReticleSide(phone.width, phone.height), 260.0);
  });

  test('a tall hovering card also gets the full size', () {
    expect(scanReticleSide(tallestCard.width, tallestCard.height), 260.0);
  });

  test('the shortest hovering card shrinks it instead of overlapping', () {
    final side = scanReticleSide(shortestCard.width, shortestCard.height);
    expect(side, lessThan(260.0));
    // The actual claim: chrome fits around it. Centred, the reticle occupies
    // (height - side) / 2 at each end, and that has to be at least half the
    // reserved chrome or the copy is on top of it.
    final clearance = (shortestCard.height - side) / 2;
    expect(clearance, greaterThanOrEqualTo(reticleChrome / 2));
  });

  test('it never collapses to nothing on an absurd surface', () {
    // A freeform window, a split screen, a foldable read while closed. None of
    // these should produce a reticle of zero or a negative width, which would
    // throw inside `Container` rather than merely looking wrong.
    for (final height in <double>[0, 60, 120, 200]) {
      final side = scanReticleSide(200, height);
      expect(side, greaterThanOrEqualTo(120.0));
    }
    expect(scanReticleSide(0, 0), 120.0);
  });

  test('a narrow surface constrains it too, not just a short one', () {
    // Width matters on a split screen: a 200 px wide window with plenty of
    // height must not draw a 260 px square off both edges.
    expect(scanReticleSide(200, 900), lessThan(200.0));
  });
}
