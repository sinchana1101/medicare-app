import 'package:intl/intl.dart';

class TodayDose {
  final String key;
  final Map<String, dynamic> medicine;
  final Map<String, dynamic> schedule;
  final String time;
  final DateTime scheduledFor;
  final String status; // 'taken' | 'skipped' | 'missed' | 'upcoming' | 'due'

  TodayDose({
    required this.key,
    required this.medicine,
    required this.schedule,
    required this.time,
    required this.scheduledFor,
    required this.status,
  });
}

class MedicineDoseGroup {
  final Map<String, dynamic> medicine;
  final Map<String, dynamic> schedule;
  final List<TodayDose> doses;

  MedicineDoseGroup({
    required this.medicine,
    required this.schedule,
    required this.doses,
  });

  /// The active dose needing attention (due > missed > upcoming), or fallback
  TodayDose get primaryDose {
    final due = doses.where((d) => d.status == 'due').toList();
    if (due.isNotEmpty) return due.first;

    final missed = doses.where((d) => d.status == 'missed').toList();
    if (missed.isNotEmpty) return missed.first;

    final upcoming = doses.where((d) => d.status == 'upcoming').toList();
    if (upcoming.isNotEmpty) return upcoming.first;

    return doses.isNotEmpty
        ? doses.last
        : TodayDose(
            key: '',
            medicine: medicine,
            schedule: schedule,
            time: '08:00',
            scheduledFor: DateTime.now(),
            status: 'taken',
          );
  }

  bool get allTaken => doses.isNotEmpty && doses.every((d) => d.status == 'taken');
  bool get hasMissed => doses.any((d) => d.status == 'missed');
  bool get hasDue => doses.any((d) => d.status == 'due');
  String get status => allTaken ? 'taken' : primaryDose.status;
}

class DoseUtils {
  static String friendlyTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final now = DateTime.now();
      final dt = DateTime(now.year, now.month, now.day, hour, minute);
      return DateFormat.jm().format(dt);
    } catch (e) {
      return timeStr;
    }
  }

  static List<TodayDose> buildTodayDoses({
    required List<Map<String, dynamic>> medicines,
    required List<Map<String, dynamic>> schedules,
    required List<Map<String, dynamic>> logs,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    final today = DateTime(currentTime.year, currentTime.month, currentTime.day);
    final List<TodayDose> doses = [];

    final medMap = {for (var m in medicines) m['id']: m};

    for (var schedule in schedules) {
      final medicine = medMap[schedule['medicine_id']];
      if (medicine == null) continue;

      // Check days of week (0 is Sunday in JS, 1-7 in Dart where 7 is Sunday)
      final List<dynamic> daysOfWeek = schedule['days_of_week'] ?? [];
      final List<dynamic> daysNames = schedule['days'] ?? [];
      int dartWeekday = currentTime.weekday; // 1 (Mon) - 7 (Sun)
      int jsWeekday = dartWeekday == 7 ? 0 : dartWeekday;
      
      if (daysOfWeek.isNotEmpty && !daysOfWeek.contains(jsWeekday)) continue;
      const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      final todayName = dayNames[jsWeekday];
      if (daysNames.isNotEmpty && !daysNames.contains(todayName)) continue;

      // Check start/end dates
      if (schedule['start_date'] != null && currentTime.year >= 2024) {
        try {
          final start = DateTime.parse(schedule['start_date'].toString());
          if (start.isAfter(currentTime)) continue;
        } catch (_) {}
      }
      if (schedule['end_date'] != null) {
        try {
          final end = DateTime.parse(schedule['end_date'].toString());
          if (end.isBefore(today)) continue;
        } catch (_) {}
      }

      List<dynamic> times = [];
      if (schedule['times'] is List && (schedule['times'] as List).isNotEmpty) {
        times = schedule['times'];
      } else if (schedule['time'] != null && schedule['time'].toString().isNotEmpty) {
        times = [schedule['time'].toString()];
      }

      for (var time in times) {
        final timeStr = time.toString();
        final parts = timeStr.split(':');
        if (parts.length < 2) continue;
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        
        final scheduledFor = DateTime(today.year, today.month, today.day, h, m);

        // Find log
        final log = logs.firstWhere(
          (l) {
            if (l['medicine_id'] != medicine['id']) return false;
            final sf = l['scheduled_for'];
            if (sf == null) return false;
            try {
              final parsed = DateTime.parse(sf.toString());
              return parsed.difference(scheduledFor).inMinutes.abs() < 5;
            } catch (_) {
              return false;
            }
          },
          orElse: () => {},
        );

        String status;
        if (log['status'] == 'taken') {
          status = 'taken';
        } else if (log['status'] == 'skipped') {
          status = 'skipped';
        } else if (log['status'] == 'missed') {
          status = 'missed';
        } else if (currentTime.difference(scheduledFor).inMinutes > 60) {
          status = 'missed';
        } else if (scheduledFor.difference(currentTime).inMinutes > 30) {
          status = 'upcoming';
        } else {
          status = 'due';
        }

        doses.add(TodayDose(
          key: "${schedule['id']}-$timeStr",
          medicine: medicine,
          schedule: schedule,
          time: timeStr,
          scheduledFor: scheduledFor,
          status: status,
        ));
      }
    }

    // Deduplicate doses by unique key
    final seenKeys = <String>{};
    final dedupedDoses = <TodayDose>[];
    for (final dose in doses) {
      if (!seenKeys.contains(dose.key)) {
        seenKeys.add(dose.key);
        dedupedDoses.add(dose);
      }
    }

    dedupedDoses.sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    return dedupedDoses;
  }

  static List<MedicineDoseGroup> groupTodayDoses(List<TodayDose> doses) {
    final Map<String, List<TodayDose>> map = {};
    for (final d in doses) {
      final key = (d.medicine['name'] ?? d.medicine['id'] ?? 'unknown').toString().trim().toLowerCase();
      map.putIfAbsent(key, () => []).add(d);
    }
    final List<MedicineDoseGroup> groups = [];
    for (final group in map.values) {
      group.sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
      groups.add(MedicineDoseGroup(
        medicine: group.first.medicine,
        schedule: group.first.schedule,
        doses: group,
      ));
    }
    groups.sort((a, b) => a.primaryDose.scheduledFor.compareTo(b.primaryDose.scheduledFor));
    return groups;
  }

  static String spokenSummary(List<TodayDose> doses, {String language = 'en-US'}) {
    final remaining = doses.where((d) => d.status == 'due' || d.status == 'upcoming').toList();
    final taken = doses.where((d) => d.status == 'taken').length;
    final total = doses.length;

    if (language.startsWith('kn')) {
      if (doses.isEmpty) {
        return "ಇಂದು ನಿಮಗೆ ಯಾವುದೇ ಔಷಧಿಗಳಿಲ್ಲ. ನಿಮ್ಮ ಮೊದಲ ಔಷಧಿಯನ್ನು ಸೇರಿಸಲು ಸ್ಕ್ಯಾನ್ ಒತ್ತಿ.";
      }
      final nextIndex = doses.indexWhere((d) => d.status == 'due' || d.status == 'upcoming');
      TodayDose? next = nextIndex != -1 ? doses[nextIndex] : null;

      String nextText = "";
      if (next != null) {
        nextText = " ನಿಮ್ಮ ಮುಂದಿನ ಡೋಸ್ ${next.medicine['name']} ${friendlyTime(next.time)} ಗಂಟೆಗೆ.";
      } else {
        nextText = " ನೀವು ಇಂದಿನ ಎಲ್ಲಾ ಡೋಸ್‌ಗಳನ್ನು ಪೂರ್ಣಗೊಳಿಸಿದ್ದೀರಿ.";
      }
      return "ಇಂದು ನಿಮಗೆ $total ಡೋಸ್‌ಗಳಿವೆ. $taken ತೆಗೆದುಕೊಂಡಿದೆ, ${remaining.length} ಬಾಕಿ ಇವೆ.$nextText";
    } else if (language.startsWith('hi')) {
      if (doses.isEmpty) {
        return "आज आपकी कोई दवा निर्धारित नहीं है। अपनी पहली दवा जोड़ने के लिए स्कैन दबाएं।";
      }
      final nextIndex = doses.indexWhere((d) => d.status == 'due' || d.status == 'upcoming');
      TodayDose? next = nextIndex != -1 ? doses[nextIndex] : null;

      String nextText = "";
      if (next != null) {
        nextText = " आपकी अगली खुराक ${next.medicine['name']} ${friendlyTime(next.time)} बजे है।";
      } else {
        nextText = " आपने आज की सभी खुराकें पूरी कर ली हैं।";
      }
      return "आज आपकी $total खुराकें हैं। $taken ले ली हैं, ${remaining.length} बची हैं।$nextText";
    } else {
      if (doses.isEmpty) {
        return "You have no medicines scheduled today. Tap Scan to add your first medicine.";
      }
      final nextIndex = doses.indexWhere((d) => d.status == 'due' || d.status == 'upcoming');
      TodayDose? next = nextIndex != -1 ? doses[nextIndex] : null;

      String nextText = "";
      if (next != null) {
        nextText = " Your next dose is ${next.medicine['name']} at ${friendlyTime(next.time)}.";
      } else {
        nextText = " You have finished all doses for today.";
      }
      return "You have $total doses today. $taken taken, ${remaining.length} remaining.$nextText";
    }
  }
}
