import 'package:flutter/foundation.dart';

import 'beach.dart';
import 'conditions.dart';
import 'risk_level.dart';
import 'safety_alert.dart';

/// The `/beaches/{location}/weather` payload.
///
/// This is where the live data lives — risk rating, conditions and alerts in
/// one response — while `/beaches` only carries the roster and a static
/// safety_status from the service's own fixtures.
@immutable
class BeachWeather {
  const BeachWeather({
    required this.locationId,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.observedAt,
    required this.dataSource,
    required this.riskLevel,
    required this.riskTitle,
    required this.riskDescription,
    required this.conditions,
    required this.alerts,
  });

  /// The slug the weather endpoint is keyed by: `juhu`, `marina`, …
  final String locationId;

  final String locationName;
  final double latitude;
  final double longitude;

  /// When the service assembled this reading — shown as data freshness.
  final DateTime observedAt;

  /// Which providers answered, e.g. "Tomorrow.io + Open-Meteo Marine".
  final String dataSource;

  final RiskLevel riskLevel;
  final String riskTitle;
  final String riskDescription;
  final Conditions conditions;
  final List<WeatherAlertPayload> alerts;

  factory BeachWeather.fromJson(Map<String, dynamic> json) {
    double? asDouble(Object? v) => v == null ? null : (v as num).toDouble();
    final observedAt =
        DateTime.tryParse(json['timestamp'] as String? ?? '')?.toLocal() ??
            DateTime.now();

    return BeachWeather(
      locationId: json['location_id'] as String? ?? '',
      locationName: json['location_name'] as String? ?? '',
      latitude: asDouble(json['latitude']) ?? 0,
      longitude: asDouble(json['longitude']) ?? 0,
      observedAt: observedAt,
      dataSource: json['data_source'] as String? ?? 'Unknown',
      riskLevel: RiskLevel.fromApi(json['severity_mode'] as String?),
      riskTitle: json['risk_title'] as String? ?? '',
      riskDescription: json['risk_description'] as String? ?? '',
      conditions: Conditions(
        waveHeightMeters: asDouble(json['wave_height']) ?? 0,
        windSpeedKph: asDouble(json['wind_speed']),
        windDirection: json['wind_direction'] as String?,
        uvIndex: asDouble(json['uv_index']),
        uvCategory: json['uv_category'] as String?,
        waterTempCelsius: asDouble(json['temperature_c']),
        nextTide: _parseTide(
          json['next_tide_time'] as String?,
          json['next_tide_type'] as String?,
          observedAt,
        ),
      ),
      alerts: (json['alerts'] as List<dynamic>? ?? const [])
          .map((a) => WeatherAlertPayload.fromJson(a as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  /// The service sends the next tide as a bare wall-clock time ("14:15") with
  /// no date. It is anchored to the reading's own day, and rolled forward when
  /// that would place it in the past — the *next* tide cannot already have
  /// happened.
  static TideInfo? _parseTide(String? time, String? type, DateTime observedAt) {
    if (time == null) return null;
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;

    var at = DateTime(
      observedAt.year,
      observedAt.month,
      observedAt.day,
      hour,
      minute,
    );
    if (at.isBefore(observedAt)) {
      at = at.add(const Duration(days: 1));
    }
    return TideInfo(time: at, phase: TidePhase.fromApi(type));
  }

  /// Folds the live reading into the roster entry from `/beaches`.
  ///
  /// The roster's own `safety_status` comes from static fixtures, so the live
  /// risk always wins.
  Beach applyTo(Beach beach) => beach.copyWith(
        riskLevel: riskLevel,
        conditions: conditions.copyWith(waterQuality: beach.conditions.waterQuality),
        riskSummary: riskDescription,
      );

  /// Alerts in the app's own shape.
  ///
  /// The service's alert objects are far thinner than the designs: a type, a
  /// title, a time and a scope. There is no per-alert severity, no validity
  /// window and no guidance text, so severity is inherited from the beach and
  /// the guidance sections are left empty for the detail screen to hide.
  List<SafetyAlert> toSafetyAlerts(int beachId) => [
        for (final (index, alert) in alerts.indexed)
          SafetyAlert(
            id: '$locationId-$index',
            beachId: beachId,
            kind: _kindFor(alert.alertType, alert.title),
            riskLevel: riskLevel,
            urgency: riskLevel == RiskLevel.low
                ? AlertUrgency.advisory
                : AlertUrgency.actNow,
            title: alert.title,
            summary: alert.alertType,
            zoneLabel: alert.locationScope,
            issuedAt: alert.issuedAt,
            conditions: conditions,
          ),
      ];

  /// The service names alert types in prose ("Cyclonic Swell Advisory",
  /// "Extreme Solar Radiation Alert"), so the icon is chosen by keyword.
  static AlertKind _kindFor(String type, String title) {
    final text = '$type $title'.toLowerCase();
    if (text.contains('rip') || text.contains('current')) {
      return AlertKind.ripCurrent;
    }
    if (text.contains('uv') || text.contains('solar') || text.contains('sun')) {
      return AlertKind.uv;
    }
    if (text.contains('wind') || text.contains('gale')) return AlertKind.wind;
    if (text.contains('swell') || text.contains('wave') || text.contains('surge')) {
      return AlertKind.ripCurrent;
    }
    if (text.contains('quality') || text.contains('pollut')) {
      return AlertKind.waterQuality;
    }
    return AlertKind.general;
  }
}

@immutable
class WeatherAlertPayload {
  const WeatherAlertPayload({
    required this.alertType,
    required this.title,
    required this.issuedAt,
    required this.locationScope,
  });

  final String alertType;
  final String title;
  final DateTime issuedAt;
  final String locationScope;

  factory WeatherAlertPayload.fromJson(Map<String, dynamic> json) =>
      WeatherAlertPayload(
        alertType: json['alert_type'] as String? ?? 'Advisory',
        title: json['title'] as String? ?? 'Safety Alert',
        issuedAt:
            DateTime.tryParse(json['issued_time'] as String? ?? '')?.toLocal() ??
                DateTime.now(),
        locationScope: json['location_scope'] as String? ?? '',
      );
}
