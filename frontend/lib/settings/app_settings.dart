// File: lib/settings/app_settings.dart
// Description: User configuration options including unit choices (distance, speed, temperature), time format preferences, alert filtering levels, and default beach selections.

import 'package:flutter/foundation.dart';

import '../models/risk_level.dart';

// Unit for wave height.
enum DistanceUnit {
  metres('m', 'Metres'),
  feet('ft', 'Feet');

  const DistanceUnit(this.symbol, this.label);
  final String symbol;
  final String label;

  // Wave heights arrive from the backend in metres.
  double fromMetres(double metres) =>
      this == DistanceUnit.feet ? metres * 3.28084 : metres;

  // Feet need no decimal at beach-wave scale; metres do.
  int get decimals => this == DistanceUnit.feet ? 0 : 1;
}

// Unit for wind and current speed.
enum SpeedUnit {
  kmh('km/h', 'Kilometres per hour'),
  knots('kn', 'Knots'),
  mph('mph', 'Miles per hour');

  const SpeedUnit(this.symbol, this.label);
  final String symbol;
  final String label;

  // Wind arrives from the backend in km/h.
  double fromKmh(double kmh) => switch (this) {
        SpeedUnit.kmh => kmh,
        SpeedUnit.knots => kmh * 0.539957,
        SpeedUnit.mph => kmh * 0.621371,
      };
}

enum TemperatureUnit {
  celsius('°C', 'Celsius'),
  fahrenheit('°F', 'Fahrenheit');

  const TemperatureUnit(this.symbol, this.label);
  final String symbol;
  final String label;

  double fromCelsius(double c) =>
      this == TemperatureUnit.fahrenheit ? c * 9 / 5 + 32 : c;
}

enum TimeFormat {
  twelveHour('12-hour', '12h', 'h:mm a'),
  twentyFourHour('24-hour', '24h', 'HH:mm');

  const TimeFormat(this.label, this.shortLabel, this.pattern);
  final String label;

  // Compact form for unit-symbol pills.
  final String shortLabel;

  // Pattern used for every clock in the app.
  final String pattern;


  String get hourPattern =>
      this == TimeFormat.twelveHour ? 'h a' : 'HH:00';
}

// Which alerts the Alerts tab and Home list should surface.
enum AlertSeverityFilter {
  all('All alerts', 'Show every advisory and warning'),
  moderateAndAbove('Moderate and above', 'Hide low-risk advisories'),
  severeOnly('Severe only', 'Only the most serious warnings');

  const AlertSeverityFilter(this.label, this.description);
  final String label;
  final String description;

  bool allows(RiskLevel level) => switch (this) {
        AlertSeverityFilter.all => true,
        AlertSeverityFilter.moderateAndAbove => level != RiskLevel.low,
        AlertSeverityFilter.severeOnly => level == RiskLevel.high,
      };
}

// Everything the user can configure. Immutable so changes produce new values.
@immutable
class AppSettings {
  const AppSettings({
    this.waveHeightUnit = DistanceUnit.metres,
    this.windSpeedUnit = SpeedUnit.kmh,
    this.temperatureUnit = TemperatureUnit.celsius,
    this.timeFormat = TimeFormat.twelveHour,
    this.alertFilter = AlertSeverityFilter.all,
    this.defaultBeachId,
  });

  final DistanceUnit waveHeightUnit;
  final SpeedUnit windSpeedUnit;
  final TemperatureUnit temperatureUnit;
  final TimeFormat timeFormat;
  final AlertSeverityFilter alertFilter;

  // Beach shown on launch. Null means whichever the backend lists first.
  final int? defaultBeachId;


  static const defaults = AppSettings();

  AppSettings copyWith({
    DistanceUnit? waveHeightUnit,
    SpeedUnit? windSpeedUnit,
    TemperatureUnit? temperatureUnit,
    TimeFormat? timeFormat,
    AlertSeverityFilter? alertFilter,
    int? defaultBeachId,
    bool clearDefaultBeach = false,
  }) =>
      AppSettings(
        waveHeightUnit: waveHeightUnit ?? this.waveHeightUnit,
        windSpeedUnit: windSpeedUnit ?? this.windSpeedUnit,
        temperatureUnit: temperatureUnit ?? this.temperatureUnit,
        timeFormat: timeFormat ?? this.timeFormat,
        alertFilter: alertFilter ?? this.alertFilter,
        defaultBeachId:
            clearDefaultBeach ? null : (defaultBeachId ?? this.defaultBeachId),
      );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.waveHeightUnit == waveHeightUnit &&
      other.windSpeedUnit == windSpeedUnit &&
      other.temperatureUnit == temperatureUnit &&
      other.timeFormat == timeFormat &&
      other.alertFilter == alertFilter &&
      other.defaultBeachId == defaultBeachId;

  @override
  int get hashCode => Object.hash(waveHeightUnit, windSpeedUnit,
      temperatureUnit, timeFormat, alertFilter, defaultBeachId);
}
