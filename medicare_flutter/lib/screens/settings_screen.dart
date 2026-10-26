import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/speech_service.dart';
import '../services/database_service.dart';
import '../services/ai_service.dart';
import '../services/i18n_service.dart';
import '../services/voice_controller.dart';
import '../services/voice_intent_service.dart';
import 'caregiver_screen.dart';
import 'auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> implements VoiceScreenDelegate {
  VoiceController? _voiceController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      _voiceController = Provider.of<VoiceController>(context, listen: false);
    } catch (_) {}
  }

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final voice = Provider.of<VoiceController>(context, listen: false);
        voice.setActiveDelegate(this, AppScreen.settings);
        voice.announceScreen();
      }
    });
  }

  Future<void> _loadProfile() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final ai = Provider.of<AIService>(context, listen: false);
    final speech = Provider.of<SpeechService>(context, listen: false);
    final profile = await db.getProfile();
    final emergency = await db.getEmergencyContact();
    if (emergency != null || profile != null) {
      setState(() {
        _nameController.text = emergency?['emergency_contact_name'] ?? profile?['emergency_contact_name'] ?? "";
        _phoneController.text = emergency?['emergency_contact_phone'] ?? profile?['emergency_contact_phone'] ?? "";
        _emailController.text = emergency?['emergency_contact_email'] ?? profile?['emergency_contact_email'] ?? profile?['emergency_email'] ?? "";
      });
      if (profile != null) {
        if (profile['preferred_language'] != null && profile['preferred_language'].toString().isNotEmpty) {
          speech.currentLanguage = profile['preferred_language'];
        }
        if (profile['gemini_api_key'] != null && profile['gemini_api_key'].toString().isNotEmpty) {
          ai.setApiKey(profile['gemini_api_key']);
        }
      }
    }
  }

  @override
  void dispose() {
    _voiceController?.clearActiveDelegate(this);
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  String getScreenAnnouncement() {
    if (!mounted) return "";
    final speech = Provider.of<SpeechService>(context, listen: false);
    final lang = speech.currentLanguage;
    if (lang.startsWith('kn')) {
      return "ಸೆಟ್ಟಿಂಗ್ಸ್ ಪರದೆ. ಭಾಷೆ ಬದಲಾಯಿಸಲು 'ಕನ್ನಡ', 'ಇಂಗ್ಲಿಷ್', ಅಥವಾ 'ಹಿಂದಿ' ಎನ್ನಿ. ನಿರ್ಗಮಿಸಲು 'ಲಾಗ್ ಔಟ್' ಎನ್ನಿ.";
    } else if (lang.startsWith('hi')) {
      return "सेटिंग्स स्क्रीन। भाषा बदलने के लिए 'हिंदी', 'अंग्रेजी', या 'कन्नड़' कहें। बाहर निकलने के लिए 'लॉग आउट' कहें।";
    }
    return "Settings screen. Say 'English', 'Kannada', or 'Hindi' to change language, or 'log out'.";
  }

  @override
  Future<bool> handleVoiceCommand(VoiceIntent? intent, String transcript) async {
    if (!mounted) return false;
    final speech = Provider.of<SpeechService>(context, listen: false);
    final db = Provider.of<DatabaseService>(context, listen: false);

    switch (intent) {
      case VoiceIntent.langKn:
        speech.announceLanguageChanged('kn-IN');
        await db.saveProfile({'preferred_language': 'kn-IN'});
        return true;

      case VoiceIntent.langHi:
        speech.announceLanguageChanged('hi-IN');
        await db.saveProfile({'preferred_language': 'hi-IN'});
        return true;

      case VoiceIntent.langEn:
        speech.announceLanguageChanged('en-US');
        await db.saveProfile({'preferred_language': 'en-US'});
        return true;

      case VoiceIntent.signOut:
        speech.speak("Signing out.");
        await FirebaseAuth.instance.signOut();
        if (mounted) Navigator.pop(context);
        return true;

      case VoiceIntent.readPage:
      case VoiceIntent.repeat:
        final contactName = _nameController.text.trim();
        final langName = speech.currentLanguage.startsWith('kn')
            ? "ಕನ್ನಡ"
            : speech.currentLanguage.startsWith('hi')
                ? "हिंदी"
                : "English";
        speech.speak("Current language is $langName. Emergency contact is ${contactName.isNotEmpty ? contactName : 'not set'}.");
        return true;

      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final speech = Provider.of<SpeechService>(context);
    final db = Provider.of<DatabaseService>(context);
    final ai = Provider.of<AIService>(context);
    final t = Provider.of<I18nService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        title: Text(t.translate('settings.title', speech.currentLanguage), style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
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
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        children: [
          // Active Account Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF0284C7),
                  radius: 22,
                  child: Icon(Icons.person, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Signed In Account",
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        db.activeEmail ?? "Guest User",
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          _buildSectionHeader(t.translate('settings.language', speech.currentLanguage)),
          _buildLanguageTile("English", "en-US", speech, db),
          _buildLanguageTile("ಕನ್ನಡ (Kannada)", "kn-IN", speech, db),
          _buildLanguageTile("हिंदी (Hindi)", "hi-IN", speech, db),
          const SizedBox(height: 16),

          _buildSectionHeader(
            speech.currentLanguage.startsWith('kn')
                ? "ಧ್ವನಿ ಮತ್ತು ಶಬ್ದ ರದ್ದತಿ"
                : speech.currentLanguage.startsWith('hi')
                    ? "आवाज और शोर रद्दीकरण"
                    : "Voice & Noise Cancellation",
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: speech.noiseCancellation ? const Color(0xFF10B981) : const Color(0xFF334155),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (speech.noiseCancellation ? const Color(0xFF10B981) : const Color(0xFF64748B)).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    speech.noiseCancellation ? Icons.noise_control_off_rounded : Icons.graphic_eq_rounded,
                    color: speech.noiseCancellation ? const Color(0xFF10B981) : const Color(0xFF64748B),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        speech.currentLanguage.startsWith('kn')
                            ? "ಹಿನ್ನೆಲೆ ಶಬ್ದ ರದ್ದತಿ"
                            : speech.currentLanguage.startsWith('hi')
                                ? "बैकग्राउंड शोर रद्दीकरण"
                                : "Background Noise Cancellation",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        speech.currentLanguage.startsWith('kn')
                            ? "ಮಾತನಾಡುವಾಗ ಸುತ್ತಲಿನ ಶಬ್ದ ಮತ್ತು ಇತರರ ಧ್ವನಿಯನ್ನು ತಡೆಯುತ್ತದೆ"
                            : speech.currentLanguage.startsWith('hi')
                                ? "बोलते समय पृष्ठभूमि की आवाज और टीवी शोर को रोकता है"
                                : "Filters out background voices, room murmurs, and TV audio",
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: speech.noiseCancellation,
                  activeThumbColor: const Color(0xFF10B981),
                  activeTrackColor: const Color(0xFF10B981).withValues(alpha: 0.4),
                  onChanged: (val) {
                    speech.setNoiseCancellation(val);
                    final msg = val
                        ? (speech.currentLanguage.startsWith('kn') ? "ಶಬ್ದ ರದ್ದತಿ ಆನ್ ಆಗಿದೆ." : "Noise cancellation enabled.")
                        : (speech.currentLanguage.startsWith('kn') ? "ಶಬ್ದ ರದ್ದತಿ ಆಫ್ ಆಗಿದೆ." : "Noise cancellation disabled.");
                    speech.speak(msg);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _buildSectionHeader(t.translate('settings.safety', speech.currentLanguage)),
          _SettingsActionButton(
            label: t.translate('settings.runSafety', speech.currentLanguage),
            icon: Icons.shield_outlined,
            color: const Color(0xFF1E293B),
            textColor: const Color(0xFF38BDF8),
            borderColor: const Color(0xFF38BDF8),
            onPressed: () async {
              speech.speak("Checking your medicines for safety issues.");
              final meds = await db.getMedicines();
              final result = await ai.runSafetyCheck(meds, language: speech.currentLanguage);
              speech.speak(result['spoken_summary'] ?? "Check complete.");
            },
          ),

          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFF334155)),
          const SizedBox(height: 24),

          _buildSectionHeader(t.translate('settings.emergencyContact', speech.currentLanguage)),
          _buildTextField(t.translate('settings.contactName', speech.currentLanguage), _nameController),
          const SizedBox(height: 12),
          _buildTextField(t.translate('settings.phoneNumber', speech.currentLanguage), _phoneController, keyboard: TextInputType.phone),
          const SizedBox(height: 12),
          _buildTextField(t.translate('settings.email', speech.currentLanguage), _emailController, keyboard: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _SettingsActionButton(
            label: t.translate('settings.saveContact', speech.currentLanguage),
            icon: Icons.save_rounded,
            color: const Color(0xFF0284C7),
            isLoading: _isSaving,
            onPressed: () async {
              setState(() => _isSaving = true);
              try {
                final email = _emailController.text.trim();
                await db.saveEmergencyContact(
                  name: _nameController.text.trim(),
                  phone: _phoneController.text.trim(),
                  email: email,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Emergency contact & email saved!"),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                speech.speak("Emergency contact saved.");
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Save note: $e")),
                  );
                }
              } finally {
                if (mounted) setState(() => _isSaving = false);
              }
            },
          ),

          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFF334155)),
          const SizedBox(height: 24),

          _buildSectionHeader(t.translate('settings.caregivers', speech.currentLanguage)),
          _SettingsActionButton(
            label: t.translate('settings.manageCaregivers', speech.currentLanguage),
            icon: Icons.people_rounded,
            color: const Color(0xFF6366F1),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CaregiverScreen())),
          ),

          const SizedBox(height: 32),
          _SettingsActionButton(
            label: "SWITCH ACCOUNT / CREATE NEW",
            icon: Icons.switch_account_rounded,
            color: const Color(0xFF0284C7),
            onPressed: () async {
              final db = Provider.of<DatabaseService>(context, listen: false);
              final speech = Provider.of<SpeechService>(context, listen: false);
              speech.speak("Signing out. You can now register or sign in with another Gmail.");
              await FirebaseAuth.instance.signOut();
              await db.switchUser(null);
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(height: 12),
          _SettingsActionButton(
            label: t.translate('settings.signOut', speech.currentLanguage),
            icon: Icons.logout_rounded,
            color: const Color(0xFFDC2626),
            onPressed: () async {
              final db = Provider.of<DatabaseService>(context, listen: false);
              final speech = Provider.of<SpeechService>(context, listen: false);
              speech.speak("Signing out.");
              await FirebaseAuth.instance.signOut();
              await db.switchUser(null);
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8), letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType keyboard = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF334155))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF334155))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5)),
      ),
    );
  }

  Widget _buildLanguageTile(String label, String code, SpeechService speech, DatabaseService db) {
    bool isSelected = speech.currentLanguage == code;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF0284C7).withValues(alpha: 0.15) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF334155)),
      ),
      child: ListTile(
        title: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
          ),
        ),
        trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF38BDF8), size: 24) : null,
        onTap: () async {
          speech.announceLanguageChanged(code);
          await db.saveProfile({'preferred_language': code});
        },
      ),
    );
  }
}

class _SettingsActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback onPressed;
  final bool isLoading;

  const _SettingsActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.textColor = Colors.white,
    this.borderColor,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: textColor,
        side: borderColor != null ? BorderSide(color: borderColor!, width: 1.5) : null,
        minimumSize: const Size(double.infinity, 58),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Icon(icon, color: textColor, size: 24),
      label: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
    );
  }
}
