import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// India's outline, loaded once from the bundled GeoJSON-derived asset.
///
/// Source: Natural Earth 1:10m admin-0 countries, **India point-of-view**
/// edition (`ne_10m_admin_0_countries_ind`), public domain. The India POV
/// edition matters: the default Natural Earth release draws Jammu & Kashmir on
/// de-facto control lines rather than India's official boundary, which is the
/// wrong depiction to ship in an Indian government context.
@immutable
class IndiaGeometry {
  const IndiaGeometry({required this.rings, required this.bounds});

  /// Closed polygon rings in lon/lat degrees, largest first. Includes the
  /// mainland, Andaman & Nicobar and Lakshadweep.
  final List<List<GeoPoint>> rings;

  final GeoBounds bounds;

  static IndiaGeometry? _cached;

  /// Parses the asset, caching the result — the geometry never changes, and
  /// re-parsing 3,000 points on every rebuild would be wasteful.
  static Future<IndiaGeometry> load() async {
    if (_cached != null) return _cached!;

    final raw = await rootBundle.loadString('assets/geo/india.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;

    final bbox = (json['bbox'] as List<dynamic>).cast<num>();
    final rings = (json['rings'] as List<dynamic>)
        .map((ring) => (ring as List<dynamic>)
            .map((p) => GeoPoint(
                  (p as List<dynamic>)[0].toDouble() as double,
                  p[1].toDouble() as double,
                ))
            .toList(growable: false))
        .toList(growable: false);

    return _cached = IndiaGeometry(
      rings: rings,
      bounds: GeoBounds(
        west: bbox[0].toDouble(),
        south: bbox[1].toDouble(),
        east: bbox[2].toDouble(),
        north: bbox[3].toDouble(),
      ),
    );
  }
}

@immutable
class GeoPoint {
  const GeoPoint(this.longitude, this.latitude);
  final double longitude;
  final double latitude;
}

@immutable
class GeoBounds {
  const GeoBounds({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  final double west;
  final double south;
  final double east;
  final double north;

  bool contains(double lon, double lat) =>
      lon >= west && lon <= east && lat >= south && lat <= north;
}

/// Web Mercator, the projection people expect a map to use.
///
/// Latitude spacing widens toward the poles, so a plain lon/lat plot would
/// squash the north. India spans 6.7°N to 37°N, where that distortion is
/// visible enough to be worth correcting.
abstract final class Mercator {
  static double x(double longitudeDegrees) => longitudeDegrees;

  static double y(double latitudeDegrees) {
    final clamped = latitudeDegrees.clamp(-85.05, 85.05);
    return (180 / math.pi) *
        math.log(math.tan(math.pi / 4 + clamped * math.pi / 360));
  }
}
