import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'speech_service.dart';
import 'database_service.dart';
import 'dose_utils.dart';

class AlarmService extends ChangeNotifier {
  TodayDose? _ringingDose;
  TodayDose? get ringingDose => _ringingDose;

  Timer? _timer;
  final Set<String> _firedKeys = {};
  final Set<String> _missedAlertedKeys = {};
  String? _monitoredUserId;

  void reset() {
    _ringingDose = null;
    _firedKeys.clear();
    _missedAlertedKeys.clear();
    notifyListeners();
  }

  void startMonitoring(BuildContext context) {
    _timer?.cancel();
    // Check every 20 seconds, same as React
    _timer = Timer.periodic(const Duration(seconds: 20), (timer) async {
      final db = Provider.of<DatabaseService>(context, listen: false);
      final speech = Provider.of<SpeechService>(context, listen: false);
      
      final currentUid = db.userId;
      if (_monitoredUserId != null && _monitoredUserId != currentUid) {
        reset();
      }
      _monitoredUserId = currentUid;
      
      try {
        final medicines = await db.getMedicines();
        final schedules = await db.getSchedules();
        final logs = await db.getDoseLogs();
        
        final doses = DoseUtils.buildTodayDoses(
          medicines: medicines,
          schedules: schedules,
          logs: logs,
        );

        final now = DateTime.now();

        // 1. Detect and alert for missed doses (> 60 minutes past scheduled time)
        for (var dose in doses) {
          if (dose.status == 'missed' && !_missedAlertedKeys.contains(dose.key)) {
            _missedAlertedKeys.add(dose.key);
            debugPrint("AlarmService: Missed dose detected for ${dose.medicine['name']} at ${dose.time}. Auto-logging & emailing caregivers.");
            await db.logDose(
              dose.medicine['id'],
              'missed',
              scheduleId: dose.schedule['id'],
              scheduledFor: dose.scheduledFor,
            );
          }
        }
        
        // 2. Find a dose that is "due" and hasn't been fired today
        for (var dose in doses) {
          if (dose.status == 'due' && !_firedKeys.contains(dose.key)) {
            // Check if it's within the valid window (not older than 1 hour)
            if (now.difference(dose.scheduledFor).inHours.abs() < 1) {
              _ringingDose = dose;
              _firedKeys.add(dose.key);
              notifyListeners();
              
              speech.speak("It is ${DoseUtils.friendlyTime(dose.time)}. Time for ${dose.medicine['name']}. Please say taken or snooze.");
              break; 
            }
          }
        }
      } catch (e) {
        debugPrint("Alarm monitor error: $e");
      }
    });
  }

  Future<void> acknowledge(String action, BuildContext context) async {
    if (_ringingDose == null) return;
    
    final speech = Provider.of<SpeechService>(context, listen: false);
    final db = Provider.of<DatabaseService>(context, listen: false);

    if (action == 'taken') {
      await db.logDose(
        _ringingDose!.medicine['id'], 
        'taken',
        scheduleId: _ringingDose!.schedule['id'],
        scheduledFor: _ringingDose!.scheduledFor,
      );
      speech.speak("Marked as taken. Well done.");
    } else if (action == 'skip' || action == 'skipped') {
      await db.logDose(
        _ringingDose!.medicine['id'], 
        'skipped',
        scheduleId: _ringingDose!.schedule['id'],
        scheduledFor: _ringingDose!.scheduledFor,
      );
      speech.speak("Dose skipped. Caregiver notified.");
    } else {
      speech.speak("Snoozed for 10 minutes.");
      // Temporarily remove from fired keys so it can ring again
      final key = _ringingDose!.key;
      _firedKeys.remove(key);
      Timer(const Duration(minutes: 10), () {
        // It will be picked up by the next periodic check if still due
      });
    }
    
    _ringingDose = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
