# 💊 SmartMediCare

**SmartMediCare** is an AI-powered, voice-first Flutter mobile application designed specifically to assist **visually impaired and elderly users in managing their medications safely and independently**. 

Every screen can be operated entirely through speech in **English**, **ಕನ್ನಡ (Kannada)**, or **हिंदी (Hindi)**, with automated background reminders, optical character recognition (OCR) for prescription labels, real-time caregiver email notifications for missed doses, and an emergency SOS system.

---

## 🌟 Key Features

### 🎙️ 1. Voice-First Accessibility
- **Full Screen-by-Screen Spoken Guidance**: Every screen announces its title, contents, and available commands using Text-to-Speech (`flutter_tts`).
- **Hands-Free Speech Recognition (`speech_to_text`)**: Users can navigate anywhere by speaking:
  - *"Home"*, *"Scan"*, *"Schedule"*, *"Caregivers"*, *"Emergency"*, *"Settings"*.
- **Helper Voice Commands**:
  - *"Where am I"* — reads current screen location.
  - *"Repeat"* / *"Read page"* — re-reads all screen details aloud.
  - *"What are my medicines"* — recites current active medications.
  - *"Go back"* — navigates to the previous screen.
- **Interactive Spoken Alarm Setup**: A conversational voice wizard asks step-by-step for the medicine name, dosage, frequency, and time, scheduling reminders with zero manual typing.

### 📷 2. Medicine Label & Prescription Scanning (OCR)
- **Camera & Gallery Image Processing**: Point the camera at a medicine bottle, blister pack, or prescription sheet.
- **On-Device OCR (`google_mlkit_text_recognition`)**: Extracts text instantly offline without sending sensitive images to external servers.
- **Intelligent Information Extraction**:
  - Automatically identifies medicine names, dosage/strength (e.g., *650 mg*, *500 mg*, *5 ml*), frequency, and instructions.
  - Speaks back extracted details in the user's chosen language.
  - One-tap addition directly to user's daily medication schedule.

### ⏰ 3. Background Alarms & Dose Tracking
- **Persistent Background Alarms**: Powered by `android_alarm_manager_plus` and `flutter_local_notifications`. Alarms trigger reliably even when the app is minimized.
- **Spoken Medication Announcements**: Rings with chime and announces: *"It is time to take your [Medicine Name], [Dosage]"*.
- **Hands-Free Actioning**: Respond directly with *"Taken"* or *"Snooze"*.
- **Daily Adherence Tracking**: Visual and audio indicators for scheduled, taken, skipped, and missed doses.

### 👥 4. Caregiver Network & Missed Dose Alerts
- **Dedicated Caregiver Management**: Add and manage caregivers and family members with their names, phone numbers, and Gmail addresses.
- **Automated Missed / Skipped Dose Email Notifications**:
  - When a patient marks a dose as **Skipped** or **Misses** a scheduled dose, the system automatically sends an email alert via EmailJS REST API (`template_err1y5l`).
  - **Dynamic Recipient Routing**: Emails are dynamically sent directly to the email addresses registered in the patient's Caregivers list (ensuring alerts reach the correct caregiver).
  - Contains patient name, medicine name, scheduled dose time, and status.

### 🚨 5. Emergency SOS with Live GPS & EmailJS
- **One-Tap or Voice-Activated SOS**: Say *"Emergency"* or tap the high-contrast emergency button.

- **Real-Time GPS Location (`geolocator`)**: Fetches patient's live coordinates and builds a direct Google Maps link.
- **Automated SOS Email via EmailJS (`template_aa0wwyi`)**:
  - Directly dispatched to the designated emergency contact and caregiver emails.
  - **Includes**:
    - Patient name and emergency distress message.
    - Live Google Maps location link.
    - Active medication list.
    - Emergency contact phone number.
    - Exact event timestamp.
- **Direct Phone Dialing (`url_launcher`)**: Instantly dials the emergency contact or emergency hotline (112).

### 🔐 6. Multi-Account Isolation & Firebase Authentication
- **Secure Email & Password Authentication**: Register and log in using your own email address.
- **100% User Data Isolation**:
  - Each account has its own user-scoped cache (`medicare_cache_<uid>.json`).
  - Signing in with a different Gmail account clears previous in-memory state and loads only that account's medicines, schedules, and caregivers.
  - Eliminates cross-account data leakage.
- **Cloud Backup**: Integrates with Firebase Realtime Database for automatic data synchronization and offline resilience.

### 🌐 7. Trilingual Support
- Seamless switching between:
  - 🇬🇧 **English** (`en-US`)
  - 🇮🇳 **ಕನ್ನಡ (Kannada)** (`kn-IN`)
  - 🇮🇳 **हिंदी (Hindi)** (`hi-IN`)
- Complete UI translation, TTS voice prompts, and voice recognition across all three languages.

---

## 🛠️ Technology Stack

| Layer | Technologies |
|---|---|
| **Framework** | Flutter (Dart SDK `>=3.0.0 <4.0.0`) |
| **Authentication & Cloud** | Firebase Auth, Firebase Realtime Database, Cloud Firestore |
| **Voice & Speech** | `flutter_tts` (Text-to-Speech), `speech_to_text` (Speech-to-Text) |
| **Vision & OCR** | `google_mlkit_text_recognition`, `camera`, `image_picker` |
| **Background Scheduling** | `android_alarm_manager_plus`, `flutter_local_notifications` |
| **Location & Maps** | `geolocator` |
| **Email Service** | EmailJS REST API (Templates `template_aa0wwyi` and `template_err1y5l`) |
| **System Integrations** | `url_launcher` (Phone dialer & maps) |
| **State Management** | Provider (`provider: ^6.1.2`) |

---

## 📂 Project Structure

```
MediCare/
├── README.md                          # Root Project Documentation
└── medicare_flutter/                  # Main Flutter Application
    ├── pubspec.yaml                   # Dependencies & configurations
    ├── android/                       # Native Android configuration
    │   └── app/
    │       ├── google-services.json   # Firebase Android configuration
    │       └── src/main/AndroidManifest.xml
    └── lib/
        ├── firebase_options.dart      # Firebase initialization options
        ├── main.dart                  # App entrypoint & Provider configuration
        ├── models/                    # Data models
        ├── screens/
        │   ├── assistant_screen.dart  # AI & Voice health assistant
        │   ├── auth_screen.dart       # Account sign in / sign up
        │   ├── camera_screen.dart     # Medicine camera scanner
        │   ├── caregiver_screen.dart  # Caregiver contact management
        │   ├── emergency_screen.dart  # SOS trigger, GPS & emergency email
        │   ├── home_screen.dart       # Main dashboard with voice navigation
        │   ├── scan_screen.dart       # Scan results & medicine details
        │   ├── schedule_screen.dart   # Medicine reminder timetable
        │   └── settings_screen.dart   # Language, account & audio preferences
        └── services/
            ├── ai_service.dart             # Rule-based & AI medication safety analyzer
            ├── alarm_service.dart          # Audio chime & alert player
            ├── alarm_setup_service.dart    # Conversational voice alarm setup
            ├── background_alarm_manager.dart# Background alarm scheduler
            ├── database_service.dart       # Offline-first cache & cloud sync with user isolation
            ├── dose_utils.dart             # Dose adherence & calculation utilities
            ├── emailjs_service.dart        # EmailJS integration (SOS & Missed Doses)
            ├── i18n_service.dart           # Trilingual translations (EN, KN, HI)
            ├── location_service.dart       # GPS geolocator & Maps URL builder
            ├── ocr_service.dart            # ML Kit OCR & prescription text parser
            ├── speech_service.dart         # Flutter TTS engine wrapper
            ├── voice_ai_service.dart       # Conversational voice AI processing
            ├── voice_intent_service.dart   # Voice command classifier
            └── voice_service.dart          # Speech-to-text listener
```

---

## 📧 EmailJS Configuration

SmartMediCare uses EmailJS to send automated emails directly from the mobile app without requiring a dedicated backend server:

- **Service ID**: `service_l5bgxos`
- **Public Key**: `LvbbrVLjBxjp47Oiu`
- **Templates**:
  1. **Emergency SOS (`template_aa0wwyi`)**:
     - **Fields**: `to_email`, `patient_name`, `emergency_message`, `location_url`, `medicine_list`, `timestamp`.
     - Triggered automatically when pressing SOS or saying *"Emergency"*.
  2. **Missed / Skipped Dose Alert (`template_err1y5l`)**:
     - **Fields**: `to_email`, `patient_name`, `medicine_name`, `scheduled_time`, `status`, `dosage`, `timestamp`.
     - Sent dynamically to the Gmail address added in the **Caregivers** section.

---

## 📱 How to Run the App

### Prerequisites
1. [Flutter SDK](https://docs.flutter.dev/get-started/install) installed (v3.22+ recommended).
2. Android Studio / Android SDK with USB debugging enabled on your physical device.

### Running on a Connected Android Phone
1. Connect your Android phone to your PC via USB cable.
2. Enable **Developer Options** and **USB Debugging** on your phone.
3. Verify connection:
   ```bash
   flutter devices
   ```
4. Navigate to the app directory and install dependencies:
   ```bash
   cd medicare_flutter
   flutter pub get
   ```
5. Launch the application:
   ```bash
   flutter run
   ```

### Running on a Different Android Phone
To install and run SmartMediCare on another phone:
1. Connect the new phone via USB with USB Debugging enabled.
2. Run `flutter devices` to find the device ID (e.g., `<DEVICE_ID>`).
3. Run:
   ```bash
   flutter run -d <DEVICE_ID>
   ```
4. Or build a standalone release APK:
   ```bash
   flutter build apk --release
   ```
   The APK will be generated at `medicare_flutter/build/app/outputs/flutter-apk/app-release.apk`. Transfer and install it directly on any Android phone.

---

## 🎯 Target Impact

SmartMediCare bridges the accessibility gap in modern digital healthcare by eliminating physical touch barriers, ensuring visually impaired and elderly patients take the right medicines at the right time, while giving caregivers peace of mind through automated real-time alerts.
