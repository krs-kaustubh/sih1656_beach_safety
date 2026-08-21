import 'package:beach_safety/features/maps/map_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MapGeometry geometry;

  setUpAll(() async {
    geometry = await MapGeometry.load();
  });

  test('loads India and its neighbours from the bundled asset', () {
    expect(geometry.countries.length, greaterThan(5));
    expect(geometry.india.isIndia, isTrue);
    expect(geometry.india.rings.first.length, greaterThan(100));

    // The neighbours the reference design calls for.
    final names = geometry.countries.map((c) => c.name).toSet();
    for (final neighbour in ['Pakistan', 'China', 'Nepal', 'Bangladesh',
                             'Myanmar', 'Sri Lanka', 'Bhutan']) {
      expect(names, contains(neighbour));
    }
  });

  test('every ring is a usable closed polygon', () {
    for (final country in geometry.countries) {
      for (final ring in country.rings) {
        expect(ring.length, greaterThanOrEqualTo(4));
      }
    }
  });

  test('every country has a label anchor inside the region', () {
    for (final country in geometry.countries) {
      expect(
        geometry.region.contains(
          country.labelPoint.longitude,
          country.labelPoint.latitude,
        ),
        isTrue,
        reason: '${country.name} label falls outside the map',
      );
    }
  });

  test('carries city labels including Indian metros', () {
    expect(geometry.cities, isNotEmpty);
    final names = geometry.cities.map((c) => c.name).toSet();
    expect(names, contains('Mumbai'));
    expect(names, contains('Chennai'));
    expect(names, contains('New Delhi'));
    // Natural Earth lists both "Delhi" and "New Delhi" at the same spot.
    expect(names, isNot(contains('Delhi')));
  });

  test('India spans its official extent', () {
    // India spans roughly 68°7'E–97°25'E and 6°45'N–37°6'N, the northern
    // limit reflecting the India point-of-view boundary for Jammu & Kashmir.
    final pts = geometry.india.rings.expand((r) => r);
    final lons = pts.map((p) => p.longitude);
    final lats = pts.map((p) => p.latitude);
    expect(lons.reduce((a, b) => a < b ? a : b), closeTo(68.14, 0.3));
    expect(lons.reduce((a, b) => a > b ? a : b), closeTo(97.36, 0.3));
    expect(lats.reduce((a, b) => a > b ? a : b), closeTo(37.05, 0.3));
  });

  test('the region is wide enough to show the neighbours', () {
    expect(geometry.region.west, lessThan(68.0));
    expect(geometry.region.east, greaterThan(97.4));
    expect(geometry.region.north, greaterThan(37.0));
  });

  test('includes the island territories', () {
    // Radhanagar Beach is in the Andamans, so losing these rings to
    // simplification would drop a beach off the map entirely.
    bool hasPointNear(double lon, double lat, double slop) =>
        geometry.india.rings.any((ring) => ring.any((p) =>
            (p.longitude - lon).abs() < slop && (p.latitude - lat).abs() < slop));

    expect(hasPointNear(92.9, 11.9, 1.0), isTrue, reason: 'Andaman Islands');
    expect(hasPointNear(93.0, 7.2, 1.5), isTrue, reason: 'Nicobar Islands');
  });

  test('India lies entirely inside the mapped region', () {
    for (final ring in geometry.india.rings) {
      for (final p in ring) {
        expect(geometry.region.contains(p.longitude, p.latitude), isTrue,
            reason: '${p.longitude},${p.latitude} outside the region');
      }
    }
  });

  test('caches so the asset is parsed only once', () async {
    final again = await MapGeometry.load();
    expect(identical(geometry, again), isTrue);
  });
}
