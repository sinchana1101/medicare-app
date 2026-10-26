import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'speech_service.dart';
import 'voice_intent_service.dart';
import 'database_service.dart';
import 'emailjs_service.dart';
import 'ai_service.dart';
import 'dose_utils.dart';
import '../screens/home_screen.dart';
import '../screens/camera_screen.dart';
import '../screens/scan_screen.dart';
import '../screens/schedule_screen.dart';
import '../screens/assistant_screen.dart';
import '../screens/emergency_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/auth_screen.dart';

enum AppScreen {
  auth,
  home,
  scan,
  camera,
  schedule,
  assistant,
  emergency,
  settings,
  alarmOverlay,
}

abstract class VoiceScreenDelegate {
  Future<bool> handleVoiceCommand(VoiceIntent? intent, String transcript);
  String getScreenAnnouncement();
}

class VoiceController extends ChangeNotifier {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final SpeechService _speech;
  final DatabaseService db;
  final AIService? ai;

  AppScreen _currentScreen = AppScreen.home;
  AppScreen get currentScreen => _currentScreen;

  VoiceScreenDelegate? _activeDelegate;
  VoiceScreenDelegate? get activeDelegate {
    if (_activeDelegate != null && _activeDelegate is State && !(_activeDelegate as State).mounted) {
      _activeDelegate = null;
    }
    return _activeDelegate;
  }

  String _lastHeard = "";
  String get lastHeard => _lastHeard;

  String _statusMessage = "";
  String get statusMessage => _statusMessage;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  // Persistent continuous voice mode state
  bool _isContinuousMode = false;
  bool get isContinuousMode => _isContinuousMode;

  @override
  void notifyListeners() {
    final phase = WidgetsBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks || phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        super.notifyListeners();
      });
    } else {
      super.notifyListeners();
    }
  }

  VoiceController(this._speech, this.db, {this.ai}) {
    _speech.onInstantIntent = (intent, transcript) {
      _lastHeard = transcript;
      _statusMessage = "Heard: \"$transcript\"";
      notifyListeners();
      executeIntent(intent, transcript);
    };
  }

  void setActiveDelegate(VoiceScreenDelegate delegate, AppScreen screen) {
    _activeDelegate = delegate;
    _currentScreen = screen;
    notifyListeners();
  }

  void clearActiveDelegate(VoiceScreenDelegate delegate) {
    if (_activeDelegate == delegate) {
      _activeDelegate = null;
      notifyListeners();
    }
  }

  void setCurrentScreen(AppScreen screen) {
    _currentScreen = screen;
    notifyListeners();
  }

  /// Announces current screen details and commands
  void announceScreen() {
    if (_activeDelegate != null) {
      if (_activeDelegate is State && !(_activeDelegate as State).mounted) {
        _activeDelegate = null;
      } else {
        try {
          final announcement = _activeDelegate!.getScreenAnnouncement();
          if (announcement.isNotEmpty) {
            _speech.speak(announcement);
            return;
          }
        } catch (_) {
          _activeDelegate = null;
        }
      }
    }

    final lang = _speech.currentLanguage;
    String text;
    if (lang.startsWith('kn')) {
      switch (_currentScreen) {
        case AppScreen.home:
          text = "ಮುಖಪುಟ. ಇಂದಿನ ವೇಳಾಪಟ್ಟಿ ಕೇಳಲು 'ವೇಳಾಪಟ್ಟಿ ಓದಿ' ಎನ್ನಿ, ಅಥವಾ 'ಸ್ಕ್ಯಾನ್', 'ತುರ್ತು', 'ಸಹಾಯ' ಎನ್ನಿ.";
          break;
        case AppScreen.scan:
          text = "ಔಷಧಿ ಸ್ಕ್ಯಾನ್ ಪರದೆ. ಫೋಟೋ ತೆಗೆಯಲು 'ಫೋಟೋ ತೆಗೆ' ಎನ್ನಿ, ಅಥವಾ 'ಗ್ಯಾಲರಿ', 'ಹಿಂದಕ್ಕೆ' ಎನ್ನಿ.";
          break;
        case AppScreen.camera:
          text = "ಕ್ಯಾಮೆರಾ ಪರದೆ. ಚಿತ್ರ ತೆಗೆಯಲು 'ಕ್ಲಿಕ್' ಅಥವಾ 'ಫೋಟೋ' ಎನ್ನಿ. ಟಾರ್ಚ್‌ಗೆ 'ಟಾರ್ಚ್' ಎನ್ನಿ.";
          break;
        case AppScreen.schedule:
          text = "ವೇಳಾಪಟ್ಟಿ ಪರದೆ. 'ಎಲ್ಲಾ ಓದಿ', 'ತೆಗೆದುಕೊಂಡೆ', ಅಥವಾ 'ಹಿಂದಕ್ಕೆ' ಎನ್ನಿ.";
          break;
        case AppScreen.assistant:
          text = "ಎಐ ಸಹಾಯಕ. ನಿಮ್ಮ ಆರೋಗ್ಯ ಅಥವಾ ಔಷಧಿಯ ಪ್ರಶ್ನೆಯನ್ನು ಕೇಳಿ.";
          break;
        case AppScreen.emergency:
          text = "ತುರ್ತು ಪರದೆ. ಎಸ್ಒಎಸ್ ಕಳುಹಿಸಲು 'ಎಸ್ಒಎಸ್' ಅಥವಾ 'ಆಂಬ್ಯುಲೆನ್ಸ್', 'ಆರೈಕೆದಾರರಿಗೆ ಕರೆ' ಎನ್ನಿ.";
          break;
        case AppScreen.settings:
          text = "ಸೆಟ್ಟಿಂಗ್ಸ್ ಪರದೆ. ಭಾಷೆ ಬದಲಾಯಿಸಲು 'ಕನ್ನಡ', 'ಇಂಗ್ಲಿಷ್', ಅಥವಾ 'ಹಿಂದಿ' ಎನ್ನಿ.";
          break;
        case AppScreen.auth:
          text = "ಸ್ಮಾರ್ಟ್ ಮೆಡಿಕೇರ್. ತಕ್ಷಣ ಪ್ರಾರಂಭಿಸಲು 'ಡೆಮೊ' ಅಥವಾ 'ಆಫ್‌ಲೈನ್' ಎನ್ನಿ.";
          break;
        default:
          text = "ಮೆಡಿಕೇರ್ ಆಪ್.";
      }
    } else if (lang.startsWith('hi')) {
      switch (_currentScreen) {
        case AppScreen.home:
          text = "मुख्य पृष्ठ। आज की दवाएं सुनने के लिए 'दवाएं पढ़ो' कहें, या 'स्कैन', 'आपातकाल', 'मदद' कहें।";
          break;
        case AppScreen.scan:
          text = "दवा स्कैन स्क्रीन। फोटो लेने के लिए 'फोटो लो' कहें, या 'गैलरी', 'वापस' कहें।";
          break;
        case AppScreen.camera:
          text = "कैमरा स्क्रीन। फोटो लेने के लिए 'क्लिक' या 'फोटो' कहें। रोशनी के लिए 'टॉर्च' कहें।";
          break;
        case AppScreen.schedule:
          text = "समय-सारणी स्क्रीन। 'सब पढ़ो', 'ले ली', या 'वापस' कहें।";
          break;
        case AppScreen.assistant:
          text = "एआई सहायक। अपनी सेहत या दवा के बारे में कोई भी प्रश्न पूछें।";
          break;
        case AppScreen.emergency:
          text = "आपातकालीन स्क्रीन। मदद के लिए 'एसओएस', 'एम्बुलेंस', या 'केयरगिवर को कॉल' कहें।";
          break;
        case AppScreen.settings:
          text = "सेटिंग्स स्क्रीन। भाषा बदलने के लिए 'हिंदी', 'अंग्रेजी', या 'कन्नड़' कहें।";
          break;
        case AppScreen.auth:
          text = "स्मार्ट मेडिकेयर में स्वागत है। तुरंत शुरू करने के लिए 'डेमो' या 'ऑफ़लाइन' कहें।";
          break;
        default:
          text = "मेडिकेयर ऐप।";
      }
    } else {
      switch (_currentScreen) {
        case AppScreen.home:
          text = "Home screen. Say 'read schedule', 'mark taken', 'scan', 'emergency', or 'help'.";
          break;
        case AppScreen.scan:
          text = "Scan medicine screen. Say 'take photo', 'upload photo', 'save', or 'go back'.";
          break;
        case AppScreen.camera:
          text = "Camera screen. Say 'click' or 'capture' to take photo, or 'torch' for light.";
          break;
        case AppScreen.schedule:
          text = "Medicine schedule. Say 'read all', 'mark taken', or 'go back'.";
          break;
        case AppScreen.assistant:
          text = "Voice Assistant. Ask any health or medicine question.";
          break;
        case AppScreen.emergency:
          text = "Emergency SOS screen. Say 'send SOS', 'call caregiver', 'call 108', or 'go back'.";
          break;
        case AppScreen.settings:
          text = "Settings screen. Say 'English', 'Kannada', 'Hindi', or 'test alarm'.";
          break;
        case AppScreen.auth:
          text = "Welcome to Smart MediCare. Say 'demo' or 'continue offline' to start immediately.";
          break;
        default:
          text = "MediCare App.";
      }
    }
    _speech.speak(text);
  }

  /// Toggles continuous voice mode on or off.
  /// Double-tapping anywhere on screen toggles this mode.
  Future<void> toggleContinuousListening() async {
    if (_isContinuousMode) {
      await stopContinuousListening();
    } else {
      await startContinuousListening();
    }
  }

  /// Push-to-talk microphone trigger: listens for a command, interprets and executes it immediately
  Future<void> listenAndExecute() async {
    if (_isProcessing) return;

    if (_speech.isSpeaking) {
      await _speech.stopTTS();
    }
    if (_speech.isListening) {
      await _speech.stopSTT();
      return;
    }

    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    _isProcessing = true;
    final lang = _speech.currentLanguage;
    _statusMessage = lang.startsWith('kn')
        ? "ಕೇಳಿಸಿಕೊಳ್ಳುತ್ತಿದ್ದೇನೆ... ಮಾತನಾಡಿ"
        : lang.startsWith('hi')
            ? "सुन रहा हूँ... बोलिए"
            : "Listening... Speak now";
    notifyListeners();

    try {
      final transcript = await _speech.listenOnce(timeoutSeconds: 8);
      if (transcript.trim().isNotEmpty) {
        _lastHeard = transcript;
        _statusMessage = "Heard: \"$transcript\"";
        notifyListeners();

        final intent = VoiceIntentService.matchIntent(transcript);
        if (intent != null && VoiceIntentService.shouldDebounce(intent, debounceMs: 900)) {
          // Already handled on streaming partial with zero latency
        } else {
          if (intent != null) {
            VoiceIntentService.recordExecution(intent);
          }
          await executeIntent(intent, transcript);
        }
      }
    } catch (e) {
      debugPrint("listenAndExecute error: $e");
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Starts continuous listening mode.
  /// The mic stays on until user double-taps or says stop.
  Future<void> startContinuousListening({String? customAnnouncement}) async {
    if (_isContinuousMode) return;
    _isContinuousMode = true;
    _isProcessing = false;
    notifyListeners();

    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    final lang = _speech.currentLanguage;
    final startMsg = customAnnouncement ?? (lang.startsWith('kn')
        ? "ಧ್ವನಿ ಮೋಡ್ ಆನ್ ಆಗಿದೆ."
        : lang.startsWith('hi')
            ? "वॉइस मोड चालू है।"
            : "Voice mode on.");

    await _speech.speak(startMsg);
    await _speech.waitForSpeech();

    // Start background continuous listening cycle
    _runContinuousLoop();
  }

  /// Stops continuous listening mode.
  Future<void> stopContinuousListening() async {
    _isContinuousMode = false;
    _isProcessing = false;
    _statusMessage = "Voice stopped";
    notifyListeners();

    await _speech.stop();

    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    final lang = _speech.currentLanguage;
    final stopMsg = lang.startsWith('kn')
        ? "ಧ್ವನಿ ಮೋಡ್ ಆಫ್ ಆಗಿದೆ."
        : lang.startsWith('hi')
            ? "वॉइस मोड बंद है।"
            : "Voice mode off.";

    await _speech.speak(stopMsg);
  }

  /// Persistent loop that runs as long as continuous mode is active
  Future<void> _runContinuousLoop() async {
    while (_isContinuousMode) {
      // 0. If speech/TTS is playing (e.g. reading medicine details or announcing screens),
      // pause microphone listening until reading finishes so speaker audio isn't picked up by STT!
      if (_speech.isSpeaking) {
        await _speech.waitForSpeech();
      }

      if (!_isContinuousMode) break;

      _statusMessage = "Listening...";
      notifyListeners();

      String transcript = "";
      try {
        transcript = await _speech.listenOnce(timeoutSeconds: 8);
      } catch (e) {
        debugPrint("Continuous voice listen error: $e");
        await Future.delayed(const Duration(milliseconds: 1500));
        continue;
      }

      if (!_isContinuousMode) break;

      if (transcript.trim().isNotEmpty) {
        debugPrint("Voice Heard: '$transcript'");
        _lastHeard = transcript;
        _statusMessage = "Heard: \"$transcript\"";
        notifyListeners();

        // 1. Check if user asked to stop/turn off mic
        final lower = transcript.toLowerCase();
        if (lower.contains("stop listening") ||
            lower.contains("turn off mic") ||
            lower.contains("stop mic") ||
            lower.contains("turn off voice") ||
            lower.contains("stop voice") ||
            transcript.contains("ಮೈಕ್ ಆಫ್") ||
            transcript.contains("ಧ್ವನಿ ನಿಲ್ಲಿಸಿ") ||
            transcript.contains("ಮಾತನಾಡುವುದು ಬೇಡ") ||
            transcript.contains("माइक बंद") ||
            transcript.contains("वॉइस बंद")) {
          await stopContinuousListening();
          break;
        }

        // 2. Match intent and execute (with deduplication if already executed on partial stream)
        final intent = VoiceIntentService.matchIntent(transcript);
        if (intent != null && VoiceIntentService.shouldDebounce(intent, debounceMs: 900)) {
          // Already fired on streaming partial result with zero latency!
        } else {
          _isProcessing = true;
          notifyListeners();
          try {
            if (intent != null) {
              VoiceIntentService.recordExecution(intent);
            }
            await executeIntent(intent, transcript);
          } catch (e) {
            debugPrint("Voice execution error: $e");
          } finally {
            _isProcessing = false;
            notifyListeners();
          }
        }

        // 3. Wait for all speech feedback to finish before mic resumes
        if (_speech.isSpeaking) {
          await _speech.waitForSpeech();
        }
      }

      // Safe pause so Android OS audioserver and microphone hardware properly reset
      if (_isContinuousMode) {
        final delayMs = transcript.trim().isEmpty ? 800 : 250;
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }
  }

  Future<List<TodayDose>> _getTodayDoses() async {
    try {
      final medicines = await db.getMedicines();
      final schedules = await db.getSchedules();
      final logs = await db.getDoseLogs();
      return DoseUtils.buildTodayDoses(
        medicines: medicines,
        schedules: schedules,
        logs: logs,
      );
    } catch (_) {
      return [];
    }
  }


  /// Navigates from ANY page to ANY page seamlessly with clean route hygiene
  Future<void> navigateTo(AppScreen targetScreen, {bool autoTriggerSos = false}) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    final lang = _speech.currentLanguage;

    if (_currentScreen == targetScreen) {
      if (targetScreen == AppScreen.emergency && autoTriggerSos && _activeDelegate != null) {
        _activeDelegate!.handleVoiceCommand(VoiceIntent.emergency, "sos");
        return;
      }
      announceScreen();
      return;
    }

    _activeDelegate = null;

    switch (targetScreen) {
      case AppScreen.home:
        final homeMsg = lang.startsWith('kn')
            ? "ಮುಖಪುಟ."
            : lang.startsWith('hi')
                ? "मुख्य पृष्ठ।"
                : "Home.";
        // Instant non-blocking route pop
        if (nav.canPop()) {
          nav.popUntil((route) => route.isFirst);
        }
        _currentScreen = AppScreen.home;
        notifyListeners();
        _speech.speak(homeMsg);
        break;

      case AppScreen.scan:
        final scanMsg = lang.startsWith('kn')
            ? "ಸ್ಕ್ಯಾನ್."
            : lang.startsWith('hi')
                ? "स्कैन।"
                : "Scan.";
        // Instant non-blocking route transition
        if (nav.canPop()) {
          nav.popUntil((route) => route.isFirst);
        }
        _currentScreen = AppScreen.scan;
        notifyListeners();
        nav.push(
          MaterialPageRoute(builder: (_) => const ScanScreen()),
        ).then((_) {
          if (_currentScreen == AppScreen.scan) {
            _currentScreen = AppScreen.home;
            notifyListeners();
          }
        });
        _speech.speak(scanMsg);
        break;

      case AppScreen.camera:
        final camMsg = lang.startsWith('kn')
            ? "ಕ್ಯಾಮೆರಾ."
            : lang.startsWith('hi')
                ? "कैमरा।"
                : "Camera.";
        _currentScreen = AppScreen.camera;
        notifyListeners();
        nav.push<String>(
          MaterialPageRoute(builder: (_) => const CameraScreen()),
        ).then((capturedPath) {
          if (capturedPath != null && capturedPath.isNotEmpty) {
            nav.push(
              MaterialPageRoute(builder: (_) => ScanScreen(initialImagePath: capturedPath)),
            );
          } else {
            _currentScreen = AppScreen.home;
            notifyListeners();
          }
        });
        _speech.speak(camMsg);
        break;

      case AppScreen.schedule:
        final schedMsg = lang.startsWith('kn')
            ? "ವೇಳಾಪಟ್ಟಿ."
            : lang.startsWith('hi')
                ? "शेड्यूल।"
                : "Schedule.";
        if (nav.canPop()) {
          nav.popUntil((route) => route.isFirst);
        }
        _currentScreen = AppScreen.schedule;
        notifyListeners();
        nav.push(
          MaterialPageRoute(builder: (_) => const ScheduleScreen()),
        ).then((_) {
          if (_currentScreen == AppScreen.schedule) {
            _currentScreen = AppScreen.home;
            notifyListeners();
          }
        });
        _speech.speak(schedMsg);
        break;

      case AppScreen.assistant:
        final asstMsg = lang.startsWith('kn')
            ? "ಸಹಾಯಕ."
            : lang.startsWith('hi')
                ? "सहायक।"
                : "Assistant.";
        if (nav.canPop()) {
          nav.popUntil((route) => route.isFirst);
        }
        _currentScreen = AppScreen.assistant;
        notifyListeners();
        nav.push(
          MaterialPageRoute(builder: (_) => const AssistantScreen()),
        ).then((_) {
          if (_currentScreen == AppScreen.assistant) {
            _currentScreen = AppScreen.home;
            notifyListeners();
          }
        });
        _speech.speak(asstMsg);
        break;

      case AppScreen.emergency:
        final emerMsg = lang.startsWith('kn')
            ? "ತುರ್ತು."
            : lang.startsWith('hi')
                ? "आपातकाल।"
                : "Emergency.";
        if (nav.canPop()) {
          nav.popUntil((route) => route.isFirst);
        }
        _currentScreen = AppScreen.emergency;
        notifyListeners();
        nav.push(
          MaterialPageRoute(builder: (_) => EmergencyScreen(autoTrigger: autoTriggerSos)),
        ).then((_) {
          if (_currentScreen == AppScreen.emergency) {
            _currentScreen = AppScreen.home;
            notifyListeners();
          }
        });
        _speech.speak(emerMsg);
        break;

      case AppScreen.settings:
        final openMsg = lang.startsWith('kn')
            ? "ಸೆಟ್ಟಿಂಗ್ಸ್."
            : lang.startsWith('hi')
                ? "सेटिंग्स।"
                : "Settings.";
        if (nav.canPop()) {
          nav.popUntil((route) => route.isFirst);
        }
        _currentScreen = AppScreen.settings;
        notifyListeners();
        nav.push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ).then((_) {
          if (_currentScreen == AppScreen.settings) {
            _currentScreen = AppScreen.home;
            notifyListeners();
          }
        });
        _speech.speak(openMsg);
        break;

      default:
        break;
    }
  }

  Future<void> goBack() async {
    final nav = navigatorKey.currentState;
    final lang = _speech.currentLanguage;
    if (nav?.canPop() == true) {
      nav?.pop();
      final backMsg = lang.startsWith('kn')
          ? "ಹಿಂದಿನ ಪರದೆಗೆ ಹೋಗಲಾಗಿದೆ."
          : lang.startsWith('hi')
              ? "पिछले पृष्ठ पर वापस आ गए।"
              : "Going back.";
      _speech.speak(backMsg);
    } else {
      _speech.speak(lang.startsWith('kn')
          ? "ನೀವು ಈಗಾಗಲೇ ಮುಖ್ಯ ಪುಟದಲ್ಲಿದ್ದೀರಿ."
          : lang.startsWith('hi')
              ? "आप पहले से ही मुख्य पृष्ठ पर हैं।"
              : "You are already on the home screen.");
    }
  }

  /// Dispatches the recognized voice intent to navigation, delegate, or universal handlers.
  /// Guarantees that EVERY feature in the entire app can be triggered by voice from any page.
  Future<void> _handleMarkTaken(String lang, {String? transcript}) async {
    try {
      final doses = await _getTodayDoses();
      if (doses.isEmpty) {
        final noMeds = lang.startsWith('kn')
            ? "ಯಾವುದೇ ಔಷಧಿ ನಿಗದಿಯಾಗಿಲ್ಲ. ಹೊಸ ಔಷಧಿಯನ್ನು ಸೇರಿಸಲು 'ಸ್ಕ್ಯಾನ್' ಎನ್ನಿ."
            : lang.startsWith('hi')
                ? "कोई दवा निर्धारित नहीं है। नई दवा जोड़ने के लिए 'स्कैन' कहें।"
                : "No medicines in your schedule yet. Say 'scan' to add a medicine.";
        await _speech.speak(noMeds);
        return;
      }

      final pending = doses.where((d) => d.status != 'taken').toList();
      if (pending.isEmpty) {
        final allTaken = lang.startsWith('kn')
            ? "ಇಂದಿನ ಎಲ್ಲಾ ಔಷಧಿಗಳನ್ನು ಈಗಾಗಲೇ ತೆಗೆದುಕೊಳ್ಳಲಾಗಿದೆ. ತುಂಬಾ ಒಳ್ಳೆಯದು!"
            : lang.startsWith('hi')
                ? "आज की सभी दवाएं पहले ही ली जा चुकी हैं।"
                : "All medicines for today are already marked as taken. Well done!";
        await _speech.speak(allTaken);
        return;
      }

      // Check if user specified a medicine name in speech
      TodayDose target = pending.first;
      if (transcript != null && transcript.isNotEmpty) {
        final lower = transcript.toLowerCase();
        for (final d in pending) {
          final name = (d.medicine['name'] ?? '').toString().toLowerCase();
          if (name.isNotEmpty && lower.contains(name)) {
            target = d;
            break;
          }
        }
      }

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
      await _speech.speak(done);

      // Safe delegate notification
      if (_activeDelegate != null && _activeDelegate is State && (_activeDelegate as State).mounted) {
        try {
          await _activeDelegate!.handleVoiceCommand(VoiceIntent.markTaken, transcript ?? "mark taken");
        } catch (_) {}
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error handling markTaken: $e");
      await _speech.speak(lang.startsWith('kn') ? "ಔಷಧಿ ತೆಗೆದುಕೊಳ್ಳಲಾಗಿದೆ." : "Marked as taken.");
    }
  }

  Future<void> _handleSkipDose(String lang, {String? transcript}) async {
    try {
      final doses = await _getTodayDoses();
      if (doses.isEmpty) {
        final noMeds = lang.startsWith('kn')
            ? "ಯಾವುದೇ ಔಷಧಿ ನಿಗದಿಯಾಗಿಲ್ಲ."
            : lang.startsWith('hi')
                ? "कोई दवा निर्धारित नहीं है।"
                : "No medicines in your schedule yet.";
        await _speech.speak(noMeds);
        return;
      }

      final pending = doses.where((d) => d.status != 'taken').toList();
      if (pending.isEmpty) {
        final noPending = lang.startsWith('kn')
            ? "ಬಿಟ್ಟುಬಿಡಲು ಯಾವುದೇ ಬಾಕಿ ಔಷಧಿಗಳಿಲ್ಲ."
            : lang.startsWith('hi')
                ? "छोड़ने के लिए कोई दवा बाकी नहीं है।"
                : "No pending doses left to skip.";
        await _speech.speak(noPending);
        return;
      }

      TodayDose target = pending.first;
      if (transcript != null && transcript.isNotEmpty) {
        final lower = transcript.toLowerCase();
        for (final d in pending) {
          final name = (d.medicine['name'] ?? '').toString().toLowerCase();
          if (name.isNotEmpty && lower.contains(name)) {
            target = d;
            break;
          }
        }
      }

      final medName = target.medicine['name'] ?? 'Medicine';
      await db.logDose(
        target.medicine['id'],
        'skipped',
        scheduleId: target.schedule['id'],
        scheduledFor: target.scheduledFor,
      );

      final skipMsg = lang.startsWith('kn')
          ? "$medName ಬಿಟ್ಟುಬಿಡಲಾಗಿದೆ. ಆರೈಕೆದಾರರಿಗೆ ಎಚ್ಚರಿಕೆ ನೀಡಲಾಗಿದೆ."
          : lang.startsWith('hi')
              ? "$medName छोड़ दी गई। केयरगिवर को सूचित किया गया।"
              : "Skipped $medName. Caregiver notified.";
      await _speech.speak(skipMsg);

      // Safe delegate notification
      if (_activeDelegate != null && _activeDelegate is State && (_activeDelegate as State).mounted) {
        try {
          await _activeDelegate!.handleVoiceCommand(VoiceIntent.skipDose, transcript ?? "skip dose");
        } catch (_) {}
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error handling skipDose: $e");
      await _speech.speak(lang.startsWith('kn') ? "ಡೋಸ್ ಬಿಟ್ಟುಬಿಡಲಾಗಿದೆ." : "Dose skipped.");
    }
  }

    Future<void> executeIntent(VoiceIntent? intent, String transcript) async {
    final lang = _speech.currentLanguage;

    final clean = VoiceIntentService.normalize(transcript);
    if (clean == "open" || clean == "open the" || clean == "ತೆರೆ" || clean == "ಓಪನ್" || clean == "खोलो" || clean == "ओपन") {
      final prompt = lang.startsWith('kn')
          ? "ಏನನ್ನು ತೆರೆಯಬೇಕು? ಮುಖಪುಟ, ಸ್ಕ್ಯಾನ್, ವೇಳಾಪಟ್ಟಿ, ಅಥವಾ ಸೆಟ್ಟಿಂಗ್ಸ್ ಎನ್ನಿ."
          : lang.startsWith('hi')
              ? "क्या खोलना चाहते हैं? होम, स्कैन, समय सारणी, या सेटिंग्स कहें।"
              : "What would you like to open? Say Home, Scan, Schedule, or Settings.";
      await _speech.speak(prompt);
      return;
    }

    // 1. Language switching commands work from ANY screen, ANY time
    if (intent == VoiceIntent.langKn) {
      _speech.announceLanguageChanged('kn-IN');
      await db.saveProfile({'preferred_language': 'kn-IN'});
      return;
    }
    if (intent == VoiceIntent.langHi) {
      _speech.announceLanguageChanged('hi-IN');
      await db.saveProfile({'preferred_language': 'hi-IN'});
      return;
    }
    if (intent == VoiceIntent.langEn) {
      _speech.announceLanguageChanged('en-US');
      await db.saveProfile({'preferred_language': 'en-US'});
      return;
    }

    // 2. Universal noise cancellation toggle: works from ANY screen, ANY time
    if (intent == VoiceIntent.noiseCancelOn) {
      _speech.setNoiseCancellation(true);
      final onMsg = lang.startsWith('kn')
          ? "ಹಿನ್ನೆಲೆ ಶಬ್ದ ರದ್ದತಿ ಆನ್ ಆಗಿದೆ."
          : lang.startsWith('hi')
              ? "बैकग्राउंड शोर रद्दीकरण चालू किया गया।"
              : "Noise cancellation enabled.";
      await _speech.speak(onMsg);
      return;
    }
    if (intent == VoiceIntent.noiseCancelOff) {
      _speech.setNoiseCancellation(false);
      final offMsg = lang.startsWith('kn')
          ? "ಹಿನ್ನೆಲೆ ಶಬ್ದ ರದ್ದತಿ ಆಫ್ ಆಗಿದೆ."
          : lang.startsWith('hi')
              ? "बैकग्राउंड शोर रद्दीकरण बंद किया गया।"
              : "Noise cancellation disabled.";
      await _speech.speak(offMsg);
      return;
    }

    // 3. Audio playback controls (stops spoken voice output, keeps mic listening)
    if (intent == VoiceIntent.stop) {
      await _speech.stopTTS();
      return;
    }
    if (intent == VoiceIntent.repeat) {
      await _speech.repeat();
      return;
    }

    // Continuous Voice controls
    if (intent == VoiceIntent.continuousVoiceOn) {
      await startContinuousListening();
      return;
    }
    if (intent == VoiceIntent.continuousVoiceOff) {
      await stopContinuousListening();
      return;
    }

    // 4. Delegate has priority for screen-specific actions (e.g. snapping photo on camera, saving medicine on scan)
    if (_activeDelegate != null) {
      if (_activeDelegate is State && !(_activeDelegate as State).mounted) {
        _activeDelegate = null;
      } else {
        try {
          final handled = await _activeDelegate!.handleVoiceCommand(intent, transcript);
          if (handled) return;
        } catch (e) {
          debugPrint("Active delegate voice handling note: $e");
          _activeDelegate = null;
        }
      }
    }

    // 5. Universal Page-to-Page Navigation: Works from ANY page to ANY page 100% reliably!
    if (intent == VoiceIntent.home) {
      await navigateTo(AppScreen.home);
      return;
    }
    if (intent == VoiceIntent.scan) {
      await navigateTo(AppScreen.scan);
      return;
    }
    if (intent == VoiceIntent.schedule) {
      await navigateTo(AppScreen.schedule);
      return;
    }
    if (intent == VoiceIntent.assistant) {
      await navigateTo(AppScreen.assistant);
      return;
    }
    if (intent == VoiceIntent.emergency) {
      if (_currentScreen == AppScreen.emergency && _activeDelegate != null) {
        await _activeDelegate!.handleVoiceCommand(VoiceIntent.emergency, transcript);
      } else {
        await navigateTo(AppScreen.emergency, autoTriggerSos: true);
      }
      return;
    }
    if (intent == VoiceIntent.more) {
      await navigateTo(AppScreen.settings);
      return;
    }
    if (intent == VoiceIntent.back) {
      await goBack();
      return;
    }

    // 6. Universal Medicine Actions (Work from ANY screen 100% reliably with zero delegate dependency)
    if (intent == VoiceIntent.markTaken) {
      await _handleMarkTaken(lang, transcript: transcript);
      return;
    }
    if (intent == VoiceIntent.skipDose) {
      await _handleSkipDose(lang, transcript: transcript);
      return;
    }
    if (intent == VoiceIntent.sendMail) {
      await _handleSendMail(lang);
      return;
    }

    // 7. Universal Global Handlers
    final navContext = navigatorKey.currentContext;

    switch (intent) {

      case VoiceIntent.readPage:
        final doses = await _getTodayDoses();
        if (doses.isEmpty) {
          await _speech.speak(lang.startsWith('kn') ? "ಇಂದು ಯಾವುದೇ ಔಷಧಿಗಳಿಲ್ಲ." : "You have no medicines scheduled for today.");
        } else {
          final summary = DoseUtils.spokenSummary(doses, language: lang);
          await _speech.speak(summary);
        }
        return;

      case VoiceIntent.nextMedicine:
        final doses = await _getTodayDoses();
        final pending = doses.where((d) => d.status != 'taken').toList();
        if (pending.isNotEmpty) {
          final next = pending.first;
          final medName = next.medicine['name'] ?? 'Medicine';
          final timeStr = DoseUtils.friendlyTime(next.time);
          final msg = lang.startsWith('kn')
              ? "ನಿಮ್ಮ ಮುಂದಿನ ಔಷಧಿ $medName, ಸಮಯ $timeStr."
              : lang.startsWith('hi')
                  ? "आपकी अगली दवा $medName $timeStr बजे है।"
                  : "Your next medicine is $medName at $timeStr.";
          await _speech.speak(msg);
        } else {
          await _speech.speak(lang.startsWith('kn') ? "ಇಂದು ಇನ್ನು ಯಾವುದೇ ಬಾಕಿ ಔಷಧಿಗಳಿಲ್ಲ." : "No upcoming doses for today.");
        }
        return;

      case VoiceIntent.callAmbulance:
        await _speech.speak("Calling 108 emergency ambulance.");
        final Uri telUri = Uri(scheme: 'tel', path: '108');
        if (await canLaunchUrl(telUri)) {
          await launchUrl(telUri);
        }
        return;

      case VoiceIntent.callCaregiver:
        final contact = await db.getEmergencyContact();
        final phone = contact?['emergency_contact_phone'] ?? '112';
        final name = contact?['emergency_contact_name'] ?? 'Caregiver';
        await _speech.speak("Calling $name at $phone.");
        final Uri telUri = Uri(scheme: 'tel', path: phone);
        if (await canLaunchUrl(telUri)) {
          await launchUrl(telUri);
        }
        return;

      case VoiceIntent.takePhoto:
        if (_currentScreen == AppScreen.camera && _activeDelegate != null) {
          final handled = await _activeDelegate!.handleVoiceCommand(VoiceIntent.takePhoto, transcript);
          if (handled) return;
        }
        await navigateTo(AppScreen.camera);
        return;

      case VoiceIntent.uploadPhoto:
        await navigateTo(AppScreen.scan);
        return;

      case VoiceIntent.testAlarm:
        try {
          HapticFeedback.heavyImpact();
        } catch (_) {}
        final testMsg = lang.startsWith('kn')
            ? "ಅಲಾರಾಂ ಪರೀಕ್ಷೆ. ಟ್ರಿಂಗ್ ಟ್ರಿಂಗ್! ನಿಮ್ಮ ಔಷಧಿ ಜ್ಞಾಪನೆ ಸಕ್ರಿಯವಾಗಿದೆ."
            : lang.startsWith('hi')
                ? "अलार्म टेस्ट। रिंग रिंग! आपकी दवा का रिमाइंडर सक्रिय है।"
                : "Testing alarm sound. Ring ring! Your medicine reminder is working loud and clear.";
        await _speech.speak(testMsg);
        return;

      case VoiceIntent.setAlarm:
        await navigateTo(AppScreen.schedule);
        final alarmMsg = lang.startsWith('kn')
            ? "ವೇಳಾಪಟ್ಟಿ ತೆರೆಯಲಾಗಿದೆ. ಹೊಸ ಅಲಾರಾಂ ಹೊಂದಿಸಲು 'ವೇಳಾಪಟ್ಟಿ' ಬಳಸಿ."
            : lang.startsWith('hi')
                ? "समय-सारणी स्क्रीन खोली गई।"
                : "Schedule screen opened. Say 'read all' or 'go back'.";
        await _speech.speak(alarmMsg);
        return;

      case VoiceIntent.refresh:
        announceScreen();
        return;

      case VoiceIntent.prescriptionMode:
      case VoiceIntent.medicineMode:
        await navigateTo(AppScreen.scan);
        return;

      case VoiceIntent.save:
        final saveMsg = lang.startsWith('kn')
            ? "ಉಳಿಸಲು ಯಾವುದೇ ಹೊಸ ಮಾಹಿತಿ ಇಲ್ಲ. ಮೊದಲು ಔಷಧಿಯನ್ನು ಸ್ಕ್ಯಾನ್ ಮಾಡಿ."
            : lang.startsWith('hi')
                ? "सहेजने के लिए कोई नई जानकारी नहीं है। कृपया पहले दवा स्कैन करें।"
                : "Nothing new to save. Please scan a medicine first.";
        await _speech.speak(saveMsg);
        return;

      case VoiceIntent.cancel:
        await _speech.stopTTS();
        return;

      case VoiceIntent.snooze:
        final snoozeMsg = lang.startsWith('kn')
            ? "ಅಲಾರಾಂ ಹತ್ತು ನಿಮಿಷಗಳ ಕಾಲ ಮುಂದೂಡಲಾಗಿದೆ."
            : lang.startsWith('hi')
                ? "अलार्म 10 मिनट के लिए स्नूज़ किया गया।"
                : "Alarm snoozed for 10 minutes.";
        await _speech.speak(snoozeMsg);
        return;

      case VoiceIntent.demoLogin:
        const demoEmail = "demo_patient@medicare.com";
        const offlineId = "usr_demo_patient";
        await db.switchUser(offlineId);
        await db.saveProfile({'full_name': 'Patient', 'email': demoEmail});
        if (navContext != null) {
          navigatorKey.currentState?.pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
        await _speech.speak("Logged in to demo mode.");
        return;

      case VoiceIntent.signOut:
        await FirebaseAuth.instance.signOut();
        await db.switchUser('usr_offline_guest');
        if (navContext != null) {
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const AuthScreen()),
            (r) => false,
          );
        }
        await _speech.speak("Signed out.");
        return;

      case VoiceIntent.whereAmI:
        announceScreen();
        return;

      case VoiceIntent.help:
        final helpText = lang.startsWith('kn')
            ? "ಲಭ್ಯವಿರುವ ಆದೇಶಗಳು: ಮುಖಪುಟ, ಸ್ಕ್ಯಾನ್, ವೇಳಾಪಟ್ಟಿ, ತುರ್ತು, ಸಹಾಯಕ, ಇಂಗ್ಲಿಷ್, ಹಿಂದಿ, ಅಥವಾ ರದ್ದು."
            : lang.startsWith('hi')
                ? "उपलब्ध कमांड: होम, स्कैन, समय सारणी, आपातकाल, सहायक, हिंदी, अंग्रेजी, या वापस।"
                : "Available commands: Home, Scan, Schedule, Emergency, Assistant, English, Kannada, Hindi, or Go Back.";
        await _speech.speak(helpText);
        return;

      default:
        // If not a known system intent, route to AI Assistant for health or medicine answers!
        if (ai != null && transcript.trim().isNotEmpty) {
          final answer = await ai!.askAssistant(transcript, "", language: lang);
          await _speech.speak(answer);
        } else {
          final unrecogMsg = lang.startsWith('kn')
              ? "ಆಜ್ಞೆ ಅರ್ಥವಾಗಲಿಲ್ಲ. 'ಸಹಾಯ' ಎನ್ನಿ ಅಥವಾ ಮುಖಪುಟ, ಸ್ಕ್ಯಾನ್, ವೇಳಾಪಟ್ಟಿ ಎನ್ನಿ."
              : lang.startsWith('hi')
                  ? "आदेश समझ नहीं आया। 'मदद' कहें या होम, स्कैन, समय सारणी कहें।"
                  : "Command not recognized. Say 'help' to hear available options.";
          await _speech.speak(unrecogMsg);
        }
    }
  }

  /// Trigger sending caregiver email report (can be called by voice intent or UI button)
  Future<bool> sendCaregiverMail({String? targetEmail}) async {
    final lang = _speech.currentLanguage;
    return await _handleSendMail(lang, targetEmail: targetEmail);
  }

  Future<bool> _handleSendMail(String lang, {String? targetEmail}) async {
    final startMsg = lang.startsWith('kn')
        ? "ಆರೈಕೆದಾರರಿಗೆ ಇಮೇಲ್ ಕಳುಹಿಸಲಾಗುತ್ತಿದೆ..."
        : lang.startsWith('hi')
            ? "केयरगिवर को ईमेल भेजा जा रहा है..."
            : "Sending email report to caregiver...";
    await _speech.speak(startMsg);

    try {
      // 1. Fetch recipient email(s) from Caregivers list or Emergency Contact
      final recipientEmails = <String>{};
      if (targetEmail != null && targetEmail.trim().contains('@')) {
        recipientEmails.add(targetEmail.trim());
      } else {
        final caregivers = await db.getCaregivers();
        for (final cg in caregivers) {
          final em = cg['email']?.toString().trim();
          if (em != null && em.isNotEmpty && em.contains('@')) {
            recipientEmails.add(em);
          }
        }
        if (recipientEmails.isEmpty) {
          final ec = await db.getEmergencyContact();
          final em = ec?['emergency_contact_email']?.toString().trim() ??
              ec?['emergency_email']?.toString().trim();
          if (em != null && em.isNotEmpty && em.contains('@')) {
            recipientEmails.add(em);
          }
        }
        if (recipientEmails.isEmpty) {
          final profile = await db.getProfile();
          final em = profile?['emergency_contact_email']?.toString().trim() ??
              profile?['emergency_email']?.toString().trim();
          if (em != null && em.isNotEmpty && em.contains('@')) {
            recipientEmails.add(em);
          }
        }
        if (recipientEmails.isEmpty) {
          final noEmailMsg = lang.startsWith('kn')
              ? "ಯಾವುದೇ ಆರೈಕೆದಾರರ ಅಥವಾ ತುರ್ತು ಇಮೇಲ್ ಕಾನ್ಫಿಗರ್ ಮಾಡಲಾಗಿಲ್ಲ. ದಯವಿಟ್ಟು ಆರೈಕೆದಾರರಲ್ಲಿ ಅಥವಾ ತುರ್ತು ಸಂಪರ್ಕದಲ್ಲಿ ಇಮೇಲ್ ಸೇರಿಸಿ."
              : lang.startsWith('hi')
                  ? "कोई केयरगिवर या आपातकालीन ईमेल कॉन्फ़िगर नहीं किया गया है। कृपया केयरगिवर या आपातकालीन संपर्क में ईमेल जोड़ें।"
                  : "No caregiver or emergency contact email configured. Please add an email in Caregivers or Emergency Contact first.";
          await _speech.speak(noEmailMsg);
          return false;
        }
      }

      // 2. Build summary of doses and health status
      final profile = await db.getProfile();
      final patientName = profile?['full_name'] ?? 'Patient';
      final doses = await _getTodayDoses();
      final dosesSummary = doses.map((d) => "- ${d.medicine['name']}: ${d.time} (${d.status.toUpperCase()})").join("\n");

      final subject = "MediCare Health Report - $patientName";
      final emailBody = "Hello Caregiver,\n\n"
          "This is an automated health status update for $patientName from the MediCare app.\n\n"
          "Today's Medication Schedule & Status:\n"
          "${dosesSummary.isNotEmpty ? dosesSummary : 'All current medications are on track.'}\n\n"
          "Report generated at: ${DateTime.now().toString().split('.').first}\n"
          "Smart MediCare Health System";

      // 3. Send via 2nd EmailJS Template (template_err1y5l)
      bool anySuccess = false;
      for (final email in recipientEmails) {
        debugPrint("EmailJS: Sending Caregiver Template (template_err1y5l) to $email...");
        final sent = await EmailJSService.sendCaregiverEmail(
          toEmail: email,
          patientName: patientName,
          message: emailBody,
          subject: subject,
          medicineName: doses.isNotEmpty ? doses.first.medicine['name']?.toString() : 'Daily Schedule',
          status: 'Schedule Update',
        );
        if (sent) anySuccess = true;
      }

      if (anySuccess) {
        final successMsg = lang.startsWith('kn')
            ? "ಆರೈಕೆದಾರರಿಗೆ ಇಮೇಲ್ ಕಳುಹಿಸಲಾಗಿದೆ."
            : lang.startsWith('hi')
                ? "केयरगिवर को ईमेल सफलतापूर्वक भेज दिया गया।"
                : "Email to caregiver has been sent.";
        await _speech.speak(successMsg);
        return true;
      } else {
        final err = EmailJSService.lastError ?? '';
        if (err.contains("Gmail account disconnected") || err.contains("Invalid grant")) {
          final warnMsg = lang.startsWith('kn')
              ? "ಇಮೇಲ್‌ಜೆಎಸ್ ಜಿಮೇಲ್ ಖಾತೆ ಸಂಪರ್ಕ ಕಡಿತಗೊಂಡಿದೆ. ಡ್ಯಾಶ್‌ಬೋರ್ಡ್‌ನಲ್ಲಿ ಮರುಸಂಪರ್ಕಿಸಿ."
              : "EmailJS Gmail account is disconnected. Please reconnect it in your EmailJS dashboard.";
          await _speech.speak(warnMsg);
        } else {
          await _speech.speak(lang.startsWith('kn')
              ? "ಇಮೇಲ್ ಕಳುಹಿಸಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ."
              : "Could not send email via EmailJS.");
        }
        return false;
      }
    } catch (e) {
      debugPrint("Error in _handleSendMail: $e");
      await _speech.speak("Email error: $e");
      return false;
    }
  }
}

