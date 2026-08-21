import 'package:flutter/foundation.dart';

/// Whether the next tide event is a high or a low tide.
enum TidePhase {
  low('Low'),
  high('High');

  const TidePhase(this.label);
  final String label;

  static TidePhase fromApi(String? value) =>
      (value ?? '').trim().toLowerCase() == 'high' ? TidePhase.high : TidePhase.low;
}

/// UV exposure band. Thresholds follow the WHO Global Solar UV Index.
enum UvBand {
  low('Low'),
  moderate('Moderate'),
  high('High'),
  veryHigh('Very High'),
  extreme('Extreme');

  const UvBand(this.label);
  final String label;

  static UvBand fromIndex(double index) {
    if (index < 3) return UvBand.low;
    if (index < 6) return UvBand.moderate;
    if (index < 8) return UvBand.high;
    if (index < 11) return UvBand.veryHigh;
    return UvBand.extreme;
  }
}

/// The next tide turn: when it happens and which way it is going.
@immutable
class TideInfo {
  const TideInfo({required this.time, required this.phase});

  final DateTime time;
  final TidePhase phase;

  factory TideInfo.fromJson(Map<String, dynamic> json) => TideInfo(
        time: DateTime.parse(json['time'] as String),
        phase: TidePhase.fromApi(json['phase'] as String?),
      );
}

/// A snapshot of measurable conditions at a beach.
///
/// The live backend currently returns only [waveHeightMeters] and
/// [currentSpeedKnots] (plus a water-quality string). Every other field is
/// modelled here because the designs display it, and is nullable so the UI can
/// degrade gracefully until the backend catches up — see [fromJson].
@immutable
class Conditions {
  const Conditions({
    required this.waveHeightMeters,
    this.currentSpeedKnots,
    this.windSpeedKph,
    this.windDirection,
    this.uvIndex,
    this.nextTide,
    this.waterTempCelsius,
    this.waterQuality,
    this.uvCategory,
  });

  final double waveHeightMeters;
  final double? currentSpeedKnots;
  final double? windSpeedKph;

  /// Compass abbreviation such as `SW`.
  final String? windDirection;
  final double? uvIndex;
  final TideInfo? nextTide;
  final double? waterTempCelsius;

  /// Free-form on the backend today ("Excellent" / "Moderate" / "Poor"), so it
  /// is deliberately kept as a string rather than forced into an enum.
  final String? waterQuality;

  /// The service's own UV wording, when it sends one. Preferred over the
  /// locally derived band so the app never contradicts the service about how
  /// dangerous the sun is.
  final String? uvCategory;

  UvBand? get uvBand => uvIndex == null ? null : UvBand.fromIndex(uvIndex!);

  /// What to print beside the UV number.
  String? get uvLabel => uvCategory ?? uvBand?.label;

  /// Tolerant parser: unknown fields are ignored and missing fields become
  /// null rather than throwing, so a backend that grows new fields — or lags
  /// behind the designs — never crashes the client.
  factory Conditions.fromJson(Map<String, dynamic> json) {
    double? asDouble(Object? v) => v == null ? null : (v as num).toDouble();
    return Conditions(
      waveHeightMeters: asDouble(json['wave_height_meters']) ?? 0,
      currentSpeedKnots: asDouble(json['current_speed_knots']),
      windSpeedKph: asDouble(json['wind_speed_kph']),
      windDirection: json['wind_direction'] as String?,
      uvIndex: asDouble(json['uv_index']),
      nextTide: json['next_tide'] == null
          ? null
          : TideInfo.fromJson(json['next_tide'] as Map<String, dynamic>),
      waterTempCelsius: asDouble(json['water_temp_celsius']),
      waterQuality: json['water_quality'] as String?,
      uvCategory: json['uv_category'] as String?,
    );
  }

  Conditions copyWith({
    double? waveHeightMeters,
    double? windSpeedKph,
    String? windDirection,
    double? uvIndex,
    TideInfo? nextTide,
    double? waterTempCelsius,
    String? waterQuality,
    String? uvCategory,
  }) =>
      Conditions(
        waveHeightMeters: waveHeightMeters ?? this.waveHeightMeters,
        currentSpeedKnots: currentSpeedKnots,
        windSpeedKph: windSpeedKph ?? this.windSpeedKph,
        windDirection: windDirection ?? this.windDirection,
        uvIndex: uvIndex ?? this.uvIndex,
        nextTide: nextTide ?? this.nextTide,
        waterTempCelsius: waterTempCelsius ?? this.waterTempCelsius,
        waterQuality: waterQuality ?? this.waterQuality,
        uvCategory: uvCategory ?? this.uvCategory,
      );
}
