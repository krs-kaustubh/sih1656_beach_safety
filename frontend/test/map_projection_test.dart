// File: test/map_projection_test.dart
// Description: Unit test suite verifying Web Mercator projection calculations, geographic bounds checking, and canvas coordinate mapping.

import 'dart:math' as math;
import 'dart:ui';

import 'package:beach_safety/features/maps/map_geometry.dart';
import 'package:beach_safety/features/maps/map_projection.dart';
import 'package:flutter_test/flutter_test.dart';

// India's full extent bounding box for testing.
const _india = GeoBounds(
  west: 68.1434,
  south: 6.7456,
  east: 97.3623,
  north: 37.0545,
);

void main() {

  group('Mercator', () {
    test('is symmetric about the equator', () {
      expect(Mercator.y(20), closeTo(-Mercator.y(-20), 1e-9));
    });

    test('maps the equator to zero', () {
      expect(Mercator.y(0), closeTo(0, 1e-9));
    });

    test('stretches spacing towards the poles', () {
      // The whole point of using Mercator over a raw lat/lon plot: a degree
      // near 35N must occupy more vertical space than a degree near 10N.
      final low = Mercator.y(11) - Mercator.y(10);
      final high = Mercator.y(36) - Mercator.y(35);
      expect(high, greaterThan(low));
    });

    test('clamps beyond the projection limit instead of returning infinity', () {
      expect(Mercator.y(90).isFinite, isTrue);
      expect(Mercator.y(-90).isFinite, isTrue);
    });
  });

  group('MapProjection.fit', () {
    const size = Size(360, 800);
    final projection = MapProjection.fit(bounds: _india, size: size);

    test('keeps the whole country inside the canvas', () {
      final corners = [
        projection.toCanvas(_india.west, _india.north),
        projection.toCanvas(_india.east, _india.north),
        projection.toCanvas(_india.west, _india.south),
        projection.toCanvas(_india.east, _india.south),
      ];
      for (final c in corners) {
        expect(c.dx, inInclusiveRange(0, size.width));
        expect(c.dy, inInclusiveRange(0, size.height));
      }
    });

    test('puts north above south and east right of west', () {
      final north = projection.toCanvas(78, 35);
      final south = projection.toCanvas(78, 10);
      expect(north.dy, lessThan(south.dy));

      final west = projection.toCanvas(70, 20);
      final east = projection.toCanvas(95, 20);
      expect(west.dx, lessThan(east.dx));
    });

    test('does not distort the aspect ratio', () {
      // A span that is square in projected units must stay square on canvas.
      const lonSpan = 4.0;
      final a = projection.toCanvas(75, 15);
      final b = projection.toCanvas(75 + lonSpan, 15);
      final horizontal = b.dx - a.dx;

      final yTop = Mercator.y(15) + lonSpan;
      final latTop = _inverseMercator(yTop);
      final c = projection.toCanvas(75, latTop);
      final vertical = a.dy - c.dy;

      expect(horizontal, closeTo(vertical, 0.01));
    });

    test('centres the fitted map in the leftover space', () {
      // India is roughly square, so a tall portrait canvas should leave equal
      // margins above and below.
      final top = projection.toCanvas(78, _india.north).dy;
      final bottom = projection.toCanvas(78, _india.south).dy;
      expect(top, closeTo(size.height - bottom, 0.01));
    });

    test('places real beaches on the correct side of the country', () {
      // Juhu is on the west coast, Marina on the east, Radhanagar far east
      // in the Andamans.
      final juhu = projection.toCanvas(72.8267, 19.0988);
      final marina = projection.toCanvas(80.2824, 13.0499);
      final radhanagar = projection.toCanvas(92.9548, 11.9841);

      expect(juhu.dx, lessThan(marina.dx));
      expect(marina.dx, lessThan(radhanagar.dx));

      // Juhu is well north of both southern beaches.
      expect(juhu.dy, lessThan(marina.dy));
    });

    test('value equality lets the painter skip redundant repaints', () {
      final same = MapProjection.fit(bounds: _india, size: size);
      final different = MapProjection.fit(bounds: _india, size: const Size(400, 800));
      expect(projection, equals(same));
      expect(projection, isNot(equals(different)));
    });
  });

  group('GeoBounds', () {
    test('contains points inside India and rejects points outside', () {
      expect(_india.contains(72.8267, 19.0988), isTrue); // Juhu
      expect(_india.contains(92.9548, 11.9841), isTrue); // Radhanagar
      expect(_india.contains(55.0, 25.0), isFalse); // Dubai
      expect(_india.contains(80.0, 45.0), isFalse); // north of the bbox
    });
  });
}

// Inverse Web Mercator for testing square spans.
double _inverseMercator(double y) {

  final phi = 2 * math.atan(math.exp(y * math.pi / 180)) - math.pi / 2;
  return phi * 180 / math.pi;
}
