import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/speech_service.dart';
import '../services/voice_controller.dart';

class AccessibleVoiceOverlay extends StatefulWidget {
  final Widget child;
  const AccessibleVoiceOverlay({super.key, required this.child});

  @override
  State<AccessibleVoiceOverlay> createState() => _AccessibleVoiceOverlayState();
}

class _AccessibleVoiceOverlayState extends State<AccessibleVoiceOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final speech = Provider.of<SpeechService>(context);
    final voice = Provider.of<VoiceController>(context);

    final isVoiceActive = voice.isContinuousMode || speech.isListening || voice.isProcessing;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // 1. Gesture detector for double-tap anywhere on screen to toggle persistent voice listening
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onDoubleTap: () {
              voice.toggleContinuousListening();
            },
            child: widget.child,
          ),

          // 2. Persistent Live Voice HUD banner (displays while continuous voice is active)
          if (isVoiceActive)
            Positioned(
              top: 50,
              left: 20,
              right: 20,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: 1.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: speech.isListening
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF38BDF8),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (speech.isListening
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF38BDF8))
                            .withValues(alpha: 0.35),
                        blurRadius: 25,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: speech.isListening
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF0284C7),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            speech.isListening
                                ? Icons.graphic_eq_rounded
                                : Icons.mic_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              voice.isProcessing
                                  ? (speech.currentLanguage.startsWith('kn')
                                      ? "ಆಜ್ಞೆಯನ್ನು ಪ್ರಕ್ರಿಯೆಗೊಳಿಸಲಾಗುತ್ತಿದೆ..."
                                      : speech.currentLanguage.startsWith('hi')
                                          ? "आदेश पर काम हो रहा है..."
                                          : "Processing command...")
                                  : speech.isListening
                                      ? (speech.currentLanguage.startsWith('kn')
                                          ? "ಕೇಳಿಸಿಕೊಳ್ಳುತ್ತಿದ್ದೇನೆ... ಮಾತನಾಡಿ"
                                          : speech.currentLanguage.startsWith('hi')
                                              ? "सुन रहा हूँ... बोलिए"
                                              : "Listening continuously... Speak now")
                                      : (speech.currentLanguage.startsWith('kn')
                                          ? "ಧ್ವನಿ ಮೋಡ್ ಸಕ್ರಿಯ • ನಿಲ್ಲಿಸಲು ಡಬಲ್ ಟ್ಯಾಪ್ ಮಾಡಿ"
                                          : speech.currentLanguage.startsWith('hi')
                                              ? "लगातार वॉइस चालू • बंद करने के लिए दो बार टैप करें"
                                              : "Voice Mode Active • Double-tap to stop"),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            if (speech.lastRecognizedText.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                "\"${speech.lastRecognizedText}\"",
                                style: const TextStyle(
                                  color: Color(0xFF38BDF8),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ] else if (voice.isContinuousMode) ...[
                              const SizedBox(height: 3),
                              Text(
                                speech.currentLanguage.startsWith('kn')
                                    ? "ಯಾವುದೇ ಆಜ್ಞೆಯನ್ನು ಹೇಳಿ (ಮುಖ್ಯಪುಟ, ಸ್ಕ್ಯಾನ್, ತೆಗೆದುಕೊಂಡೆ)"
                                    : speech.currentLanguage.startsWith('hi')
                                        ? "कोई भी आदेश बोलें (होम, स्कैन, दवा ले ली)"
                                        : "Speak any command (Home, Scan, Mark Taken...)",
                                style: TextStyle(
                                  color: Colors.cyanAccent.shade200,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => voice.stopContinuousListening(),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white70,
                            size: 26,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
