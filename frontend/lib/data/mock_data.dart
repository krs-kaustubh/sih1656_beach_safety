import '../models/beach.dart';
import '../models/conditions.dart';
import '../models/risk_level.dart';
import '../models/safety_alert.dart';

/// Mock content mirroring the UI designs.
///
/// Times are built relative to "today" so the app never looks stale during a
/// demo. Everything here is replaced by the API once the backend serves these
/// fields — the shapes already match `SafetyAlert.fromJson` and
/// `Beach.fromJson`.
abstract final class MockData {
  static DateTime _todayAt(int hour, int minute) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  static List<Beach> beaches() => [
        Beach(
          id: 1,
          name: 'Juhu Beach',
          region: 'Mumbai, West Coast',
          latitude: 19.0988,
          longitude: 72.8267,
          riskLevel: RiskLevel.high,
          riskSummary:
              'Dangerous conditions. Strong currents and high waves. Avoid entering water.',
          conditions: Conditions(
            waveHeightMeters: 2.8,
            currentSpeedKnots: 4.5,
            windSpeedKph: 32,
            windDirection: 'SW',
            uvIndex: 9,
            nextTide: TideInfo(time: _todayAt(12, 30), phase: TidePhase.high),
            waterTempCelsius: 28,
            waterQuality: 'Poor',
          ),
        ),
        Beach(
          id: 2,
          name: 'Marina Beach',
          region: 'Chennai, East Coast',
          latitude: 13.0499,
          longitude: 80.2824,
          riskLevel: RiskLevel.moderate,
          riskSummary:
              'Rip currents reported near the shore break south of the lifeguard tower.',
          conditions: Conditions(
            waveHeightMeters: 1.4,
            currentSpeedKnots: 2.1,
            windSpeedKph: 18,
            windDirection: 'SW',
            uvIndex: 6,
            nextTide: TideInfo(time: _todayAt(11, 20), phase: TidePhase.high),
            waterTempCelsius: 28,
            waterQuality: 'Moderate',
          ),
        ),
        Beach(
          id: 3,
          name: 'Radhanagar Beach',
          region: 'Havelock Island, Andaman',
          latitude: 11.9841,
          longitude: 92.9548,
          riskLevel: RiskLevel.low,
          riskSummary: 'Conditions are safe for swimming and other water activities.',
          conditions: Conditions(
            waveHeightMeters: 0.6,
            currentSpeedKnots: 0.8,
            windSpeedKph: 12,
            windDirection: 'SW',
            uvIndex: 3,
            nextTide: TideInfo(time: _todayAt(9, 45), phase: TidePhase.low),
            waterTempCelsius: 28,
            waterQuality: 'Excellent',
          ),
        ),
        Beach(
          id: 4,
          name: 'Om Beach',
          region: 'Gokarna, West Coast',
          latitude: 14.5106,
          longitude: 74.3170,
          riskLevel: RiskLevel.low,
          riskSummary: 'Conditions are safe for swimming and other water activities.',
          conditions: Conditions(
            waveHeightMeters: 0.5,
            currentSpeedKnots: 0.6,
            windSpeedKph: 9,
            windDirection: 'W',
            uvIndex: 2,
            nextTide: TideInfo(time: _todayAt(10, 15), phase: TidePhase.low),
            waterTempCelsius: 27,
            waterQuality: 'Excellent',
          ),
        ),
      ];

  static const _ripCurrentActions = [
    'Swim only in front of the lifeguard tower.',
    'If caught in a current, swim parallel to shore, not against it.',
    'Keep young swimmers within arm’s reach.',
  ];

  static const _ripCurrentTip =
      'If caught in a rip current, stay calm and swim parallel to shore.';

  static List<SafetyAlert> alerts() => [
        // --- Juhu Beach (high risk) ---
        SafetyAlert(
          id: 'juhu-rip',
          beachId: 1,
          kind: AlertKind.ripCurrent,
          riskLevel: RiskLevel.high,
          urgency: AlertUrgency.actNow,
          title: 'Rip Current Warning',
          summary: 'Very strong rip currents near the southern lifeguard tower.',
          zoneLabel: 'South Shore',
          issuedAt: _todayAt(6, 15),
          validUntil: _todayAt(11, 20),
          whatsHappening:
              'Very strong rip currents are pulling away from shore near the southern '
              'lifeguard tower, caused by the outgoing tide meeting strong swell from '
              'the southwest. Conditions are expected to ease after the 11:20 AM high tide.',
          whatToDo: _ripCurrentActions,
          lifeguard: const LifeguardStatus(towerName: 'Tower 3', onDuty: true),
          affectedArea: const AffectedArea(
            zoneName: 'South Shore Zone',
            description: '250 m south of lifeguard tower.',
            latitude: 19.0955,
            longitude: 72.8258,
          ),
          conditions: Conditions(
            waveHeightMeters: 2.8,
            windSpeedKph: 32,
            windDirection: 'SW',
            nextTide: TideInfo(time: _todayAt(12, 30), phase: TidePhase.high),
            waterTempCelsius: 28,
          ),
          safetyTip: _ripCurrentTip,
        ),
        SafetyAlert(
          id: 'juhu-uv',
          beachId: 1,
          kind: AlertKind.uv,
          riskLevel: RiskLevel.high,
          urgency: AlertUrgency.actNow,
          title: 'High UV Warning',
          summary: 'Extreme UV levels expected through the middle of the day.',
          zoneLabel: 'Whole Coastline',
          issuedAt: _todayAt(11, 0),
          validUntil: _todayAt(15, 0),
          timeStyle: AlertTimeStyle.window,
          whatsHappening:
              'The UV index is forecast to reach 9 (Extreme) between 11 AM and 3 PM. '
              'Unprotected skin can burn in under 15 minutes.',
          whatToDo: const [
            'Stay in shade between 11 AM and 3 PM.',
            'Apply SPF 50+ sunscreen and reapply every two hours.',
            'Wear a hat, sunglasses and a rash guard in the water.',
          ],
          lifeguard: const LifeguardStatus(towerName: 'Tower 3', onDuty: true),
          affectedArea: const AffectedArea(
            zoneName: 'Whole Coastline',
            description: 'All beach access points.',
          ),
          safetyTip: 'Sunscreen washes off in water. Reapply after every swim.',
        ),
        SafetyAlert(
          id: 'juhu-wind',
          beachId: 1,
          kind: AlertKind.wind,
          riskLevel: RiskLevel.high,
          urgency: AlertUrgency.actNow,
          title: 'Strong Wind Warning',
          summary: 'Sustained winds above 30 km/h.',
          zoneLabel: 'Whole Coastline',
          issuedAt: _todayAt(5, 40),
          validUntil: _todayAt(18, 0),
          whatsHappening:
              'Sustained southwesterly winds above 30 km/h are driving choppy water and '
              'blowing sand along the full length of the beach.',
          whatToDo: const [
            'Secure umbrellas and loose belongings.',
            'Avoid inflatables and paddle craft.',
            'Expect reduced visibility from blowing sand.',
          ],
          lifeguard: const LifeguardStatus(towerName: 'Tower 3', onDuty: true),
          affectedArea: const AffectedArea(
            zoneName: 'Whole Coastline',
            description: 'All beach access points.',
          ),
          safetyTip: 'Offshore winds can push inflatables out to sea within minutes.',
        ),

        // --- Marina Beach (moderate risk) ---
        SafetyAlert(
          id: 'marina-rip',
          beachId: 2,
          kind: AlertKind.ripCurrent,
          riskLevel: RiskLevel.moderate,
          urgency: AlertUrgency.actNow,
          title: 'Rip Current Advisory',
          summary: 'Rip currents reported near the shore break.',
          zoneLabel: 'South Shore',
          issuedAt: _todayAt(6, 15),
          validUntil: _todayAt(11, 20),
          whatsHappening:
              'Strong rip currents are pulling away from shore near the southern '
              'lifeguard tower, caused by the outgoing tide meeting swell from the '
              'southwest. Conditions are expected to ease after the 11:20 AM high tide.',
          whatToDo: _ripCurrentActions,
          lifeguard: const LifeguardStatus(towerName: 'Tower 3', onDuty: true),
          affectedArea: const AffectedArea(
            zoneName: 'South Shore Zone',
            description: '250 m south of lifeguard tower.',
            latitude: 13.0462,
            longitude: 80.2818,
          ),
          conditions: Conditions(
            waveHeightMeters: 1.4,
            windSpeedKph: 18,
            windDirection: 'SW',
            nextTide: TideInfo(time: _todayAt(11, 20), phase: TidePhase.high),
            waterTempCelsius: 28,
          ),
          safetyTip: _ripCurrentTip,
        ),
        SafetyAlert(
          id: 'marina-uv',
          beachId: 2,
          kind: AlertKind.uv,
          riskLevel: RiskLevel.moderate,
          urgency: AlertUrgency.advisory,
          title: 'High UV Warning',
          summary: 'UV index reaching 6 (High) around midday.',
          zoneLabel: 'Whole Coastline',
          issuedAt: _todayAt(11, 0),
          validUntil: _todayAt(15, 0),
          timeStyle: AlertTimeStyle.window,
          whatsHappening:
              'The UV index is forecast to reach 6 (High) between 11 AM and 3 PM.',
          whatToDo: const [
            'Seek shade during the middle of the day.',
            'Apply SPF 30+ sunscreen before going out.',
            'Wear sunglasses and a wide-brimmed hat.',
          ],
          lifeguard: const LifeguardStatus(towerName: 'Tower 3', onDuty: true),
          affectedArea: const AffectedArea(
            zoneName: 'Whole Coastline',
            description: 'All beach access points.',
          ),
          safetyTip: 'Sunscreen washes off in water. Reapply after every swim.',
        ),

        // --- Radhanagar Beach (low risk) keeps one advisory so the low-risk
        // detail screen from the designs is reachable in the demo.
        SafetyAlert(
          id: 'radhanagar-rip',
          beachId: 3,
          kind: AlertKind.ripCurrent,
          riskLevel: RiskLevel.low,
          urgency: AlertUrgency.advisory,
          title: 'Rip Current Advisory',
          summary: 'Low risk of rip currents near the southern tower.',
          zoneLabel: 'South Shore',
          issuedAt: _todayAt(6, 15),
          validUntil: _todayAt(11, 20),
          whatsHappening:
              'There is a low risk of rip currents near the southern lifeguard tower '
              'due to the outgoing tide and swells from the southwest. Conditions are '
              'expected to ease after the 11:20 AM high tide.',
          whatToDo: _ripCurrentActions,
          lifeguard: const LifeguardStatus(towerName: 'Tower 3', onDuty: true),
          affectedArea: const AffectedArea(
            zoneName: 'South Shore Zone',
            description: '250 m south of lifeguard tower.',
            latitude: 11.9820,
            longitude: 92.9540,
          ),
          conditions: Conditions(
            waveHeightMeters: 0.6,
            windSpeedKph: 12,
            windDirection: 'SW',
            nextTide: TideInfo(time: _todayAt(9, 45), phase: TidePhase.low),
            waterTempCelsius: 28,
          ),
          safetyTip: _ripCurrentTip,
        ),
      ];
}
