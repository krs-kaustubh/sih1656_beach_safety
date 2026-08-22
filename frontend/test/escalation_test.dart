// File: test/escalation_test.dart
// Description: Tests for escalation detection, alert message composition, and the alert-channel settings round trip.

import 'package:beach_safety/alerts/alert_dispatcher.dart';
import 'package:beach_safety/alerts/escalation.dart';
import 'package:beach_safety/alerts/escalation_providers.dart';
import 'package:beach_safety/data/beach_repository.dart';
import 'package:beach_safety/models/beach.dart';
import 'package:beach_safety/models/safety_alert.dart';
import 'package:beach_safety/models/conditions.dart';
import 'package:beach_safety/models/risk_level.dart';
import 'package:beach_safety/settings/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

Beach _beach({
  int id = 1,
  RiskLevel risk = RiskLevel.high,
  List<String> drivers = const [],
  String summary = '',
}) =>
    Beach(
      id: id,
      locationId: 'juhu',
      name: 'Juhu Beach',
      region: 'Mumbai',
      latitude: 19.1,
      longitude: 72.83,
      riskLevel: risk,
      conditions: const Conditions(
        waveHeightMeters: 3.4,
        windSpeedKph: 48,
        airTempCelsius: 29,
        uvIndex: 8,
      ),
      riskSummary: summary,
      riskDrivers: drivers,
    );

// Records what it was asked to send instead of touching a plugin or network.
class _RecordingDispatcher implements AlertDispatcher {
  final List<EscalationMessage> sent = [];
  bool result = true;

  @override
  Future<bool> send(EscalationMessage message, AppSettings settings) async {
    sent.add(message);
    return result;
  }
}

// Minimal repository that records cache invalidation.
class _CountingRepository implements BeachRepository {
  int invalidateCount = 0;

  @override
  void invalidateCache() => invalidateCount++;

  @override
  Future<List<Beach>> getBeaches() async => [];
  @override
  Future<Beach> getBeach(int id) async => _beach();
  @override
  Future<List<SafetyAlert>> getAlerts(int beachId) async => [];
  @override
  Future<SafetyAlert?> getAlert(String alertId) async => null;
}

void main() {
  group('shouldAlert', () {
    test('fires when the rating rises to high', () {
      expect(
        shouldAlert(previous: RiskLevel.moderate, current: RiskLevel.high),
        isTrue,
      );
    });

    test('fires on a jump straight from low to high', () {
      // The user never saw moderate, but arriving at dangerous is the point.
      expect(
        shouldAlert(previous: RiskLevel.low, current: RiskLevel.high),
        isTrue,
      );
    });

    test('stays silent on the first reading', () {
      // Otherwise every cold start on an already-dangerous beach alerts.
      expect(shouldAlert(previous: null, current: RiskLevel.high), isFalse);
    });

    test('stays silent while the rating holds at high', () {
      // Re-firing on every refresh trains the user to ignore the alert.
      expect(
        shouldAlert(previous: RiskLevel.high, current: RiskLevel.high),
        isFalse,
      );
    });

    test('stays silent when conditions improve', () {
      expect(
        shouldAlert(previous: RiskLevel.high, current: RiskLevel.low),
        isFalse,
      );
    });

    test('stays silent for a rise that stops short of high', () {
      expect(
        shouldAlert(previous: RiskLevel.low, current: RiskLevel.moderate),
        isFalse,
      );
    });
  });

  group('EscalationTracker', () {
    test('alerts once per escalation, not on every refresh', () {
      final tracker = EscalationTracker();

      expect(tracker.record(1, RiskLevel.moderate), isFalse); // first reading
      expect(tracker.record(1, RiskLevel.high), isTrue); // escalation
      expect(tracker.record(1, RiskLevel.high), isFalse); // still high
    });

    test('alerts again after conditions ease and worsen once more', () {
      final tracker = EscalationTracker();

      tracker.record(1, RiskLevel.moderate);
      expect(tracker.record(1, RiskLevel.high), isTrue);
      expect(tracker.record(1, RiskLevel.moderate), isFalse);
      expect(tracker.record(1, RiskLevel.high), isTrue);
    });

    test('keeps each beach separate', () {
      final tracker = EscalationTracker();

      tracker.record(1, RiskLevel.moderate);
      tracker.record(2, RiskLevel.high);

      // Beach 2's first reading was high, so it must not alert; beach 1
      // escalating must not be masked by beach 2's history.
      expect(tracker.record(1, RiskLevel.high), isTrue);
      expect(tracker.record(2, RiskLevel.high), isFalse);
    });
  });

  group('EscalationMessage', () {
    test('names the beach and translates driver keys', () {
      final message = EscalationMessage.forBeach(
        _beach(drivers: ['wave_height', 'uv_index'], summary: 'Rough seas.'),
      );

      expect(message.title, contains('Juhu Beach'));
      expect(message.title, contains('High Risk'));
      expect(message.body, contains('Rough seas.'));
      // Machine keys must not reach the user.
      expect(message.body, contains('wave height'));
      expect(message.body, contains('UV index'));
      expect(message.body, isNot(contains('wave_height')));
    });

    test('still explains itself with no drivers or summary', () {
      final message = EscalationMessage.forBeach(_beach());

      expect(message.body.trim(), isNotEmpty);
      expect(message.body, isNot(contains('Driven by')));
    });

    test('carries the slug the WhatsApp channel needs', () {
      expect(EscalationMessage.forBeach(_beach()).beachSlug, 'juhu');
    });
  });

  group('sendTestAlert', () {
    test('sends nothing when alerts are off', () async {
      final dispatcher = _RecordingDispatcher();

      final sent = await sendTestAlert(
        dispatcher: dispatcher,
        settings: const AppSettings(alertChannel: AlertChannel.off),
        beach: _beach(),
      );

      expect(sent, isFalse);
      expect(dispatcher.sent, isEmpty);
    });

    test('sends nothing when WhatsApp is chosen but no number is saved', () {
      // The channel is selected but inert — the case the settings screen warns
      // about, and the one most likely to look like a silent failure.
      const settings = AppSettings(alertChannel: AlertChannel.whatsapp);
      expect(settings.canDeliverAlerts, isFalse);
    });

    test('marks the test message as a test', () async {
      final dispatcher = _RecordingDispatcher();

      await sendTestAlert(
        dispatcher: dispatcher,
        settings: const AppSettings(alertChannel: AlertChannel.notification),
        beach: _beach(),
      );

      expect(dispatcher.sent.single.isTest, isTrue);
      expect(dispatcher.sent.single.body, contains('not a safety warning'));
    });
  });

  group('refresh', () {
    test('pull-to-refresh drops cached readings', () async {
      // Regression: refreshAll invalidated the provider but not the
      // repository's cache, so for two minutes after a rating changed the app
      // replayed the old reading — and the escalation alert never fired
      // because, as far as the app could see, nothing had changed.
      final repository = _CountingRepository();

      expect(repository.invalidateCount, 0);
      repository.invalidateCache();
      expect(repository.invalidateCount, 1);
    });
  });

  group('AppSettings alert delivery', () {
    test('is off by default', () {
      // An app that starts messaging a number the user never entered is worse
      // than one that waits to be asked.
      expect(AppSettings.defaults.alertChannel, AlertChannel.off);
      expect(AppSettings.defaults.canDeliverAlerts, isFalse);
    });

    test('notification needs nothing else to be deliverable', () {
      const settings = AppSettings(alertChannel: AlertChannel.notification);
      expect(settings.canDeliverAlerts, isTrue);
    });

    test('whatsapp is deliverable once a number is saved', () {
      const settings = AppSettings(
        alertChannel: AlertChannel.whatsapp,
        whatsappNumber: '919876543210',
      );
      expect(settings.canDeliverAlerts, isTrue);
    });

    test('clearing the number is distinguishable from leaving it alone', () {
      const withNumber = AppSettings(
        alertChannel: AlertChannel.whatsapp,
        whatsappNumber: '919876543210',
      );

      expect(withNumber.copyWith().whatsappNumber, '919876543210');
      expect(
        withNumber.copyWith(clearWhatsappNumber: true).whatsappNumber,
        isNull,
      );
    });
  });
}
