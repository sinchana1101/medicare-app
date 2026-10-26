import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/speech_service.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/i18n_service.dart';
import '../services/emailjs_service.dart';
import '../services/voice_controller.dart';
import '../services/voice_intent_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

class EmergencyScreen extends StatefulWidget {
  final bool autoTrigger;
  const EmergencyScreen({super.key, this.autoTrigger = false});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with SingleTickerProviderStateMixin
    implements VoiceScreenDelegate {
  VoiceController? _voiceController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      _voiceController = Provider.of<VoiceController>(context, listen: false);
    } catch (_) {}
  }

  bool _isSending = false;
  String? _statusMessage;
  bool _emailSent = false;
  bool _smsSent = false;
  bool _callTriggered = false;
  final LocationService _locationService = LocationService();
  late AnimationController _pulseController;
  String? _contactName;
  String? _contactPhone;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _loadSavedContact();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final voice = Provider.of<VoiceController>(context, listen: false);
        voice.setActiveDelegate(this, AppScreen.emergency);
        voice.announceScreen();
        if (widget.autoTrigger) {
          _triggerSOS();
        }
      }
    });
  }

  @override
  void dispose() {
    _voiceController?.clearActiveDelegate(this);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  String getScreenAnnouncement() {
    if (!mounted) return "";
    final speech = Provider.of<SpeechService>(context, listen: false);
    final lang = speech.currentLanguage;
    if (lang.startsWith('kn')) {
      return "ತುರ್ತು ಪರದೆ. ಎಸ್ಒಎಸ್ ಕಳುಹಿಸಲು 'ಎಸ್ಒಎಸ್' ಅಥವಾ 'ಸಹಾಯ' ಎನ್ನಿ. ಆಂಬ್ಯುಲೆನ್ಸ್‌ಗೆ '೧೦೮' ಎನ್ನಿ, ಅಥವಾ 'ಆರೈಕೆದಾರರಿಗೆ ಕರೆ' ಎನ್ನಿ.";
    } else if (lang.startsWith('hi')) {
      return "आपातकालीन स्क्रीन। मदद के लिए 'एसओएस' या 'मदद' कहें। एम्बुलेंस के लिए '१०८' कहें, या 'केयरगिवर को कॉल' कहें।";
    }
    return "Emergency SOS screen. Say 'send SOS', 'call ambulance', 'call caregiver', or 'go back'.";
  }

  @override
  Future<bool> handleVoiceCommand(VoiceIntent? intent, String transcript) async {
    if (!mounted) return false;
    final speech = Provider.of<SpeechService>(context, listen: false);
    final db = Provider.of<DatabaseService>(context, listen: false);
    final lower = transcript.toLowerCase().trim();

    if (intent == VoiceIntent.emergency ||
        intent == VoiceIntent.sendMail ||
        lower.contains("send") ||
        lower.contains("sos") ||
        lower.contains("mail") ||
        lower.contains("email") ||
        lower.contains("sms") ||
        lower.contains("alert") ||
        lower.contains("help") ||
        transcript.contains("ಕಳುಹಿಸು") ||
        transcript.contains("ಎಸ್ಒಎಸ್") ||
        transcript.contains("ಇಮೇಲ್") ||
        transcript.contains("ಮೇಲ್") ||
        transcript.contains("ತುರ್ತು") ||
        transcript.contains("ಸಹಾಯ") ||
        transcript.contains("ಕಾಪಾಡಿ") ||
        transcript.contains("भेजो") ||
        transcript.contains("एसओएस") ||
        transcript.contains("ईमेल") ||
        transcript.contains("मेल") ||
        transcript.contains("मदद")) {
      speech.speak(speech.currentLanguage.startsWith('kn')
          ? "ತುರ್ತು ಎಸ್ಒಎಸ್ ಪ್ರಾರಂಭಿಸಲಾಗುತ್ತಿದೆ!"
          : speech.currentLanguage.startsWith('hi')
              ? "आपातकालीन एसओएस तुरंत शुरू किया जा रहा है!"
              : "Triggering emergency SOS immediately!");
      await _triggerSOS();
      return true;
    }

    switch (intent) {
      case VoiceIntent.callAmbulance:
        speech.speak("Calling 108 emergency ambulance.");
        final Uri telUri = Uri(scheme: 'tel', path: '108');
        if (await canLaunchUrl(telUri)) {
          await launchUrl(telUri);
        }
        return true;

      case VoiceIntent.callCaregiver:
        final contact = await db.getEmergencyContact();
        final phone = contact?['emergency_contact_phone'] ?? '112';
        final name = contact?['emergency_contact_name'] ?? 'Caregiver';
        speech.speak("Calling $name at $phone.");
        final Uri telUri = Uri(scheme: 'tel', path: phone);
        if (await canLaunchUrl(telUri)) {
          await launchUrl(telUri);
        }
        return true;

      case VoiceIntent.readPage:
      case VoiceIntent.repeat:
        final contact = await db.getEmergencyContact();
        final phone = contact?['emergency_contact_phone'] ?? '112';
        final name = contact?['emergency_contact_name'] ?? 'Emergency Services';
        speech.speak("Emergency contact is $name, phone number $phone. You can say 'send SOS' or 'call caregiver'.");
        return true;

      default:
        return false;
    }
  }

  Future<void> _loadSavedContact() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final contact = await db.getEmergencyContact();
    final profile = await db.getProfile();
    final name = contact?['emergency_contact_name'] ?? profile?['emergency_contact_name'];
    final phone = contact?['emergency_contact_phone'] ?? profile?['emergency_contact_phone'];
    if (mounted) {
      setState(() {
        if (name != null && name.toString().trim().isNotEmpty) {
          _contactName = name.toString().trim();
        }
        if (phone != null && phone.toString().trim().isNotEmpty) {
          _contactPhone = phone.toString().trim();
        }
      });
    }
  }

  Future<void> _triggerSOS() async {
    setState(() {
      _isSending = true;
      _statusMessage = null;
      _emailSent = false;
      _smsSent = false;
      _callTriggered = false;
    });

    final speech = Provider.of<SpeechService>(context, listen: false);
    final db = Provider.of<DatabaseService>(context, listen: false);

    try {
      // Announce SOS activation
      final startingMsg = speech.currentLanguage.startsWith('kn')
          ? "ತುರ್ತು SOS ಸಕ್ರಿಯಗೊಳಿಸಲಾಗುತ್ತಿದೆ. ನಿಮ್ಮ ಸ್ಥಳವನ್ನು ಪಡೆಯಲಾಗುತ್ತಿದೆ."
          : speech.currentLanguage.startsWith('hi')
              ? "आपातकालीन एसओएस सक्रिय किया जा रहा है। आपका स्थान प्राप्त किया जा रहा है।"
              : "Activating emergency SOS. Fetching your location.";
      speech.speak(startingMsg);
      setState(() => _statusMessage = "📍 Getting your location...");

      // 1. Get Location (Fast 2s timeout)
      Position? position;
      try {
        position = await _locationService.getCurrentLocation().timeout(
          const Duration(seconds: 2),
          onTimeout: () => null,
        );
      } catch (_) {}
      String locationMsg = "Emergency! I need help urgently. MediCare SOS Alert.";
      String? mapsUrl;

      if (position != null) {
        mapsUrl = _locationService.getGoogleMapsUrl(position);
        locationMsg += "\n📍 My location: $mapsUrl";
      }

      // 2. Fetch Emergency Contact
      final contact = await db.getEmergencyContact();
      final String phone = contact?['emergency_contact_phone'] ?? "112";
      final String contactName = contact?['emergency_contact_name'] ?? "Emergency Services";

      // 3. Get patient profile & medicines
      final profile = await db.getProfile();
      final patientName = profile?['full_name'] ?? "MediCare User";
      final medicines = await db.getMedicines();
      final medicineList = medicines
          .map((m) => "${m['name']} (${m['dosage'] ?? m['strength'] ?? ''})")
          .join(", ");

      // 4. Log event to database
      setState(() => _statusMessage = "📝 Logging emergency event...");
      await db.logEmergency(
        kind: 'sos',
        locationText: mapsUrl ?? "Location unavailable",
        note: "SOS triggered from mobile app",
      );

      // 5. Send Emergency Email via EmailJS (1st Template: template_aa0wwyi)
      final recipientEmails = <String>{};
      final caregivers = await db.getCaregivers();
      for (final cg in caregivers) {
        final em = cg['email']?.toString().trim();
        if (em != null && em.isNotEmpty && em.contains('@')) {
          recipientEmails.add(em);
        }
      }
      final ecEmail = contact?['emergency_contact_email']?.toString().trim() ??
          contact?['emergency_email']?.toString().trim() ??
          profile?['emergency_contact_email']?.toString().trim() ??
          profile?['emergency_email']?.toString().trim();
      if (ecEmail != null && ecEmail.isNotEmpty && ecEmail.contains('@')) {
        recipientEmails.add(ecEmail);
      }
      if (recipientEmails.isEmpty) {
        debugPrint("No emergency contact or caregiver emails found for this user.");
        setState(() => _statusMessage = "⚠️ No emergency contact email saved. You can configure it in Settings.");
      }

      final emailBody = "🚨 EMERGENCY SOS ALERT!\n\n"
          "$patientName has triggered an emergency SOS from the MediCare app.\n\n"
          "📍 Location: ${mapsUrl ?? 'Location unavailable'}\n"
          "💊 Medicines: ${medicineList.isNotEmpty ? medicineList : 'No medicines recorded'}\n"
          "📞 Emergency Contact: $contactName ($phone)\n"
          "🕒 Time: ${DateTime.now().toString().split('.').first}";

      bool anyEmailSuccess = false;
      if (recipientEmails.isNotEmpty) {
        for (final targetEmail in recipientEmails) {
          setState(() => _statusMessage = "📧 Sending SOS email to $targetEmail via EmailJS template...");
          debugPrint("EmailJS: Sending SOS 1st template (template_aa0wwyi) to $targetEmail...");
          final emailSuccess = await EmailJSService.sendEmergencyEmail(
            toEmail: targetEmail,
            patientName: patientName,
            emergencyMessage: emailBody,
            locationUrl: mapsUrl,
            medicineList: medicineList.isNotEmpty ? medicineList : "No medicines recorded",
            additionalNote: "Emergency contact: $contactName ($phone)\n"
                "Time: ${DateTime.now().toString()}",
          );
          if (emailSuccess) {
            anyEmailSuccess = true;
          }
        }

        if (anyEmailSuccess) {
          setState(() => _emailSent = true);
          final emailOk = speech.currentLanguage.startsWith('kn')
              ? "ತುರ್ತು ಇಮೇಲ್ ಯಶಸ್ವಿಯಾಗಿ ಕಳುಹಿಸಲಾಗಿದೆ."
              : speech.currentLanguage.startsWith('hi')
                  ? "आपातकालीन ईमेल सफलतापूर्वक भेजी गई।"
                  : "Emergency SOS email sent successfully via EmailJS.";
          speech.speak(emailOk);
        } else {
          final lastErr = EmailJSService.lastError ?? '';
          if (lastErr.contains("Invalid grant") || lastErr.contains("disconnected")) {
            setState(() => _statusMessage = "⚠️ EmailJS Gmail disconnected! Reconnect at dashboard.emailjs.com");
            speech.speak(speech.currentLanguage.startsWith('kn')
                ? "ಇಮೇಲ್‌ಜೆಎಸ್ ಖಾತೆ ಸಂಪರ್ಕ ಕಡಿತಗೊಂಡಿದೆ. ಮರುಸಂಪರ್ಕಿಸಿ."
                : "EmailJS Gmail account needs to be reconnected in EmailJS dashboard.");
          } else {
            setState(() => _statusMessage = "⚠️ Could not send SOS email via EmailJS.");
          }
        }
      } else {
        speech.speak("No emergency contact email saved. You can configure it in Settings.");
      }

      // 6. Send SMS
      setState(() => _statusMessage = "📱 Sending SMS to $contactName...");
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: phone,
        queryParameters: <String, String>{
          'body': locationMsg,
        },
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        setState(() => _smsSent = true);
      }

      // 7. Make Phone Call
      setState(() => _statusMessage = "📞 Calling $contactName...");
      final callingMsg = speech.currentLanguage.startsWith('kn')
          ? "$contactName ಅವರಿಗೆ ತಿಳಿಸಲಾಗುತ್ತಿದೆ ಮತ್ತು ಕರೆ ಮಾಡಲಾಗುತ್ತಿದೆ."
          : speech.currentLanguage.startsWith('hi')
              ? "$contactName को सूचित किया जा रहा है और कॉल की जा रही है।"
              : "Notifying $contactName and calling now.";
      speech.speak(callingMsg);

      final Uri callUri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(callUri)) {
        await launchUrl(callUri);
        setState(() => _callTriggered = true);
      }

      setState(() => _statusMessage = "✅ SOS completed — help is on the way!");

    } catch (e) {
      final failMsg = speech.currentLanguage.startsWith('kn')
          ? "ತುರ್ತು ಕರೆ ವಿಫಲವಾಗಿದೆ. ದಯವಿಟ್ಟು ನೇರವಾಗಿ ಕರೆ ಮಾಡಿ."
          : speech.currentLanguage.startsWith('hi')
              ? "आपातकालीन ट्रिगर विफल रहा। कृपया सीधे कॉल करें।"
              : "Emergency trigger failed. Please call for help manually.";
      speech.speak(failMsg);
      setState(() => _statusMessage = "❌ SOS failed: $e");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final speech = Provider.of<SpeechService>(context);
    final t = Provider.of<I18nService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        title: Text(
          t.translate('emergency.title', speech.currentLanguage),
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: -0.3),
        ),
        backgroundColor: const Color(0xFF7F1D1D),
        elevation: 0,
        actions: [
          Consumer<VoiceController>(
            builder: (context, voice, child) {
              final active = voice.isContinuousMode || speech.isListening;
              return IconButton(
                tooltip: "Voice command",
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFFEF4444) : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: active ? const Color(0xFFEF4444) : const Color(0xFF334155)),
                  ),
                  child: Icon(
                    active ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                onPressed: () {
                  if (voice.isContinuousMode) {
                    voice.stopContinuousListening();
                  } else {
                    voice.listenAndExecute();
                  }
                },
                onLongPress: () {
                  voice.toggleContinuousListening();
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Warning Icon with Pulse
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseController.value * 0.08),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 100,
                    color: Color(0xFFEF4444),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),
            Text(
              t.translate('emergency.help', speech.currentLanguage),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
            ),
            const SizedBox(height: 8),
            Text(
              t.translate('emergency.desc', speech.currentLanguage),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFF94A3B8), height: 1.4),
            ),
            const SizedBox(height: 6),
            const Text(
              "Sends: 📧 Email  •  📱 SMS  •  📞 Call",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 30),

            // SOS Button
            _isSending
                ? Column(
                    children: [
                      const SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          color: Color(0xFFEF4444),
                          strokeWidth: 5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_statusMessage != null)
                        Text(
                          _statusMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                    ],
                  )
                : ElevatedButton(
                    onPressed: _triggerSOS,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      minimumSize: const Size(double.infinity, 140),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      elevation: 8,
                      shadowColor: const Color(0x80EF4444),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.sos_rounded, size: 60, color: Colors.white),
                        const SizedBox(height: 8),
                        Text(
                          t.translate('emergency.sendSos', speech.currentLanguage),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),

            const SizedBox(height: 16),

            // Quick Call Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final Uri telUri = Uri(scheme: 'tel', path: '108');
                      if (await canLaunchUrl(telUri)) {
                        await launchUrl(telUri);
                      }
                    },
                    icon: const Icon(Icons.local_hospital_rounded, color: Color(0xFFEF4444), size: 20),
                    label: const Text(
                      "Call 108",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final phone = _contactPhone ?? '112';
                      final Uri telUri = Uri(scheme: 'tel', path: phone);
                      if (await canLaunchUrl(telUri)) {
                        await launchUrl(telUri);
                      }
                    },
                    icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF38BDF8), size: 20),
                    label: Text(
                      _contactName != null && _contactName!.isNotEmpty ? "Call $_contactName" : "Call Caregiver",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      side: const BorderSide(color: Color(0xFF0284C7), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Status Results
            if (_emailSent || _smsSent || _callTriggered) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0x1A10B981),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x6610B981)),
                ),
                child: Column(
                  children: [
                    if (_emailSent)
                      const _StatusRow(icon: Icons.email_rounded, text: "Emergency email sent ✅", color: Color(0xFF10B981)),
                    if (_smsSent)
                      const _StatusRow(icon: Icons.sms_rounded, text: "SMS opened ✅", color: Color(0xFF10B981)),
                    if (_callTriggered)
                      const _StatusRow(icon: Icons.phone_rounded, text: "Phone call triggered ✅", color: Color(0xFF10B981)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_statusMessage != null && !_isSending)
              Text(
                _statusMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Color(0xFF94A3B8)),
              ),

            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                t.translate('emergency.goBack', speech.currentLanguage),
                style: const TextStyle(fontSize: 18, color: Colors.white70, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _StatusRow({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}
