// File: lib/models/risk_level.dart
// Description: Enum defining overall safety risk levels (Low, Moderate, High), API string mapping, risk meter position calculations, and surface contrast settings.

// Overall safety rating for a beach or an alert.
enum RiskLevel {
  low(apiValue: 'Green', label: 'Low Risk', shortLabel: 'Low'),
  moderate(apiValue: 'Amber', label: 'Moderate Risk', shortLabel: 'Moderate'),
  high(apiValue: 'Red', label: 'High Risk', shortLabel: 'Severe');

  const RiskLevel({
    required this.apiValue,
    required this.label,
    required this.shortLabel,
  });

  // Value used by the backend's safety_status field.
  final String apiValue;

  // Full label, e.g. the risk banner headline on Home.
  final String label;

  // Compact label used in the risk meter and status chips.
  final String shortLabel;

  // The service speaks two vocabularies: Green/Amber/Red and Normal/Intermediate/Severe.
  static const _aliases = <String, RiskLevel>{
    'green': RiskLevel.low,
    'normal': RiskLevel.low,
    'amber': RiskLevel.moderate,
    'yellow': RiskLevel.moderate,
    'intermediate': RiskLevel.moderate,
    'red': RiskLevel.high,
    'severe': RiskLevel.high,
  };

  // Parses a risk value from either vocabulary, falling back to moderate for unrecognised values.
  static RiskLevel fromApi(String? value) {
    if (value == null) return RiskLevel.moderate;
    return _aliases[value.trim().toLowerCase()] ?? RiskLevel.moderate;
  }

  // Position on the Low - Moderate - Severe meter, from 0.0 to 1.0.
  double get meterPosition => switch (this) {
        RiskLevel.low => 0.0,
        RiskLevel.moderate => 0.5,
        RiskLevel.high => 1.0,
      };

  // High-risk screens in the designs are dark-themed; the others light.
  bool get usesDarkSurface => this == RiskLevel.high;
}

