import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/speech_service.dart';
import '../services/ai_service.dart';
import '../services/database_service.dart';
import '../services/i18n_service.dart';
import '../services/voice_controller.dart';
import '../services/voice_intent_service.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> implements VoiceScreenDelegate {
  VoiceController? _voiceController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      _voiceController = Provider.of<VoiceController>(context, listen: false);
    } catch (_) {}
  }

  final List<Map<String, String>> _messages = [];
  final _controller = TextEditingController();
  bool _isListening = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final voice = Provider.of<VoiceController>(context, listen: false);
        voice.setActiveDelegate(this, AppScreen.assistant);
        voice.announceScreen();
      }
    });
  }

  @override
  void dispose() {
    _voiceController?.clearActiveDelegate(this);
    _voiceController?.setCurrentScreen(AppScreen.home);
    _controller.dispose();
    super.dispose();
  }

  @override
  String getScreenAnnouncement() {
    if (!mounted) return "";
    final speech = Provider.of<SpeechService>(context, listen: false);
    final lang = speech.currentLanguage;
    if (lang.startsWith('kn')) {
      return "ಎಐ ಸಹಾಯಕ ಪರದೆ. ನಿಮ್ಮ ಯಾವುದೇ ಆರೋಗ್ಯ ಪ್ರಶ್ನೆಯನ್ನು ನೇರವಾಗಿ ಮಾತನಾಡಿ ಕೇಳಬಹುದು.";
    } else if (lang.startsWith('hi')) {
      return "एआई सहायक स्क्रीन। अपनी सेहत या दवा के बारे में सीधे बोलकर सवाल पूछें।";
    }
    return "AI Voice Assistant screen. Ask any medicine or health question directly.";
  }

  @override
  Future<bool> handleVoiceCommand(VoiceIntent? intent, String transcript) async {
    if (!mounted) return false;
    final speech = Provider.of<SpeechService>(context, listen: false);
    if (intent == VoiceIntent.repeat) {
      if (_messages.isNotEmpty) {
        final lastAssistant = _messages.lastWhere((m) => m['role'] == 'assistant', orElse: () => {});
        if (lastAssistant.isNotEmpty) {
          speech.speak(lastAssistant['text']!);
          return true;
        }
      }
    }

    // If it's a global navigation intent like home, scan, back, let VoiceController handle it
    if (intent == VoiceIntent.home ||
        intent == VoiceIntent.scan ||
        intent == VoiceIntent.schedule ||
        intent == VoiceIntent.emergency ||
        intent == VoiceIntent.more ||
        intent == VoiceIntent.back ||
        intent == VoiceIntent.langEn ||
        intent == VoiceIntent.langKn ||
        intent == VoiceIntent.langHi ||
        intent == VoiceIntent.stop) {
      return false;
    }

    // Any other question is directly answered by the AI assistant!
    if (transcript.trim().isNotEmpty) {
      await _ask(transcript);
      return true;
    }
    return false;
  }

  void _addMessage(String text, bool isUser) {
    setState(() {
      _messages.add({'text': text, 'role': isUser ? 'user' : 'assistant'});
    });
  }

  Future<void> _ask(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _busy) return;

    final speech = Provider.of<SpeechService>(context, listen: false);
    final ai = Provider.of<AIService>(context, listen: false);
    final db = Provider.of<DatabaseService>(context, listen: false);

    _addMessage(trimmed, true);
    _controller.clear();
    setState(() => _busy = true);

    try {
      final medicines = await db.getMedicines();
      final schedules = await db.getSchedules();
      final medInfo = medicines.map((m) {
        final comp = (m['composition'] != null && m['composition'].toString().isNotEmpty) ? " contains ${m['composition']}" : "";
        final timing = (m['when_to_take'] != null && m['when_to_take'].toString().isNotEmpty) ? ". When to take: ${m['when_to_take']}" : "";
        final inst = (m['instructions'] != null && m['instructions'].toString().isNotEmpty) ? ". Instructions: ${m['instructions']}" : "";
        return "${m['name']}$comp$timing$inst";
      }).join(". ");
      final schedInfo = schedules.isNotEmpty ? "; Schedules: ${schedules.map((s) => s['time']).join(', ')}" : "";
      final contextText = "$medInfo$schedInfo";

      speech.speak(speech.currentLanguage.startsWith('kn') ? "ಯೋಚಿಸುತ್ತಿದ್ದೇನೆ..." : "Thinking...");
      final answer = await ai.askAssistant(trimmed, contextText, language: speech.currentLanguage);

      _addMessage(answer, false);
      speech.speak(answer);
    } catch (e) {
      final errorMsg = speech.currentLanguage.startsWith('kn')
          ? "ಕ್ಷಮಿಸಿ, ಸಹಾಯಕನಿಗೆ ಸಂಪರ್ಕ ಸಾಧಿಸಲು ಸಾಧ್ಯವಾಗುತ್ತಿಲ್ಲ."
          : speech.currentLanguage.startsWith('hi')
              ? "क्षमा करें, सहायक से जुड़ने में समस्या आ रही है।"
              : "Sorry, I'm having trouble connecting to the assistant.";
      _addMessage(errorMsg, false);
      speech.speak(errorMsg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleVoiceCommand() async {
    final speech = Provider.of<SpeechService>(context, listen: false);
    final voice = Provider.of<VoiceController>(context, listen: false);
    setState(() => _isListening = true);
    final heard = await speech.listenOnce();
    setState(() => _isListening = false);
    if (heard.isNotEmpty) {
      final intent = VoiceIntentService.matchIntent(heard);
      if (intent != null && intent != VoiceIntent.help) {
        final handled = await handleVoiceCommand(intent, heard);
        if (!handled) {
          await voice.executeIntent(intent, heard);
          return;
        }
      }
      _ask(heard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final speech = Provider.of<SpeechService>(context);
    final t = Provider.of<I18nService>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(t.translate('nav.assistant', speech.currentLanguage)),
        backgroundColor: Colors.blueGrey[900],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[700] : Colors.blueGrey[800],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      msg['text']!,
                      style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(),
            ),
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.blueGrey[900],
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: _ask,
                    decoration: const InputDecoration(
                      hintText: "Ask anything...",
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.white54),
                    ),
                    style: const TextStyle(fontSize: 20, color: Colors.white),
                  ),
                ),
                IconButton(
                  icon: Icon(_isListening ? Icons.graphic_eq : Icons.mic, size: 45, color: Colors.white),
                  onPressed: _handleVoiceCommand,
                ),
                IconButton(
                  icon: const Icon(Icons.send, size: 40, color: Colors.blue),
                  onPressed: () => _ask(_controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
