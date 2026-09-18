import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EmergencyProfileData {
  final String bloodType;
  final String emergencyContactName;
  final String emergencyContactPhone;
  final String medicalAllergies;
  final String medicalConditions;
  final String assignedSector;
  final String certifications;

  EmergencyProfileData({
    required this.bloodType,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.medicalAllergies,
    required this.medicalConditions,
    required this.assignedSector,
    required this.certifications,
  });

  EmergencyProfileData copyWith({
    String? bloodType,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? medicalAllergies,
    String? medicalConditions,
    String? assignedSector,
    String? certifications,
  }) {
    return EmergencyProfileData(
      bloodType: bloodType ?? this.bloodType,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      medicalAllergies: medicalAllergies ?? this.medicalAllergies,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      assignedSector: assignedSector ?? this.assignedSector,
      certifications: certifications ?? this.certifications,
    );
  }
}

class ProfileService extends ChangeNotifier {
  static final ProfileService instance = ProfileService._init();
  ProfileService._init();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  EmergencyProfileData _profile = EmergencyProfileData(
    bloodType: 'O+',
    emergencyContactName: 'Disaster Relief Ops Base',
    emergencyContactPhone: '+1 (800) 555-RESQ',
    medicalAllergies: 'Penicillin (Mild)',
    medicalConditions: 'None / Fit for duty',
    assignedSector: 'Sector 4 - Civic Center Corridor',
    certifications: 'FEMA CERT Level 2, Wilderness First Aid, CPR/AED',
  );

  bool _isLoaded = false;
  EmergencyProfileData get profile => _profile;
  bool get isLoaded => _isLoaded;

  Future<void> loadProfile() async {
    try {
      final blood = await _storage.read(key: 'profile_blood_type');
      final contactName = await _storage.read(key: 'profile_contact_name');
      final contactPhone = await _storage.read(key: 'profile_contact_phone');
      final allergies = await _storage.read(key: 'profile_allergies');
      final conditions = await _storage.read(key: 'profile_conditions');
      final sector = await _storage.read(key: 'profile_sector');
      final certs = await _storage.read(key: 'profile_certs');

      _profile = _profile.copyWith(
        bloodType: blood ?? _profile.bloodType,
        emergencyContactName: contactName ?? _profile.emergencyContactName,
        emergencyContactPhone: contactPhone ?? _profile.emergencyContactPhone,
        medicalAllergies: allergies ?? _profile.medicalAllergies,
        medicalConditions: conditions ?? _profile.medicalConditions,
        assignedSector: sector ?? _profile.assignedSector,
        certifications: certs ?? _profile.certifications,
      );
    } catch (e) {
      debugPrint('Error reading secure profile storage: $e');
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> updateEmergencyProfile({
    required String bloodType,
    required String emergencyContactName,
    required String emergencyContactPhone,
    required String medicalAllergies,
    required String medicalConditions,
    String? assignedSector,
  }) async {
    _profile = _profile.copyWith(
      bloodType: bloodType,
      emergencyContactName: emergencyContactName,
      emergencyContactPhone: emergencyContactPhone,
      medicalAllergies: medicalAllergies,
      medicalConditions: medicalConditions,
      assignedSector: assignedSector ?? _profile.assignedSector,
    );

    try {
      await _storage.write(key: 'profile_blood_type', value: bloodType);
      await _storage.write(key: 'profile_contact_name', value: emergencyContactName);
      await _storage.write(key: 'profile_contact_phone', value: emergencyContactPhone);
      await _storage.write(key: 'profile_allergies', value: medicalAllergies);
      await _storage.write(key: 'profile_conditions', value: medicalConditions);
      if (assignedSector != null) {
        await _storage.write(key: 'profile_sector', value: assignedSector);
      }
    } catch (e) {
      debugPrint('Error writing secure profile storage: $e');
    }

    notifyListeners();
  }
}
