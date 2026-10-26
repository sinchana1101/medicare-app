import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:medicare_flutter/services/emailjs_service.dart';

class _AllowAllHttpOverrides extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _AllowAllHttpOverrides();

  group('EmailJS Service Live API Verification (service_l5bgxos)', () {
    test('1st Template: Emergency SOS (template_aa0wwyi) sends successfully', () async {
      final success = await EmailJSService.sendEmergencyEmail(
        toEmail: 'sujaykarkera5@gmail.com',
        patientName: 'Sujay (Self-Test)',
        emergencyMessage: '🚨 This is an automated live verification of Emergency SOS via EmailJS 1st Template (template_aa0wwyi).',
        locationUrl: 'https://maps.google.com/?q=12.9716,77.5946',
        medicineList: 'Dolo 650, Metformin 500mg',
        additionalNote: 'Service: service_l5bgxos | Status: Operational',
      );

      expect(success, isTrue, reason: 'Emergency SOS email failed: ${EmailJSService.lastError}');
    });

    test('2nd Template: Caregiver Alert (template_err1y5l) sends successfully', () async {
      final success = await EmailJSService.sendCaregiverEmail(
        toEmail: 'sujaykarumbar@gmail.com',
        patientName: 'Sujay (Self-Test)',
        message: 'Hello Caregiver,\nThis is an automated live verification of Caregiver report via EmailJS 2nd Template (template_err1y5l).\nAll systems verified working.',
        subject: 'MediCare Caregiver Status Report (Verification)',
        medicineName: 'Dolo 650',
        status: 'Daily Schedule Report',
      );

      expect(success, isTrue, reason: 'Caregiver email failed: ${EmailJSService.lastError}');
    });

    test('2nd Template: Skipped/Missed Dose Alert (template_err1y5l) sends successfully', () async {
      final success = await EmailJSService.sendMissedOrSkippedDoseEmail(
        toEmail: 'sujaykarumbar@gmail.com',
        patientName: 'Sujay (Self-Test)',
        medicineName: 'Dolo 650',
        scheduledTime: '9:00 AM',
        status: 'Skipped',
        dosage: '650 mg',
      );

      expect(success, isTrue, reason: 'Skipped dose email failed: ${EmailJSService.lastError}');
    });
  });
}
