import 'package:flutter/foundation.dart';

import 'conditions.dart';
import 'risk_level.dart';

/// A beach and its current safety picture.
@immutable
class Beach {
  const Beach({
    required this.id,
    this.locationId,
    required this.name,
    required this.region,
    required this.latitude,
    required this.longitude,
    required this.riskLevel,
    required this.conditions,
    this.riskSummary = '',
  });

  final int id;

  /// The key the weather endpoint uses (`juhu`, `marina`, ...). Null on older
  /// builds of the service, which did not send it.
  final String? locationId;

  /// Display name. The backend ships this as "Juhu Beach, Mumbai"; the designs
  /// split it into a title and a region subtitle, which [fromJson] handles.
  final String name;

  /// Subtitle under the beach name, e.g. "Mumbai, West Coast".
  final String region;

  final double latitude;
  final double longitude;
  final RiskLevel riskLevel;
  final Conditions conditions;

  /// Sentence shown inside the risk banner on Home.
  final String riskSummary;

  factory Beach.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'] as String? ?? 'Unknown Beach';

    // The backend packs name and city into one string ("Juhu Beach, Mumbai").
    // The designs need them apart, so split on the first comma and treat the
    // remainder as the region. An explicit `region` field, if the backend ever
    // adds one, wins over the split.
    final commaIndex = rawName.indexOf(',');
    final hasSplit = commaIndex > 0;
    final title = hasSplit ? rawName.substring(0, commaIndex).trim() : rawName;
    final derivedRegion = hasSplit ? rawName.substring(commaIndex + 1).trim() : '';

    return Beach(
      id: (json['id'] as num?)?.toInt() ?? -1,
      locationId: json['location_id'] as String?,
      name: title,
      region: json['region'] as String? ?? derivedRegion,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      riskLevel: RiskLevel.fromApi(json['safety_status'] as String?),
      conditions: Conditions.fromJson(json),
      riskSummary: json['risk_summary'] as String? ?? '',
    );
  }

  Beach copyWith({
    String? region,
    RiskLevel? riskLevel,
    Conditions? conditions,
    String? riskSummary,
  }) =>
      Beach(
        id: id,
        locationId: locationId,
        name: name,
        region: region ?? this.region,
        latitude: latitude,
        longitude: longitude,
        riskLevel: riskLevel ?? this.riskLevel,
        conditions: conditions ?? this.conditions,
        riskSummary: riskSummary ?? this.riskSummary,
      );
}
