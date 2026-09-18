import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/profile/profile_service.dart';

void main() {
  group('EmergencyProfileData Unit Tests', () {
    test('Default EmergencyProfileData instance has expected emergency fields', () {
      final profile = EmergencyProfileData(
        bloodType: 'O+',
        emergencyContactName: 'Disaster Relief Ops Base',
        emergencyContactPhone: '+1 (800) 555-RESQ',
        medicalAllergies: 'Penicillin (Mild)',
        medicalConditions: 'None / Fit for duty',
        assignedSector: 'Sector 4 - Civic Center Corridor',
        certifications: 'FEMA CERT Level 2, Wilderness First Aid, CPR/AED',
      );

      expect(profile.bloodType, 'O+');
      expect(profile.emergencyContactName, 'Disaster Relief Ops Base');
      expect(profile.emergencyContactPhone, '+1 (800) 555-RESQ');
      expect(profile.medicalAllergies, 'Penicillin (Mild)');
      expect(profile.medicalConditions, 'None / Fit for duty');
      expect(profile.assignedSector, 'Sector 4 - Civic Center Corridor');
      expect(profile.certifications, contains('FEMA CERT'));
    });

    test('EmergencyProfileData copyWith updates specific fields while preserving others', () {
      final original = EmergencyProfileData(
        bloodType: 'O+',
        emergencyContactName: 'Base Alpha',
        emergencyContactPhone: '555-0100',
        medicalAllergies: 'None',
        medicalConditions: 'Fit',
        assignedSector: 'Sector 1',
        certifications: 'Standard First Aid',
      );

      final updated = original.copyWith(
        bloodType: 'A-',
        emergencyContactPhone: '555-0199',
        assignedSector: 'Sector 3 - High Ground',
      );

      expect(updated.bloodType, 'A-');
      expect(updated.emergencyContactName, 'Base Alpha'); // preserved
      expect(updated.emergencyContactPhone, '555-0199'); // updated
      expect(updated.medicalAllergies, 'None'); // preserved
      expect(updated.assignedSector, 'Sector 3 - High Ground'); // updated
      expect(updated.certifications, 'Standard First Aid'); // preserved
    });

    test('ProfileService singleton provides initialized profile data', () {
      final service = ProfileService.instance;
      expect(service.profile.bloodType, isNotEmpty);
      expect(service.profile.emergencyContactName, isNotEmpty);
      expect(service.profile.emergencyContactPhone, isNotEmpty);
    });
  });
}
