import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'india_geometry.dart';

/// Maps lon/lat onto a canvas, fitting India's bounds inside [size] without
/// distorting the aspect ratio.
///
/// Built once per layout and shared by the painter and by hit-testing, so a
/// marker is always drawn exactly where a tap will find it.
@immutable
class MapProjection {
  const MapProjection._({
    required this.size,
    required this.scale,
    required this.originX,
    required this.originY,
  });

  factory MapProjection.fit({
    required GeoBounds bounds,
    required Size size,
    double padding = 12,
  }) {
    final left = Mercator.x(bounds.west);
    final right = Mercator.x(bounds.east);
    final top = Mercator.y(bounds.north);
    final bottom = Mercator.y(bounds.south);

    final spanX = right - left;
    final spanY = top - bottom;

    final usableW = (size.width - padding * 2).clamp(1.0, double.infinity);
    final usableH = (size.height - padding * 2).clamp(1.0, double.infinity);

    // Uniform scale on both axes: anything else stretches the coastline.
    final scale = (usableW / spanX) < (usableH / spanY)
        ? usableW / spanX
        : usableH / spanY;

    // Centre whatever slack the fit leaves over.
    final originX = (size.width - spanX * scale) / 2 - left * scale;
    final originY = (size.height - spanY * scale) / 2 + top * scale;

    return MapProjection._(
      size: size,
      scale: scale,
      originX: originX,
      originY: originY,
    );
  }

  final Size size;

  /// Canvas pixels per unit of projected (Mercator) space.
  final double scale;

  final double originX;
  final double originY;

  Offset toCanvas(double longitude, double latitude) => Offset(
        originX + Mercator.x(longitude) * scale,
        originY - Mercator.y(latitude) * scale,
      );

  Offset pointToCanvas(GeoPoint p) => toCanvas(p.longitude, p.latitude);

  // Value equality so the painter can skip repaints when a rebuild produces
  // an identical projection.
  @override
  bool operator ==(Object other) =>
      other is MapProjection &&
      other.size == size &&
      other.scale == scale &&
      other.originX == originX &&
      other.originY == originY;

  @override
  int get hashCode => Object.hash(size, scale, originX, originY);
}
