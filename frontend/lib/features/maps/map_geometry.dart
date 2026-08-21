import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// The India region's countries and cities, loaded once from the bundled
/// asset.
///
/// Source: Natural Earth 1:10m admin-0 countries, **India point-of-view**
/// edition (`ne_10m_admin_0_countries_ind`), plus populated places. Public
/// domain. The India POV edition matters: the default Natural Earth release
/// draws Jammu & Kashmir on de-facto control lines rather than India's official
/// boundary, which is the wrong depiction to ship in an Indian government
/// context.
@immutable
class MapGeometry {
  MapGeometry({
    required this.countries,
    required this.cities,
    required this.region,
  });

  /// India first, then neighbours by descending area.
  final List<CountryShape> countries;

  final List<CityLabel> cities;

  /// The full extent the map covers — India plus enough of its neighbours to
  /// give it context. Pan and zoom are bounded to this.
  final GeoBounds region;

  static MapGeometry? _cached;

  static Future<MapGeometry> load() async {
    if (_cached != null) return _cached!;

    final raw = await rootBundle.loadString('assets/geo/region.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;

    final box = (json['region'] as List<dynamic>).cast<num>();

    return _cached = MapGeometry(
      countries: (json['countries'] as List<dynamic>)
          .map((c) => CountryShape.fromJson(c as Map<String, dynamic>))
          .toList(growable: false),
      cities: (json['cities'] as List<dynamic>? ?? const [])
          .map((c) => CityLabel.fromJson(c as Map<String, dynamic>))
          .toList(growable: false),
      region: GeoBounds(
        west: box[0].toDouble(),
        south: box[1].toDouble(),
        east: box[2].toDouble(),
        north: box[3].toDouble(),
      ),
    );
  }

  /// India's own shape, used for the highlighted border.
  CountryShape get india =>
      countries.firstWhere((c) => c.isIndia, orElse: () => countries.first);

  /// India's extent, which is what the map opens on. The wider [region] is
  /// only reachable by zooming out.
  late final GeoBounds indiaBounds = _boundsOf(india);

  static GeoBounds _boundsOf(CountryShape country) {
    var west = 180.0, east = -180.0, south = 90.0, north = -90.0;
    for (final ring in country.rings) {
      for (final p in ring) {
        if (p.longitude < west) west = p.longitude;
        if (p.longitude > east) east = p.longitude;
        if (p.latitude < south) south = p.latitude;
        if (p.latitude > north) north = p.latitude;
      }
    }
    return GeoBounds(west: west, south: south, east: east, north: north);
  }
}

@immutable
class CountryShape {
  const CountryShape({
    required this.name,
    required this.iso,
    required this.isIndia,
    required this.labelPoint,
    required this.rings,
  });

  final String name;
  final String iso;
  final bool isIndia;

  /// Cartographer-placed label anchor from Natural Earth, falling back to the
  /// largest ring's centroid.
  final GeoPoint labelPoint;

  final List<List<GeoPoint>> rings;

  factory CountryShape.fromJson(Map<String, dynamic> json) {
    final label = (json['label'] as List<dynamic>).cast<num>();
    return CountryShape(
      name: json['name'] as String? ?? '',
      iso: json['iso'] as String? ?? '',
      isIndia: json['isIndia'] as bool? ?? false,
      labelPoint: GeoPoint(label[0].toDouble(), label[1].toDouble()),
      rings: (json['rings'] as List<dynamic>)
          .map((ring) => (ring as List<dynamic>)
              .map((p) => GeoPoint(
                    (p as List<dynamic>)[0].toDouble() as double,
                    p[1].toDouble() as double,
                  ))
              .toList(growable: false))
          .toList(growable: false),
    );
  }
}

@immutable
class CityLabel {
  const CityLabel({
    required this.name,
    required this.point,
    required this.rank,
    required this.isCapital,
  });

  final String name;
  final GeoPoint point;

  /// Natural Earth scale rank — lower means it stays visible when zoomed out.
  final int rank;

  final bool isCapital;

  factory CityLabel.fromJson(Map<String, dynamic> json) => CityLabel(
        name: json['name'] as String? ?? '',
        point: GeoPoint(
          (json['lon'] as num).toDouble(),
          (json['lat'] as num).toDouble(),
        ),
        rank: (json['rank'] as num?)?.toInt() ?? 99,
        isCapital: json['capital'] as bool? ?? false,
      );
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
/// squash the north. The region spans 2°N to 40.5°N, where that distortion is
/// visible enough to be worth correcting. The bundled terrain texture is
/// pre-reprojected to match.
abstract final class Mercator {
  static double x(double longitudeDegrees) => longitudeDegrees;

  static double y(double latitudeDegrees) {
    final clamped = latitudeDegrees.clamp(-85.05, 85.05);
    return (180 / math.pi) *
        math.log(math.tan(math.pi / 4 + clamped * math.pi / 360));
  }
}
