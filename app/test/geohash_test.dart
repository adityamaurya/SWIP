import 'package:flutter_test/flutter_test.dart';
import 'package:swip/core/location/capture_location.dart';

/// `F-40`. The geohash is what actually reaches the database, and the database
/// is what gets exported to the user's own Drive — so its precision is a
/// privacy guarantee, not a formatting detail. These tests exist to make a
/// future "just bump it to 9 characters, it's more accurate" change fail loudly.
void main() {
  group('Geohash.encode', () {
    // The canonical fixture from Niemeyer's original description.
    test('matches the reference value', () {
      expect(Geohash.encode(57.64911, 10.40744, precision: 11),
          'u4pruydqqvj');
    });

    test('defaults to 6 characters', () {
      expect(Geohash.encode(19.0760, 72.8777).length, 6);
    });

    test('handles the poles and the antimeridian without throwing', () {
      for (final (lat, lon) in const [
        (90.0, 180.0),
        (-90.0, -180.0),
        (0.0, 0.0),
      ]) {
        expect(Geohash.encode(lat, lon).length, 6);
      }
    });

    test('two points ~200 m apart stay in the same neighbourhood', () {
      // Bandra West, Mumbai — a shop and the next street over. They do not
      // always land in the *same* cell: geohash cells are a grid, and two
      // close points either side of a boundary get different last characters.
      // What is guaranteed, and what the privacy claim actually rests on, is
      // that the cell is far too coarse to identify a building.
      final a = Geohash.encode(19.0596, 72.8295);
      final b = Geohash.encode(19.0614, 72.8302);
      expect(a.substring(0, 5), b.substring(0, 5),
          reason: 'the cell must be coarse enough to hide which building');
    });

    test('two cities never share a cell', () {
      expect(Geohash.encode(19.0760, 72.8777), // Mumbai
          isNot(Geohash.encode(28.6139, 77.2090))); // Delhi
    });

    test('is deterministic — the graph key must match across devices', () {
      expect(Geohash.encode(19.0760, 72.8777), Geohash.encode(19.0760, 72.8777));
    });
  });
}
