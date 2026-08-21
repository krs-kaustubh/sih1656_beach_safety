/// Overall safety rating for a beach or an alert.
///
/// The backend expresses this as `safety_status` with the values
/// `Green` | `Amber` | `Red`. Everything user-facing keys off this enum, so
/// the wire format stays confined to [fromApi].
enum RiskLevel {
  low(apiValue: 'Green', label: 'Low Risk', shortLabel: 'Low'),
  moderate(apiValue: 'Amber', label: 'Moderate Risk', shortLabel: 'Moderate'),
  high(apiValue: 'Red', label: 'High Risk', shortLabel: 'Severe');

  const RiskLevel({
    required this.apiValue,
    required this.label,
    required this.shortLabel,
  });

  /// Value used by the backend's `safety_status` field.
  final String apiValue;

  /// Full label, e.g. the risk banner headline on Home.
  final String label;

  /// Compact label used in the risk meter and status chips.
  final String shortLabel;

  /// Parses a backend `safety_status`, falling back to [moderate] for values
  /// we do not recognise.
  ///
  /// Failing "safe" here would be worse than failing cautious: an unknown
  /// status rendered as Low Risk could tell someone the water is fine when
  /// the backend was trying to say otherwise.
  static RiskLevel fromApi(String? value) {
    if (value == null) return RiskLevel.moderate;
    final normalised = value.trim().toLowerCase();
    for (final level in RiskLevel.values) {
      if (level.apiValue.toLowerCase() == normalised) return level;
    }
    return RiskLevel.moderate;
  }

  /// Position on the Low - Moderate - Severe meter, from 0.0 to 1.0.
  double get meterPosition => switch (this) {
        RiskLevel.low => 0.0,
        RiskLevel.moderate => 0.5,
        RiskLevel.high => 1.0,
      };

  /// The high-risk screens in the designs are dark-themed; the others light.
  bool get usesDarkSurface => this == RiskLevel.high;
}
