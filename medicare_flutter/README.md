# 💊 SmartMediCare Flutter Mobile Application

SmartMediCare is a voice-first, accessible Flutter app for medication management tailored for visually impaired and elderly users.

For full project overview, features, and system architecture, please see the [Main Project README](../README.md).

---

## 🚀 Quick Start

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Verify Connected Devices
```bash
flutter devices
```

### 3. Run Debug Build
```bash
flutter run
```

### 4. Build Release APK (for installing on any Android device)
```bash
flutter build apk --release
```
The output file will be at:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 🔑 Key Integrations

- **Firebase Auth & RTDB**: Offline-first database with account isolation (`medicare_cache_<uid>.json`).
- **Google ML Kit**: Offline text recognition on medicine packaging.
- **Flutter TTS & Speech-to-Text**: Trilingual voice interface (English, Kannada, Hindi).
- **EmailJS**: Real-time email dispatch for SOS emergencies (`template_aa0wwyi`) and missed/skipped dose alerts (`template_err1y5l`).
- **Background Alarms**: Native alarm scheduling via `android_alarm_manager_plus`.
