import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/speech_service.dart';
import '../services/voice_controller.dart';
import '../services/voice_intent_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> implements VoiceScreenDelegate {
  VoiceController? _voiceController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      _voiceController = Provider.of<VoiceController>(context, listen: false);
    } catch (_) {}
  }

  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _isProcessing = false;
  bool _isTorchOn = false;
  Offset? _focusPoint;

  @override
  void initState() {
    super.initState();
    _initCamera();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        final voice = Provider.of<VoiceController>(context, listen: false);
        voice.setActiveDelegate(this, AppScreen.camera);
        // Ensure continuous voice listening is active on camera screen so the user can immediately say "capture"
        if (!voice.isContinuousMode) {
          await voice.startContinuousListening(customAnnouncement: getScreenAnnouncement());
        } else {
          try {
            HapticFeedback.mediumImpact();
          } catch (_) {}
        }
      }
    });
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint("No cameras available on this device");
        return;
      }

      // Use veryHigh (1080p) so small text on medicine strips is captured with razor-sharp clarity
      _controller = CameraController(
        cameras.first,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _initializeControllerFuture = _controller!.initialize().then((_) async {
        try {
          await _controller!.setFocusMode(FocusMode.auto);
        } catch (e) {
          debugPrint("Camera setFocusMode note: $e");
        }
        try {
          await _controller!.setExposureMode(ExposureMode.auto);
        } catch (_) {}
        try {
          await _controller!.setFlashMode(FlashMode.off);
        } catch (_) {}
        if (mounted) setState(() {});
      });
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint("Camera init error: $e");
    }
  }

  Future<void> _toggleTorch() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final nextMode = _isTorchOn ? FlashMode.off : FlashMode.torch;
      await _controller!.setFlashMode(nextMode);
      setState(() => _isTorchOn = !_isTorchOn);
      HapticFeedback.lightImpact();
      if (!mounted) return;
      final speech = Provider.of<SpeechService>(context, listen: false);
      final lang = speech.currentLanguage;
      if (_isTorchOn) {
        speech.speak(lang.startsWith('kn') ? "ಟಾರ್ಚ್ ಆನ್ ಮಾಡಲಾಗಿದೆ." : lang.startsWith('hi') ? "टॉर्च चालू किया गया।" : "Torch on.");
      } else {
        speech.speak(lang.startsWith('kn') ? "ಟಾರ್ಚ್ ಆಫ್ ಮಾಡಲಾಗಿದೆ." : lang.startsWith('hi') ? "टॉर्च बंद किया गया।" : "Torch off.");
      }
    } catch (e) {
      debugPrint("Torch toggle error: $e");
    }
  }

  @override
  void dispose() {
    _voiceController?.clearActiveDelegate(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  String getScreenAnnouncement() {
    if (!mounted) return "";
    final speech = Provider.of<SpeechService>(context, listen: false);
    final lang = speech.currentLanguage;
    if (lang.startsWith('kn')) {
      return "ಕ್ಯಾಮೆರಾ ಸಿದ್ಧ. ಕ್ಲಿಕ್ ಅಥವಾ ಫೋಟೋ ಎನ್ನಿ. ಬೆಳಕಿಗೆ ಟಾರ್ಚ್ ಎನ್ನಿ.";
    } else if (lang.startsWith('hi')) {
      return "कैमरा तैयार. क्लिक या फोटो कहें. रोशनी के लिए टॉर्च कहें.";
    }
    return "Camera ready. Say click or capture. Say torch for light.";
  }

  @override
  Future<bool> handleVoiceCommand(VoiceIntent? intent, String transcript) async {
    if (!mounted) return false;
    final lower = transcript.toLowerCase().trim();
    debugPrint("CameraScreen handleVoiceCommand: '$transcript' (intent: $intent)");

    if (intent == VoiceIntent.back ||
        intent == VoiceIntent.cancel ||
        lower.contains("back") ||
        lower.contains("cancel") ||
        lower.contains("exit") ||
        transcript.contains("ಹಿಂದಕ್ಕೆ") ||
        transcript.contains("ವಾಪಸ್")) {
      if (mounted) Navigator.pop(context);
      return true;
    }

    // Toggle Torch on voice command
    if (lower.contains("torch") ||
        lower.contains("light") ||
        lower.contains("flash") ||
        transcript.contains("ಟಾರ್ಚ್") ||
        transcript.contains("ಬೆಳಕು") ||
        transcript.contains("ಫ್ಲ್ಯಾಶ್") ||
        transcript.contains("टॉर्च") ||
        transcript.contains("लाइट")) {
      await _toggleTorch();
      return true;
    }

    // Photo capture commands specifically - triggers shutter immediately!
    if (intent == VoiceIntent.takePhoto ||
        lower.contains("capture") ||
        lower.contains("click") ||
        lower.contains("snap") ||
        lower.contains("shoot") ||
        lower.contains("photo") ||
        lower.contains("picture") ||
        lower.contains("take") ||
        lower.contains("camera") ||
        lower.contains("now") ||
        transcript.contains("ಕ್ಲಿಕ್") ||
        transcript.contains("ಫೋಟೋ") ||
        transcript.contains("ಕ್ಯಾಪ್ಚರ್") ||
        transcript.contains("ಚಿತ್ರ") ||
        transcript.contains("ಕ್ಯಾಮರಾ") ||
        transcript.contains("फोटो") ||
        transcript.contains("क्लिक") ||
        transcript.contains("खींचो") ||
        transcript.contains("तस्वीर") ||
        transcript.contains("कैमरा")) {
      await _captureAndScan();
      return true;
    }

    // Any other command is NOT handled by CameraScreen, allowing VoiceController to execute global navigation/actions!
    return false;
  }

  Future<void> _captureAndScan() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    debugPrint("CameraScreen: executing _captureAndScan now!");

    final speech = Provider.of<SpeechService>(context, listen: false);

    try {
      if (_initializeControllerFuture != null) {
        await _initializeControllerFuture;
      }
      if (_controller == null || !_controller!.value.isInitialized) {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 2400,
          maxHeight: 2400,
          imageQuality: 95,
        );
        if (picked != null && mounted) {
          Navigator.pop(context, picked.path);
          return;
        }
        speech.speak("Camera is not ready. Please try again.");
        setState(() => _isProcessing = false);
        return;
      }

      final image = await _controller!.takePicture();

      try {
        HapticFeedback.heavyImpact();
      } catch (_) {}

      final lang = speech.currentLanguage;
      final capturedMsg = lang.startsWith('kn')
          ? "ಫೋಟೋ ತೆಗೆಯಲಾಗಿದೆ. ಔಷಧಿಯನ್ನು ಓದಲಾಗುತ್ತಿದೆ."
          : lang.startsWith('hi')
              ? "फोटो खींच ली गई। दवा पढ़ी जा रही है।"
              : "Photo captured. Reading medicine.";
      speech.speak(capturedMsg);

      if (mounted) {
        Navigator.pop(context, image.path);
      }
    } catch (e) {
      debugPrint("Camera capture error: $e");
      try {
        final picker = ImagePicker();
        final picked = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 2400,
          maxHeight: 2400,
          imageQuality: 95,
        );
        if (picked != null && mounted) {
          Navigator.pop(context, picked.path);
          return;
        }
      } catch (_) {}
      speech.speak("Could not capture photo. Please try again.");
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _onTapToFocus(TapDownDetails details) async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final size = MediaQuery.of(context).size;
      final x = (details.globalPosition.dx / size.width).clamp(0.0, 1.0);
      final y = (details.globalPosition.dy / size.height).clamp(0.0, 1.0);
      await _controller!.setFocusPoint(Offset(x, y));
      await _controller!.setExposurePoint(Offset(x, y));
      setState(() {
        _focusPoint = details.globalPosition;
      });
      HapticFeedback.selectionClick();
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) setState(() => _focusPoint = null);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Scan Medicine Label", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF0F172A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isTorchOn ? const Color(0xFFFACC15) : Colors.white70,
              size: 26,
            ),
            tooltip: _isTorchOn ? "Turn Torch Off" : "Turn Torch On for Clear OCR",
            onPressed: _toggleTorch,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done &&
              _controller != null &&
              _controller!.value.isInitialized) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: _captureAndScan,
              onTapDown: _onTapToFocus,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(_controller!),
                  // Tap to focus reticle indicator
                  if (_focusPoint != null)
                    Positioned(
                      left: _focusPoint!.dx - 32,
                      top: _focusPoint!.dy - kToolbarHeight - 32,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFF38BDF8), width: 2.5),
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                    ),
                  // High contrast guide box for packaging alignment
                  Center(
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF38BDF8), width: 3.5),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                            blurRadius: 18,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 20,
                    left: 20,
                    right: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Hold medicine packaging inside blue box",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            "Say \"CAPTURE\" or tap button below. Tap screen to focus.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF38BDF8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_isProcessing)
                    Container(
                      color: Colors.black.withValues(alpha: 0.85),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF38BDF8), strokeWidth: 5),
                            SizedBox(height: 24),
                            Text(
                              "READING MEDICINE...",
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          } else {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)));
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        elevation: 6,
        onPressed: _captureAndScan,
        icon: const Icon(Icons.camera_alt_rounded, size: 28),
        label: const Text("Capture Photo", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
