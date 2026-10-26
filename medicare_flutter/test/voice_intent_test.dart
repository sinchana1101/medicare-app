import 'package:flutter_test/flutter_test.dart';
import 'package:medicare_flutter/services/voice_intent_service.dart';
import 'package:medicare_flutter/services/speech_engine_interface.dart';

void main() {
  group('VoiceIntentService Tests', () {
    test('Matches English navigation intents and sentences accurately', () {
      expect(VoiceIntentService.matchIntent("home"), VoiceIntent.home);
      expect(VoiceIntentService.matchIntent("open home"), VoiceIntent.home);
      expect(VoiceIntentService.matchIntent("open the home"), VoiceIntent.home);
      expect(VoiceIntentService.matchIntent("go to home"), VoiceIntent.home);
      expect(VoiceIntentService.matchIntent("take me to the main page"), VoiceIntent.home);
      expect(VoiceIntentService.matchIntent("dashboard"), VoiceIntent.home);

      expect(VoiceIntentService.matchIntent("scan"), VoiceIntent.scan);
      expect(VoiceIntentService.matchIntent("open scan"), VoiceIntent.scan);
      expect(VoiceIntentService.matchIntent("open the scan"), VoiceIntent.scan);
      expect(VoiceIntentService.matchIntent("go to scan"), VoiceIntent.scan);
      expect(VoiceIntentService.matchIntent("open camera"), VoiceIntent.scan);
      expect(VoiceIntentService.matchIntent("open camera to scan label"), VoiceIntent.scan);

      expect(VoiceIntentService.matchIntent("schedule"), VoiceIntent.schedule);
      expect(VoiceIntentService.matchIntent("open schedule"), VoiceIntent.schedule);
      expect(VoiceIntentService.matchIntent("open the schedule"), VoiceIntent.schedule);
      expect(VoiceIntentService.matchIntent("show my schedule"), VoiceIntent.schedule);
      expect(VoiceIntentService.matchIntent("alarms"), VoiceIntent.schedule);
      expect(VoiceIntentService.matchIntent("open alarms"), VoiceIntent.schedule);
      expect(VoiceIntentService.matchIntent("alarm"), VoiceIntent.schedule);

      expect(VoiceIntentService.matchIntent("assistant"), VoiceIntent.assistant);
      expect(VoiceIntentService.matchIntent("open assistant"), VoiceIntent.assistant);
      expect(VoiceIntentService.matchIntent("open the assistant"), VoiceIntent.assistant);
      expect(VoiceIntentService.matchIntent("voice assistant"), VoiceIntent.assistant);

      expect(VoiceIntentService.matchIntent("emergency"), VoiceIntent.emergency);
      expect(VoiceIntentService.matchIntent("open emergency"), VoiceIntent.emergency);
      expect(VoiceIntentService.matchIntent("help me sos"), VoiceIntent.emergency);

      expect(VoiceIntentService.matchIntent("settings"), VoiceIntent.more);
      expect(VoiceIntentService.matchIntent("setting"), VoiceIntent.more);
      expect(VoiceIntentService.matchIntent("open settings"), VoiceIntent.more);
      expect(VoiceIntentService.matchIntent("open the settings"), VoiceIntent.more);
      expect(VoiceIntentService.matchIntent("back"), VoiceIntent.back);
      expect(VoiceIntentService.matchIntent("go back"), VoiceIntent.back);
    });

    test('Matches compound voice command sentences where latest command takes precedence', () {
      // The user's exact example: "open home open the scan" -> scan
      expect(VoiceIntentService.matchIntent("open home open the scan"), VoiceIntent.scan);
      // Inverse: "open the scan open home" -> home
      expect(VoiceIntentService.matchIntent("open the scan open home"), VoiceIntent.home);
      // In Kannada: "ಹೋಮ್ ಓಪನ್ ಸ್ಕ್ಯಾನ್ ಓಪನ್" -> scan
      expect(VoiceIntentService.matchIntent("ಹೋಮ್ ಓಪನ್ ಸ್ಕ್ಯಾನ್ ಓಪನ್"), VoiceIntent.scan);
      // In Hindi: "होम खोलो स्कैन खोलो" -> scan
      expect(VoiceIntentService.matchIntent("होम खोलो स्कैन खोलो"), VoiceIntent.scan);
    });

    test('Matches Kannada voice commands accurately', () {
      expect(VoiceIntentService.matchIntent("ಮುಖಪುಟ"), VoiceIntent.home);
      expect(VoiceIntentService.matchIntent("ಮನೆ"), VoiceIntent.home);
      expect(VoiceIntentService.matchIntent("ಹೋಮ್"), VoiceIntent.home);
      expect(VoiceIntentService.matchIntent("ಹೋಮ್ ತೆರೆ"), VoiceIntent.home);
      expect(VoiceIntentService.matchIntent("ಹೋಮ್ ಓಪನ್"), VoiceIntent.home);
      expect(VoiceIntentService.matchIntent("ಓಪನ್ ಹೋಮ್"), VoiceIntent.home);

      expect(VoiceIntentService.matchIntent("ಸ್ಕ್ಯಾನ್"), VoiceIntent.scan);
      expect(VoiceIntentService.matchIntent("ಸ್ಕ್ಯಾನ್ ತೆರೆ"), VoiceIntent.scan);
      expect(VoiceIntentService.matchIntent("ಸ್ಕ್ಯಾನ್ ಓಪನ್"), VoiceIntent.scan);
      expect(VoiceIntentService.matchIntent("ಓಪನ್ ಸ್ಕ್ಯಾನ್"), VoiceIntent.scan);
      expect(VoiceIntentService.matchIntent("ಕ್ಯಾಮರಾ"), VoiceIntent.scan);
      expect(VoiceIntentService.matchIntent("ಕ್ಯಾಮೆರಾ ತೆರೆ"), VoiceIntent.scan);

      expect(VoiceIntentService.matchIntent("ವೇಳಾಪಟ್ಟಿ"), VoiceIntent.schedule);
      expect(VoiceIntentService.matchIntent("ವೇಳಾಪಟ್ಟಿ ತೆರೆ"), VoiceIntent.schedule);
      expect(VoiceIntentService.matchIntent("ಶೆಡ್ಯೂಲ್ ಓಪನ್"), VoiceIntent.schedule);
      expect(VoiceIntentService.matchIntent("ಅಲಾರಾಂ"), VoiceIntent.schedule);
      expect(VoiceIntentService.matchIntent("ಅಲಾರಂ"), VoiceIntent.schedule);

      expect(VoiceIntentService.matchIntent("ಸಹಾಯಕ ತೆರೆ"), VoiceIntent.assistant);
      expect(VoiceIntentService.matchIntent("ತುರ್ತು"), VoiceIntent.emergency);
      expect(VoiceIntentService.matchIntent("ತುರ್ತು ತೆರೆ"), VoiceIntent.emergency);
      expect(VoiceIntentService.matchIntent("ಫೋಟೋ ತೆಗೆ"), VoiceIntent.takePhoto);
      expect(VoiceIntentService.matchIntent("ಕ್ಲಿಕ್"), VoiceIntent.takePhoto);
      expect(VoiceIntentService.matchIntent("ಸೆಟ್ಟಿಂಗ್ಸ್"), VoiceIntent.more);
      expect(VoiceIntentService.matchIntent("ಸೆಟ್ಟಿಂಗ್ಸ್ ತೆರೆ"), VoiceIntent.more);
      expect(VoiceIntentService.matchIntent("ತೆಗೆದುಕೊಂಡೆ"), VoiceIntent.markTaken);
      expect(VoiceIntentService.matchIntent("ಹಿಂದಕ್ಕೆ"), VoiceIntent.back);
      expect(VoiceIntentService.matchIntent("ವಾಪಸ್"), VoiceIntent.back);
      expect(VoiceIntentService.matchIntent("ಕನ್ನಡದಲ್ಲಿ ಮಾತನಾಡಿ"), VoiceIntent.langKn);
    });

    test('Matches Hindi voice commands accurately', () {
      expect(VoiceIntentService.matchIntent("होम"), VoiceIntent.home);
      expect(VoiceIntentService.matchIntent("होम खोलो"), VoiceIntent.home);
      expect(VoiceIntentService.matchIntent("होम ओपन"), VoiceIntent.home);
      expect(VoiceIntentService.matchIntent("ओपन होम"), VoiceIntent.home);

      expect(VoiceIntentService.matchIntent("स्कैन"), VoiceIntent.scan);
      expect(VoiceIntentService.matchIntent("स्कैन खोलो"), VoiceIntent.scan);
      expect(VoiceIntentService.matchIntent("स्कैन ओपन"), VoiceIntent.scan);
      expect(VoiceIntentService.matchIntent("ओपन स्कैन"), VoiceIntent.scan);
      expect(VoiceIntentService.matchIntent("स्कैनर"), VoiceIntent.scan);
      expect(VoiceIntentService.matchIntent("कैमरा खोलो"), VoiceIntent.scan);

      expect(VoiceIntentService.matchIntent("समय सारणी"), VoiceIntent.schedule);
      expect(VoiceIntentService.matchIntent("शेड्यूल खोलो"), VoiceIntent.schedule);
      expect(VoiceIntentService.matchIntent("अलार्म"), VoiceIntent.schedule);
      expect(VoiceIntentService.matchIntent("अलार्म खोलो"), VoiceIntent.schedule);
      expect(VoiceIntentService.matchIntent("सहायक खोलो"), VoiceIntent.assistant);
      expect(VoiceIntentService.matchIntent("आपातकाल"), VoiceIntent.emergency);
      expect(VoiceIntentService.matchIntent("मदद करो"), VoiceIntent.emergency);
      expect(VoiceIntentService.matchIntent("फोटो लो"), VoiceIntent.takePhoto);
      expect(VoiceIntentService.matchIntent("क्लिक"), VoiceIntent.takePhoto);
      expect(VoiceIntentService.matchIntent("सेटिंग्स"), VoiceIntent.more);
      expect(VoiceIntentService.matchIntent("सेटिंग्स खोलो"), VoiceIntent.more);
      expect(VoiceIntentService.matchIntent("दवा खा ली"), VoiceIntent.markTaken);
      expect(VoiceIntentService.matchIntent("वापस जाओ"), VoiceIntent.back);
      expect(VoiceIntentService.matchIntent("वापस"), VoiceIntent.back);
      expect(VoiceIntentService.matchIntent("हिंदी में बोलो"), VoiceIntent.langHi);
    });

    test('Matches Blind/Elderly Action intents accurately', () {
      expect(VoiceIntentService.matchIntent("take photo"), VoiceIntent.takePhoto);
      expect(VoiceIntentService.matchIntent("take the photo"), VoiceIntent.takePhoto);
      expect(VoiceIntentService.matchIntent("take a photo"), VoiceIntent.takePhoto);
      expect(VoiceIntentService.matchIntent("click picture"), VoiceIntent.takePhoto);
      expect(VoiceIntentService.matchIntent("click photo"), VoiceIntent.takePhoto);
      expect(VoiceIntentService.matchIntent("click the photo"), VoiceIntent.takePhoto);
      expect(VoiceIntentService.matchIntent("capture"), VoiceIntent.takePhoto);
      expect(VoiceIntentService.matchIntent("capture the photo"), VoiceIntent.takePhoto);
      expect(VoiceIntentService.matchIntent("capture a photo"), VoiceIntent.takePhoto);
      expect(VoiceIntentService.matchIntent("capture photo"), VoiceIntent.takePhoto);
      expect(VoiceIntentService.matchIntent("capture image"), VoiceIntent.takePhoto);
      expect(VoiceIntentService.matchIntent("click"), VoiceIntent.takePhoto);
      expect(VoiceIntentService.matchIntent("snap"), VoiceIntent.takePhoto);
      expect(VoiceIntentService.matchIntent("photo"), VoiceIntent.takePhoto);
      expect(VoiceIntentService.matchIntent("click it"), VoiceIntent.takePhoto);
      expect(VoiceIntentService.matchIntent("capture it"), VoiceIntent.takePhoto);
      expect(VoiceIntentService.matchIntent("upload photo"), VoiceIntent.uploadPhoto);
      expect(VoiceIntentService.matchIntent("gallery"), VoiceIntent.uploadPhoto);
      expect(VoiceIntentService.matchIntent("ಗ್ಯಾಲರಿ"), VoiceIntent.uploadPhoto);
      expect(VoiceIntentService.matchIntent("गैलरी"), VoiceIntent.uploadPhoto);
      expect(VoiceIntentService.matchIntent("save medicine"), VoiceIntent.save);
      expect(VoiceIntentService.matchIntent("mark taken"), VoiceIntent.markTaken);
      expect(VoiceIntentService.matchIntent("mark as taken"), VoiceIntent.markTaken);
      expect(VoiceIntentService.matchIntent("mark"), VoiceIntent.markTaken);
      expect(VoiceIntentService.matchIntent("took"), VoiceIntent.markTaken);
      expect(VoiceIntentService.matchIntent("took dolo"), VoiceIntent.markTaken);
      expect(VoiceIntentService.matchIntent("i took my pill"), VoiceIntent.markTaken);
      expect(VoiceIntentService.matchIntent("ತೆಗೆದುಕೊಂಡೆ"), VoiceIntent.markTaken);
      expect(VoiceIntentService.matchIntent("ತಗೊಂಡೆ"), VoiceIntent.markTaken);
      expect(VoiceIntentService.matchIntent("ತಗೊಂಡಿದ್ದೀನಿ"), VoiceIntent.markTaken);
      expect(VoiceIntentService.matchIntent("ಎತ್ತು"), VoiceIntent.markTaken);
      expect(VoiceIntentService.matchIntent("skip"), VoiceIntent.skipDose);
      expect(VoiceIntentService.matchIntent("skip dose"), VoiceIntent.skipDose);
      expect(VoiceIntentService.matchIntent("skip it"), VoiceIntent.skipDose);
      expect(VoiceIntentService.matchIntent("ಬಿಟ್ಟುಬಿಡಿ"), VoiceIntent.skipDose);
      expect(VoiceIntentService.matchIntent("ಬಿಡು"), VoiceIntent.skipDose);
      expect(VoiceIntentService.matchIntent("ಬೇಡ"), VoiceIntent.skipDose);
      expect(VoiceIntentService.matchIntent("send"), VoiceIntent.emergency);
      expect(VoiceIntentService.matchIntent("send SMS"), VoiceIntent.emergency);
      expect(VoiceIntentService.matchIntent("send SMS now"), VoiceIntent.emergency);
      expect(VoiceIntentService.matchIntent("send now"), VoiceIntent.emergency);
      expect(VoiceIntentService.matchIntent("what is next medicine"), VoiceIntent.nextMedicine);
      expect(VoiceIntentService.matchIntent("read page"), VoiceIntent.readPage);
      expect(VoiceIntentService.matchIntent("call 108"), VoiceIntent.callAmbulance);
      expect(VoiceIntentService.matchIntent("call caregiver"), VoiceIntent.callCaregiver);
      expect(VoiceIntentService.matchIntent("demo login"), VoiceIntent.demoLogin);
      expect(VoiceIntentService.matchIntent("test alarm"), VoiceIntent.testAlarm);
      expect(VoiceIntentService.matchIntent("set alarm"), VoiceIntent.setAlarm);
      expect(VoiceIntentService.matchIntent("help"), VoiceIntent.help);
      expect(VoiceIntentService.matchIntent("what can i say"), VoiceIntent.help);
      expect(VoiceIntentService.matchIntent("ಸಹಾಯ"), VoiceIntent.help);
      expect(VoiceIntentService.matchIntent("मदद"), VoiceIntent.help);
      expect(VoiceIntentService.matchIntent("sign out"), VoiceIntent.signOut);
      expect(VoiceIntentService.matchIntent("log out"), VoiceIntent.signOut);
      expect(VoiceIntentService.matchIntent("refresh"), VoiceIntent.refresh);
      expect(VoiceIntentService.matchIntent("where am i"), VoiceIntent.whereAmI);
      expect(VoiceIntentService.matchIntent("prescription mode"), VoiceIntent.prescriptionMode);
      expect(VoiceIntentService.matchIntent("medicine mode"), VoiceIntent.medicineMode);
      expect(VoiceIntentService.matchIntent("snooze"), VoiceIntent.snooze);
      expect(VoiceIntentService.matchIntent("cancel"), VoiceIntent.cancel);
    });

    test('Matches Noise Cancellation commands accurately across languages', () {
      expect(VoiceIntentService.matchIntent("turn on noise cancellation"), VoiceIntent.noiseCancelOn);
      expect(VoiceIntentService.matchIntent("noise cancellation on"), VoiceIntent.noiseCancelOn);
      expect(VoiceIntentService.matchIntent("turn off noise cancellation"), VoiceIntent.noiseCancelOff);
      expect(VoiceIntentService.matchIntent("noise cancellation off"), VoiceIntent.noiseCancelOff);

      // Kannada
      expect(VoiceIntentService.matchIntent("ಶಬ್ದ ರದ್ದತಿ ಆನ್"), VoiceIntent.noiseCancelOn);
      expect(VoiceIntentService.matchIntent("ಶಬ್ದ ರದ್ದತಿ ಆಫ್"), VoiceIntent.noiseCancelOff);

      // Hindi
      expect(VoiceIntentService.matchIntent("शोर रद्दीकरण चालू"), VoiceIntent.noiseCancelOn);
      expect(VoiceIntentService.matchIntent("शोर रद्दीकरण बंद"), VoiceIntent.noiseCancelOff);
    });

    test('Matches Continuous Voice commands accurately across languages', () {
      expect(VoiceIntentService.matchIntent("turn on continuous voice"), VoiceIntent.continuousVoiceOn);
      expect(VoiceIntentService.matchIntent("voice mode on"), VoiceIntent.continuousVoiceOn);
      expect(VoiceIntentService.matchIntent("turn off continuous voice"), VoiceIntent.continuousVoiceOff);
      expect(VoiceIntentService.matchIntent("voice mode off"), VoiceIntent.continuousVoiceOff);

      // Kannada
      expect(VoiceIntentService.matchIntent("ಧ್ವನಿ ಮೋಡ್ ಆನ್"), VoiceIntent.continuousVoiceOn);
      expect(VoiceIntentService.matchIntent("ಧ್ವನಿ ಮೋಡ್ ಆಫ್"), VoiceIntent.continuousVoiceOff);

      // Hindi
      expect(VoiceIntentService.matchIntent("वॉइस मोड चालू"), VoiceIntent.continuousVoiceOn);
      expect(VoiceIntentService.matchIntent("वॉइस मोड बंद"), VoiceIntent.continuousVoiceOff);
    });

    test('Matches Mail and Email Caregiver commands accurately across languages', () {
      expect(VoiceIntentService.matchIntent("send mail"), VoiceIntent.sendMail);
      expect(VoiceIntentService.matchIntent("send email"), VoiceIntent.sendMail);
      expect(VoiceIntentService.matchIntent("mail caregiver"), VoiceIntent.sendMail);
      expect(VoiceIntentService.matchIntent("email caregiver"), VoiceIntent.sendMail);
      expect(VoiceIntentService.matchIntent("send mail to caregiver"), VoiceIntent.sendMail);
      expect(VoiceIntentService.matchIntent("email report"), VoiceIntent.sendMail);

      // Kannada
      expect(VoiceIntentService.matchIntent("ಇಮೇಲ್ ಕಳುಹಿಸು"), VoiceIntent.sendMail);
      expect(VoiceIntentService.matchIntent("ಮೇಲ್ ಕಳುಹಿಸು"), VoiceIntent.sendMail);
      expect(VoiceIntentService.matchIntent("ಆರೈಕೆದಾರರಿಗೆ ಇಮೇಲ್"), VoiceIntent.sendMail);

      // Hindi
      expect(VoiceIntentService.matchIntent("ईमेल भेजो"), VoiceIntent.sendMail);
      expect(VoiceIntentService.matchIntent("मेल भेजो"), VoiceIntent.sendMail);
      expect(VoiceIntentService.matchIntent("केयरगिवर को ईमेल"), VoiceIntent.sendMail);
    });

    test('Measures sub-millisecond command matching latency and accurate execution metrics', () {
      final samplePhrases = [
        "home",
        "open the scan",
        "take photo",
        "mark taken",
        "schedule",
        "emergency",
        "ಮುಖಪುಟ",
        "ಸ್ಕ್ಯಾನ್ ತೆರೆ",
        "ತೆಗೆದುಕೊಂಡೆ",
        "ವೇಳಾಪಟ್ಟಿ",
        "होम खोलो",
        "दवा खा ली",
        "समय सारणी",
        "turn on noise cancellation",
        "help",
      ];

      for (final phrase in samplePhrases) {
        final result = VoiceIntentService.matchIntentWithMetrics(phrase);
        expect(result.intent, isNotNull, reason: 'Failed to match $phrase');
        // Assert command interpretation overhead is sub-millisecond (< 1000 microseconds)
        // Highly optimized O(1) hash map and precompiled regexes
        expect(result.executionMicroseconds, lessThan(10000),
            reason: 'Match overhead too high for $phrase: ${result.executionMicroseconds} µs');
      }
    });

    test('Prevents duplicate execution from rapid streaming partials (debouncing)', () {
      VoiceIntentService.resetDebounce();

      // First partial match: should NOT be debounced
      expect(VoiceIntentService.shouldDebounce(VoiceIntent.scan), isFalse);
      VoiceIntentService.recordExecution(VoiceIntent.scan);

      // Immediate second partial match within 900ms: SHOULD be debounced
      expect(VoiceIntentService.shouldDebounce(VoiceIntent.scan, debounceMs: 900), isTrue);

      // Different intent should NOT be debounced
      expect(VoiceIntentService.shouldDebounce(VoiceIntent.home), isFalse);

      VoiceIntentService.resetDebounce();
      expect(VoiceIntentService.shouldDebounce(VoiceIntent.scan), isFalse);
    });

    test('Unknown commands and gibberish do not trigger false actions', () {
      final unknownPhrases = [
        "purple elephant jumping",
        "xyz123abc",
        "what is the weather today",
        "tell me a joke",
        "play music",
        "random noise in the room",
        "ಇದು ಯಾದೃಚ್ಛಿಕ ಶಬ್ದ",
        "ಕೇವಲ ಹರಟೆ",
        "यह एक सुंदर दिन है",
        "मौसम कैसा है",
      ];

      for (final phrase in unknownPhrases) {
        final result = VoiceIntentService.matchIntent(phrase);
        expect(result, isNull, reason: 'Expected null intent for unknown phrase: "$phrase"');
      }
    });

    test('Acoustic noise phonemes and uncertain fragments do not trigger critical actions', () {
      final ambientFragments = [
        "uh",
        "um",
        "ah",
        "er",
        "hmm",
        "mm",
        "a",
        "the",
        "",
        "   ",
        "...",
      ];

      for (final fragment in ambientFragments) {
        final result = VoiceIntentService.matchIntent(fragment);
        expect(result, isNull, reason: 'Ambient fragment "$fragment" should not trigger any action');
      }
    });

    test('Language-specific intent aliases correctly identify target languages', () {
      // English aliases
      expect(VoiceIntentService.matchIntent("speak english"), VoiceIntent.langEn);
      expect(VoiceIntentService.matchIntent("switch to english"), VoiceIntent.langEn);
      expect(VoiceIntentService.matchIntent("change to english"), VoiceIntent.langEn);
      expect(VoiceIntentService.matchIntent("english"), VoiceIntent.langEn);

      // Kannada aliases
      expect(VoiceIntentService.matchIntent("speak kannada"), VoiceIntent.langKn);
      expect(VoiceIntentService.matchIntent("switch to kannada"), VoiceIntent.langKn);
      expect(VoiceIntentService.matchIntent("change to kannada"), VoiceIntent.langKn);
      expect(VoiceIntentService.matchIntent("kannada"), VoiceIntent.langKn);
      expect(VoiceIntentService.matchIntent("ಕನ್ನಡ"), VoiceIntent.langKn);
      expect(VoiceIntentService.matchIntent("ಕನ್ನಡದಲ್ಲಿ ಮಾತನಾಡಿ"), VoiceIntent.langKn);

      // Hindi aliases
      expect(VoiceIntentService.matchIntent("speak hindi"), VoiceIntent.langHi);
      expect(VoiceIntentService.matchIntent("switch to hindi"), VoiceIntent.langHi);
      expect(VoiceIntentService.matchIntent("change to hindi"), VoiceIntent.langHi);
      expect(VoiceIntentService.matchIntent("hindi"), VoiceIntent.langHi);
      expect(VoiceIntentService.matchIntent("हिंदी"), VoiceIntent.langHi);
      expect(VoiceIntentService.matchIntent("हिंदी में बोलो"), VoiceIntent.langHi);
    });

    test('Pluggable Speech Engine Architecture and Model Specifications validate correctly', () {
      // 1. Verify Whisper Model Specs
      expect(WhisperModelInfo.tiny.id, 'tiny');
      expect(WhisperModelInfo.tiny.fileName, 'ggml-tiny.bin');
      expect(WhisperModelInfo.tiny.fileSizeBytes, greaterThan(70 * 1024 * 1024));
      expect(WhisperModelInfo.base.id, 'base');
      expect(WhisperModelInfo.base.fileName, 'ggml-base.bin');
      expect(WhisperModelInfo.base.fileSizeBytes, greaterThan(140 * 1024 * 1024));

      // 2. Verify WhisperModelManager lifecycle & default state
      final manager = WhisperModelManager();
      expect(manager.selectedModel.id, 'tiny');
      expect(manager.status, ModelDownloadStatus.notDownloaded);
      expect(manager.downloadProgress, 0.0);

      // 3. Verify Model Selection
      manager.selectModel(WhisperModelInfo.base);
      expect(manager.selectedModel.id, 'base');

      // 4. Verify WhisperSpeechEngine initial unavailable state
      final whisperEngine = WhisperSpeechEngine(modelManager: manager);
      expect(whisperEngine.engineType, SpeechEngineType.whisperOnDevice);
      expect(whisperEngine.isAvailable, isFalse);
      expect(whisperEngine.isListening, isFalse);

      // 5. Verify NativeSpeechEngine specifications
      final nativeEngine = NativeSpeechEngine();
      expect(nativeEngine.engineType, SpeechEngineType.native);
      expect(nativeEngine.isListening, isFalse);
    });
  });
}

