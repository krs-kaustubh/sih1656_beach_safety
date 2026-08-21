import 'package:beach_safety/models/beach.dart';
import 'package:beach_safety/models/conditions.dart';
import 'package:beach_safety/models/risk_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RiskLevel.fromApi', () {
    test('maps the backend safety_status values', () {
      expect(RiskLevel.fromApi('Green'), RiskLevel.low);
      expect(RiskLevel.fromApi('Amber'), RiskLevel.moderate);
      expect(RiskLevel.fromApi('Red'), RiskLevel.high);
    });

    test('is tolerant of case and whitespace', () {
      expect(RiskLevel.fromApi('  red '), RiskLevel.high);
      expect(RiskLevel.fromApi('AMBER'), RiskLevel.moderate);
    });

    test('falls back to moderate rather than low for unknown input', () {
      // Failing safe would be worse than failing cautious here: an unknown
      // status must never render as "safe to swim".
      expect(RiskLevel.fromApi(null), RiskLevel.moderate);
      expect(RiskLevel.fromApi('Chartreuse'), RiskLevel.moderate);
      expect(RiskLevel.fromApi(''), RiskLevel.moderate);
    });
  });

  group('Beach.fromJson', () {
    // Exactly the payload the live backend serves today.
    final livePayload = <String, dynamic>{
      'id': 1,
      'name': 'Juhu Beach, Mumbai',
      'latitude': 19.0988,
      'longitude': 72.8267,
      'wave_height_meters': 2.8,
      'current_speed_knots': 4.5,
      'water_quality': 'Poor',
      'safety_status': 'Red',
    };

    test('parses the current backend payload', () {
      final beach = Beach.fromJson(livePayload);
      expect(beach.id, 1);
      expect(beach.riskLevel, RiskLevel.high);
      expect(beach.conditions.waveHeightMeters, 2.8);
      expect(beach.conditions.waterQuality, 'Poor');
    });

    test('splits the packed name into title and region', () {
      final beach = Beach.fromJson(livePayload);
      expect(beach.name, 'Juhu Beach');
      expect(beach.region, 'Mumbai');
    });

    test('prefers an explicit region field when the backend adds one', () {
      final beach = Beach.fromJson({
        ...livePayload,
        'region': 'Mumbai, West Coast',
      });
      expect(beach.name, 'Juhu Beach');
      expect(beach.region, 'Mumbai, West Coast');
    });

    test('handles a name with no comma', () {
      final beach = Beach.fromJson({...livePayload, 'name': 'Juhu Beach'});
      expect(beach.name, 'Juhu Beach');
      expect(beach.region, '');
    });

    test('leaves fields the backend does not send as null', () {
      final beach = Beach.fromJson(livePayload);
      expect(beach.conditions.windSpeedKph, isNull);
      expect(beach.conditions.uvIndex, isNull);
      expect(beach.conditions.nextTide, isNull);
      expect(beach.conditions.waterTempCelsius, isNull);
    });

    test('picks up the richer fields once the backend sends them', () {
      final beach = Beach.fromJson({
        ...livePayload,
        'wind_speed_kph': 32,
        'wind_direction': 'SW',
        'uv_index': 9,
        'water_temp_celsius': 28,
        'next_tide': {'time': '2026-08-21T12:30:00', 'phase': 'High'},
      });
      expect(beach.conditions.windSpeedKph, 32);
      expect(beach.conditions.windDirection, 'SW');
      expect(beach.conditions.uvIndex, 9);
      expect(beach.conditions.nextTide!.phase, TidePhase.high);
      expect(beach.conditions.nextTide!.time.hour, 12);
    });

    test('survives an unexpected or malformed payload', () {
      final beach = Beach.fromJson(<String, dynamic>{});
      expect(beach.id, -1);
      expect(beach.conditions.waveHeightMeters, 0);
      expect(beach.riskLevel, RiskLevel.moderate);
    });
  });

  group('UvBand.fromIndex', () {
    test('follows the WHO Global Solar UV Index bands', () {
      expect(UvBand.fromIndex(2), UvBand.low);
      expect(UvBand.fromIndex(3), UvBand.moderate);
      expect(UvBand.fromIndex(6), UvBand.high);
      expect(UvBand.fromIndex(8), UvBand.veryHigh);
      expect(UvBand.fromIndex(11), UvBand.extreme);
    });
  });
}
