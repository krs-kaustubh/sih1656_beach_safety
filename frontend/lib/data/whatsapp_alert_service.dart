import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// A beach the backend's `check-safety` endpoint knows about.
///
/// Deliberately separate from [Beach] (the mock/live UI model) — this list
/// is fixed to the three slugs `services/geofence.py` has hazard polygons
/// for, and always hits the real backend even while the rest of the app
/// runs on mock data.
@immutable
class WhatsAppAlertBeach {
  const WhatsAppAlertBeach({
    required this.slug,
    required this.label,
    required this.lat,
    required this.lon,
  });

  final String slug;
  final String label;
  final double lat;
  final double lon;
}

/// Matches `core.config.LOCATION_MAP` on the backend.
const whatsAppAlertBeaches = <WhatsAppAlertBeach>[
  WhatsAppAlertBeach(
    slug: 'juhu',
    label: 'Juhu Beach, Mumbai',
    lat: 19.1075,
    lon: 72.8263,
  ),
  WhatsAppAlertBeach(
    slug: 'marina',
    label: 'Marina Beach, Chennai',
    lat: 13.0500,
    lon: 80.2824,
  ),
  WhatsAppAlertBeach(
    slug: 'radhanagar',
    label: 'Radhanagar Beach, Havelock',
    lat: 11.9841,
    lon: 92.9515,
  ),
];

/// Outcome of a `check-safety` call, enough for a settings-screen snackbar.
@immutable
class WhatsAppAlertResult {
  const WhatsAppAlertResult({
    required this.alerted,
    required this.severityMode,
    required this.riskTitle,
  });

  factory WhatsAppAlertResult.fromJson(Map<String, dynamic> json) {
    return WhatsAppAlertResult(
      alerted: json['in_hazard_zone_and_alerted'] as bool? ?? false,
      severityMode: json['severity_mode'] as String? ?? 'UNKNOWN',
      riskTitle: json['risk_title'] as String? ?? '',
    );
  }

  final bool alerted;
  final String severityMode;
  final String riskTitle;
}

/// Calls `POST /beaches/{location}/check-safety`.
///
/// Independent of [ApiBeachRepository] on purpose: the rest of the app can
/// stay on mock data while this one feature talks to the real backend.
class WhatsAppAlertService {
  WhatsAppAlertService({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<WhatsAppAlertResult> checkSafety({
    required WhatsAppAlertBeach beach,
    required String chatId,
  }) async {
    final json = await _client.postQuery(
      '/beaches/${beach.slug}/check-safety',
      {
        'user_lat': beach.lat.toString(),
        'user_lon': beach.lon.toString(),
        'chat_id': chatId,
      },
    );
    return WhatsAppAlertResult.fromJson(json as Map<String, dynamic>);
  }
}
