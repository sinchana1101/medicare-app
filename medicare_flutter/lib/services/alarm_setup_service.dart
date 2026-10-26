import 'dart:async';
import 'package:flutter/material.dart';
import 'speech_service.dart';
import 'database_service.dart';
import 'dose_utils.dart';
import 'voice_intent_service.dart';

class AlarmSetupService extends ChangeNotifier {
  final SpeechService _speech;
  final DatabaseService _db;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  String _status = "";
  String get status => _status;

  bool _isCancelled = false;

  AlarmSetupService(this._speech, this._db);

  static const Map<String, int> numberWords = {
    'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6,
    'once': 1, 'twice': 2, 'thrice': 3,
    'ಒಂದು': 1, 'ಎರಡು': 2, 'ಮೂರು': 3, 'ನಾಲ್ಕು': 4, 'ಐದು': 5, 'ಆರು': 6,
    'एक': 1, 'दो': 2, 'तीन': 3, 'चार': 4, 'पांच': 5, 'पाँच': 5, 'छह': 6,
  };

  int? _parseSpokenNumber(String text) {
    final digits = RegExp(r'\d+').firstMatch(text);
    if (digits != null) return int.tryParse(digits.group(0)!);
    
    final lower = text.toLowerCase();
    for (var entry in numberWords.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  String? _parseSpokenTime(String text) {
    final lower = text.toLowerCase();
    int? hour;
    int minute = 0;

    final clockMatch = RegExp(r'(\d{1,2})[:.](\d{2})').firstMatch(lower);
    if (clockMatch != null) {
      hour = int.tryParse(clockMatch.group(1)!);
      minute = int.tryParse(clockMatch.group(2)!) ?? 0;
    } else {
      hour = _parseSpokenNumber(lower);
    }

    if (hour == null || hour > 23) return null;

    final isEvening = RegExp(r'evening|night|pm|afternoon|ಸಂಜೆ|ರಾತ್ರಿ|ಮಧ್ಯಾಹ್ನ|शाम|रात|दोपहर').hasMatch(lower);
    final isMorning = RegExp(r'morning|am|ಬೆಳಗ್ಗೆ|ಬೆಳಿಗ್ಗೆ|सुबह|प्रातः').hasMatch(lower);

    if (hour <= 12) {
      if (isEvening && hour != 12) {
        hour += 12;
      } else if (isMorning && hour == 12) {
        hour = 0;
      }
    }

    if (minute > 59) return null;
    return "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
  }

  Future<String> _ask(String prompt) async {
    _status = prompt;
    notifyListeners();
    await _speech.speak(prompt);
    await _speech.waitForSpeech();
    
    if (_isCancelled) return "";
    
    _status = "$prompt — Listening...";
    notifyListeners();
    
    final heard = await _speech.listenOnce();
    final intent = VoiceIntentService.matchIntent(heard);
    
    if (intent == VoiceIntent.cancel || intent == VoiceIntent.stop) {
      _isCancelled = true;
      return "";
    }
    return heard;
  }

  void cancel() {
    _isCancelled = true;
    _isRunning = false;
    _status = "";
    _speech.stop(); // Fixed: using standard stop() method
    _speech.speak("Setup cancelled.");
    notifyListeners();
  }

  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;
    _isCancelled = false;
    notifyListeners();

    try {
      // 1. Medicine Name
      String name = "";
      for (int i = 0; i < 2 && name.isEmpty; i++) {
        name = await _ask(i == 0 ? "Which medicine would you like to set an alarm for?" : "I didn't catch that. What is the medicine name?");
        if (_isCancelled) return;
      }
      if (name.isEmpty) {
        await _speech.speak("Sorry, I couldn't hear the medicine name.");
        return;
      }

      // 2. Count
      int? count;
      for (int i = 0; i < 3 && count == null; i++) {
        final heard = await _ask("How many times a day should you take $name?");
        if (_isCancelled) return;
        count = _parseSpokenNumber(heard);
        if (count != null && (count < 1 || count > 6)) count = null;
      }
      if (count == null) {
        await _speech.speak("Setup cancelled due to invalid count.");
        return;
      }

      // 3. Times
      List<String> times = [];
      for (int i = 1; i <= count; i++) {
        String? time;
        for (int attempt = 0; attempt < 3 && time == null; attempt++) {
          final heard = await _ask("At what time for dose $i?");
          if (_isCancelled) return;
          time = _parseSpokenTime(heard);
        }
        if (time == null) {
          await _speech.speak("Setup cancelled.");
          return;
        }
        times.add(time);
        await _speech.speak("Time set to ${DoseUtils.friendlyTime(time)}");
      }

      // 4. Confirm
      final timeStr = times.map((t) => DoseUtils.friendlyTime(t)).join(", ");
      final confirmHeard = await _ask("Confirm: $name, $count times a day at $timeStr. Say yes to save.");
      if (_isCancelled) return;
      
      final intent = VoiceIntentService.matchIntent(confirmHeard);
      if (intent == VoiceIntent.yes || intent == VoiceIntent.save) {
        // Save to DB
        final medicines = await _db.getMedicines();
        final existing = medicines.firstWhere((m) => m['name'].toString().toLowerCase().contains(name.toLowerCase()), orElse: () => {});
        
        String medId;
        if (existing.isNotEmpty) {
          medId = existing['id'];
        } else {
          await _db.addMedicine({'name': name});
          final updated = await _db.getMedicines();
          medId = updated.firstWhere((m) => m['name'] == name)['id'];
        }

        await _db.insertSchedule({
          'medicine_id': medId,
          'times': times,
          'days_of_week': [0, 1, 2, 3, 4, 5, 6],
          'start_date': DateTime.now().toIso8601String().substring(0, 10),
          'active': true,
        });

        await _speech.speak("Alarm saved for $name.");
      } else {
        await _speech.speak("Setup discarded.");
      }

    } catch (e) {
      debugPrint("Alarm setup error: $e");
      await _speech.speak("Something went wrong with the setup.");
    } finally {
      _isRunning = false;
      _status = "";
      notifyListeners();
    }
  }
}
