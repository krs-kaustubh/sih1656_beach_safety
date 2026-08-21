import 'package:flutter/foundation.dart';

/// A number worth having one tap away when conditions turn bad.
@immutable
class EmergencyContact {
  const EmergencyContact({
    required this.name,
    required this.number,
    required this.description,
  });

  final String name;

  /// Dialled as-is. Kept as a string because short codes have no country code
  /// and must not be reformatted.
  final String number;

  final String description;
}

/// India-wide emergency numbers.
///
/// These are national short codes, not per-beach contacts. Verify them against
/// current official sources before any public release, and add the local
/// lifeguard or municipal number per beach once the backend can supply it —
/// a wrong number in a safety app is worse than no number.
const emergencyContacts = <EmergencyContact>[
  EmergencyContact(
    name: 'Emergency services',
    number: '112',
    description: 'India\'s single emergency number — police, fire, ambulance',
  ),
  EmergencyContact(
    name: 'Indian Coast Guard',
    number: '1554',
    description: 'Maritime search and rescue',
  ),
  EmergencyContact(
    name: 'Ambulance',
    number: '108',
    description: 'Medical emergency response',
  ),
  EmergencyContact(
    name: 'Disaster management',
    number: '1078',
    description: 'National Disaster Response Force helpline',
  ),
];
