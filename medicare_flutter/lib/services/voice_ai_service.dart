import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class VoiceAIService extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  final SpeechToText _stt = SpeechToText();
  
  String _currentLanguage = 'en-US';
  String get currentLanguage => _currentLanguage;
  
  set currentLanguage(String lang) {
    _currentLanguage = lang;
    notifyListeners();
  }

  final String _aiKey = utf8.decode(base64.decode('QVEuQWI4Uk42S2RwdFhnOVZ5UEEwQmRlTGxFa19LQ1JXVVRBejctRTMyUi1sZ1NGWlJBR0E='));

  Future<void> speak(String text) async {
    await _tts.setLanguage(_currentLanguage);
    await _tts.speak(text);
  }

  Future<void> startListening(Function(String) onResult) async {
    bool available = await _stt.initialize();
    if (available) {
      _stt.listen(
        onResult: (val) {
          if (val.finalResult) {
            onResult(val.recognizedWords);
          }
        },
        listenOptions: SpeechListenOptions(localeId: _currentLanguage),
      );
    } else {
      speak("Voice recognition is not available.");
    }
  }

  Future<Map<String, dynamic>> scanMedicine(String base64Image, String language) async {
    if (_aiKey.isEmpty) throw Exception("AI Key not configured");
    final response = await http.post(
      Uri.parse("https://ai.gateway.lovable.dev/v1/chat/completions"),
      headers: {"Content-Type": "application/json", "Lovable-API-Key": _aiKey},
      body: jsonEncode({
        "model": "google/gemini-2.5-flash",
        "messages": [
          {"role": "system", "content": "Return ONLY JSON with: name, dosage, strength, instructions, scanned_text. Language: $language"},
          {"role": "user", "content": [{"type": "text", "text": "Read this label."}, {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,$base64Image"}}]}
        ]
      }),
    );
    final data = jsonDecode(response.body);
    String cleaned = data['choices'][0]['message']['content'].replaceAll(RegExp(r'```json|```'), '').trim();
    return jsonDecode(cleaned);
  }
}
