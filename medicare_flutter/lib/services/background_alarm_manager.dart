import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';
import 'database_service.dart';

@pragma('vm:entry-point')
Future<void> backgroundAlarmCallback() async {
  try {
    // Re-initialize Firebase for the background isolate
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final db = DatabaseService();
    final medicines = await db.getMedicines();
    
    if (medicines.isNotEmpty) {
      final med = medicines.first;
      final notifications = FlutterLocalNotificationsPlugin();
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await notifications.initialize(initSettings);

      const androidDetails = AndroidNotificationDetails(
        'med_reminders', 
        'Medicine Reminders',
        channelDescription: 'Notifications for medicine intake schedules',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
      );
      const details = NotificationDetails(android: androidDetails);
      await notifications.show(
        0, 
        "Medicine Reminder", 
        "Time to take your ${med['name']}. Please open the app to mark it as taken.", 
        details,
      );
    }
  } catch (e) {
    // Ignore background exceptions
  }
}

@pragma('vm:entry-point')
class BackgroundAlarmManager {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    try {
      await AndroidAlarmManager.initialize();
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidInit);
      await _notifications.initialize(initSettings);
    } catch (_) {}
  }

  static Future<void> scheduleDailyCheck() async {
    try {
      await AndroidAlarmManager.periodic(
        const Duration(minutes: 15),
        0, 
        backgroundAlarmCallback,
        exact: true,
        wakeup: true,
      );
    } catch (_) {}
  }

  static Future<void> cancelDailyCheck() async {
    try {
      await AndroidAlarmManager.cancel(0);
    } catch (_) {}
  }
}
