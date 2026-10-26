import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/database_service.dart';
import '../services/speech_service.dart';
import '../services/dose_utils.dart';
import '../services/i18n_service.dart';
import '../services/voice_controller.dart';
import '../services/voice_intent_service.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> implements VoiceScreenDelegate {
  VoiceController? _voiceController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      _voiceController = Provider.of<VoiceController>(context, listen: false);
    } catch (_) {}
  }

  List<TodayDose> _doses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final voice = Provider.of<VoiceController>(context, listen: false);
        voice.setActiveDelegate(this, AppScreen.schedule);
        voice.announceScreen();
      }
    });
  }

  @override
  void dispose() {
    _voiceController?.clearActiveDelegate(this);
    super.dispose();
  }

  @override
  String getScreenAnnouncement() {
    if (!mounted) return "";
    final speech = Provider.of<SpeechService>(context, listen: false);
    final lang = speech.currentLanguage;
    final count = _doses.length;
    if (lang.startsWith('kn')) {
      return "ವೇಳಾಪಟ್ಟಿ ಪರದೆ. ಇಂದು ನಿಮಗೆ $count ಡೋಸ್‌ಗಳಿವೆ. ಕೇಳಲು 'ಎಲ್ಲಾ ಓದಿ' ಎನ್ನಿ, ಅಥವಾ 'ತೆಗೆದುಕೊಂಡೆ' ಎನ್ನಿ.";
    } else if (lang.startsWith('hi')) {
      return "समय-सारणी स्क्रीन। आज आपकी $count खुराकें हैं। सुनने के लिए 'सब पढ़ो' कहें, या 'ले ली' कहें।";
    }
    return "Schedule screen. You have $count doses today. Say 'read all' to listen, or 'mark taken'.";
  }

  @override
  Future<bool> handleVoiceCommand(VoiceIntent? intent, String transcript) async {
    if (!mounted) return false;
    final speech = Provider.of<SpeechService>(context, listen: false);
    final db = Provider.of<DatabaseService>(context, listen: false);
    final lang = speech.currentLanguage;

    switch (intent) {
      case VoiceIntent.readPage:
      case VoiceIntent.repeat:
        if (_doses.isEmpty) {
          speech.speak(lang.startsWith('kn') ? "ಇಂದು ಯಾವುದೇ ಔಷಧಿ ನಿಗದಿಯಾಗಿಲ್ಲ." : "No medicines scheduled for today.");
        } else {
          final buffer = StringBuffer();
          buffer.write(lang.startsWith('kn') ? "ಇಂದಿನ ವೇಳಾಪಟ್ಟಿ: " : "Today's schedule: ");
          for (var d in _doses) {
            final time = DoseUtils.friendlyTime(d.time);
            final name = d.medicine['name'] ?? 'Medicine';
            final status = d.status == 'taken'
                ? (lang.startsWith('kn') ? "ತೆಗೆದುಕೊಳ್ಳಲಾಗಿದೆ" : "already taken")
                : (lang.startsWith('kn') ? "ಬಾಕಿ ಇದೆ" : "pending");
            buffer.write("$time: $name, $status. ");
          }
          speech.speak(buffer.toString());
        }
        return true;

      case VoiceIntent.markTaken:
        final pending = _doses.where((d) => d.status != 'taken').toList();
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
              ? "$medName ತೆಗೆದುಕೊಂಡಂತೆ ಗುರುತಿಸಲಾಗಿದೆ."
              : lang.startsWith('hi')
                  ? "$medName ले ली गई के रूप में चिह्नित किया गया।"
                  : "Marked $medName as taken. Well done.";
          speech.speak(done);
          await _refresh();
        } else {
          speech.speak(lang.startsWith('kn') ? "ಎಲ್ಲಾ ಔಷಧಿಗಳನ್ನು ಈಗಾಗಲೇ ತೆಗೆದುಕೊಳ್ಳಲಾಗಿದೆ." : "All medicines are already marked as taken.");
        }
        return true;

      case VoiceIntent.refresh:
        await _refresh();
        speech.speak("Schedule refreshed.");
        return true;

      default:
        return false;
    }
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final db = Provider.of<DatabaseService>(context, listen: false);
    
    try {
      final medicines = await db.getMedicines();
      final schedules = await db.getSchedules();
      final logs = await db.getDoseLogs();

      if (!mounted) return;
      setState(() {
        _doses = DoseUtils.buildTodayDoses(
          medicines: medicines,
          schedules: schedules,
          logs: logs,
        );
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final speech = Provider.of<SpeechService>(context);
    final db = Provider.of<DatabaseService>(context);
    final t = Provider.of<I18nService>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        title: Text(
          t.translate('schedule.title', speech.currentLanguage),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF111827),
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refresh),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)))
          : _doses.isEmpty
              ? _buildEmptyState(t, speech)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _doses.length,
                  itemBuilder: (context, index) {
                    final dose = _doses[index];
                    return _DoseCard(
                      dose: dose,
                      onMarkTaken: () async {
                        final markedMsg = speech.currentLanguage.startsWith('kn')
                            ? "${dose.medicine['name']} ತೆಗೆದುಕೊಂಡಂತೆ ಗುರುತಿಸಲಾಗಿದೆ."
                            : speech.currentLanguage.startsWith('hi')
                                ? "${dose.medicine['name']} ले ली गई के रूप में चिह्नित किया गया।"
                                : "Marking ${dose.medicine['name']} as taken.";
                        speech.speak(markedMsg);
                        await db.logDose(
                          dose.medicine['id'], 
                          'taken',
                          scheduleId: dose.schedule['id'],
                          scheduledFor: dose.scheduledFor,
                        );
                        _refresh();
                      },
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState(I18nService t, SpeechService speech) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today, size: 100, color: Color(0xFF64748B)),
          const SizedBox(height: 20),
          Text(
            t.translate('schedule.empty', speech.currentLanguage),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

class _DoseCard extends StatelessWidget {
  final TodayDose dose;
  final VoidCallback onMarkTaken;

  const _DoseCard({required this.dose, required this.onMarkTaken});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    
    switch (dose.status) {
      case 'taken':
        statusColor = const Color(0xFF10B981);
        statusIcon = Icons.check_circle;
        break;
      case 'missed':
        statusColor = const Color(0xFFEF4444);
        statusIcon = Icons.error_outline;
        break;
      case 'due':
        statusColor = const Color(0xFF38BDF8);
        statusIcon = Icons.access_time_filled;
        break;
      default:
        statusColor = const Color(0xFF64748B);
        statusIcon = Icons.access_time;
    }

    return Card(
      color: const Color(0xFF1E293B),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: statusColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DoseUtils.friendlyTime(dose.time),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    dose.medicine['name'],
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  if (dose.medicine['composition'] != null && dose.medicine['composition'].toString().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.science_outlined, size: 14, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            dose.medicine['composition'].toString(),
                            style: const TextStyle(fontSize: 13, color: Color(0xFF38BDF8), fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (dose.medicine['purpose'] != null && dose.medicine['purpose'].toString().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.healing_outlined, size: 14, color: Color(0xFF34D399)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            dose.medicine['purpose'].toString(),
                            style: const TextStyle(fontSize: 13, color: Color(0xFF34D399), fontWeight: FontWeight.w500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (dose.medicine['when_to_take'] != null && dose.medicine['when_to_take'].toString().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.alarm_on_rounded, size: 14, color: Color(0xFFFBBF24)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            dose.medicine['when_to_take'].toString(),
                            style: const TextStyle(fontSize: 13, color: Color(0xFFFBBF24), fontWeight: FontWeight.w600),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (dose.medicine['dosage'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(dose.medicine['dosage'], style: const TextStyle(fontSize: 15, color: Colors.white70)),
                    ),
                ],
              ),
            ),
            if (dose.status != 'taken')
              IconButton(
                icon: Icon(statusIcon, size: 44, color: statusColor),
                onPressed: onMarkTaken,
              )
            else
              Icon(statusIcon, size: 44, color: statusColor),
          ],
        ),
      ),
    );
  }
}
