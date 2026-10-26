import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:medicare_flutter/services/speech_service.dart';
import 'package:medicare_flutter/services/voice_controller.dart';
import 'package:medicare_flutter/services/voice_intent_service.dart';
import 'package:medicare_flutter/widgets/accessible_voice_overlay.dart';

class FakeVoiceController extends ChangeNotifier implements VoiceController {
  bool listenCalled = false;

  @override
  bool get isProcessing => false;

  @override
  bool get isContinuousMode => false;

  @override
  AppScreen get currentScreen => AppScreen.home;

  @override
  VoiceScreenDelegate? get activeDelegate => null;

  @override
  String get lastHeard => "";

  @override
  String get statusMessage => "";

  @override
  void announceScreen() {}

  @override
  void clearActiveDelegate(VoiceScreenDelegate delegate) {}

  @override
  Future<void> executeIntent(VoiceIntent? intent, String transcript) async {}

  @override
  Future<void> listenAndExecute() async {
    listenCalled = true;
  }

  @override
  Future<void> toggleContinuousListening() async {
    listenCalled = true;
  }

  @override
  Future<void> startContinuousListening({String? customAnnouncement}) async {
    listenCalled = true;
  }

  @override
  Future<void> stopContinuousListening() async {}

  @override
  void setActiveDelegate(VoiceScreenDelegate delegate, AppScreen screen) {}

  @override
  void setCurrentScreen(AppScreen screen) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('AccessibleVoiceOverlay renders content, has no floating mic button, and triggers on double-tap', (WidgetTester tester) async {
    final speechService = SpeechService();
    final fakeVoiceController = FakeVoiceController();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SpeechService>.value(value: speechService),
          ChangeNotifierProvider<VoiceController>.value(value: fakeVoiceController),
        ],
        child: const MaterialApp(
          home: AccessibleVoiceOverlay(
            child: Scaffold(
              body: Center(child: Text("MediCare Content")),
            ),
          ),
        ),
      ),
    );

    // Verify main content is rendered
    expect(find.text("MediCare Content"), findsOneWidget);

    // Verify floating voice mic button is removed
    expect(find.byIcon(Icons.mic_rounded), findsNothing);

    // Verify double-tap anywhere triggers toggleContinuousListening
    await tester.tap(find.text("MediCare Content"));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text("MediCare Content"));
    await tester.pump(const Duration(milliseconds: 300));

    expect(fakeVoiceController.listenCalled, isTrue);
  });
}
