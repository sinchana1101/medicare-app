import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service to send emergency emails via EmailJS REST API.
/// No server needed — works directly from the Flutter app.
class EmailJSService {
  // EmailJS Credentials
  static const String _serviceId = 'service_l5bgxos';
  static const String _publicKey = 'LvbbrVLjBxjp47Oiu';
  static const String _apiUrl = 'https://api.emailjs.com/api/v1.0/email/send';

  /// 1st Template: Emergency SOS (template_aa0wwyi)
  static const String sosTemplateId = 'template_aa0wwyi';

  /// 2nd Template: Caregiver Alert / Health Report (template_err1y5l)
  static const String caregiverTemplateId = 'template_err1y5l';

  static String? lastError;

  /// Send an emergency SOS email using 1st Template (template_aa0wwyi).
  ///
  /// [toEmail] — Recipient email address (emergency contact / caregiver)
  /// [patientName] — The patient's name
  /// [emergencyMessage] — The emergency alert text
  /// [locationUrl] — Google Maps link to patient location (if available)
  /// [medicineList] — Comma-separated list of current medicines
  /// [additionalNote] — Any extra context (optional)
  ///
  /// Returns `true` if sent successfully, `false` otherwise.
  static Future<bool> sendEmergencyEmail({
    required String toEmail,
    required String patientName,
    required String emergencyMessage,
    String? locationUrl,
    String? medicineList,
    String? additionalNote,
  }) async {
    lastError = null;
    try {
      final nowStr = DateTime.now().toString().split('.').first;
      final templateParams = {
        'to_email': toEmail,
        'email': toEmail,
        'recipient_email': toEmail,
        'to_name': toEmail.split('@').first,
        'from_name': patientName,
        'name': patientName,
        'patient_name': patientName,
        'user_name': patientName,
        'title': '🚨 EMERGENCY SOS ALERT - $patientName',
        'subject': '🚨 EMERGENCY SOS ALERT: $patientName needs help!',
        'message': emergencyMessage,
        'emergency_message': emergencyMessage,
        'notes': emergencyMessage,
        'location_url': locationUrl ?? 'Location unavailable',
        'location': locationUrl ?? 'Location unavailable',
        'medicine_list': medicineList ?? 'No medicines recorded',
        'medicines': medicineList ?? 'No medicines recorded',
        'additional_note': additionalNote ?? '',
        'time': nowStr,
        'date': nowStr,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final body = jsonEncode({
        'service_id': _serviceId,
        'template_id': sosTemplateId,
        'user_id': _publicKey,
        'template_params': templateParams,
      });

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        },
        body: body,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('EmailJS: SOS email successfully sent to $toEmail using template $sosTemplateId');
        return true;
      } else {
        lastError = response.body;
        debugPrint('EmailJS: SOS Failed (${response.statusCode}): ${response.body}');
        if (response.body.contains("Invalid grant") || response.statusCode == 412) {
          lastError = 'Gmail account disconnected in EmailJS. Reconnect service "$_serviceId" at https://dashboard.emailjs.com/admin/services';
          debugPrint('⚠️ ACTION REQUIRED: $lastError');
        }
        return false;
      }
    } catch (e) {
      lastError = e.toString();
      debugPrint('EmailJS: Error sending SOS email: $e');
      return false;
    }
  }

  /// Send a Caregiver report / health status email using 2nd Template (template_err1y5l).
  ///
  /// [toEmail] — Caregiver recipient email address
  /// [patientName] — Name of the patient
  /// [message] — Caregiver notification body / dose summary
  static Future<bool> sendCaregiverEmail({
    required String toEmail,
    required String patientName,
    required String message,
    String? subject,
    String? medicineName,
    String? scheduledTime,
    String? status,
    String? dosage,
  }) async {
    lastError = null;
    try {
      final nowStr = DateTime.now().toString().split('.').first;
      final templateParams = {
        'to_email': toEmail,
        'email': toEmail,
        'recipient_email': toEmail,
        'to_name': toEmail.split('@').first,
        'from_name': patientName,
        'name': patientName,
        'patient_name': patientName,
        'user_name': patientName,
        'title': subject ?? 'MediCare Caregiver Report - $patientName',
        'subject': subject ?? 'MediCare Caregiver Report - $patientName',
        'message': message,
        'emergency_message': message,
        'notes': message,
        'medicine_name': medicineName ?? 'All Medications',
        'medicine': medicineName ?? 'All Medications',
        'dosage': dosage ?? '',
        'dose': dosage ?? '',
        'scheduled_time': scheduledTime ?? nowStr,
        'time': scheduledTime ?? nowStr,
        'status': status ?? 'Report',
        'action': status ?? 'Report',
        'timestamp': DateTime.now().toIso8601String(),
        'date': nowStr,
      };

      final body = jsonEncode({
        'service_id': _serviceId,
        'template_id': caregiverTemplateId,
        'user_id': _publicKey,
        'template_params': templateParams,
      });

      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
        },
        body: body,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint('EmailJS: Caregiver email successfully sent to $toEmail using template $caregiverTemplateId');
        return true;
      } else {
        lastError = response.body;
        debugPrint('EmailJS: Caregiver email Failed (${response.statusCode}): ${response.body}');
        if (response.body.contains("Invalid grant") || response.statusCode == 412) {
          lastError = 'Gmail account disconnected in EmailJS. Reconnect service "$_serviceId" at https://dashboard.emailjs.com/admin/services';
          debugPrint('⚠️ ACTION REQUIRED: $lastError');
        }
        return false;
      }
    } catch (e) {
      lastError = e.toString();
      debugPrint('EmailJS: Error sending caregiver email: $e');
      return false;
    }
  }

  /// Send an automatic alert email when a dose is missed or skipped.
  /// Uses 2nd Template: template_err1y5l
  static Future<bool> sendMissedOrSkippedDoseEmail({
    required String toEmail,
    required String patientName,
    required String medicineName,
    required String scheduledTime,
    required String status,
    String? dosage,
  }) async {
    final formattedStatus = status.toLowerCase() == 'skipped' ? 'Skipped' : 'Missed';
    final alertText = 'Alert: Patient $patientName has $formattedStatus their scheduled dose of $medicineName'
        '${(dosage != null && dosage.isNotEmpty) ? " ($dosage)" : ""}'
        ' scheduled for $scheduledTime.';

    return sendCaregiverEmail(
      toEmail: toEmail,
      patientName: patientName,
      message: alertText,
      subject: 'MediCare Alert: $formattedStatus Dose - $medicineName',
      medicineName: medicineName,
      scheduledTime: scheduledTime,
      status: formattedStatus,
      dosage: dosage,
    );
  }
}
