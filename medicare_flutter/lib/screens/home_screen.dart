import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/speech_service.dart';
import '../services/alarm_setup_service.dart';
import '../services/database_service.dart';
import '../services/dose_utils.dart';
import '../services/voice_intent_service.dart';
import '../services/i18n_service.dart';
import '../services/ai_service.dart';
import '../services/voice_controller.dart';
import 'camera_screen.dart';
import 'scan_screen.dart';
import 'schedule_screen.dart';
import 'assistant_screen.dart';
import 'emergency_screen.dart';
import 'settings_screen.dart';
import '../services/emailjs_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> implements VoiceScreenDelegate {
  VoiceController? _voiceController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      _voiceController = Provider.of<VoiceController>(context, listen: false);
    } catch (_) {}
  }

  List<TodayDose> _todayDoses = [];
  List<Map<String, dynamic>> _alerts = [];
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  int _currentNavIndex = 0;
  static bool _initialSummarySpoken = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final voice = Provider.of<VoiceController>(context, listen: false);
        voice.setActiveDelegate(this, AppScreen.home);
      }
    });
  }

  @override
  void dispose() {
    try {
      _voiceController?.clearActiveDelegate(this);
    } catch (_) {}
    super.dispose();
  }

  @override
  String getScreenAnnouncement() {
    if (!mounted) return "";
    final speech = Provider.of<SpeechService>(context, listen: false);
    final summary = DoseUtils.spokenSummary(_todayDoses, language: speech.currentLanguage);
    final hint = speech.currentLanguage.startsWith('kn')
        ? "ಹೇಳಿ: 'ತೆಗೆದುಕೊಂಡೆ', 'ಮುಂದಿನ ಔಷಧಿ', 'ಸ್ಕ್ಯಾನ್', ಅಥವಾ 'ತುರ್ತು'."
        : speech.currentLanguage.startsWith('hi')
            ? "कहें: 'ले ली', 'अगली दवा', 'स्कैन', या 'आपातकाल'।"
            : "Say: 'mark taken', 'next medicine', 'scan', 'emergency', or 'help'.";
    return "$summary. $hint";
  }

  @override
  Future<bool> handleVoiceCommand(VoiceIntent? intent, String transcript) async {
    if (!mounted) return false;
    final setup = Provider.of<AlarmSetupService>(context, listen: false);
    final speech = Provider.of<SpeechService>(context, listen: false);
    final db = Provider.of<DatabaseService>(context, listen: false);
    final lang = speech.currentLanguage;

    switch (intent) {
      case VoiceIntent.markTaken:
        final pending = _todayDoses.where((d) => d.status != 'taken').toList();
        if (pending.isNotEmpty) {
          final target = pending.first;
          final medName = target.medicine['name'] ?? 'Medicine';
          await db.logDose(
            target.medicine['id'],
            'taken',
            scheduleId: target.schedule['id'],
            scheduledFor: target.scheduledFor,
          );
          final done = lang.startsWith('kn')
              ? "$medName ತೆಗೆದುಕೊಂಡಂತೆ ಗುರುತಿಸಲಾಗಿದೆ. ಉತ್ತಮ!"
              : lang.startsWith('hi')
                  ? "$medName ले ली गई के रूप में चिह्नित किया गया।"
                  : "Marked $medName as taken. Well done.";
          speech.speak(done);
          await _loadData();
        } else {
          speech.speak(lang.startsWith('kn') ? "ಇಂದಿನ ಎಲ್ಲಾ ಔಷಧಿಗಳನ್ನು ಈಗಾಗಲೇ ತೆಗೆದುಕೊಳ್ಳಲಾಗಿದೆ." : "All medicines for today are already marked as taken.");
        }
        return true;

      case VoiceIntent.skipDose:
        final pending = _todayDoses.where((d) => d.status != 'taken').toList();
        if (pending.isNotEmpty) {
          final target = pending.first;
          final medName = target.medicine['name'] ?? 'Medicine';
          await db.logDose(
            target.medicine['id'],
            'skipped',
            scheduleId: target.schedule['id'],
            scheduledFor: target.scheduledFor,
          );
          speech.speak(lang.startsWith('kn')
              ? "$medName ಬಿಟ್ಟುಬಿಡಲಾಗಿದೆ. ಆರೈಕೆದಾರರಿಗೆ ಎಚ್ಚರಿಕೆ ಕಳುಹಿಸಲಾಗಿದೆ."
              : "Skipped $medName. Caregiver notified.");
          await _loadData();
        } else {
          speech.speak("No pending doses to skip.");
        }
        return true;

      case VoiceIntent.nextMedicine:
        final pending = _todayDoses.where((d) => d.status != 'taken').toList();
        if (pending.isNotEmpty) {
          final next = pending.first;
          final time = DoseUtils.friendlyTime(next.time);
          final name = next.medicine['name'] ?? 'Medicine';
          speech.speak(lang.startsWith('kn')
              ? "ನಿಮ್ಮ ಮುಂದಿನ ಔಷಧಿ $name, ಸಮಯ $time."
              : "Your next medicine is $name at $time.");
        } else {
          speech.speak(lang.startsWith('kn') ? "ಇಂದು ಮುಂದೆ ಯಾವುದೇ ಬಾಕಿ ಔಷಧಿಗಳಿಲ್ಲ." : "No upcoming doses left for today.");
        }
        return true;

      case VoiceIntent.readPage:
      case VoiceIntent.repeat:
        speech.speak(getScreenAnnouncement());
        return true;

      case VoiceIntent.takePhoto:
        Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (context) => const CameraScreen()),
        ).then((capturedPath) {
          if (mounted) {
            final voice = Provider.of<VoiceController>(context, listen: false);
            voice.setActiveDelegate(this, AppScreen.home);
            if (capturedPath != null && capturedPath.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ScanScreen(initialImagePath: capturedPath)),
              ).then((_) => _loadData());
            } else {
              _loadData();
            }
          }
        });
        return true;

      case VoiceIntent.setAlarm:
        setup.start();
        return true;

      case VoiceIntent.refresh:
        await _loadData();
        speech.speak("Dashboard refreshed.");
        return true;

      case VoiceIntent.sendMail:
        final voice = Provider.of<VoiceController>(context, listen: false);
        await voice.sendCaregiverMail();
        return true;

      default:
        return false;
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final db = Provider.of<DatabaseService>(context, listen: false);
    final speech = Provider.of<SpeechService>(context, listen: false);

    try {
      final medicines = await db.getMedicines();
      final schedules = await db.getSchedules();
      final logs = await db.getDoseLogs();
      final alertsData = await db.getAlerts();
      final profileData = await db.getProfile();
      if (!mounted) return;
      if (profileData != null && profileData['gemini_api_key'] != null && profileData['gemini_api_key'].toString().isNotEmpty) {
        final ai = Provider.of<AIService>(context, listen: false);
        if (ai.apiKey == null || ai.apiKey!.isEmpty) {
          ai.setApiKey(profileData['gemini_api_key']);
        }
      }

      setState(() {
        _profile = profileData;
        _todayDoses = DoseUtils.buildTodayDoses(
          medicines: medicines,
          schedules: schedules,
          logs: logs,
        );
        _alerts = alertsData.where((a) => a['acknowledged'] == false).toList();
        _isLoading = false;
      });

      // Spoken overview on first load in selected language
      if (!_initialSummarySpoken) {
        _initialSummarySpoken = true;
        final summary = DoseUtils.spokenSummary(_todayDoses, language: speech.currentLanguage);
        speech.speak(summary);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onBottomNavTapped(int index) {
    if (index == _currentNavIndex) return;
    setState(() => _currentNavIndex = index);

    switch (index) {
      case 0:
        // Already home
        break;
      case 1:
        Navigator.push(context, MaterialPageRoute(builder: (context) => const ScanScreen())).then((_) {
          setState(() => _currentNavIndex = 0);
          _loadData();
        });
        break;
      case 2:
        Navigator.push(context, MaterialPageRoute(builder: (context) => const ScheduleScreen())).then((_) {
          setState(() => _currentNavIndex = 0);
          _loadData();
        });
        break;
      case 3:
        Navigator.push(context, MaterialPageRoute(builder: (context) => const AssistantScreen())).then((_) {
          setState(() => _currentNavIndex = 0);
        });
        break;
      case 4:
        Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())).then((_) {
          setState(() => _currentNavIndex = 0);
          _loadData();
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final speech = Provider.of<SpeechService>(context);
    final setup = Provider.of<AlarmSetupService>(context);
    final db = Provider.of<DatabaseService>(context);
    final t = Provider.of<I18nService>(context);

    final summary = DoseUtils.spokenSummary(_todayDoses, language: speech.currentLanguage);
    final userName = _profile?['full_name']?.toString().split(" ").first ?? "there";
    final formattedDate = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.translate('home.hello', speech.currentLanguage, vars: {'name': userName}),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 22,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              formattedDate,
              style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          // Email caregivers report button (template_err1y5l)
          IconButton(
            tooltip: "Email report to caregivers (EmailJS template 2)",
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Icon(Icons.mark_email_read_rounded, color: Color(0xFF38BDF8), size: 24),
            ),
            onPressed: () async {
              final voice = Provider.of<VoiceController>(context, listen: false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("📧 Sending EmailJS report (template_err1y5l) to caregivers..."),
                  duration: Duration(seconds: 2),
                ),
              );
              final ok = await voice.sendCaregiverMail();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    content: Text(ok
                        ? "✅ Email report sent to caregivers!"
                        : "⚠️ EmailJS error: ${EmailJSService.lastError ?? 'Check EmailJS connection'}"),
                  ),
                );
              }
            },
          ),
          // Read aloud button
          IconButton(
            tooltip: "Read today's schedule aloud",
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Icon(Icons.volume_up_rounded, color: Color(0xFF38BDF8), size: 24),
            ),
            onPressed: () => speech.speak(summary),
          ),
          // Push-to-talk microphone button
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
                    size: 24,
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
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadData,
            color: const Color(0xFF0284C7),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              children: [
                // Today Summary Card
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            t.translate('home.today', speech.currentLanguage),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                              color: Colors.white70,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              t.translate('home.doses', speech.currentLanguage, vars: {'count': _todayDoses.length.toString()}),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        summary,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),

                // Safety / Refill Alerts (if any)
                if (_alerts.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    t.translate('home.alerts', speech.currentLanguage),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFF59E0B),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ..._alerts.map((a) => _buildAlertCard(a, db)),
                ],

                // Today's Doses Header
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      t.translate('home.todaysSchedule', speech.currentLanguage),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF38BDF8),
                        letterSpacing: 1.2,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ScheduleScreen()),
                      ).then((_) => _loadData()),
                      icon: const Icon(Icons.calendar_month, size: 16, color: Color(0xFF94A3B8)),
                      label: Text(
                        t.translate('home.allSchedules', speech.currentLanguage),
                        style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Dose Tiles List - Grouped by medicine so details never appear twice
                if (_todayDoses.isEmpty)
                  _buildEmptyState(t, speech)
                else
                  ...DoseUtils.groupTodayDoses(_todayDoses).map(
                    (g) => _MedicineGroupTile(group: g, onUpdate: _loadData, t: t, speech: speech),
                  ),
              ],
            ),
          ),

          // Floating SOS Button
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.extended(
              heroTag: 'sos_btn',
              backgroundColor: const Color(0xFFEF4444),
              elevation: 8,
              onPressed: () {
                speech.speak("Opening emergency help.");
                Navigator.push(context, MaterialPageRoute(builder: (context) => const EmergencyScreen()));
              },
              icon: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 28),
              label: Text(
                t.translate('home.sos', speech.currentLanguage),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1, color: Colors.white),
              ),
            ),
          ),

          if (setup.isRunning) _AlarmSetupOverlay(setup: setup),
          if (_isLoading) const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7))),
        ],
      ),

      // Fixed 5-Tab Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111827),
          border: Border(top: BorderSide(color: Color(0xFF1E293B), width: 1.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentNavIndex,
          onTap: _onBottomNavTapped,
          backgroundColor: const Color(0xFF111827),
          selectedItemColor: const Color(0xFF38BDF8),
          unselectedItemColor: const Color(0xFF64748B),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_rounded),
              label: t.translate('nav.home', speech.currentLanguage),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.document_scanner_rounded),
              label: t.translate('nav.scan', speech.currentLanguage),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.calendar_month_rounded),
              label: t.translate('nav.schedule', speech.currentLanguage),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.chat_bubble_rounded),
              label: t.translate('nav.assistant', speech.currentLanguage),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_rounded),
              label: t.translate('nav.more', speech.currentLanguage),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert, DatabaseService db) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert['title'] ?? "Refill / Safety Notice",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  alert['message'] ?? "",
                  style: const TextStyle(fontSize: 14, color: Color(0xFFCBD5E1), height: 1.3),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFFF59E0B), size: 28),
            onPressed: () async {
              await db.acknowledgeAlert(alert['id']);
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(I18nService t, SpeechService speech) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.5),
        border: Border.all(color: const Color(0xFF334155), width: 1.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.medication_liquid_rounded, size: 70, color: Color(0xFF64748B)),
          const SizedBox(height: 16),
          Text(
            t.translate('home.empty', speech.currentLanguage),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            t.translate('home.emptySub', speech.currentLanguage),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ScanScreen()),
            ).then((_) => _loadData()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            icon: const Icon(Icons.add_a_photo_rounded),
            label: Text(
              t.translate('home.scanCta', speech.currentLanguage),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicineGroupTile extends StatelessWidget {
  final MedicineDoseGroup group;
  final VoidCallback onUpdate;
  final I18nService t;
  final SpeechService speech;
  const _MedicineGroupTile({
    required this.group,
    required this.onUpdate,
    required this.t,
    required this.speech,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'taken':
        return const Color(0xFF10B981);
      case 'due':
        return const Color(0xFF38BDF8);
      case 'upcoming':
        return const Color(0xFF64748B);
      case 'missed':
        return const Color(0xFFEF4444);
      case 'skipped':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _getStatusText(String status) {
    return t.translate('status.$status', speech.currentLanguage);
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final isAllTaken = group.allTaken;
    final primaryDose = group.primaryDose;
    final statusColor = _getStatusColor(group.status);
    final isDue = group.status == 'due';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDue ? const Color(0xFF0284C7) : const Color(0xFF334155),
          width: isDue ? 2 : 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  isAllTaken ? "COMPLETED" : _getStatusText(group.status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                    color: statusColor,
                  ),
                ),
              ),

              // Time chips row showing all dose timings for today
              Flexible(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.end,
                  children: group.doses.map((d) {
                    final dColor = _getStatusColor(d.status);
                    final isThisPrimary = d.key == primaryDose.key && !isAllTaken;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isThisPrimary ? dColor.withValues(alpha: 0.22) : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isThisPrimary ? dColor : const Color(0xFF334155),
                          width: isThisPrimary ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            d.status == 'taken' ? Icons.check_circle_rounded : Icons.schedule_rounded,
                            size: 13,
                            color: dColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            DoseUtils.friendlyTime(d.time),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isThisPrimary ? FontWeight.w800 : FontWeight.w600,
                              color: isThisPrimary ? Colors.white : const Color(0xFFCBD5E1),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Medicine Name and Strength (displayed ONLY ONCE per medicine)
          Text(
            group.medicine['name'] ?? "Medicine",
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          if (group.medicine['composition'] != null && group.medicine['composition'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.science_outlined, size: 15, color: Color(0xFF38BDF8)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    group.medicine['composition'].toString(),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF38BDF8), fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (group.medicine['purpose'] != null && group.medicine['purpose'].toString().isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(Icons.healing_outlined, size: 15, color: Color(0xFF34D399)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    group.medicine['purpose'].toString(),
                    style: const TextStyle(fontSize: 13, color: Color(0xFF34D399), fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (group.medicine['when_to_take'] != null && group.medicine['when_to_take'].toString().isNotEmpty) ...[
            const SizedBox(height: 5),
            Row(
              children: [
                const Icon(Icons.alarm_on_rounded, size: 15, color: Color(0xFFFBBF24)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    group.medicine['when_to_take'].toString(),
                    style: const TextStyle(fontSize: 13, color: Color(0xFFFBBF24), fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (group.medicine['dosage'] != null || group.medicine['instructions'] != null) ...[
            const SizedBox(height: 6),
            Text(
              [group.medicine['dosage'], group.medicine['instructions']]
                  .where((s) => s != null && s.toString().isNotEmpty)
                  .join(" • "),
              style: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8), height: 1.3),
            ),
          ],

          const SizedBox(height: 16),

          // Actions
          if (isAllTaken)
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "All doses completed for today!",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                  ),
                ),
                IconButton(
                  tooltip: "Delete this schedule",
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                  ),
                  onPressed: () => _confirmDelete(context, db),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final doneText = speech.currentLanguage.startsWith('kn')
                          ? "ತೆಗೆದುಕೊಂಡಂತೆ ಗುರುತಿಸಲಾಗಿದೆ."
                          : speech.currentLanguage.startsWith('hi')
                              ? "ले ली गई के रूप में चिह्नित किया गया।"
                              : "Marked as taken. Well done.";
                      speech.speak(doneText);
                      await db.logDose(
                        primaryDose.medicine['id'],
                        'taken',
                        scheduleId: primaryDose.schedule['id'],
                        scheduledFor: primaryDose.scheduledFor,
                      );
                      onUpdate();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 56),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 22),
                    label: Text(
                      "${t.translate('home.markTaken', speech.currentLanguage)} (${DoseUtils.friendlyTime(primaryDose.time)})",
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: OutlinedButton(
                    onPressed: () async {
                      final skipText = speech.currentLanguage.startsWith('kn')
                          ? "ಡೋಸ್ ಬಿಟ್ಟುಬಿಡಲಾಗಿದೆ. ಆರೈಕೆದಾರರಿಗೆ ಇಮೇಲ್ ಕಳುಹಿಸಲಾಗಿದೆ."
                          : speech.currentLanguage.startsWith('hi')
                              ? "खुराक छोड़ दी गई। देखभालकर्ता को ईमेल भेजा गया।"
                              : "Dose skipped. Caregiver notified via email.";
                      speech.speak(skipText);
                      await db.logDose(
                        primaryDose.medicine['id'],
                        'skipped',
                        scheduleId: primaryDose.schedule['id'],
                        scheduledFor: primaryDose.scheduledFor,
                      );
                      onUpdate();

                      final caregivers = await db.getCaregivers();
                      final caregiverEmail = caregivers.isNotEmpty &&
                              caregivers.first['email'] != null &&
                              caregivers.first['email'].toString().isNotEmpty
                          ? caregivers.first['email'].toString()
                          : "caregiver";

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFFF59E0B),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            content: Row(
                              children: [
                                const Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "Dose skipped. Alert sent to $caregiverEmail!",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF94A3B8),
                      side: const BorderSide(color: Color(0xFF475569), width: 1.5),
                      minimumSize: const Size(0, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      t.translate('home.skip', speech.currentLanguage),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: "Delete this schedule",
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF64748B), size: 22),
                  onPressed: () => _confirmDelete(context, db),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, DatabaseService db) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Color(0xFFEF4444), size: 28),
            SizedBox(width: 10),
            Text("Delete Schedule", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "Delete \"${group.medicine['name']}\" and its schedule? This cannot be undone.",
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              speech.speak("${group.medicine['name']} deleted.");
              await db.deleteMedicine(group.medicine['id']);
              await db.deactivateSchedule(group.schedule['id']);
              onUpdate();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.delete_rounded, size: 18),
            label: const Text("Delete", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _AlarmSetupOverlay extends StatelessWidget {
  final AlarmSetupService setup;
  const _AlarmSetupOverlay({required this.setup});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF0284C7), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.alarm_add_rounded, size: 64, color: Color(0xFF38BDF8)),
              const SizedBox(height: 16),
              const Text(
                "Voice Alarm Setup",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Text(
                setup.status.isNotEmpty ? setup.status : "Listening for medicine details...",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17, color: Color(0xFFCBD5E1), height: 1.4),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: setup.cancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text("CANCEL SETUP", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
