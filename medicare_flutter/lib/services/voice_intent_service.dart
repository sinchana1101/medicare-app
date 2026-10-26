enum VoiceIntent {
  home,
  scan,
  schedule,
  assistant,
  more,
  emergency,
  takePhoto,
  uploadPhoto,
  save,
  markTaken,
  skipDose,
  nextMedicine,
  readPage,
  repeat,
  stop,
  help,
  setAlarm,
  back,
  whereAmI,
  yes,
  no,
  cancel,
  snooze,
  callCaregiver,
  callAmbulance,
  demoLogin,
  testAlarm,
  signOut,
  prescriptionMode,
  medicineMode,
  refresh,
  langEn,
  langKn,
  langHi,
  noiseCancelOn,
  noiseCancelOff,
  continuousVoiceOn,
  continuousVoiceOff,
  sendMail
}

class _IntentCandidate {
  final VoiceIntent intent;
  final int startIndex;
  final int length;

  _IntentCandidate(this.intent, this.startIndex, this.length);
}

class VoiceIntentService {
  static const Map<VoiceIntent, List<String>> _phrases = {
    // Navigation Intents
    VoiceIntent.home: [
      "home", "open home", "open the home", "go to home", "show home", "main page", "dashboard", "today's schedule", "main screen", "home screen", "take me home", "back to home", "main",
      "ಮುಖಪುಟ", "ಮನೆ", "ಮುಖ್ಯ ಪುಟ", "ಇಂದಿನ ವೇಳಾಪಟ್ಟಿ", "ಹೋಮ್", "ಹೋಂ", "ಹೋಮ್ ತೆರೆ", "ಹೋಮ್ ಓಪನ್", "ಓಪನ್ ಹೋಮ್", "ಮುಖಪುಟ ತೆರೆ", "ಮನೆಗೆ ಹೋಗು", "ಹೋಮ್", "ಹೋಂ", "ಹೋಮ್ ಸ್ಕ್ರೀನ್",
      "होम", "मुख्य पृष्ठ", "घर", "आज की खुराक", "डैशबोर्ड", "मुख्य स्क्रीन", "होम स्क्रीन", "होम खोलो", "ओपन होम", "होम जाओ"
    ],
    VoiceIntent.scan: [
      "scan", "open scan", "open the scan", "go to scan", "camera", "read label", "scan medicine", "open camera", "open the camera", "scan box", "scan screen", "start scan", "take me to scan", "scanner", "open scanner", "can", "open can", "open the can", "scam", "skan", "scann",
      "ಸ್ಕ್ಯಾನ್", "ಕ್ಯಾಮೆರಾ", "ಕ್ಯಾಮರಾ", "ಲೇಬಲ್ ಓದಿ", "ಔಷಧಿ ಸ್ಕ್ಯಾನ್", "ಸ್ಕ್ಯಾನ್ ತೆರೆ", "ಸ್ಕ್ಯಾನ್ ಓಪನ್", "ಓಪನ್ ಸ್ಕ್ಯಾನ್", "ಕ್ಯಾಮೆರಾ ತೆರೆ", "ಕ್ಯಾಮರಾ ಓಪನ್", "ಸ್ಕ್ಯಾನರ್", "ಸ್ಕಾನರ್", "ಸ್ಕ್ಯಾನ್ ಸ್ಕ್ರೀನ್",
      "स्कैन", "कैमरा", "दवा स्कैन", "लेबल पढ़ो", "स्कैनर", "स्कैन खोलो", "स्कैन ओपन", "ओपन स्कैन", "कैमरा खोलो", "स्कैन पर जाओ", "स्कैन स्क्रीन", "स्कैनर खोलो"
    ],
    VoiceIntent.schedule: [
      "schedule", "open schedule", "open the schedule", "go to schedule", "my medicines", "reminders", "all medicines", "pill list", "timeline", "calendar", "show schedule", "schedule screen", "alarms", "alarm", "open alarms", "open alarm", "pills", "doses", "skedule", "shedule",
      "ವೇಳಾಪಟ್ಟಿ", "ಔಷಧಿಗಳು", "ನನ್ನ ಔಷಧಿಗಳು", "ಎಲ್ಲಾ ಔಷಧಿಗಳು", "ಶೆಡ್ಯೂಲ್", "ವೇಳಾಪಟ್ಟಿ ತೆರೆ", "ಶೆಡ್ಯೂಲ್ ತೆರೆ", "ಶೆಡ್ಯೂಲ್ ಓಪನ್", "ಓಪನ್ ಶೆಡ್ಯೂಲ್", "ಅಲಾರಾಂ", "ಅಲಾರಂ", "ಅಲಾರಾಂ ತೆರೆ", "ಅಲಾರಂ ತೆರೆ",
      "समय सारणी", "समय-सारणी", "दवाएं", "दवाएँ", "रिमाइंडर", "मेरी दवाएं", "दवाइयों की सूची", "शेड्यूल", "शेड्यूल खोलो", "शेड्यूल ओपन", "ओपन शेड्यूल", "अलार्म", "अलार्म खोलो", "ओपन अलार्म"
    ],
    VoiceIntent.assistant: [
      "assistant", "open assistant", "open the assistant", "voice assistant", "ask", "question", "talk to ai", "ask doctor", "ai assistant", "talk to assistant", "go to assistant", "ai", "doctor", "bot",
      "ಸಹಾಯಕ", "ಪ್ರಶ್ನೆ", "ಎಐ ಸಹಾಯಕ", "ಕೇಳು", "ಅಸಿಸ್ಟೆಂಟ್", "ಸಹಾಯಕ ತೆರೆ", "ಅಸಿಸ್ಟೆಂಟ್ ಓಪನ್", "ಓಪನ್ ಅಸಿಸ್ಟೆಂಟ್",
      "सहायक", "प्रश्न", "पूछ", "डॉक्टर", "मददगार", "आवाज सहायक", "असिस्टेंट", "सहायक खोलो", "असिस्टेंट ओपन", "ओपन असिस्टेंट"
    ],
    VoiceIntent.more: [
      "settings", "setting", "the setting", "the settings", "open settings", "open the settings", "open setting", "go to settings", "go to setting", "app settings", "show settings", "more", "options", "preferences", "profile", "account",
      "ಸೆಟ್ಟಿಂಗ್", "ಸೆಟ್ಟಿಂಗ್ಸ್", "ಸೆಟ್ಟಿಂಗ್ ತೆರೆ", "ಸೆಟ್ಟಿಂಗ್ಸ್ ತೆರೆ", "ಸೆಟ್ಟಿಂಗ್ಸ್ ಓಪನ್", "ಓಪನ್ ಸೆಟ್ಟಿಂಗ್ಸ್", "ಇನ್ನಷ್ಟು", "ಖಾತೆ",
      "सेटिंग", "सेटिंग्स", "सेटिंग खोलो", "सेटिंग्स खोलो", "सेटिंग्स ओपन", "ओपन सेटिंग्स", "और", "प्रोफाइल", "खाता", "विकल्प"
    ],
    VoiceIntent.emergency: [
      "emergency", "open emergency", "open the emergency", "help me", "sos", "call for help", "danger", "urgent", "save me", "send sos",
      "send", "send now", "send sms", "send alert", "send message", "trigger sos", "sos alert", "alert",
      "ತುರ್ತು", "ಸಹಾಯ ಬೇಕು", "ಅಪಾಯ", "ರಕ್ಷಿಸಿ", "ಎಮರ್ಜೆನ್ಸಿ", "ಎಸ್ಒಎಸ್", "ತುರ್ತು ತೆರೆ", "ಎಮರ್ಜೆನ್ಸಿ ಓಪನ್", "ಕಳುಹಿಸು", "ಎಸ್ಒಎಸ್ ಕಳುಹಿಸು",
      "आपातकाल", "मदद करो", "बचाओ", "खतरा", "इमरजेंसी", "एसओएस", "इमरजेंसी खोलो", "आपातकाल खोलो", "भेजो", "एसओएस भेजो"
    ],

    // Action Intents
    VoiceIntent.takePhoto: [
      "take photo", "take a photo", "take the photo", "take picture", "take a picture", "take the picture",
      "click photo", "click the photo", "click a photo", "capture", "capture image", "capture photo", "capture the photo", "capture a photo", "capture this photo",
      "snap", "click picture", "click the picture", "click", "shoot", "snap photo", "photo", "camera", "picture", "pic", "cheese", "shutter", "clik", "klick",
      "click it", "capture it", "take it", "snap it", "shoot it",
      "ಫೋಟೋ ತೆಗೆ", "ಚಿತ್ರ ತೆಗೆ", "ಕ್ಲಿಕ್ ಮಾಡಿ", "ಕ್ಲಿಕ್", "ಕ್ಯಾಪ್ಚರ್", "ಫೋಟೋ", "ಕ್ಯಾಮರಾ", "ಚಿತ್ರ",
      "फोटो लो", "फोटो लें", "तस्वीर लो", "फोटो खींचो", "क्लिक करो", "क्लिक", "चित्र लो", "फोटो", "कैमरा", "तस्वीर", "खींचो"
    ],
    VoiceIntent.uploadPhoto: [
      "upload photo", "upload", "choose photo", "gallery", "pick image", "select photo",
      "ಅಪ್‌ಲೋಡ್", "ಗ್ಯಾಲರಿ", "ಫೋಟೋ ಆರಿಸಿ", "ಚಿತ್ರ ಆರಿಸಿ",
      "अपलोड", "गैलरी", "फोटो चुनो", "गैलरी से लो"
    ],
    VoiceIntent.save: [
      "save", "save medicine", "confirm save", "add to schedule", "save this", "store",
      "ಉಳಿಸಿ", "ಸೇವ್", "ಸೇರಿಸಿ", "ಖಚಿತಪಡಿಸಿ",
      "सहेज", "सेव", "सुरक्षित करें", "जोड़ो", "रख लो"
    ],
    VoiceIntent.markTaken: [
      "mark taken", "marked taken", "marc taken", "marck taken", "mark take", "mark as taken",
      "mark", "mark it", "mark this", "mark dose", "mark medicine", "mark pill", "mark dolo",
      "taken", "i took", "took my medicine", "i have taken", "pill taken", "medicine taken", "dose taken",
      "done", "consumed", "already taken", "took", "had my medicine", "had medicine", "ate medicine",
      "took pill", "took my pill", "take pill", "pill was taken", "i took it", "took it", "swallowed", "finished",
      "ತೆಗೆದುಕೊಂಡೆ", "ತೆಗೆದುಕೊಂಡಿದ್ದೀನಿ", "ತೆಗೆದುಕೊಂಡಿದ್ದೇನೆ", "ತೆಗೆದುಕೊಂಡೆನು",
      "ತಗೊಂಡೆ", "ತಗೊಂಡಿದ್ದೀನಿ", "ತಗೊಂಡಿದ್ದೇನೆ", "ತಗೊಂಡೆನು", "ತಗೊಂಡಿನಿ", "ತಗೊಂಡಾಯ್ತು",
      "ಸೇವಿಸಿದೆ", "ಕುಡಿದೆ", "ಮುಗಿಯಿತು", "ಆಗಿದೆ", "ಔಷಧಿ ಸೇವಿಸಿದೆ", "ಔಷಧಿ ತೆಗೆದುಕೊಂಡೆ", "ಔಷಧಿ ತಗೊಂಡೆ", "ಔಷಧ ತಗೊಂಡೆ",
      "ಡೋಸ್ ತೆಗೆದುಕೊಂಡೆ", "ಡೋಸ್ ತಗೊಂಡೆ", "ಮಾತ್ರೆ ತೆಗೆದುಕೊಂಡೆ", "ಮಾತ್ರೆ ತಗೊಂಡೆ", "ಮಾರ್ಕ್ ಮಾಡು", "ಮಾರ್ಕ್ ಟೇಕನ್", "ಮಾರ್ಕ್",
      "ಎತ್ತು", "ಎತ್ತಿದೆ", "ಹಾಕಿದೆ", "ಹಾಕ್ಕೊಂಡೆ",
      "ले लिया", "ले ली", "खा लिया", "खा ली", "दवा खा ली", "दवा ले ली", "गोली ले ली", "गोली खा ली",
      "खुराक ले ली", "हो गया", "पी लिया", "मार्क टेकन", "मार्क करो", "मार्क"
    ],
    VoiceIntent.skipDose: [
      "skip", "skip dose", "skip medicine", "skip pill", "skipped", "skip it", "skip this", "skip the dose",
      "did not take", "didn't take", "missed", "missed dose", "missed it", "not taking", "don't take", "leave it", "cancel dose",
      "ಬಿಟ್ಟುಬಿಡಿ", "ಬಿಟ್ಟು ಬಿಡಿ", "ಬಿಡು", "ಬಿಡ್ರಿ", "ಬೇಡ", "ಡೋಸ್ ಬಿಡಿ", "ಡೋಸ್ ಬೇಡ", "ಔಷಧಿ ಬಿಡಿ", "ಔಷಧಿ ಬೇಡ", "ಮಾತ್ರೆ ಬೇಡ",
      "ತೆಗೆದುಕೊಳ್ಳಬೇಡ", "ತೆಗೆದುಕೊಂಡಿಲ್ಲ", "ತಗೊಂಡಿಲ್ಲ", "ಸ್ಕಿಪ್", "ಸ್ಕಿಪ್ ಮಾಡು", "ಸ್ಕಿಪ್ ಡೋಸ್",
      "छोड़ो", "छोड़ दिया", "छोड़ दें", "छोड़ दीजिए", "दवा छोड़ दो", "नहीं ली", "नहीं लिया", "नहीं खाना", "नहीं खाया", "स्किप", "स्किप करो"
    ],
    VoiceIntent.nextMedicine: [
      "next medicine", "what next", "next dose", "upcoming medicine", "when is next", "next pill",
      "ಮುಂದಿನ ಔಷಧಿ", "ಮುಂದಿನದು ಯಾವುದು", "ಮುಂದೆ ಏನು",
      "अगली दवा", "आगे क्या है", "अगली खुराक"
    ],
    VoiceIntent.readPage: [
      "read page", "read this", "read aloud", "what is on screen", "describe screen", "read schedule", "read medicines", "tell me my medicines", "read all",
      "ಪುಟ ಓದಿ", "ಓದಿ", "ಸ್ಕ್ರೀನ್ ಓದಿ", "ಔಷಧಿಗಳನ್ನು ಓದಿ", "ವಿವರಿಸಿ", "ಎಲ್ಲಾ ಓದಿ",
      "पृष्ठ पढ़", "पढ़ो", "पढ़ें", "स्क्रीन पढ़ो", "दवाएं बताओ", "सुनाओ", "सब पढ़ो"
    ],
    VoiceIntent.repeat: [
      "repeat", "say again", "what did you say", "pardon", "one more time", "again",
      "ಮತ್ತೆ ಹೇಳಿ", "ಪುನಃ", "ಇನ್ನೊಮ್ಮೆ ಹೇಳಿ", "ಮತ್ತೆ",
      "फिर से", "दोहरा", "दोहराओ", "एक बार फिर", "फिर बोलो"
    ],
    VoiceIntent.stop: [
      "stop", "quiet", "silence", "shut up", "pause", "hush", "mute",
      "ನಿಲ್ಲಿಸಿ", "ಸುಮ್ಮನಿರಿ", "ಸಾಕು", "ಚುಪ್", "ಸ್ಟಾಪ್",
      "रुको", "बंद करो", "चुप", "शांत", "स्टॉप"
    ],
    VoiceIntent.help: [
      "help", "what can i say", "commands", "how to use", "options", "instructions",
      "ಸಹಾಯ", "ಏನು ಹೇಳಬಹುದು", "ಆದೇಶಗಳು",
      "मदद", "क्या कह सकता", "निर्देश", "कमांड"
    ],
    VoiceIntent.setAlarm: [
      "set alarm", "set an alarm", "set a reminder", "add reminder", "new alarm", "remind me",
      "ಅಲಾರಂ ಇಡಿ", "ಅಲಾರಂ", "ನೆನಪಿಸು", "ಜ್ಞಾಪನೆ ಇಡಿ",
      "अलार्म लगाओ", "अलार्म", "याद दिलाओ", "रिमाइंडर लगाओ"
    ],
    VoiceIntent.snooze: [
      "snooze", "later", "remind in 10 minutes", "after 10 minutes",
      "ಸ್ನೂಜ್", "ನಂತರ", "ಹತ್ತು ನಿಮಿಷ ಬಿಟ್ಟು",
      "स्नूज़", "स्नूज", "बाद में", "१० मिनट बाद"
    ],
    VoiceIntent.back: [
      "go back", "back", "previous", "return", "exit screen",
      "ಹಿಂದಕ್ಕೆ", "ಹಿಂದಿನದು", "ಹಿಂದೆ ಹೋಗು", "ವಾಪಸ್",
      "वापस", "पीछे", "वापस जाओ", "पिछला"
    ],
    VoiceIntent.whereAmI: [
      "where am i", "which screen", "current screen", "what page",
      "ನಾನು ಎಲ್ಲಿದ್ದೇನೆ", "ಯಾವ ಪರದೆ", "ಯಾವ ಪುಟ",
      "मैं कहाँ हूँ", "कौन सी स्क्रीन", "यह क्या है"
    ],
    VoiceIntent.yes: [
      "yes", "yeah", "correct", "okay", "ok", "confirm", "sure", "yep",
      "ಹೌದು", "ಸರಿ", "ಖಂಡಿತ",
      "हाँ", "हां", "ठीक", "सही", "अवश्य"
    ],
    VoiceIntent.no: [
      "no", "wrong", "nope", "never", "incorrect",
      "ಇಲ್ಲ", "ತಪ್ಪು", "ಬೇಡ",
      "नहीं", "गलत", "मत करो"
    ],
    VoiceIntent.cancel: [
      "cancel", "abort", "discard", "dismiss",
      "ರದ್ದು", "ರದ್ದುಮಾಡಿ", "ಬೇಡ",
      "रद्द", "बंद", "हटाओ"
    ],
    VoiceIntent.callCaregiver: [
      "call caregiver", "call emergency contact", "call family", "call doctor", "call my helper",
      "ಆರೈಕೆದಾರರಿಗೆ ಕರೆ", "ಸಹಾಯಕರಿಗೆ ಕರೆ", "ತುರ್ತು ಕರೆ",
      "केयरगिवर को कॉल", "सहायक को कॉल", "संपर्क को फोन करो", "परिवार को फोन"
    ],
    VoiceIntent.callAmbulance: [
      "call ambulance", "ambulance", "call 108", "dial 108", "108", "hospital call",
      "ಆಂಬ್ಯುಲೆನ್ಸ್", "೧೦೮", "೧೦೮ ಗೆ ಕರೆ", "ಆಸ್ಪತ್ರೆಗೆ ಕರೆ",
      "एम्बुलेंस", "१०८", "१०८ पर कॉल", "अस्पताल को फोन"
    ],
    VoiceIntent.demoLogin: [
      "demo", "demo login", "continue offline", "offline mode", "guest login", "guest",
      "ಡೆಮೊ", "ಆಫ್‌ಲೈನ್", "ಡೆಮೊ ಲಾಗಿನ್",
      "डेमो", "ऑफ़लाइन", "डेमो लॉगिन", "अतिथि"
    ],
    VoiceIntent.testAlarm: [
      "test alarm", "alarm test", "check alarm",
      "ಅಲಾರಂ ಪರೀಕ್ಷೆ", "ಅಲಾರಂ ಚೆಕ್",
      "अलार्म टेस्ट", "अलार्म जांचें"
    ],
    VoiceIntent.signOut: [
      "sign out", "log out", "logout",
      "ನಿರ್ಗಮಿಸಿ", "ಲಾಗ್ ಔಟ್",
      "लॉग आउट", "साइन आउट"
    ],
    VoiceIntent.prescriptionMode: [
      "prescription mode", "prescription", "doctor note", "switch to prescription",
      "ಪ್ರಿಸ್ಕ್ರಿಪ್ಷನ್", "ವೈದ್ಯರ ಚೀಟಿ", "ಚೀಟಿ ಮೋಡ್",
      "पर्चा", "डॉक्टर का पर्चा", "पर्चा मोड"
    ],
    VoiceIntent.medicineMode: [
      "medicine mode", "box mode", "switch to medicine", "medicine label",
      "ಔಷಧಿ ಮೋಡ್", "ಬಾಕ್ಸ್ ಮೋಡ್",
      "दवा मोड", "बॉक्स मोड"
    ],
    VoiceIntent.refresh: [
      "refresh", "reload", "update",
      "ನವೀಕರಿಸಿ", "ರಿಫ್ರೆಶ್",
      "रिफ्रेश", "ताज़ा करें"
    ],
    VoiceIntent.langEn: [
      "speak english", "english", "switch to english", "change to english",
      "ಇಂಗ್ಲಿಷ್", "ಇಂಗ್ಲಿಷ್ ಭಾಷೆ",
      "अंग्रेज़ी", "अंग्रेजी", "इंग्लिश"
    ],
    VoiceIntent.langKn: [
      "speak kannada", "kannada", "switch to kannada", "change to kannada",
      "ಕನ್ನಡ", "ಕನ್ನಡ್", "ಕನ್ನಡದಲ್ಲಿ ಮಾತನಾಡಿ"
    ],
    VoiceIntent.langHi: [
      "speak hindi", "hindi", "switch to hindi", "change to hindi",
      "ಹಿಂದಿ",
      "हिंदी", "हिन्दी", "हिंदी में बोलो"
    ],
    VoiceIntent.noiseCancelOn: [
      "turn on noise cancellation", "noise cancellation on", "enable noise cancellation",
      "ಶಬ್ದ ರದ್ದತಿ ಆನ್",
      "शोर रद्दीकरण चालू"
    ],
    VoiceIntent.noiseCancelOff: [
      "turn off noise cancellation", "noise cancellation off", "disable noise cancellation",
      "ಶಬ್ದ ರದ್ದತಿ ಆಫ್",
      "शोर रद्दीकरण बंद"
    ],
    VoiceIntent.continuousVoiceOn: [
      "turn on continuous voice", "continuous voice on", "start continuous listening", "voice mode on", "hands free on", "hands free mode", "keep listening",
      "ಧ್ವನಿ ಮೋಡ್ ಆನ್", "ವಾಯ್ಸ್ ಮೋಡ್ ಆನ್",
      "वॉइस मोड चालू", "कंटीन्यूअस वॉइस ऑन"
    ],
    VoiceIntent.continuousVoiceOff: [
      "turn off continuous voice", "continuous voice off", "stop continuous listening", "voice mode off", "hands free off", "stop listening",
      "ಧ್ವನಿ ಮೋಡ್ ಆಫ್", "ವಾಯ್ಸ್ ಮೋಡ್ ಆಫ್",
      "वॉइस मोड बंद", "कंटीन्यूअस वॉइस बंद"
    ],
    VoiceIntent.sendMail: [
      "send mail", "send email", "mail", "email", "mail caregiver", "email caregiver",
      "send mail to caregiver", "send email to caregiver", "email report", "mail report",
      "send emergency mail", "email alert", "mail alert", "send a mail", "send an email",
      "caregiver email", "caregiver mail", "compose mail", "compose email",
      "ಇಮೇಲ್ ಕಳುಹಿಸು", "ಮೇಲ್ ಕಳುಹಿಸು", "ಇಮೇಲ್", "ಮೇಲ್", "ಆರೈಕೆದಾರರಿಗೆ ಇಮೇಲ್", "ಆರೈಕೆದಾರರಿಗೆ ಮೇಲ್", "ಡಾಕ್ಟರ್‌ಗೆ ಇಮೇಲ್", "ಜಿಮೇಲ್",
      "ईमेल भेजो", "मेल भेजो", "ईमेल", "मेल", "केयरगिवर को ईमेल", "केयरगिवर को मेल", "डॉक्टर को ईमेल", "ईमेल भेजें", "मेल भेजें", "जीमेल"
    ],
  };

  // High-performance precompiled regular expressions for sentence and keyword matching
  static final RegExp _sendMailRegex = RegExp(
    r'\b(?:(?:send\s+(?:an?\s+)?|trigger\s+|compose\s+)?(?:mail|email|e-mail|gmail)|'
    r'(?:mail|email|e-mail)\s+(?:caregiver|doctor|family|contact|report|alert|now|to\s+caregiver)|'
    r'caregiver\s+mail|caregiver\s+email)\b|'
    r'(?:(?:ಇಮೇಲ್|ಮೇಲ್|ಜಿಮೇಲ್)(?:\s*(?:ಕಳುಹಿಸು|ಮಾಡು|ಬರೆ|ಓಪನ್))?|'
    r'(?:ಆರೈಕೆದಾರರಿಗೆ|ಡಾಕ್ಟರ್‌ಗೆ|ಕುಟುಂಬಕ್ಕೆ)\s*(?:ಇಮೇಲ್|ಮೇಲ್))|'
    r'(?:(?:ईमेल|मेल|जीमेल)(?:\s*(?:भेजो|भेजें|करो|लिखो|खोलो))?|'
    r'(?:केयरगिवर|डॉक्टर|परिवार)\s*(?:को\s*)?(?:ईमेल|मेल))',
    caseSensitive: false,
  );

  static final RegExp _homeRegex = RegExp(
    r'(?:(?:open|go\s*to|goto|show|navigate\s*to|back\s*to|take\s*me\s*to|view|visit)\s+(?:the\s+)?)?(?:home|hom|whom|dashboard|main\s*(?:page|screen)?|today(?:\x27?s)?\s*schedule)\b|'
    r'(?:(?:ಓಪನ್\s+)?(?:ಹೋಮ್|ಹೋಂ|ಮುಖಪುಟ|ಮನೆ|ಮುಖ್ಯ\s*ಪುಟ|ಇಂದಿನ\s*ವೇಳಾಪಟ್ಟಿ)(?:\s*(?:ತೆರೆ|ಓಪನ್|ಗೆ\s*ಹೋಗು|ತೋರಿಸು|ಸ್ಕ್ರೀನ್))?)|'
    r'(?:(?:ओपन\s+)?(?:होम|मुख्य|मुखपृष्ठ|घर|डैशबोर्ड|आज\s*(?:का\s*)?(?:शेड्यूल|समय\s*सारणी))(?:\s*(?:खोलो|ओपन|पर\s*जाओ|दिखाओ|स्क्रीन))?)',
    caseSensitive: false,
  );

  static final RegExp _scanRegex = RegExp(
    r'(?:(?:open|go\s*to|goto|show|navigate\s*to|start|launch|take\s*me\s*to)\s+(?:the\s+)?)?'
    r'(?:scan|camera|scanner|skan|scann|scam|cam|camra|camara|can|scan\s*medicine|scan\s*box|scan\s*screen|read\s*label)\b|'
    r'\b(?:open\s+(?:the\s+)?)?can\b|'
    r'(?:(?:ಓಪನ್\s+)?(?:ಸ್ಕ್ಯಾನ್|ಸ್ಕಾನರ್|ಕ್ಯಾಮೆರಾ|ಕ್ಯಾಮರಾ)(?:\s*(?:ತೆರೆ|ಓಪನ್|ಮಾಡು|ತೋರಿಸು|ಸ್ಕ್ರೀನ್|ಔಷಧಿ|ಓದಿ))?)|'
    r'(?:(?:ओपन\s+)?(?:स्कैन|स्कैनर|कैमरा|कैमरे)(?:\s*(?:खोलो|ओपन|करो|दिखाओ|जाओ|स्क्रीन|दवा|पढ़ो))?)',
    caseSensitive: false,
  );

  static final RegExp _scheduleRegex = RegExp(
    r'(?:(?:open|go\s*to|goto|show|navigate\s*to|view|list|tell\s*me)\s+(?:the\s+)?)?'
    r'(?:schedule|skedule|shedule|schedul|shedul|reminders?|my\s*medicines?|all\s*medicines?|medicines?|pill\s*list|medicine\s*list|dose\s*list|timeline|calendar|alarms?|my\s*doses?|my\s*pills?)\b|'
    r'(?:(?:ಓಪನ್\s+)?(?:ವೇಳಾಪಟ್ಟಿ|ಶೆಡ್ಯೂಲ್|ಶೆಡ್ಯೂಲ|ಔಷಧಿಗಳು|ನನ್ನ\s*ಔಷಧಿಗಳು|ಎಲ್ಲಾ\s*ಔಷಧಿಗಳು|ಅಲಾರಾಂ|ಅಲಾರಂ)(?:\s*(?:ತೆರೆ|ಓಪನ್|ತೋರಿಸು|ಪಟ್ಟಿ))?)|'
    r'(?:(?:ओपन\s+)?(?:शेड्यूल|समय\s*सारणी|समय-सारणी|दवाएं|दवाएँ|मेरी\s*दवाएं|दवाइयों\s*की\s*सूची|रिमाइंडर|अलार्म)(?:\s*(?:खोलो|ओपन|दिखाओ|जाओ))?)',
    caseSensitive: false,
  );

  static final RegExp _assistantRegex = RegExp(
    r'(?:(?:open|go\s*to|talk\s*to|ask|chat\s*with)\s+(?:the\s+)?)?'
    r'(?:assistant|asistant|assistance|voice\s*assistant|ai|ai\s*assistant|doctor|doc|bot|virtual\s*doctor)\b|'
    r'(?:(?:ಓಪನ್\s+)?(?:ಸಹಾಯಕ|ಅಸಿಸ್ಟೆಂಟ್|ಎಐ|ಡಾಕ್ಟರ್)(?:\s*(?:ತೆರೆ|ಓಪನ್|ಕೇಳು|ಮಾತನಾಡು|ಜೊತೆ\s*ಮಾತನಾಡು))?)|'
    r'(?:(?:ओपन\s+)?(?:सहायक|असिस्टेंट|मददगार|डॉक्टर|एआई)(?:\s*(?:खोलो|ओपन|पूछो|बात\s*करो))?)',
    caseSensitive: false,
  );

  static final RegExp _settingsRegex = RegExp(
    r'(?:(?:open|go\s*to|goto|show|navigate\s*to)\s+(?:the\s+)?)?'
    r'(?:settings?|setings?|preferences|profile|options?|account|more)\b|'
    r'(?:(?:ಓಪನ್\s+)?(?:ಸೆಟ್ಟಿಂಗ್|ಸೆಟ್ಟಿಂಗ್ಸ್|ಇನ್ನಷ್ಟು|ಖಾತೆ)(?:\s*(?:ತೆರೆ|ಓಪನ್|ತೋರಿಸು))?)|'
    r'(?:(?:ओपन\s+)?(?:सेटिंग|सेटिंग्स|और|विकल्प|प्रोफाइल|खाता)(?:\s*(?:खोलो|ओपन|दिखाओ))?)',
    caseSensitive: false,
  );

  static final RegExp _emergencyRegex = RegExp(
    r'(?:(?:open|send|trigger)\s+(?:the\s+)?)?'
    r'(?:emergency|emergenci|sos|s\s*o\s*s|help\s*me|save\s*me|danger|urgent|send\s*sms|send\s*sos|send\s*alert|send\s*message|trigger\s*sos|send\s*now|send)\b|'
    r'(?:(?:ಓಪನ್\s+)?(?:ತುರ್ತು|ಆಪತ್ತು|ಎಮರ್ಜೆನ್ಸಿ|ಎಸ್ಒಎಸ್|ಕಾಪಾಡಿ|ಸಹಾಯ\s*ಬೇಕು|ಕಳುಹಿಸು)(?:\s*(?:ತೆರೆ|ಓಪನ್|ಮಾಡು))?)|'
    r'(?:(?:ओपन\s+)?(?:आपातकाल|इमरजेंसी|एसओएस|खतरा|बचाओ|मदद\s*करो|भेजो)(?:\s*(?:खोलो|ओपन))?)',
    caseSensitive: false,
  );

  static final RegExp _takePhotoRegex = RegExp(
    r'\b(?:(?:take|click|capture|snap|shoot)\s+(?:the\s+|a\s+|this\s+)?(?:photo|picture|image|pic)?|'
    r'click\s+it|capture\s+it|take\s+it|snap\s+it|shoot\s+it|'
    r'click|clik|klick|capture|captur|snap|shoot|photo|picture|pic|cheese|shutter)\b|'
    r'(?:(?:ಫೋಟೋ|ಚಿತ್ರ)\s*(?:ತೆಗೆ|ಕ್ಲಿಕ್\s*ಮಾಡಿ|ಕ್ಯಾಪ್ಚರ್|ಮಾಡು|ಲೋ)?|ಕ್ಲಿಕ್|ಕ್ಯಾಪ್ಚರ್|ಫೋಟೋ|ಚಿತ್ರ)|'
    r'(?:(?:फोटो|तस्वीर|चित्र)\s*(?:लो|खींचो|क्लिक\s*करो|लें|कैप्चर)?|क्लिक|कैप्चर|खींचो|फोटो|तस्वीर)',
    caseSensitive: false,
  );

  static final RegExp _ambulanceRegex = RegExp(
    r'\b(?:(?:call|dial|open)\s+)?(?:108|ambulance|hospital)\b|'
    r'(?:(?:ಕರೆ\s*ಮಾಡಿ\s+)?(?:ಆಂಬ್ಯುಲೆನ್ಸ್|೧೦೮))|'
    r'(?:(?:कॉल\s*करो\s+)?(?:एम्बुलेंस|१०८))',
    caseSensitive: false,
  );

  static final RegExp _caregiverRegex = RegExp(
    r'\b(?:(?:call|contact)\s+(?:my\s+)?)?(?:caregiver|family|helper)\b|'
    r'(?:(?:ಕರೆ\s*ಮಾಡಿ\s+)?(?:ಆರೈಕೆದಾರ|ಕುಟುಂಬ|ಸಹಾಯಕ))|'
    r'(?:(?:कॉल\s*करो\s+)?(?:केयरगिवर|परिवार|सहायक))',
    caseSensitive: false,
  );

  static final RegExp _stopRegex = RegExp(
    r'\b(?:stop|silence|quiet|shut\s*up|pause|hush|mute|stop\s*talking)\b|(?:ನಿಲ್ಲಿಸಿ|ಸುಮ್ಮನಿರಿ|ಸಾಕು|ಚುಪ್|ಸ್ಟಾಪ್)|(?:रुको|बंद\s*करो|चुप|शांत|स्टॉप)',
    caseSensitive: false,
  );

  static final RegExp _markTakenRegex = RegExp(
    r'\b(?:mark\s*(?:as\s+)?taken|marked\s*taken|marc\s*taken|marck\s*taken|mark\s*take|mark\s*it|mark\s*this|'
    r'mark\s*(?:my\s+)?(?:dose|medicine|pill)?|'
    r'i\s*(?:have\s+)?taken\s*(?:my\s+)?(?:pill|pills|medicine|medicines|dose|it)?|'
    r'i\s*took\s*(?:my\s+)?(?:pill|pills|medicine|medicines|dose|it)?|'
    r'took\s*(?:my\s+)?(?:pill|pills|medicine|medicines|dose|it)?|'
    r'had\s*(?:my\s+)?(?:medicine|pill|dose)|ate\s*(?:my\s+)?(?:medicine|pill)|'
    r'already\s*taken|pill\s*taken|medicine\s*taken|dose\s*taken|take\s*pill|took\s*pill|'
    r'taken|took|done|consumed|finished|swallowed)\b|'
    r'(?:ತೆಗೆದುಕೊಂಡೆ(?:ನು|ವು)?|ತೆಗೆದುಕೊಂಡಿದ್ದೀನಿ|ತೆಗೆದುಕೊಂಡಿದ್ದೇನೆ|ತಗೊಂಡೆ(?:ನು|ವು)?|ತಗೊಂಡಿದ್ದೀನಿ|ತಗೊಂಡಿದ್ದೇನೆ|ತಗೊಂಡಿನಿ|ತಗೊಂಡಾಯ್ತು|'
    r'ಔಷಧಿ\s*(?:ಸೇವಿಸಿದೆ|ತೆಗೆದುಕೊಂಡೆ|ತಗೊಂಡೆ)|ಔಷಧ\s*(?:ತೆಗೆದುಕೊಂಡೆ|ತಗೊಂಡೆ)|ಮಾತ್ರೆ\s*(?:ತೆಗೆದುಕೊಂಡೆ|ತಗೊಂಡೆ)|ಡೋಸ್\s*(?:ತೆಗೆದುಕೊಂಡೆ|ತಗೊಂಡೆ)|'
    r'ಮಾರ್ಕ್\s*(?:ಮಾಡು|ಟೇಕನ್)?|ಎತ್ತಿದೆ|ಎತ್ತು|ಹಾಕಿದೆ|ಹಾಕ್ಕೊಂಡೆ|ಕುಡಿದೆ|ಸೇವಿಸಿದೆ|ಮುಗಿಯಿತು|ಆಗಿದೆ)|'
    r'(?:ले\s*लिया|ले\s*ली|खा\s*लिया|खा\s*ली|दवा\s*खा\s*ली|दवा\s*ले\s*ली|गोली\s*ले\s*ली|गोली\s*खा\s*ली|खुराक\s*ले\s*ली|'
    r'हो\s*गया|पी\s*लिया|मार्क\s*(?:करो|टेकन)?)',
    caseSensitive: false,
  );

  static final RegExp _skipDoseRegex = RegExp(
    r'\b(?:skip\s*(?:dose|medicine|pill|it|this|the\s+dose)?|skipped|did\s*not\s*take|didn\x27?t\s*take|missed\s*(?:dose|medicine|it)?|missed|not\s*taking|don\x27?t\s*take|leave\s*it|cancel\s*dose)\b|'
    r'(?:ಬಿಟ್ಟುಬಿಡಿ|ಬಿಟ್ಟು\s*ಬಿಡಿ|ಬಿಡು|ಬಿಡ್ರಿ|ಬೇಡ|ಡೋಸ್\s*ಬಿಡಿ|ಡೋಸ್\s*ಬೇಡ|ಔಷಧಿ\s*ಬಿಡಿ|ಔಷಧಿ\s*ಬೇಡ|ಮಾತ್ರೆ\s*ಬೇಡ|'
    r'ತೆಗೆದುಕೊಳ್ಳಬೇಡ|ತೆಗೆದುಕೊಂಡಿಲ್ಲ|ತಗೊಂಡಿಲ್ಲ|ಸ್ಕಿಪ್\s*(?:ಮಾಡು|ಡೋಸ್)?)|'
    r'(?:छोड़ो|छोड़\s*दिया|छोड़\s*दें|छोड़\s*दीजिए|दवा\s*छोड़\s*दो|नहीं\s*ली|नहीं\s*लिया|नहीं\s*खाना|नहीं\s*खाया|स्किप\s*(?:करो)?)',
    caseSensitive: false,
  );

  static final RegExp _backRegex = RegExp(
    r'\b(?:go\s+back|back|previous|return|exit\s*screen|exit|close)\b|(?:ಹಿಂದಕ್ಕೆ|ಹಿಂದಿನದು|ಹಿಂದೆ\s*ಹೋಗು|ವಾಪಸ್|ಹಿಂದೆ)|(?:वापस|पीछे|वापस\s*जाओ|पिछला)',
    caseSensitive: false,
  );

  static final RegExp _saveRegex = RegExp(
    r'\b(?:save|save\s*medicine|confirm\s*save|add\s*to\s*schedule|save\s*this|store)\b|(?:ಉಳಿಸಿ|ಸೇವ್|ಸೇರಿಸಿ|ಖಚಿತಪಡಿಸಿ)|(?:सहेज|सेव|सुरक्षित\s*करें|जोड़ो|रख\s*ಲೋ)',
    caseSensitive: false,
  );

  static final RegExp _nextMedicineRegex = RegExp(
    r'\b(?:next|upcoming|what\s*next)\b.*\b(?:medicine|dose|pill)?\b|(?:ಮುಂದಿನ\s*ಔಷಧಿ|ಮುಂದಿನದು|ಮುಂದೆ\s*ಏನು)|(?:अगली\s*दवा|आगे\s*क्या\s*है|अगली\s*खुराक)',
    caseSensitive: false,
  );

  static final RegExp _readPageRegex = RegExp(
    r'\b(?:read\s*(?:page|this|aloud|schedule|medicines?|all)?|what\s+is\s+on\s+screen|describe\s+screen|tell\s+me\s+my\s+medicines|speak\s+schedule)\b|'
    r'(?:ಪುಟ\s*ಓದಿ|ಓದಿ|ಸ್ಕ್ರೀನ್\s*ಓದಿ|ವಿವರಿಸಿ|ಎಲ್ಲಾ\s*ಓದಿ)|'
    r'(?:पृष्ठ\s*पढ़|पढ़ो|पढ़ें|स्क्रीन\s*पढ़ो|दवाएं\s*बताओ|सुनाओ|सब\s*पढ़ो)',
    caseSensitive: false,
  );

  static final RegExp _repeatRegex = RegExp(
    r'\b(?:repeat|say\s*again|what\s+did\s+you\s+say|pardon|one\s+more\s+time|once\s+more|again)\b|(?:ಮತ್ತೆ\s*ಹೇಳಿ|ಪುನಃ|ಇನ್ನೊಮ್ಮೆ\s*ಹೇಳಿ|ಮತ್ತೆ)|(?:फिर\s*से|दोहरा|दोहराओ|एक\s*बार\s*फिर|फिर\s*बोलो)',
    caseSensitive: false,
  );

  static final RegExp _langKnRegex = RegExp(
    r'\b(?:speak\s+kannada|switch\s+to\s+kannada|change\s+to\s+kannada|kannada)\b|(?:ಕನ್ನಡ|ಕನ್ನಡದಲ್ಲಿ\s*ಮಾತನಾಡಿ)|(?:कन्नड़|कन्नड)',
    caseSensitive: false,
  );

  static final RegExp _langHiRegex = RegExp(
    r'\b(?:speak\s+hindi|switch\s+to\s+hindi|change\s+to\s+hindi|hindi)\b|(?:ಹಿಂದಿ|ಹಿಂದಿಯಲ್ಲಿ\s*ಮಾತನಾಡಿ)|(?:हिंदी|हिन्दी|हिंदी\s*में\s*बोलो)',
    caseSensitive: false,
  );

  static final RegExp _langEnRegex = RegExp(
    r'\b(?:speak\s+english|switch\s+to\s+english|change\s+to\s+english|english)\b|(?:ಇಂಗ್ಲಿಷ್|ಇಂಗ್ಲಿಷ್\s*ಭಾಷೆ)|(?:अंग्रेज़ी|अंग्रेजी|इंग्लिश)',
    caseSensitive: false,
  );

  static final RegExp _demoRegex = RegExp(
    r'\b(?:demo|offline|guest)\b|(?:ಡೆಮೊ|ಆಫ್‌ಲೈನ್)|(?:डेमो|ऑफ़लाइन)',
    caseSensitive: false,
  );

  static final RegExp _noiseCancelOnRegex = RegExp(
    r'\b(?:(?:turn\s*on|enable|start|activate)\s+noise\s*cancellation|noise\s*cancellation\s*on|cancel\s*noise)\b|(?:ಶಬ್ದ\s*ರದ್ದತಿ\s*ಆನ್)|(?:शोर\s*रद्दीकरण\s*चालू|शोर\s*हटाना\s*चालू|नॉइज़\s*कैंसलेशन\s*ऑन)',
    caseSensitive: false,
  );

  static final RegExp _noiseCancelOffRegex = RegExp(
    r'\b(?:(?:turn\s*off|disable|stop|deactivate)\s+noise\s*cancellation|noise\s*cancellation\s*off)\b|(?:ಶಬ್ದ\s*ರದ್ದತಿ\s*ಆಫ್)|(?:शोर\s*रद्दीकरण\s*बंद|शोर\s*हटाना\s*बंद|नॉइज़\s*कैंसलेशन\s*ऑफ़)',
    caseSensitive: false,
  );

  static final RegExp _continuousVoiceOnRegex = RegExp(
    r'\b(?:(?:turn\s*on|start|enable|activate)\s+continuous\s*(?:voice|listening)?|continuous\s*voice\s*on|voice\s*mode\s*on|hands\s*free\s*on|hands\s*free\s*mode|keep\s*listening)\b|'
    r'(?:ಧ್ವನಿ\s*ಮೋಡ್\s*ಆನ್|ವಾಯ್ಸ್\s*ಮೋಡ್\s*ಆನ್)|'
    r'(?:वॉइस\s*मोड\s*चालू|कंटीन्यूअस\s*वॉइस\s*ऑन)',
    caseSensitive: false,
  );

  static final RegExp _continuousVoiceOffRegex = RegExp(
    r'\b(?:(?:turn\s*off|stop|disable|deactivate)\s+continuous\s*(?:voice|listening)?|continuous\s*voice\s*off|voice\s*mode\s*off|hands\s*free\s*off|stop\s*continuous\s*listening)\b|'
    r'(?:ಧ್ವನಿ\s*ಮೋಡ್\s*ಆಫ್|ವಾಯ್ಸ್\s*ಮೋಡ್\s*ಆಫ್)|'
    r'(?:वॉइस\s*मोड\s*बंद|कंटीन्यूअस\s*वॉइस\s*बंद)',
    caseSensitive: false,
  );

  static final RegExp _helpRegex = RegExp(
    r'\b(?:help(?:\s*me)?|what\s+can\s+i\s+say|commands?|how\s+to\s+use|instructions?|options?)\b|'
    r'(?:ಸಹಾಯ|ಏನು\s*ಹೇಳಬಹುದು|ಆದೇಶಗಳು|ಹೇಗೆ\s*ಬಳಸುವುದು)|'
    r'(?:मदद|क्या\s*कह\s*सकता|निर्देश|कमांड|सहायता)',
    caseSensitive: false,
  );

  static final RegExp _uploadPhotoRegex = RegExp(
    r'\b(?:upload\s+(?:a\s+)?photo|upload\s+image|upload|choose\s+photo|gallery|pick\s+(?:image|photo)|select\s+photo)\b|'
    r'(?:ಅಪ್‌ಲೋಡ್|ಗ್ಯಾಲರಿ|ಫೋಟೋ\s*ಆರಿಸಿ|ಚಿತ್ರ\s*ಆರಿಸಿ)|'
    r'(?:अपलोड|गैलरी|फोटो\s*चुनो|गैलरी\s*से\s*लो)',
    caseSensitive: false,
  );

  static final RegExp _setAlarmRegex = RegExp(
    r'\b(?:set\s+(?:an?\s+)?alarm|set\s+(?:a\s+)?reminder|add\s+reminder|new\s+alarm|remind\s+me)\b|'
    r'(?:ಅಲಾರಂ\s*ಇಡಿ|ಅಲಾರಾಂ\s*ಇಡಿ|ನೆನಪಿಸು|ಜ್ಞಾಪನೆ\s*ಇಡಿ)|'
    r'(?:अलार्म\s*लगाओ|अलार्म\s*सेट|याद\s*दिलाओ|रिमाइंडर\s*लगाओ)',
    caseSensitive: false,
  );

  static final RegExp _testAlarmRegex = RegExp(
    r'\b(?:test\s+alarm|alarm\s+test|check\s+alarm)\b|'
    r'(?:ಅಲಾರಂ\s*ಪರೀಕ್ಷೆ|ಅಲಾರಾಂ\s*ಪರೀಕ್ಷೆ|ಅಲಾರಂ\s*ಚೆಕ್)|'
    r'(?:अलार्म\s*टेस्ट|अलार्म\s*जांचें)',
    caseSensitive: false,
  );

  static final RegExp _signOutRegex = RegExp(
    r'\b(?:sign\s*out|log\s*out|logout)\b|'
    r'(?:ನಿರ್ಗಮಿಸಿ|ಲಾಗ್\s*ಔಟ್)|'
    r'(?:लॉग\s*आउट|साइन\s*आउट)',
    caseSensitive: false,
  );

  static final RegExp _refreshRegex = RegExp(
    r'\b(?:refresh|reload|update)\b|'
    r'(?:ನವೀಕರಿಸಿ|ರಿಫ್ರೆಶ್)|'
    r'(?:रिफ्रेश|ताज़ा\s*करें)',
    caseSensitive: false,
  );

  static final RegExp _whereAmIRegex = RegExp(
    r'\b(?:where\s+am\s+i|which\s+screen|current\s+screen|what\s+page)\b|'
    r'(?:ನಾನು\s*ಎಲ್ಲಿದ್ದೇನೆ|ಯಾವ\s*ಪರದೆ|ಯಾವ\s*ಪುಟ)|'
    r'(?:मैं\s*कहाँ\s*हूँ|कौन\s*सी\s*स्क्रीन|यह\s*क्या\s*है)',
    caseSensitive: false,
  );

  static final RegExp _prescriptionModeRegex = RegExp(
    r'\b(?:prescription\s+mode|prescription|doctor\s*note|switch\s+to\s+prescription)\b|'
    r'(?:ಪ್ರಿಸ್ಕ್ರಿಪ್ಷನ್|ವೈದ್ಯರ\s*ಚೀಟಿ|ಚೀಟಿ\s*ಮೋಡ್)|'
    r'(?:पर्चा|डॉक्टर\s*का\s*पर्चा|पर्चा\s*मोड)',
    caseSensitive: false,
  );

  static final RegExp _medicineModeRegex = RegExp(
    r'\b(?:medicine\s+mode|box\s+mode|switch\s+to\s+medicine|medicine\s+label)\b|'
    r'(?:ಔಷಧಿ\s*ಮೋಡ್|ಬಾಕ್ಸ್\s*ಮೋಡ್)|'
    r'(?:दवा\s*मोड|बॉक्स\s*मोड)',
    caseSensitive: false,
  );

  static final RegExp _yesRegex = RegExp(
    r'\b(?:yes|yeah|correct|okay|ok|confirm|sure|yep)\b|'
    r'(?:ಹೌದು|ಸರಿ|ಖಂಡಿತ)|'
    r'(?:हाँ|हां|ठीक|सही|अवश्य)',
    caseSensitive: false,
  );

  static final RegExp _noRegex = RegExp(
    r'\b(?:no|wrong|nope|never|incorrect)\b|'
    r'(?:ಇಲ್ಲ|ತಪ್ಪು|ಬೇಡ)|'
    r'(?:नहीं|गलत|मत\s*करो)',
    caseSensitive: false,
  );

  static final RegExp _cancelRegex = RegExp(
    r'\b(?:cancel|abort|discard|dismiss)\b|'
    r'(?:ರದ್ದು|ರದ್ದುಮಾಡಿ)|'
    r'(?:रद्द|हटाओ)',
    caseSensitive: false,
  );

  static final RegExp _snoozeRegex = RegExp(
    r'\b(?:snooze|later|remind\s+(?:me\s+)?later|remind\s+in\s+10\s+minutes?)\b|'
    r'(?:ಸ್ನೂಜ್|ನಂತರ|ಹತ್ತು\s*ನಿಮಿಷ\s*ಬಿಟ್ಟು)|'
    r'(?:स्नूज़|स्नूज|बाद\s*में|१०\s*मिनट\s*बाद)',
    caseSensitive: false,
  );

  /// Smart normalization: removes punctuation, excess spaces, and lowercases
  static String normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'''[!?,.:;"'()\[\]{}<>/\\|@#$%^&*~`_+=—–\-]'''), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  // Pre-compiled fast O(1) lookup tables initialized once for zero matching latency
  static final Map<String, VoiceIntent> _exactLookup = _buildExactLookup();
  static final List<MapEntry<String, VoiceIntent>> _sortedPhrases = _buildSortedPhrases();

  static Map<String, VoiceIntent> _buildExactLookup() {
    final map = <String, VoiceIntent>{};
    for (final entry in _phrases.entries) {
      for (final phrase in entry.value) {
        final norm = normalize(phrase);
        if (norm.isNotEmpty) {
          map.putIfAbsent(norm, () => entry.key);
        }
      }
    }
    return map;
  }

  static List<MapEntry<String, VoiceIntent>> _buildSortedPhrases() {
    final list = <MapEntry<String, VoiceIntent>>[];
    for (final entry in _phrases.entries) {
      for (final phrase in entry.value) {
        final norm = normalize(phrase);
        if (norm.isNotEmpty) {
          list.add(MapEntry(norm, entry.key));
        }
      }
    }
    // Sort descending by length so longest specific phrases match first
    list.sort((a, b) => b.key.length.compareTo(a.key.length));
    return list;
  }

  // Debounce & deduplication tracker to prevent duplicate executions from streaming partials
  static VoiceIntent? _lastExecutedIntent;
  static int _lastExecutionTimestamp = 0;

  static bool shouldDebounce(VoiceIntent intent, {int debounceMs = 1200}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastExecutedIntent == intent && (now - _lastExecutionTimestamp) < debounceMs) {
      return true;
    }
    return false;
  }

  static void recordExecution(VoiceIntent intent) {
    _lastExecutedIntent = intent;
    _lastExecutionTimestamp = DateTime.now().millisecondsSinceEpoch;
  }

  static void resetDebounce() {
    _lastExecutedIntent = null;
    _lastExecutionTimestamp = 0;
  }

  /// High-accuracy matching engine with zero latency, sentence scanning,
  /// multi-language support (English, Kannada, Hindi), and compound phrase resolution.
  static VoiceIntent? matchIntent(String transcript) {
    final clean = normalize(transcript);
    if (clean.isEmpty) return null;

    // 1. Direct O(1) hash map lookup for exact phrase matches (<50 microseconds)
    final exact = _exactLookup[clean];
    if (exact != null) {
      return exact;
    }

    // 2. Scan all regex matches across the string to support natural sentences,
    // single words, and compound commands (e.g. "open home open the scan" -> scan).
    final List<_IntentCandidate> candidates = [];

    void check(VoiceIntent intent, RegExp regex) {
      for (final match in regex.allMatches(clean)) {
        candidates.add(_IntentCandidate(intent, match.start, match.end - match.start));
      }
    }

    check(VoiceIntent.langKn, _langKnRegex);
    check(VoiceIntent.langHi, _langHiRegex);
    check(VoiceIntent.langEn, _langEnRegex);
    check(VoiceIntent.sendMail, _sendMailRegex);
    check(VoiceIntent.emergency, _emergencyRegex);
    check(VoiceIntent.callAmbulance, _ambulanceRegex);
    check(VoiceIntent.callCaregiver, _caregiverRegex);
    check(VoiceIntent.stop, _stopRegex);
    check(VoiceIntent.takePhoto, _takePhotoRegex);
    check(VoiceIntent.uploadPhoto, _uploadPhotoRegex);
    check(VoiceIntent.markTaken, _markTakenRegex);
    check(VoiceIntent.skipDose, _skipDoseRegex);
    check(VoiceIntent.back, _backRegex);
    check(VoiceIntent.readPage, _readPageRegex);
    check(VoiceIntent.repeat, _repeatRegex);
    check(VoiceIntent.save, _saveRegex);
    check(VoiceIntent.nextMedicine, _nextMedicineRegex);
    check(VoiceIntent.demoLogin, _demoRegex);
    check(VoiceIntent.testAlarm, _testAlarmRegex);
    check(VoiceIntent.setAlarm, _setAlarmRegex);
    check(VoiceIntent.signOut, _signOutRegex);
    check(VoiceIntent.refresh, _refreshRegex);
    check(VoiceIntent.whereAmI, _whereAmIRegex);
    check(VoiceIntent.help, _helpRegex);
    check(VoiceIntent.prescriptionMode, _prescriptionModeRegex);
    check(VoiceIntent.medicineMode, _medicineModeRegex);
    check(VoiceIntent.yes, _yesRegex);
    check(VoiceIntent.no, _noRegex);
    check(VoiceIntent.cancel, _cancelRegex);
    check(VoiceIntent.snooze, _snoozeRegex);
    check(VoiceIntent.noiseCancelOn, _noiseCancelOnRegex);
    check(VoiceIntent.noiseCancelOff, _noiseCancelOffRegex);
    check(VoiceIntent.continuousVoiceOn, _continuousVoiceOnRegex);
    check(VoiceIntent.continuousVoiceOff, _continuousVoiceOffRegex);

    // Primary navigation intents
    check(VoiceIntent.home, _homeRegex);
    check(VoiceIntent.scan, _scanRegex);
    check(VoiceIntent.schedule, _scheduleRegex);
    check(VoiceIntent.assistant, _assistantRegex);
    check(VoiceIntent.more, _settingsRegex);

    if (candidates.isNotEmpty) {
      // 1. Discard sub-matches that are completely enclosed within a longer match span
      // (e.g. prevent internal keywords like 'pill' from overriding 'i took my pill')
      candidates.removeWhere((c) {
        return candidates.any((other) =>
            other != c &&
            other.length > c.length &&
            c.startIndex >= other.startIndex &&
            (c.startIndex + c.length) <= (other.startIndex + other.length));
      });

      // 2. Sort primarily by highest startIndex (the latest independent command takes precedence)
      // Ties broken by match length (more specific pattern wins)
      candidates.sort((a, b) {
        final cmp = b.startIndex.compareTo(a.startIndex);
        if (cmp != 0) return cmp;
        return b.length.compareTo(a.length);
      });
      return candidates.first.intent;
    }

    // 3. Fallback: Pre-sorted phrase matching with word-boundary protection
    for (final entry in _sortedPhrases) {
      final phrase = entry.key;
      if (phrase.contains(' ') || phrase.length > 5) {
        if (RegExp(r'(?:^|\s)' + RegExp.escape(phrase) + r'(?:$|\s)').hasMatch(clean)) {
          return entry.value;
        }
      } else {
        if (clean == phrase ||
            clean == "open $phrase" ||
            clean == "go to $phrase" ||
            clean == "show $phrase") {
          return entry.value;
        }
      }
    }

    return null;
  }

  /// Measures exact match execution time in microseconds for diagnostic benchmarking
  static MatchResult matchIntentWithMetrics(String transcript) {
    final sw = Stopwatch()..start();
    final intent = matchIntent(transcript);
    sw.stop();
    return MatchResult(
      intent: intent,
      executionMicroseconds: sw.elapsedMicroseconds,
      transcript: transcript,
    );
  }
}

class MatchResult {
  final VoiceIntent? intent;
  final int executionMicroseconds;
  final String transcript;

  MatchResult({
    required this.intent,
    required this.executionMicroseconds,
    required this.transcript,
  });
}
