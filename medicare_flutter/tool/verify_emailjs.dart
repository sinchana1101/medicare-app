import 'package:medicare_flutter/services/emailjs_service.dart';

void main() async {
  print("=== LIVE EMAILJS VERIFICATION WITH service_l5bgxos ===");

  print("\n1. Testing 1st Template: Emergency SOS (template_aa0wwyi)...");
  final sosResult = await EmailJSService.sendEmergencyEmail(
    toEmail: 'sujaykarkera5@gmail.com',
    patientName: 'Sujay (Self-Verification)',
    emergencyMessage: '🚨 This is an automated live verification of Emergency SOS via EmailJS 1st Template (template_aa0wwyi).',
    locationUrl: 'https://maps.google.com/?q=12.9716,77.5946',
    medicineList: 'Dolo 650, Metformin 500mg',
    additionalNote: 'Service ID: service_l5bgxos | Status: Operational',
  );
  print("SOS Email Result: $sosResult (Error: ${EmailJSService.lastError})");

  print("\n2. Testing 2nd Template: Caregiver Alert (template_err1y5l)...");
  final caregiverResult = await EmailJSService.sendCaregiverEmail(
    toEmail: 'sujaykarumbar@gmail.com',
    patientName: 'Sujay (Self-Verification)',
    message: 'Hello Caregiver,\nThis is a live test of Caregiver report using EmailJS 2nd Template (template_err1y5l). All services 100% functional.',
    subject: 'MediCare Caregiver Status Report (Verification)',
    medicineName: 'Dolo 650',
    status: 'Daily Report',
  );
  print("Caregiver Email Result: $caregiverResult (Error: ${EmailJSService.lastError})");

  print("\n3. Testing 2nd Template: Missed/Skipped Dose Alert (template_err1y5l)...");
  final skipResult = await EmailJSService.sendMissedOrSkippedDoseEmail(
    toEmail: 'sujaykarumbar@gmail.com',
    patientName: 'Sujay (Self-Verification)',
    medicineName: 'Dolo 650',
    scheduledTime: '9:00 AM',
    status: 'Skipped',
    dosage: '650 mg',
  );
  print("Skipped Dose Email Result: $skipResult (Error: ${EmailJSService.lastError})");

  if (sosResult && caregiverResult && skipResult) {
    print("\n🎉 ALL 3 EMAILJS TEMPLATE VERIFICATIONS PASSED 100%!");
  } else {
    print("\n❌ SOME VERIFICATIONS FAILED!");
  }
}
