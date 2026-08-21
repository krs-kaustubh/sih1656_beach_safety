import 'package:flutter/foundation.dart';

import 'conditions.dart';
import 'risk_level.dart';

/// Kind of hazard an alert describes. Drives the icon shown on the alert card.
enum AlertKind {
  ripCurrent('Rip Current'),
  uv('UV'),
  wind('Wind'),
  waterQuality('Water Quality'),
  general('Advisory');

  const AlertKind(this.label);
  final String label;

  static AlertKind fromApi(String? value) {
    final normalised = (value ?? '').trim().toLowerCase().replaceAll('_', '');
    return switch (normalised) {
      'ripcurrent' => AlertKind.ripCurrent,
      'uv' => AlertKind.uv,
      'wind' => AlertKind.wind,
      'waterquality' => AlertKind.waterQuality,
      _ => AlertKind.general,
    };
  }
}

/// The call-to-action chip beside the risk level on the detail header.
enum AlertUrgency {
  advisory('ADVISORY'),
  actNow('ACT NOW');

  const AlertUrgency(this.label);
  final String label;
}

/// Whether an alert's time is presented as a single issue time or a window.
enum AlertTimeStyle { issued, window }

/// On-duty state of the lifeguard tower covering an alert's zone.
@immutable
class LifeguardStatus {
  const LifeguardStatus({
    required this.towerName,
    required this.onDuty,
  });

  final String towerName;
  final bool onDuty;

  String get statusLabel => onDuty ? 'On Duty' : 'Off Duty';

  factory LifeguardStatus.fromJson(Map<String, dynamic> json) => LifeguardStatus(
        towerName: json['tower_name'] as String? ?? 'Lifeguard Tower',
        onDuty: json['on_duty'] as bool? ?? false,
      );
}

/// The geographic zone an alert applies to, plus the thumbnail map copy.
@immutable
class AffectedArea {
  const AffectedArea({
    required this.zoneName,
    required this.description,
    this.latitude,
    this.longitude,
  });

  final String zoneName;
  final String description;
  final double? latitude;
  final double? longitude;

  factory AffectedArea.fromJson(Map<String, dynamic> json) => AffectedArea(
        zoneName: json['zone_name'] as String? ?? 'Affected Zone',
        description: json['description'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );
}

/// A safety alert for a beach.
///
/// Named `SafetyAlert` rather than `Alert` to avoid colliding with Flutter's
/// Material `Alert*` widgets.
@immutable
class SafetyAlert {
  const SafetyAlert({
    required this.id,
    required this.beachId,
    required this.kind,
    required this.riskLevel,
    required this.urgency,
    required this.title,
    required this.summary,
    required this.zoneLabel,
    required this.issuedAt,
    this.validUntil,
    this.timeStyle = AlertTimeStyle.issued,
    this.whatsHappening = '',
    this.whatToDo = const <String>[],
    this.lifeguard,
    this.affectedArea,
    this.conditions,
    this.safetyTip,
  });

  final String id;
  final int beachId;
  final AlertKind kind;
  final RiskLevel riskLevel;
  final AlertUrgency urgency;

  /// Headline, e.g. "Rip Current Advisory".
  final String title;

  /// One-line description shown under the title on the Home alert card.
  final String summary;

  /// Where it applies, e.g. "South Shore" or "Whole Coastline".
  final String zoneLabel;

  final DateTime issuedAt;
  final DateTime? validUntil;

  /// Whether the card shows "Issued 6:15 AM" or a "11 AM - 3 PM" window.
  final AlertTimeStyle timeStyle;

  final String whatsHappening;
  final List<String> whatToDo;
  final LifeguardStatus? lifeguard;
  final AffectedArea? affectedArea;

  /// Conditions at the time the alert was raised. Falls back to the beach's
  /// current conditions when the backend does not supply a snapshot.
  final Conditions? conditions;

  final String? safetyTip;

  factory SafetyAlert.fromJson(Map<String, dynamic> json) => SafetyAlert(
        id: json['id']?.toString() ?? '',
        beachId: (json['beach_id'] as num?)?.toInt() ?? -1,
        kind: AlertKind.fromApi(json['kind'] as String?),
        riskLevel: RiskLevel.fromApi(json['risk_level'] as String?),
        urgency: (json['urgency'] as String?)?.toLowerCase() == 'advisory'
            ? AlertUrgency.advisory
            : AlertUrgency.actNow,
        title: json['title'] as String? ?? 'Safety Alert',
        summary: json['summary'] as String? ?? '',
        zoneLabel: json['zone_label'] as String? ?? '',
        issuedAt: DateTime.tryParse(json['issued_at'] as String? ?? '') ?? DateTime.now(),
        validUntil: DateTime.tryParse(json['valid_until'] as String? ?? ''),
        timeStyle: (json['time_style'] as String?) == 'window'
            ? AlertTimeStyle.window
            : AlertTimeStyle.issued,
        whatsHappening: json['whats_happening'] as String? ?? '',
        whatToDo: (json['what_to_do'] as List<dynamic>?)?.cast<String>() ?? const <String>[],
        lifeguard: json['lifeguard'] == null
            ? null
            : LifeguardStatus.fromJson(json['lifeguard'] as Map<String, dynamic>),
        affectedArea: json['affected_area'] == null
            ? null
            : AffectedArea.fromJson(json['affected_area'] as Map<String, dynamic>),
        conditions: json['conditions'] == null
            ? null
            : Conditions.fromJson(json['conditions'] as Map<String, dynamic>),
        safetyTip: json['safety_tip'] as String?,
      );
}
