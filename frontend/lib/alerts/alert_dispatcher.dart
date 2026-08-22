// File: lib/alerts/alert_dispatcher.dart
// Description: Delivery of escalation alerts through the channel the user chose — an Android notification on this device, or a WhatsApp message via the backend gateway.

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/api_beach_repository.dart';
import '../data/api_client.dart';
import '../models/beach.dart';
import '../settings/app_settings.dart';

// What the user is told when a beach turns dangerous.
//
// Built once and shared by both channels so the WhatsApp message and the
// notification cannot drift apart into two different accounts of the same
// event.
@immutable
class EscalationMessage {
  const EscalationMessage({
    required this.title,
    required this.body,
    this.beachSlug,
    this.isTest = false,
  });

  final String title;
  final String body;

  // The weather endpoint's key for this beach. Needed only by the WhatsApp
  // channel, which asks the service to compose and send the message.
  final String? beachSlug;

  // A test alert skips the service's severity check and says plainly that it
  // is a test, so confirming the setup cannot be mistaken for a real warning.
  final bool isTest;

  factory EscalationMessage.forBeach(Beach beach) {
    final drivers = beach.riskDrivers
        .map(_readableDriver)
        .where((d) => d.isNotEmpty)
        .toList(growable: false);

    // The summary already reads as a sentence; the drivers say which
    // measurements moved, which is the part a user can act on.
    final reason = beach.riskSummary.trim().isNotEmpty
        ? beach.riskSummary.trim()
        : 'Conditions have deteriorated.';

    return EscalationMessage(
      beachSlug: ApiBeachRepository.slugFor(beach),
      title: '${beach.name}: now High Risk',
      body: drivers.isEmpty
          ? reason
          : '$reason\nDriven by: ${drivers.join(', ')}.',
    );
  }

  // Backend parameter names are snake_case machine keys; nobody wants to read
  // "wave_height" in a warning.
  static String _readableDriver(String raw) => switch (raw.trim()) {
        'wave_height' => 'wave height',
        'wind_speed' => 'wind speed',
        'swell' => 'swell',
        'uv_index' => 'UV index',
        'water_quality' => 'water quality',
        final other => other.replaceAll('_', ' '),
      };

  String get whatsappText => '⚠️ $title\n\n$body';
}

// Sends an escalation alert somewhere. Split out from the delivery details so
// the escalation logic can be tested without a plugin or a network.
abstract interface class AlertDispatcher {
  // Returns true if the alert was delivered.
  Future<bool> send(EscalationMessage message, AppSettings settings);
}

// Android notification channel. Declared once; Android ignores re-creation.
const _androidChannel = AndroidNotificationDetails(
  'beach_escalation',
  'Beach risk escalations',
  channelDescription:
      'Fires when a beach you are watching rises to High Risk.',
  importance: Importance.high,
  priority: Priority.high,
  styleInformation: BigTextStyleInformation(''),
);

// Routes an alert to whichever channel the user picked.
class ChannelAlertDispatcher implements AlertDispatcher {
  ChannelAlertDispatcher({
    FlutterLocalNotificationsPlugin? notifications,
    ApiClient? client,
  })  : _notifications = notifications ?? FlutterLocalNotificationsPlugin(),
        _client = client ?? ApiClient();

  final FlutterLocalNotificationsPlugin _notifications;
  final ApiClient _client;

  bool _initialised = false;

  // Android 13+ withholds notifications until the user grants the runtime
  // permission, so ask on first use rather than at launch — by then the user
  // has chosen the channel and the request has visible context.
  Future<bool> _ensureReady() async {
    if (_initialised) return true;

    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission() ?? false;

    _initialised = true;
    return granted;
  }

  @override
  Future<bool> send(EscalationMessage message, AppSettings settings) async {
    switch (settings.alertChannel) {
      case AlertChannel.off:
        return false;

      case AlertChannel.notification:
        if (!await _ensureReady()) return false;
        await _notifications.show(
          // One fixed id: a newer escalation replaces the older notification
          // rather than stacking a column of near-identical warnings.
          id: _escalationNotificationId,
          title: message.title,
          body: message.body,
          notificationDetails:
              const NotificationDetails(android: _androidChannel),
        );
        return true;

      case AlertChannel.whatsapp:
        final number = settings.whatsappNumber;
        if (number == null || number.isEmpty) return false;
        final slug = message.beachSlug;
        if (slug == null) return false;
        return _client.postWhatsappEscalation(
          slug: slug,
          chatId: '$number@c.us',
          test: message.isTest,
        );
    }
  }

  static const _escalationNotificationId = 1001;

  void dispose() => _client.dispose();
}
