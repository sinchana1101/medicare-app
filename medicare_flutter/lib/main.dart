import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'services/speech_service.dart';
import 'services/database_service.dart';
import 'services/alarm_service.dart';
import 'services/i18n_service.dart';
import 'services/background_alarm_manager.dart';
import 'services/ai_service.dart';
import 'services/alarm_setup_service.dart';
import 'services/location_service.dart';
import 'services/voice_controller.dart';
import 'services/voice_intent_service.dart';
import 'widgets/accessible_voice_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with your project medicare-ba41e
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    debugPrint("Firebase initialized successfully for medicare-ba41e with offline persistence");
  } catch (e) {
    debugPrint("Firebase initialization note: $e");
  }

  // Initialize Background Services ONLY if NOT on Web
  if (!kIsWeb) {
    await BackgroundAlarmManager.init();
    await BackgroundAlarmManager.scheduleDailyCheck();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SpeechService()),
        ChangeNotifierProvider(create: (_) => AlarmService()),
        ChangeNotifierProvider(create: (_) => DatabaseService()),
        ChangeNotifierProvider(create: (_) => AIService()),
        Provider(create: (_) => I18nService()),
        Provider(create: (_) => LocationService()),
        ChangeNotifierProxyProvider3<SpeechService, DatabaseService, AIService, VoiceController>(
          create: (context) => VoiceController(
            Provider.of<SpeechService>(context, listen: false),
            Provider.of<DatabaseService>(context, listen: false),
            ai: Provider.of<AIService>(context, listen: false),
          ),
          update: (context, speech, db, ai, previous) => previous ?? VoiceController(speech, db, ai: ai),
        ),
        ChangeNotifierProxyProvider2<SpeechService, DatabaseService, AlarmSetupService>(
          create: (context) => AlarmSetupService(
            Provider.of<SpeechService>(context, listen: false),
            Provider.of<DatabaseService>(context, listen: false),
          ),
          update: (context, speech, db, previous) => AlarmSetupService(speech, db),
        ),
      ],
      child: const SmartMediCareApp(),
    ),
  );
}

class SmartMediCareApp extends StatelessWidget {
  const SmartMediCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Start monitoring alarms as soon as the app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AlarmService>(context, listen: false).startMonitoring(context);
    });

    return MaterialApp(
      navigatorKey: VoiceController.navigatorKey,
      title: 'SmartMediCare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF0284C7),
        scaffoldBackgroundColor: const Color(0xFF0A0F1D),
        cardColor: const Color(0xFF1E293B),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF111827),
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(fontSize: 18, color: Color(0xFFCBD5E1)),
        ),
      ),
      home: const AuthWrapper(),
      builder: (context, child) {
        return Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => Stack(
                children: [
                  AccessibleVoiceOverlay(child: child!),
                  const GlobalAlarmOverlay(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DatabaseService>(
      builder: (context, db, child) {
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFF0A0F1D),
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final user = snapshot.data;
            if (user != null || db.isAuthenticated) {
              return const HomeScreen();
            } else {
              return const AuthScreen();
            }
          },
        );
      },
    );
  }
}

class GlobalAlarmOverlay extends StatefulWidget {
  const GlobalAlarmOverlay({super.key});

  @override
  State<GlobalAlarmOverlay> createState() => _GlobalAlarmOverlayState();
}

class _GlobalAlarmOverlayState extends State<GlobalAlarmOverlay> {
  String? _lastRingingDoseKey;
  bool _isListeningForAlarm = false;

  void _triggerVoiceAlarmInteraction(AlarmService alarm) async {
    if (_isListeningForAlarm || alarm.ringingDose == null) return;
    _isListeningForAlarm = true;

    final speech = Provider.of<SpeechService>(context, listen: false);
    final medName = alarm.ringingDose?.medicine['name'] ?? 'medicine';
    final lang = speech.currentLanguage;

    final prompt = lang.startsWith('kn')
        ? "$medName ತೆಗೆದುಕೊಳ್ಳುವ ಸಮಯ. 'ತೆಗೆದುಕೊಂಡೆ' ಅಥವಾ 'ಸ್ನೂಜ್' ಎನ್ನಿ."
        : lang.startsWith('hi')
            ? "$medName लेने का समय है। कृपया 'ले ली' या 'स्नूज़' कहें।"
            : "Time for $medName. Please say 'taken' or 'snooze'.";

    await speech.speak(prompt);
    await speech.waitForSpeech();

    if (!mounted || alarm.ringingDose == null) {
      _isListeningForAlarm = false;
      return;
    }

    final heard = await speech.listenOnce(timeoutSeconds: 7);
    if (!mounted || alarm.ringingDose == null) {
      _isListeningForAlarm = false;
      return;
    }

    final intent = VoiceIntentService.matchIntent(heard);
    if (intent == VoiceIntent.markTaken || intent == VoiceIntent.yes) {
      await alarm.acknowledge('taken', context);
    } else if (intent == VoiceIntent.snooze) {
      await alarm.acknowledge('snooze', context);
    } else if (intent == VoiceIntent.skipDose) {
      await alarm.acknowledge('skip', context);
    }

    _isListeningForAlarm = false;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AlarmService>(
      builder: (context, alarm, child) {
        if (alarm.ringingDose == null) {
          _lastRingingDoseKey = null;
          return const SizedBox.shrink();
        }

        if (_lastRingingDoseKey != alarm.ringingDose!.key) {
          _lastRingingDoseKey = alarm.ringingDose!.key;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _triggerVoiceAlarmInteraction(alarm);
          });
        }

        return Material(
          color: Colors.transparent,
          child: Container(
            color: const Color(0xFF0F172A).withValues(alpha: 0.98),
            padding: const EdgeInsets.all(28),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFEF4444), width: 3),
                    ),
                    child: const Icon(Icons.alarm_on_rounded, size: 80, color: Color(0xFFEF4444)),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    "MEDICINE REMINDER",
                    style: TextStyle(fontSize: 20, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    alarm.ringingDose!.medicine['name'] ?? 'Unknown Medicine',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Speak \"TAKEN\" or \"SNOOZE\" hands-free",
                    style: TextStyle(fontSize: 16, color: Colors.cyanAccent.shade200, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton.icon(
                    onPressed: () => alarm.acknowledge('taken', context),
                    icon: const Icon(Icons.check_circle_rounded, size: 36),
                    label: const Text("I TOOK IT", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 90),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      elevation: 4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () => alarm.acknowledge('snooze', context),
                    icon: const Icon(Icons.snooze_rounded, size: 28),
                    label: const Text("SNOOZE 10 MIN", style: TextStyle(fontSize: 22, color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF64748B), width: 2.5),
                      minimumSize: const Size(double.infinity, 70),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
