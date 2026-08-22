// File: lib/features/settings/emergency_contacts.dart
// Description: Data models and national emergency shortcode helpline contacts list for quick dialing during incidents.

import 'package:flutter/foundation.dart';

// A number worth having one tap away when conditions turn bad.
@immutable
class EmergencyContact {
  const EmergencyContact({
    required this.name,
    required this.number,
    required this.description,
  });

  final String name;

  // Dialled as-is short code string.
  final String number;

  final String description;
}

// India-wide emergency numbers list.
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
