import 'package:beach_safety/features/maps/india_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late IndiaGeometry geometry;

  setUpAll(() async {
    geometry = await IndiaGeometry.load();
  });

  test('loads rings from the bundled asset', () {
    expect(geometry.rings, isNotEmpty);
    expect(geometry.rings.first.length, greaterThan(100));
  });

  test('every ring is a usable closed polygon', () {
    for (final ring in geometry.rings) {
      expect(ring.length, greaterThanOrEqualTo(4));
    }
  });

  test('covers India\'s official extent', () {
    // India spans roughly 68°7'E–97°25'E and 6°45'N–37°6'N, the northern
    // limit reflecting the India point-of-view boundary for Jammu & Kashmir.
    expect(geometry.bounds.west, closeTo(68.14, 0.2));
    expect(geometry.bounds.east, closeTo(97.36, 0.2));
    expect(geometry.bounds.south, closeTo(6.75, 0.2));
    expect(geometry.bounds.north, closeTo(37.05, 0.2));
  });

  test('includes the island territories', () {
    // Radhanagar Beach is in the Andamans, so losing these rings to
    // simplification would drop a beach off the map entirely.
    bool hasPointNear(double lon, double lat, double slop) =>
        geometry.rings.any((ring) => ring.any((p) =>
            (p.longitude - lon).abs() < slop && (p.latitude - lat).abs() < slop));

    expect(hasPointNear(92.9, 11.9, 1.0), isTrue, reason: 'Andaman Islands');
    expect(hasPointNear(93.0, 7.2, 1.5), isTrue, reason: 'Nicobar Islands');
  });

  test('all coordinates fall inside the declared bounds', () {
    for (final ring in geometry.rings) {
      for (final p in ring) {
        expect(geometry.bounds.contains(p.longitude, p.latitude), isTrue,
            reason: '${p.longitude},${p.latitude} outside bbox');
      }
    }
  });

  test('caches so the asset is parsed only once', () async {
    final again = await IndiaGeometry.load();
    expect(identical(geometry, again), isTrue);
  });
}
