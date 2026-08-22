// File: lib/settings/unit_formatter.dart
// Description: Utility class for formatting environmental readings (wave height, wind speed, temperatures, UV index) and alert timestamps according to user unit settings.

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/safety_alert.dart';
import 'app_settings.dart';

// One formatted reading: the number and the unit shown beside it.
@immutable
class Reading {
  const Reading(this.value, this.unit);
  final String value;
  final String? unit;
}

// Formats every measurement and clock in the app according to AppSettings.
@immutable
class UnitFormatter {
  UnitFormatter(this.settings)
      : _clock = DateFormat(settings.timeFormat.pattern),
        _hour = DateFormat(settings.timeFormat.hourPattern);

  final AppSettings settings;
  final DateFormat _clock;
  final DateFormat _hour;

  // Formats wall-clock time depending on chosen format.
  String clock(DateTime time) => _clock.format(time);

  // Formats time window endpoints.
  String hour(DateTime time) => _hour.format(time);


  // Trims a trailing .0 so 2.8 stays 2.8 but 3.0 becomes 3.
  static String number(double value, {int decimals = 1}) {
    final text = value.toStringAsFixed(decimals);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  Reading waveHeight(double metres) {
    final unit = settings.waveHeightUnit;
    return Reading(
      number(unit.fromMetres(metres), decimals: unit.decimals),
      unit.symbol,
    );
  }

  // Wind speed, with the compass direction appended when known.
  Reading windSpeed(double? kmh, {String? direction}) {
    if (kmh == null) return Reading('—', null);
    final unit = settings.windSpeedUnit;
    return Reading(
      number(unit.fromKmh(kmh), decimals: 0),
      [unit.symbol, ?direction].join(" "),
    );
  }

  Reading temperature(double? celsius) {
    if (celsius == null) return const Reading('—', null);
    final unit = settings.temperatureUnit;
    return Reading(
      '${number(unit.fromCelsius(celsius), decimals: 0)}${unit.symbol}',
      null,
    );
  }

  // UV index is a unitless number and is shown whole.
  String uv(double value) => value.round().toString();

  // The meta line under an alert title.
  String alertMeta(SafetyAlert alert) {
    final time = switch (alert.timeStyle) {
      AlertTimeStyle.window when alert.validUntil != null =>
        '${hour(alert.issuedAt)} – ${hour(alert.validUntil!)}',
      _ => 'Issued ${clock(alert.issuedAt)}',
    };
    return alert.zoneLabel.isEmpty ? time : '$time  •  ${alert.zoneLabel}';
  }

  // Updated timestamp line on detail header.
  String alertValidity(SafetyAlert alert) {
    final updated = 'Updated ${clock(alert.issuedAt)}';
    if (alert.validUntil == null) return updated;
    return '$updated  ·  Valid until ${clock(alert.validUntil!)}';
  }
}

