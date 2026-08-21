import 'package:beach_safety/core/formatting.dart';
import 'package:beach_safety/models/risk_level.dart';
import 'package:beach_safety/models/safety_alert.dart';
import 'package:flutter_test/flutter_test.dart';

SafetyAlert _alert({
  required DateTime issuedAt,
  DateTime? validUntil,
  AlertTimeStyle timeStyle = AlertTimeStyle.issued,
  String zoneLabel = 'South Shore',
}) =>
    SafetyAlert(
      id: 'a',
      beachId: 1,
      kind: AlertKind.ripCurrent,
      riskLevel: RiskLevel.moderate,
      urgency: AlertUrgency.actNow,
      title: 'Rip Current Advisory',
      summary: '',
      zoneLabel: zoneLabel,
      issuedAt: issuedAt,
      validUntil: validUntil,
      timeStyle: timeStyle,
    );

void main() {
  group('Fmt.number', () {
    test('keeps a meaningful decimal', () {
      expect(Fmt.number(2.8), '2.8');
      expect(Fmt.number(0.6), '0.6');
    });

    test('drops a trailing .0', () {
      expect(Fmt.number(3.0), '3');
    });

    test('honours a zero-decimal request', () {
      expect(Fmt.number(32.4, decimals: 0), '32');
    });
  });

  test('Fmt.uv rounds to a whole number', () {
    expect(Fmt.uv(8.6), '9');
    expect(Fmt.uv(3.0), '3');
  });

  group('Fmt.alertMeta', () {
    test('shows an issue time by default', () {
      final meta = Fmt.alertMeta(_alert(issuedAt: DateTime(2026, 8, 21, 6, 15)));
      expect(meta, contains('Issued 6:15 AM'));
      expect(meta, contains('South Shore'));
    });

    test('shows a range for window-style alerts', () {
      final meta = Fmt.alertMeta(_alert(
        issuedAt: DateTime(2026, 8, 21, 11, 0),
        validUntil: DateTime(2026, 8, 21, 15, 0),
        timeStyle: AlertTimeStyle.window,
        zoneLabel: 'Whole Coastline',
      ));
      expect(meta, contains('11 AM – 3 PM'));
      expect(meta, contains('Whole Coastline'));
    });

    test('falls back to the issue time when a window has no end', () {
      final meta = Fmt.alertMeta(_alert(
        issuedAt: DateTime(2026, 8, 21, 11, 0),
        timeStyle: AlertTimeStyle.window,
      ));
      expect(meta, contains('Issued 11:00 AM'));
    });

    test('omits the separator when there is no zone', () {
      final meta = Fmt.alertMeta(
        _alert(issuedAt: DateTime(2026, 8, 21, 6, 15), zoneLabel: ''),
      );
      expect(meta, 'Issued 6:15 AM');
    });
  });

  group('Fmt.alertValidity', () {
    test('includes both timestamps when an expiry exists', () {
      final text = Fmt.alertValidity(_alert(
        issuedAt: DateTime(2026, 8, 21, 6, 15),
        validUntil: DateTime(2026, 8, 21, 11, 20),
      ));
      expect(text, contains('Updated 6:15 AM'));
      expect(text, contains('Valid until 11:20 AM'));
    });

    test('shows only the update time when there is no expiry', () {
      final text =
          Fmt.alertValidity(_alert(issuedAt: DateTime(2026, 8, 21, 6, 15)));
      expect(text, 'Updated 6:15 AM');
    });
  });
}
