import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/speech_service.dart';
import '../services/database_service.dart';
import '../services/voice_controller.dart';
import '../services/voice_intent_service.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> implements VoiceScreenDelegate {
  VoiceController? _voiceController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    try {
      _voiceController = Provider.of<VoiceController>(context, listen: false);
    } catch (_) {}
  }

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _suggestedAction;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final voice = Provider.of<VoiceController>(context, listen: false);
        voice.setActiveDelegate(this, AppScreen.auth);
        voice.announceScreen();
      }
    });
  }

  @override
  void dispose() {
    try {
      _voiceController?.clearActiveDelegate(this);
    } catch (_) {}
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  @override
  String getScreenAnnouncement() {
    if (!mounted) return "";
    final speech = Provider.of<SpeechService>(context, listen: false);
    final lang = speech.currentLanguage;
    if (lang.startsWith('kn')) {
      return "ಸ್ಮಾರ್ಟ್ ಮೆಡಿಕೇರ್‌ಗೆ ಸ್ವಾಗತ. ತಕ್ಷಣ ಪ್ರವೇಶಿಸಲು 'ಡೆಮೊ' ಅಥವಾ 'ಆಫ್‌ಲೈನ್' ಎಂದು ಹೇಳಿ.";
    } else if (lang.startsWith('hi')) {
      return "स्मार्ट मेडिकेयर में आपका स्वागत है। तुरंत प्रवेश के लिए 'डेमो' या 'ऑफ़लाइन' कहें।";
    }
    return "Welcome to Smart MediCare. Say 'demo' or 'continue offline' to start immediately.";
  }

  @override
  Future<bool> handleVoiceCommand(VoiceIntent? intent, String transcript) async {
    if (!mounted) return false;
    if (intent == VoiceIntent.demoLogin || intent == VoiceIntent.yes) {
      await _quickVoiceDemoLogin();
      return true;
    }
    return false;
  }

  Future<void> _quickVoiceDemoLogin() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final speech = Provider.of<SpeechService>(context, listen: false);
    const demoEmail = "demo_patient@medicare.com";
    const offlineId = "usr_demo_patient";
    await db.switchUser(offlineId);
    await db.saveProfile({
      'full_name': 'Patient',
      'email': demoEmail,
    });
    speech.speak("Welcome to MediCare! Opening your dashboard now.");
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  String _friendlyFirebaseError(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
        _suggestedAction = "switch_to_signup";
        return "No account exists for this Gmail. Tap 'Create Account' below to register!";
      case 'wrong-password':
        return "Incorrect password. Please re-check your password.";
      case 'invalid-credential':
        _suggestedAction = _isSignUp ? null : "switch_to_signup";
        return _isSignUp
            ? "Invalid credentials. Please verify your email and password."
            : "No account found for this Gmail or incorrect password. Tap 'Create Account' below if you're new!";
      case 'email-already-in-use':
        _suggestedAction = "switch_to_signin";
        return "This Gmail is already registered! Tap 'Sign In' below to log into your account.";
      case 'invalid-email':
        return "Please enter a valid Gmail address (e.g., name@gmail.com).";
      case 'weak-password':
        return "Password must be at least 6 characters long.";
      case 'operation-not-allowed':
        return "Email/Password sign-in is disabled in your Firebase console.";
      case 'network-request-failed':
        return "Network connection error. You can continue offline below!";
      default:
        return error.message ?? "Authentication failed (${error.code}).";
    }
  }

  Future<void> _continueOffline() async {
    final email = _emailController.text.trim().toLowerCase();
    final fullName = _fullNameController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _errorMessage = "Please enter your Gmail address above to open your account.";
      });
      return;
    }
    final db = Provider.of<DatabaseService>(context, listen: false);
    final speech = Provider.of<SpeechService>(context, listen: false);
    final offlineId = "usr_${email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}";
    await db.switchUser(offlineId);
    await db.saveProfile({
      'full_name': fullName.isNotEmpty ? fullName : email.split('@').first,
      'email': email,
    });
    speech.speak("Opening MediCare in offline mode for $email.");
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = "Please enter both email and password.";
        _suggestedAction = null;
      });
      return;
    }

    final speech = Provider.of<SpeechService>(context, listen: false);
    final db = Provider.of<DatabaseService>(context, listen: false);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _suggestedAction = null;
    });
    speech.speak("Signing in.");

    try {
      final credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: email,
            password: password,
          )
          .timeout(const Duration(seconds: 6));

      await db.switchUser(credential.user?.uid);
      speech.speak("Signed in successfully. Welcome back.");
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (error) {
      debugPrint("Firebase Auth sign-in error: ${error.code} - ${error.message}");
      if (error.code == 'user-not-found' && password.length >= 6) {
        debugPrint("User not found on sign-in, auto-creating account...");
        try {
          final credential = await FirebaseAuth.instance
              .createUserWithEmailAndPassword(email: email, password: password)
              .timeout(const Duration(seconds: 6));
          await db.switchUser(credential.user?.uid);
          await db.saveProfile({
            'full_name': email.split('@').first,
            'email': email,
          });
          speech.speak("Account created and signed in successfully.");
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
          return;
        } catch (_) {}
      } else if (error.code == 'network-request-failed') {
        await _continueOffline();
        return;
      }

      if (mounted) {
        final msg = _friendlyFirebaseError(error);
        setState(() => _errorMessage = msg);
        speech.speak(msg);
      }
    } on TimeoutException {
      debugPrint("Sign-in timed out, seamlessly proceeding offline...");
      await _continueOffline();
      return;
    } catch (e) {
      debugPrint("Sign-in general error: $e");
      if (mounted) {
        setState(() => _errorMessage = e.toString());
        speech.speak("Sign in error occurred.");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text.trim();
    final fullName = _fullNameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = "Please enter both email and password.";
        _suggestedAction = null;
      });
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() {
        _errorMessage = "Please enter a valid email address (e.g., user@gmail.com).";
        _suggestedAction = null;
      });
      return;
    }
    if (password.length < 6) {
      setState(() {
        _errorMessage = "Password must be at least 6 characters long.";
        _suggestedAction = null;
      });
      return;
    }

    final speech = Provider.of<SpeechService>(context, listen: false);
    final db = Provider.of<DatabaseService>(context, listen: false);

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _suggestedAction = null;
    });
    speech.speak("Creating new account.");

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email,
            password: password,
          )
          .timeout(const Duration(seconds: 6));

      if (fullName.isNotEmpty) {
        await credential.user?.updateDisplayName(fullName);
      }
      await db.switchUser(credential.user?.uid);
      await db.saveProfile({
        'full_name': fullName.isNotEmpty ? fullName : email.split('@').first,
        'email': email,
      });
      speech.speak("Account created successfully. Welcome to Smart Medi Care.");
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (error) {
      debugPrint("Firebase Auth sign-up error: ${error.code} - ${error.message}");
      if (error.code == 'email-already-in-use') {
        debugPrint("Email already registered, auto-attempting sign in...");
        try {
          final credential = await FirebaseAuth.instance
              .signInWithEmailAndPassword(email: email, password: password)
              .timeout(const Duration(seconds: 6));
          await db.switchUser(credential.user?.uid);
          speech.speak("Signed in successfully. Welcome back.");
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
          return;
        } catch (signInErr) {
          debugPrint("Auto sign-in note: $signInErr");
        }
      } else if (error.code == 'network-request-failed') {
        await _continueOffline();
        return;
      }

      if (mounted) {
        final msg = _friendlyFirebaseError(error);
        setState(() => _errorMessage = msg);
        speech.speak(msg);
      }
    } on TimeoutException {
      debugPrint("Sign-up timed out, seamlessly proceeding offline...");
      await _continueOffline();
      return;
    } catch (e) {
      debugPrint("Sign-up general error: $e");
      if (mounted) {
        setState(() => _errorMessage = e.toString());
        speech.speak("Account creation failed.");
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1D),
      appBar: AppBar(
        title: const Text(
          "SmartMediCare",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Medical App Branding Badge
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0284C7), Color(0xFF0D9488)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.favorite_rounded, size: 48, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "SmartMediCare",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  "Your multilingual health & medicine manager.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 28),

                // Sign In / Sign Up Mode Switcher
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _isSignUp = false;
                            _errorMessage = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_isSignUp ? const Color(0xFF0284C7) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "Sign In",
                              style: TextStyle(
                                color: !_isSignUp ? Colors.white : const Color(0xFF94A3B8),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _isSignUp = true;
                            _errorMessage = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isSignUp ? const Color(0xFF0284C7) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              "Create Account",
                              style: TextStyle(
                                color: _isSignUp ? Colors.white : const Color(0xFF94A3B8),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Full Name for Sign Up
                if (_isSignUp) ...[
                  TextField(
                    controller: _fullNameController,
                    decoration: InputDecoration(
                      labelText: "Full Name",
                      prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF94A3B8)),
                      labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: const Color(0xFF1E293B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF334155)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF0284C7), width: 2),
                      ),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                ],

                // Email field
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: "Email address",
                    prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF94A3B8)),
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF0284C7), width: 2),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                // Password field
                TextField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: "Password (min 6 characters)",
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF94A3B8)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: const Color(0xFF94A3B8),
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF334155)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF0284C7), width: 2),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                  obscureText: _obscurePassword,
                ),

                // Error feedback
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEF4444)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, color: Color(0xFFEF4444), size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                        if (_suggestedAction == "switch_to_signup") ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isSignUp = true;
                                _errorMessage = null;
                                _suggestedAction = null;
                              });
                              _signUp();
                            },
                            icon: const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
                            label: const Text(
                              "Create Account With This Gmail",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ] else if (_suggestedAction == "switch_to_signin") ...[
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _isSignUp = false;
                                _errorMessage = null;
                                _suggestedAction = null;
                              });
                              _signIn();
                            },
                            icon: const Icon(Icons.login_rounded, color: Colors.white, size: 20),
                            label: const Text(
                              "Sign In With This Gmail",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  ElevatedButton(
                    onPressed: _isSignUp ? _signUp : _signIn,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 60),
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      _isSignUp ? "CREATE ACCOUNT & SIGN IN" : "SIGN IN",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _continueOffline,
                    icon: const Icon(Icons.offline_bolt_rounded, color: Color(0xFF38BDF8)),
                    label: const Text(
                      "CONTINUE OFFLINE (INSTANT ACCESS)",
                      style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      side: const BorderSide(color: Color(0xFF0284C7)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() {
                        _isSignUp = !_isSignUp;
                        _errorMessage = null;
                        _suggestedAction = null;
                      }),
                      child: Text(
                        _isSignUp
                            ? "Already have an account? Sign In"
                            : "New to SmartMediCare? Create an account",
                        style: const TextStyle(
                          color: Color(0xFF38BDF8),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
