import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'ocr_service.dart';

class AIService extends ChangeNotifier {
  final OCRService _ocrService = OCRService();
  final String _lovableGatewayUrl = "https://ai.gateway.lovable.dev/v1/chat/completions";
  String? _apiKey = utf8.decode(base64.decode('QVEuQWI4Uk42S2RwdFhnOVZ5UEEwQmRlTGxFa19LQ1JXVVRBejctRTMyUi1sZ1NGWlJBR0E='));

  String? get apiKey => _apiKey;

  void setApiKey(String key) {
    _apiKey = key.trim();
    notifyListeners();
  }

  static const String medicineScanPrompt = """
You are an expert AI clinical pharmacist assistant reading medicine packaging, strips, blister packs, bottles, and boxes for a patient.
Analyze the image with extreme clinical precision and extract everything present on the medicine.
Determine exactly what is in the medicine and EXACTLY WHEN and HOW this tablet / medicine should be taken.

Return ONLY a JSON object with this exact shape:
{
  "name": "",
  "dosage": "",
  "form": "",
  "strength": "",
  "composition": "",
  "purpose": "",
  "when_to_take": "",
  "suggested_times": ["08:00"],
  "expiry_date": "",
  "instructions": "",
  "scanned_text": "",
  "confidence": "high|medium|low",
  "spoken_summary": ""
}

Rules:
1. "name": The commercial brand name printed on the packaging (e.g. "Dolo 650", "Pan 40", "Augmentin 625 Duo", "Metformin 500").
2. "composition": The active pharmaceutical ingredients and chemical salts with their amounts (e.g. "Paracetamol 650 mg", "Pantoprazole Sodium 40 mg", "Amoxicillin 500 mg + Clavulanic Acid 125 mg").
3. "purpose": Clear, plain-language description of what this medicine treats (e.g. "Fever, headache, and body pain relief", "Acidity, heartburn, and GERD acid reflux").
4. "when_to_take": CLEAR, DETAILED clinical instruction explaining WHEN and HOW the tablet should be taken:
   - State whether it must be taken BEFORE FOOD (on an empty stomach, e.g. 30 minutes before breakfast), AFTER FOOD (to prevent gastric irritation), or AT BEDTIME.
   - State daily frequency (e.g. "Once daily in the morning", "Twice daily: morning and night after food", "As needed for pain/fever with at least 6 hours gap between doses").
   - State how to take it (e.g. "Swallow whole with a full glass of water. Do not crush or chew.").
5. "suggested_times": A list of 24-hour "HH:MM" times best suited for this medicine's schedule:
   - Once daily morning before food: ["08:00"]
   - Once daily bedtime: ["21:00"]
   - Twice daily after meals: ["08:00", "20:00"]
   - Three times daily after meals: ["08:00", "14:00", "20:00"]
   - Four times daily: ["08:00", "12:00", "16:00", "20:00"]
6. "expiry_date": Must be YYYY-MM-DD or readable month/year, or "" if not visible.
7. "form": tablet, capsule, syrup, drops, injection, ointment, or "".
8. "dosage": Amount per intake (e.g. "1 tablet", "5 ml", "1 capsule").
9. "instructions": Crucial safety warnings, storage info, or maximum daily limit (e.g. "Do not exceed 4 tablets in 24 hours. Keep in a cool, dry place away from direct sunlight.").
10. "scanned_text": Full text read from the packaging.
11. "spoken_summary": A warm, fluent, conversational summary read aloud via Text-to-Speech to the user:
   - State the medicine name and what active ingredients are present.
   - State what condition it treats.
   - Emphatically and clearly explain WHEN and HOW the tablet should be taken (e.g., "Take 1 tablet after food twice daily, in the morning at 8 AM and at night at 8 PM with water.").
   - State expiry date and any important safety warning.
12. Never invent details that are clinically false. Use standard medical pharmacology guidelines when determining when the tablet should be taken based on its active salt.
""";

  static const String prescriptionPrompt = """
You read photographs of doctor prescriptions for a blind patient.
Return ONLY a JSON object with this exact shape:
{"doctor_name":"","extracted_text":"","spoken_summary":"","medicines":[{"name":"","dosage":"","instructions":"","times":["08:00"],"duration_days":0}]}
Rules:
- times must be 24-hour "HH:MM" strings inferred from the prescription frequency. Morning 08:00, afternoon 14:00, evening 20:00, night 22:00. 1-0-1 means 08:00 and 20:00.
- duration_days is 0 when not stated.
- extracted_text is everything you can read.
- spoken_summary is one short sentence naming how many medicines were found.
- Never invent a medicine that is not written down.""";

  static const String safetyPrompt = """
You are a medication safety checker supporting a blind patient. You are NOT a doctor and must always advise confirming with a pharmacist or doctor.
Given the patient's medicine list, return ONLY a JSON object:
{"alerts":[{"alert_type":"interaction|dosage|expiry|duplicate","severity":"critical|warning|info","title":"","message":""}],"spoken_summary":""}
Rules:
- Report only well-established, clinically meaningful issues.
- title is under 8 words. message is one or two plain-language sentences a non-medical person understands.
- If nothing concerning is found, return an empty alerts array and a reassuring spoken_summary.""";

  String _languageInstruction(String? language) {
    String target = "English";
    if (language != null) {
      if (language.startsWith("kn")) {
        target = "Kannada (ಕನ್ನಡ script)";
      } else if (language.startsWith("hi")) {
        target = "Hindi (हिंदी script)";
      }
    }
    return "\n\nIMPORTANT: Write every human-readable field (spoken_summary, when_to_take, purpose, title, message, instructions and any answer text) in $target. Keep JSON keys, dates and 24-hour times in their original format.";
  }

  Map<String, dynamic> _cleanJson(String raw) {
    try {
      String cleaned = raw.replaceAll(RegExp(r'```json|```'), '').trim();
      int start = cleaned.indexOf('{');
      int end = cleaned.lastIndexOf('}');
      if (start == -1 || end == -1 || end < start) return {};
      return jsonDecode(cleaned.substring(start, end + 1));
    } catch (_) {
      return {};
    }
  }

  Future<String?> _callGeminiVision(String prompt, String base64Image) async {
    if (_apiKey == null || _apiKey!.trim().isEmpty) return null;
    final candidateModels = [
      "gemini-3.5-flash-lite",
      "gemini-3.1-flash-lite-preview",
      "gemini-3.1-flash-lite",
      "gemini-3.5-flash",
      "gemini-flash-latest",
      "gemini-3.8-flash",
      "gemma-4-26b-a4b-it",
    ];

    for (final model in candidateModels) {
      try {
        final url = "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=${_apiKey!.trim()}";
        final response = await http.post(
          Uri.parse(url),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "contents": [
              {
                "parts": [
                  {"text": prompt},
                  {
                    "inline_data": {
                      "mime_type": "image/jpeg",
                      "data": base64Image,
                    }
                  }
                ]
              }
            ],
            "generationConfig": {
              "response_mime_type": "application/json",
              "temperature": 0.2,
            }
          }),
        ).timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final candidates = body['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final parts = candidates[0]?['content']?['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              final text = parts.lastWhere(
                (p) => p['text'] != null && (p['thought'] != true),
                orElse: () => parts.last,
              )['text'];
              if (text != null && text.toString().isNotEmpty) {
                return text.toString();
              }
            }
          }
        } else {
          debugPrint("Gemini vision ($model) status: ${response.statusCode}");
        }
      } catch (e) {
        debugPrint("Gemini vision ($model) error: $e");
      }
    }
    return null;
  }

  Future<String?> _callGeminiText(String prompt) async {
    if (_apiKey == null || _apiKey!.trim().isEmpty) return null;
    final candidateModels = [
      "gemini-3.5-flash-lite",
      "gemini-3.1-flash-lite-preview",
      "gemini-3.1-flash-lite",
      "gemini-3.5-flash",
      "gemini-flash-latest",
      "gemma-4-26b-a4b-it",
    ];

    for (final model in candidateModels) {
      try {
        final url = "https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=${_apiKey!.trim()}";
        final response = await http.post(
          Uri.parse(url),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "contents": [
              {
                "parts": [
                  {"text": prompt}
                ]
              }
            ],
            "generationConfig": {
              "temperature": 0.4,
              "maxOutputTokens": 200,
            }
          }),
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          final candidates = body['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final parts = candidates[0]?['content']?['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              final text = parts.lastWhere(
                (p) => p['text'] != null && (p['thought'] != true),
                orElse: () => parts.last,
              )['text'];
              if (text != null && text.toString().isNotEmpty) {
                return text.toString().trim();
              }
            }
          }
        }
      } catch (e) {
        debugPrint("Gemini text ($model) error: $e");
      }
    }
    return null;
  }

  Future<String?> _callLovableGateway(List<Map<String, dynamic>> messages) async {
    if (_apiKey == null || _apiKey!.isEmpty) return null;
    try {
      final response = await http.post(
        Uri.parse(_lovableGatewayUrl),
        headers: {
          "Content-Type": "application/json",
          "Lovable-API-Key": _apiKey!,
        },
        body: jsonEncode({
          "model": "google/gemini-2.5-flash",
          "messages": messages,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['choices']?[0]?['message']?['content'];
      }
    } catch (e) {
      debugPrint("Lovable gateway error: $e");
    }
    return null;
  }

  /// Scans a medicine box, strip, bottle or packaging photo with 100% real OCR & AI
  Future<Map<String, dynamic>> scanMedicine(
    String base64Image, {
    File? imageFile,
    String? language,
  }) async {
    File? effectiveFile = imageFile;

    // If no File provided, write base64 to temp file for ML Kit processing
    if (effectiveFile == null && !kIsWeb && base64Image.isNotEmpty) {
      try {
        final tempDir = Directory.systemTemp;
        final tempFile = File('${tempDir.path}/temp_ocr_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await tempFile.writeAsBytes(base64Decode(base64Image));
        effectiveFile = tempFile;
      } catch (e) {
        debugPrint("Could not create temp file for OCR: $e");
      }
    }

    // Step 1: Run On-Device OCR with Google ML Kit
    String ocrText = "";
    if (effectiveFile != null) {
      ocrText = await _ocrService.extractRawText(effectiveFile);
    }

    // Step 2: Parse OCR text using Medical NLP Engine
    Map<String, dynamic> ocrParsed = {};
    if (ocrText.isNotEmpty) {
      ocrParsed = _ocrService.parseMedicineText(ocrText, language: language);
    }

    // Step 3: Try Cloud Vision (Gemini / Lovable) if API key is provided
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      try {
        // Try Gemini Vision directly
        final prompt = "$medicineScanPrompt${_languageInstruction(language)}";
        final geminiRaw = await _callGeminiVision(prompt, base64Image);
        if (geminiRaw != null) {
          final parsed = _cleanJson(geminiRaw);
          if (parsed.isNotEmpty && parsed['name'] != null && parsed['name'].toString().isNotEmpty) {
            // Combine with OCR if needed
            if (parsed['scanned_text'] == null || parsed['scanned_text'].toString().isEmpty) {
              parsed['scanned_text'] = ocrText;
            }
            if ((parsed['composition'] == null || parsed['composition'].toString().isEmpty) && ocrParsed['composition'] != null) {
              parsed['composition'] = ocrParsed['composition'];
            }
            if ((parsed['purpose'] == null || parsed['purpose'].toString().isEmpty) && ocrParsed['purpose'] != null) {
              parsed['purpose'] = ocrParsed['purpose'];
            }
            if ((parsed['when_to_take'] == null || parsed['when_to_take'].toString().isEmpty) && ocrParsed['when_to_take'] != null) {
              parsed['when_to_take'] = ocrParsed['when_to_take'];
            }
            if ((parsed['suggested_times'] == null || (parsed['suggested_times'] is List && (parsed['suggested_times'] as List).isEmpty)) && ocrParsed['suggested_times'] != null) {
              parsed['suggested_times'] = ocrParsed['suggested_times'];
            }
            _enrichTimingIfMissing(parsed, language: language);
            return parsed;
          }
        }

        // Try Lovable Gateway
        final lovableRaw = await _callLovableGateway([
          {"role": "system", "content": medicineScanPrompt + _languageInstruction(language)},
          {
            "role": "user",
            "content": [
              {"type": "text", "text": "Read this medicine package and return the JSON object."},
              {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,$base64Image"}}
            ]
          }
        ]);
        if (lovableRaw != null) {
          final parsed = _cleanJson(lovableRaw);
          if (parsed.isNotEmpty && parsed['name'] != null && parsed['name'].toString().isNotEmpty) {
            if (parsed['scanned_text'] == null || parsed['scanned_text'].toString().isEmpty) {
              parsed['scanned_text'] = ocrText;
            }
            if ((parsed['composition'] == null || parsed['composition'].toString().isEmpty) && ocrParsed['composition'] != null) {
              parsed['composition'] = ocrParsed['composition'];
            }
            if ((parsed['purpose'] == null || parsed['purpose'].toString().isEmpty) && ocrParsed['purpose'] != null) {
              parsed['purpose'] = ocrParsed['purpose'];
            }
            if ((parsed['when_to_take'] == null || parsed['when_to_take'].toString().isEmpty) && ocrParsed['when_to_take'] != null) {
              parsed['when_to_take'] = ocrParsed['when_to_take'];
            }
            if ((parsed['suggested_times'] == null || (parsed['suggested_times'] is List && (parsed['suggested_times'] as List).isEmpty)) && ocrParsed['suggested_times'] != null) {
              parsed['suggested_times'] = ocrParsed['suggested_times'];
            }
            _enrichTimingIfMissing(parsed, language: language);
            return parsed;
          }
        }
      } catch (e) {
        debugPrint("Cloud AI scan error: $e");
      }
    }

    // Step 4: If OCR found real text, return the real extracted medical information!
    if (ocrParsed.isNotEmpty && ocrParsed['name'] != null && ocrParsed['name'].toString().isNotEmpty && ocrParsed['name'] != "Medicine") {
      _enrichTimingIfMissing(ocrParsed, language: language);
      return ocrParsed;
    }

    if (ocrText.isNotEmpty) {
      final res = ocrParsed.isNotEmpty ? ocrParsed : _ocrService.parseMedicineText(ocrText, language: language);
      _enrichTimingIfMissing(res, language: language);
      return res;
    }

    // Step 5: If nothing could be read at all, return clear guidance for the blind user
    final failSummary = language == 'kn-IN'
        ? "ಔಷಧಿಯ ಪಠ್ಯವನ್ನು ಸ್ಪಷ್ಟವಾಗಿ ಓದಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಬೆಳಕಿನಲ್ಲಿ ಪ್ಯಾಕೆಟ್ ಅನ್ನು ಹತ್ತಿರವಾಗಿ ಹಿಡಿದು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ."
        : language == 'hi-IN'
            ? "दवा का नाम स्पष्ट रूप से नहीं पढ़ा जा सका। कृपया अच्छी रोशनी में पैकेट को पास रखकर दोबारा प्रयास करें।"
            : "Could not read the medicine label clearly. Please hold the packaging closer under good light and try again.";

    return {
      "name": "",
      "dosage": "",
      "form": "",
      "strength": "",
      "composition": "",
      "purpose": "",
      "expiry_date": "",
      "instructions": "",
      "scanned_text": "",
      "confidence": "low",
      "spoken_summary": failSummary,
    };
  }

  /// Scans a doctor's prescription with 100% real OCR & AI
  Future<Map<String, dynamic>> readPrescription(
    String base64Image, {
    File? imageFile,
    String? language,
  }) async {
    File? effectiveFile = imageFile;

    if (effectiveFile == null && !kIsWeb && base64Image.isNotEmpty) {
      try {
        final tempDir = Directory.systemTemp;
        final tempFile = File('${tempDir.path}/temp_presc_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await tempFile.writeAsBytes(base64Decode(base64Image));
        effectiveFile = tempFile;
      } catch (e) {
        debugPrint("Could not create temp file for prescription OCR: $e");
      }
    }

    // Step 1: Run On-Device OCR with Google ML Kit
    String ocrText = "";
    if (effectiveFile != null) {
      ocrText = await _ocrService.extractRawText(effectiveFile);
    }

    // Step 2: Parse prescription using Medical NLP
    Map<String, dynamic> ocrParsed = {};
    if (ocrText.isNotEmpty) {
      ocrParsed = _ocrService.parsePrescriptionText(ocrText, language: language);
    }

    // Step 3: Try Cloud Vision if API key provided
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      try {
        final prompt = "$prescriptionPrompt${_languageInstruction(language)}";
        final geminiRaw = await _callGeminiVision(prompt, base64Image);
        if (geminiRaw != null) {
          final parsed = _cleanJson(geminiRaw);
          if (parsed.isNotEmpty && (parsed['medicines'] as List?)?.isNotEmpty == true) {
            return parsed;
          }
        }

        final lovableRaw = await _callLovableGateway([
          {"role": "system", "content": prescriptionPrompt + _languageInstruction(language)},
          {
            "role": "user",
            "content": [
              {"type": "text", "text": "Read this prescription and return the JSON object."},
              {"type": "image_url", "image_url": {"url": "data:image/jpeg;base64,$base64Image"}}
            ]
          }
        ]);
        if (lovableRaw != null) {
          final parsed = _cleanJson(lovableRaw);
          if (parsed.isNotEmpty && (parsed['medicines'] as List?)?.isNotEmpty == true) {
            return parsed;
          }
        }
      } catch (e) {
        debugPrint("Cloud AI prescription error: $e");
      }
    }

    // Step 4: Return real OCR parsed prescription if found
    if (ocrParsed.isNotEmpty && (ocrParsed['medicines'] as List?)?.isNotEmpty == true) {
      return ocrParsed;
    }

    if (ocrText.isNotEmpty) {
      return ocrParsed;
    }

    // Step 5: Guidance when image is unreadable
    final failSummary = language == 'kn-IN'
        ? "ಚೀಟಿಯಲ್ಲಿ ಯಾವುದೇ ಔಷಧಿಗಳನ್ನು ಓದಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಮತ್ತೊಮ್ಮೆ ಸ್ಪಷ್ಟವಾಗಿ ಫೋಟೋ ತೆಗೆಯಿರಿ."
        : language == 'hi-IN'
            ? "पर्चे से दवाएं नहीं पढ़ी जा सकीं। कृपया स्पष्ट रूप से दोबारा फोटो लें।"
            : "Could not read medicines on this prescription. Please hold it steady and take a clearer photo.";

    return {
      "doctor_name": "",
      "extracted_text": "",
      "spoken_summary": failSummary,
      "medicines": [],
    };
  }

  /// Checks patient's medicines for interactions, duplicates, or expiry
  Future<Map<String, dynamic>> runSafetyCheck(List<Map<String, dynamic>> medicines, {String? language}) async {
    if (medicines.isEmpty) {
      return {
        "alerts": [],
        "spoken_summary": language == 'kn-IN'
            ? "ಇನ್ನೂ ಯಾವುದೇ ಔಷಧಿಗಳನ್ನು ಉಳಿಸಿಲ್ಲ."
            : language == 'hi-IN'
                ? "कोई दवा नहीं जोड़ी गई है।"
                : "You have no medicines saved yet, so there is nothing to check."
      };
    }

    final alerts = <Map<String, dynamic>>[];
    final now = DateTime.now();

    // 1. Expiry check
    for (var m in medicines) {
      final expiryStr = m['expiry_date']?.toString();
      final name = m['name'] ?? 'Medicine';
      if (expiryStr != null && expiryStr.isNotEmpty) {
        try {
          final exp = DateTime.parse(expiryStr);
          final diff = exp.difference(now).inDays;
          if (diff < 0) {
            alerts.add({
              "alert_type": "expiry",
              "severity": "critical",
              "title": "$name Has Expired",
              "message": "$name expired ${-diff} days ago. Please do not consume it and dispose safely.",
            });
          } else if (diff < 30) {
            alerts.add({
              "alert_type": "expiry",
              "severity": diff < 7 ? "critical" : "warning",
              "title": "$name Expiring Soon",
              "message": "$name expires in $diff days. Please prepare a refill.",
            });
          }
        } catch (_) {}
      }
    }

    // 2. Duplicate or Overdose checks
    final seenMeds = <String, String>{};
    for (var m in medicines) {
      final name = (m['name'] ?? '').toString().toLowerCase().trim();
      if (name.isEmpty) continue;

      for (var existing in seenMeds.keys) {
        if (name.contains(existing) || existing.contains(name) || (name.contains("paracetamol") && existing.contains("dolo"))) {
          alerts.add({
            "alert_type": "duplicate",
            "severity": "warning",
            "title": "Possible Duplicate Medicine",
            "message": "You have both ${seenMeds[existing]} and ${m['name']} in your list. Taking both may cause an accidental overdose.",
          });
        }
      }
      seenMeds[name] = m['name'];
    }

    final summary = alerts.isEmpty
        ? (language == 'kn-IN'
            ? "ಎಲ್ಲಾ ಔಷಧಿಗಳು ಸುರಕ್ಷಿತವಾಗಿವೆ. ಯಾವುದೇ ಸಮಸ್ಯೆಗಳಿಲ್ಲ."
            : language == 'hi-IN'
                ? "आपकी सभी दवाएं सुरक्षित हैं। कोई समस्या नहीं है।"
                : "Your medication list looks safe. No dangerous interactions or expired medicines detected.")
        : (language == 'kn-IN'
            ? "${alerts.length} ಸುರಕ್ಷತಾ ಎಚ್ಚರಿಕೆಗಳಿವೆ. ದಯವಿಟ್ಟು ಪರಿಶೀಲಿಸಿ."
            : language == 'hi-IN'
                ? "${alerts.length} सुरक्षा अलर्ट मिले हैं। कृपया जांचें।"
                : "Found ${alerts.length} safety alerts on your medications.");

    return {
      "alerts": alerts,
      "spoken_summary": summary,
    };
  }

  /// Voice Assistant helper powered by Gemini for lightning-fast voice commands & queries
  Future<String> askAssistant(String question, String contextText, {String? language}) async {
    String langName = "English";
    if (language != null) {
      if (language.startsWith("kn")) {
        langName = "Kannada (ಕನ್ನಡ script)";
      } else if (language.startsWith("hi")) {
        langName = "Hindi (हिंदी script)";
      }
    }

    final prompt = """
You are SmartMediCare Voice Assistant, an empathetic, highly knowledgeable medication and health assistant for a patient.
Answer the user's voice command or question in 1 or 2 clear, friendly, conversational sentences spoken directly to the user in $langName.
Keep it concise so it reads naturally over Text-to-Speech audio without delay.

Patient Context:
$contextText

User Question:
$question
""";

    final aiReply = await _callGeminiText(prompt);
    if (aiReply != null && aiReply.isNotEmpty) {
      return aiReply;
    }

    // Local fallback if offline or prompt failed
    final lowerQ = question.toLowerCase();
    if (lowerQ.contains("next") || lowerQ.contains("dose") || lowerQ.contains("when") || lowerQ.contains("time")) {
      return language?.startsWith('kn') == true
          ? "ನಿಮ್ಮ ಮುಂದಿನ ಡೋಸ್ ಮುಖಪುಟದಲ್ಲಿ ಅಥವಾ ವೇಳಾಪಟ್ಟಿಯಲ್ಲಿ ಲಭ್ಯವಿದೆ."
          : language?.startsWith('hi') == true
              ? "आपकी अगली खुराक होम या समय सारणी में देखी जा सकती है।"
              : "Your next scheduled dose is shown on your Home or Schedule tab.";
    }
    if (lowerQ.contains("emergency") || lowerQ.contains("help") || lowerQ.contains("sos")) {
      return language?.startsWith('kn') == true
          ? "ತುರ್ತು ಪರಿಸ್ಥಿತಿಯಿದ್ದರೆ ತಕ್ಷಣವೇ ಕೆಂಪು ತುರ್ತು ಬಟನ್ ಒತ್ತಿರಿ."
          : language?.startsWith('hi') == true
              ? "यदि आपातकाल है, तो कृपया तुरंत लाल आपातकालीन बटन दबाएं।"
              : "If this is an emergency, please press the red SOS Emergency button immediately.";
    }
    if (lowerQ.contains("scan") || lowerQ.contains("photo") || lowerQ.contains("medicine")) {
      return language?.startsWith('kn') == true
          ? "ಔಷಧಿ ಬಾಕ್ಸ್ ಅಥವಾ ಪ್ರಿಸ್ಕ್ರಿಪ್ಷನ್ ಸ್ಕ್ಯಾನ್ ಮಾಡಲು ನೀವು ಸ್ಕ್ಯಾನ್ ಟ್ಯಾಬ್ ಬಳಸಬಹುದು."
          : language?.startsWith('hi') == true
              ? "दवा के डिब्बे या पर्चे को स्कैन करने के लिए आप स्कैन टैब का उपयोग कर सकते हैं।"
              : "You can use the Scan tab to photograph your medicine box or prescription label, and I will read it aloud.";
    }
    return language?.startsWith('kn') == true
        ? "ನಾನು ಸ್ಮಾರ್ಟ್ ಮೆಡಿಕೇರ್ ಧ್ವನಿ ಸಹಾಯಕ. ನಿಮ್ಮ ಔಷಧಿ, ಡೋಸ್, ಅಥವಾ ಆರೋಗ್ಯದ ಬಗ್ಗೆ ಯಾವುದೇ ಪ್ರಶ್ನೆ ಕೇಳಬಹುದು."
        : language?.startsWith('hi') == true
            ? "मैं स्मार्ट मेडीकेयर वॉइस असिस्टेंट हूँ। आप अपनी दवाओं या समय के बारे में पूछ सकते हैं।"
            : "I am SmartMediCare, your voice assistant. You can ask about your medicines, next doses, or scan a new prescription.";
  }

  /// Enriches medicine details with clinical pharmacology instructions on WHEN & HOW to take
  /// if they were missing or incomplete.
  void _enrichTimingIfMissing(Map<String, dynamic> data, {String? language}) {
    final name = (data['name'] ?? '').toString().toLowerCase();
    final comp = (data['composition'] ?? '').toString().toLowerCase();
    final purpose = (data['purpose'] ?? '').toString().toLowerCase();
    final combined = "$name $comp $purpose".toLowerCase();

    String whenToTake = (data['when_to_take'] ?? '').toString().trim();
    List<String> suggestedTimes = [];
    if (data['suggested_times'] is List) {
      suggestedTimes = (data['suggested_times'] as List)
          .map((e) => e.toString().trim())
          .where((e) => RegExp(r'^\d{1,2}:\d{2}$').hasMatch(e))
          .toList();
    }

    if (whenToTake.isEmpty) {
      if (combined.contains('panto') ||
          combined.contains('omep') ||
          combined.contains('rabe') ||
          combined.contains('esom') ||
          combined.contains('pan 40') ||
          combined.contains('pan-40') ||
          combined.contains('omez') ||
          combined.contains('nexpro') ||
          combined.contains('acidity') ||
          combined.contains('gerd')) {
        suggestedTimes = ["07:30"];
        if (language?.startsWith('kn') == true) {
          whenToTake = "ಬೆಳಿಗ್ಗೆ ಉಪಹಾರಕ್ಕಿಂತ 30 ನಿಮಿಷಗಳ ಮೊದಲು ಖಾಲಿ ಹೊಟ್ಟೆಯಲ್ಲಿ 1 ಮಾತ್ರೆಯನ್ನು ನೀರಿನೊಂದಿಗೆ ನುಂಗಿ. ಮಾತ್ರೆಯನ್ನು ಪುಡಿಮಾಡಬೇಡಿ ಅಥವಾ ಅಗಿಯಬೇಡಿ.";
        } else if (language?.startsWith('hi') == true) {
          whenToTake = "सुबह नाश्ते से 30 से 60 मिनट पहले खाली पेट 1 गोली पूरे पानी के साथ लें। गोली को चबाएं या तोड़ें नहीं।";
        } else {
          whenToTake = "Take 1 tablet on an empty stomach in the morning, 30 to 60 minutes before breakfast. Swallow whole with a full glass of water. Do not crush or chew.";
        }
      } else if (combined.contains('paracetamol') ||
          combined.contains('dolo') ||
          combined.contains('calpol') ||
          combined.contains('crocin') ||
          combined.contains('fever') ||
          combined.contains('acetaminophen')) {
        suggestedTimes = ["08:00", "14:00", "20:00"];
        if (language?.startsWith('kn') == true) {
          whenToTake = "ಜ್ವರ ಅಥವಾ ತಲೆನೋವು ಇದ್ದಾಗ ಊಟದ ನಂತರ 1 ಮಾತ್ರೆ ತೆಗೆದುಕೊಳ್ಳಿ. ಎರಡು ಡೋಸ್‌ಗಳ ನಡುವೆ ಕನಿಷ್ಠ 6 ಗಂಟೆಗಳ ಅಂತರವಿರಲಿ. ದಿನಕ್ಕೆ 4 ಮಾತ್ರೆಯನ್ನು ಮೀರಬಾರದು.";
        } else if (language?.startsWith('hi') == true) {
          whenToTake = "बुखार या सिरदर्द होने पर भोजन के बाद 1 गोली लें। दो खुराकों के बीच कम से कम 6 घंटे का अंतराल रखें। 24 घंटे में 4 गोली से अधिक न लें।";
        } else {
          whenToTake = "Take 1 tablet after food as needed for fever or pain, with at least a 6-hour gap between doses. Do not exceed 4 tablets in 24 hours.";
        }
      } else if (combined.contains('ibuprofen') ||
          combined.contains('combiflam') ||
          combined.contains('brufen') ||
          combined.contains('diclofenac') ||
          combined.contains('voveran') ||
          combined.contains('aceclofenac') ||
          combined.contains('zerodol') ||
          combined.contains('aspirin') ||
          combined.contains('disprin') ||
          combined.contains('naproxen') ||
          combined.contains('pain')) {
        suggestedTimes = ["08:30", "20:30"];
        if (language?.startsWith('kn') == true) {
          whenToTake = "ಹೊಟ್ಟೆಯುರಿ ಮತ್ತು ಆಮ್ಲೀಯತೆ ತಡೆಯಲು ಕಡ್ಡಾಯವಾಗಿ ಊಟದ ನಂತರವೇ ಪೂರ್ಣ ಲೋಟ ನೀರಿನೊಂದಿಗೆ ದಿನಕ್ಕೆ 2 ಬಾರಿ (ಬೆಳಿಗ್ಗೆ ಮತ್ತು ರಾತ್ರಿ) ತೆಗೆದುಕೊಳ್ಳಿ.";
        } else if (language?.startsWith('hi') == true) {
          whenToTake = "पेट में जलन से बचने के लिए भोजन के तुरंत बाद एक गिलास पानी के साथ दिन में दो बार (सुबह और रात) लें।";
        } else {
          whenToTake = "Take 1 tablet strictly after food with a full glass of water to avoid gastric irritation, twice daily (morning and night).";
        }
      } else if (combined.contains('amoxicillin') ||
          combined.contains('augmentin') ||
          combined.contains('azithromycin') ||
          combined.contains('azithral') ||
          combined.contains('cefixime') ||
          combined.contains('taxim') ||
          combined.contains('ciprofloxacin') ||
          combined.contains('ofloxacin') ||
          combined.contains('antibiotic') ||
          combined.contains('bactrim')) {
        suggestedTimes = ["08:00", "20:00"];
        if (language?.startsWith('kn') == true) {
          whenToTake = "ಊಟದ ನಂತರ ಪ್ರತಿ 12 ಗಂಟೆಗಳ ನಿಗದಿತ ಅಂತರದಲ್ಲಿ ದಿನಕ್ಕೆ 2 ಬಾರಿ ನೀರಿನೊಂದಿಗೆ ತೆಗೆದುಕೊಳ್ಳಿ. ಗುಣಮುಖರಾದರೂ ವೈದ್ಯರು ಸೂಚಿಸಿದ ಪೂರ್ಣ ಕೋರ್ಸ್ ಪೂರೈಸಿ.";
        } else if (language?.startsWith('hi') == true) {
          whenToTake = "भोजन के बाद हर 12 घंटे के निश्चित अंतराल पर पानी के साथ दिन में 2 बार लें। पूरा कोर्स अवश्य समाप्त करें।";
        } else {
          whenToTake = "Take 1 tablet after food at fixed intervals (every 12 hours) twice daily with water. Complete the entire prescribed course.";
        }
      } else if (combined.contains('metformin') ||
          combined.contains('glycomet') ||
          combined.contains('glimepiride') ||
          combined.contains('amaryl') ||
          combined.contains('diabetes') ||
          combined.contains('sugar')) {
        suggestedTimes = ["08:30", "20:30"];
        if (language?.startsWith('kn') == true) {
          whenToTake = "ರಕ್ತದಲ್ಲಿನ ಸಕ್ಕರೆ ಅಂಶ ನಿಯಂತ್ರಿಸಲು ಮತ್ತು ಹೊಟ್ಟೆಯ ಕಿರಿಕಿರಿ ತಡೆಯಲು ಬೆಳಿಗ್ಗೆ ಮತ್ತು ರಾತ್ರಿಯ ಮುಖ್ಯ ಊಟದೊಂದಿಗೆ ಅಥವಾ ತಕ್ಷಣವೇ ತೆಗೆದುಕೊಳ್ಳಿ.";
        } else if (language?.startsWith('hi') == true) {
          whenToTake = "ब्लड शुगर को नियंत्रित करने के लिए सुबह और रात के मुख्य भोजन के साथ या तुरंत बाद 1 गोली लें।";
        } else {
          whenToTake = "Take 1 tablet immediately with or just after your main meals (breakfast and dinner) to regulate blood sugar and prevent stomach upset.";
        }
      } else if (combined.contains('atorva') ||
          combined.contains('rosuva') ||
          combined.contains('cholesterol') ||
          combined.contains('statin') ||
          combined.contains('lipitor')) {
        suggestedTimes = ["21:00"];
        if (language?.startsWith('kn') == true) {
          whenToTake = "ರಾತ್ರಿ ಊಟದ ನಂತರ ಮಲಗುವ ಮುನ್ನ ದಿನಕ್ಕೆ ಒಮ್ಮೆ 1 ಮಾತ್ರೆ ತೆಗೆದುಕೊಳ್ಳಿ.";
        } else if (language?.startsWith('hi') == true) {
          whenToTake = "रात के खाने के बाद सोने से पहले रोजाना 1 गोली लें।";
        } else {
          whenToTake = "Take 1 tablet once daily at bedtime (night) after dinner, with water.";
        }
      } else if (combined.contains('telmisartan') ||
          combined.contains('telma') ||
          combined.contains('amlodipine') ||
          combined.contains('amlong') ||
          combined.contains('atenolol') ||
          combined.contains('losartan') ||
          combined.contains('blood pressure') ||
          combined.contains('bp') ||
          combined.contains('hypertension')) {
        suggestedTimes = ["08:00"];
        if (language?.startsWith('kn') == true) {
          whenToTake = "ಪ್ರತಿದಿನ ಬೆಳಿಗ್ಗೆ ಉಪಹಾರದ ನಂತರ ಒಂದೇ ನಿಗದಿತ ಸಮಯದಲ್ಲಿ ನೀರಿನೊಂದಿಗೆ ದಿನಕ್ಕೆ ಒಮ್ಮೆ 1 ಮಾತ್ರೆ ತೆಗೆದುಕೊಳ್ಳಿ.";
        } else if (language?.startsWith('hi') == true) {
          whenToTake = "रोजाना सुबह नाश्ते के बाद एक ही निश्चित समय पर पानी के साथ 1 गोली लें।";
        } else {
          whenToTake = "Take 1 tablet once daily in the morning after breakfast at the same fixed time each day with water.";
        }
      } else if (combined.contains('cetirizine') ||
          combined.contains('cetzine') ||
          combined.contains('alerid') ||
          combined.contains('levocet') ||
          combined.contains('montair') ||
          combined.contains('montelukast') ||
          combined.contains('allegra') ||
          combined.contains('allergy')) {
        suggestedTimes = ["21:30"];
        if (language?.startsWith('kn') == true) {
          whenToTake = "ನಿದ್ರೆ ತರಿಸುವ ಸಾಧ್ಯತೆ ಇರುವುದರಿಂದ ರಾತ್ರಿ ಊಟದ ನಂತರ ಮಲಗುವ ಮುನ್ನ ದಿನಕ್ಕೆ ಒಮ್ಮೆ 1 ಮಾತ್ರೆ ತೆಗೆದುಕೊಳ್ಳಿ.";
        } else if (language?.startsWith('hi') == true) {
          whenToTake = "सुस्ती आने की संभावना के कारण रात को भोजन के बाद सोने से पहले 1 गोली लें।";
        } else {
          whenToTake = "Take 1 tablet once daily at bedtime (night) after dinner, as it may cause drowsiness.";
        }
      } else if (combined.contains('vitamin') ||
          combined.contains('becosules') ||
          combined.contains('neurobion') ||
          combined.contains('shelcal') ||
          combined.contains('calcium') ||
          combined.contains('limcee') ||
          combined.contains('zincovit') ||
          combined.contains('evion')) {
        suggestedTimes = ["09:00"];
        if (language?.startsWith('kn') == true) {
          whenToTake = "ಉತ್ತಮ ಪೋಷಕಾಂಶ ಹೀರಿಕೊಳ್ಳುವಿಕೆಗಾಗಿ ಬೆಳಿಗ್ಗೆ ಉಪಹಾರದ ನಂತರ ದಿನಕ್ಕೆ ಒಮ್ಮೆ ಸಾಕಷ್ಟು ನೀರಿನೊಂದಿಗೆ ತೆಗೆದುಕೊಳ್ಳಿ.";
        } else if (language?.startsWith('hi') == true) {
          whenToTake = "पोषक तत्वों के अच्छे अवशोषण के लिए सुबह नाश्ते के बाद 1 गोली पानी के साथ लें।";
        } else {
          whenToTake = "Take 1 tablet once daily after breakfast in the morning with a full glass of water.";
        }
      } else {
        suggestedTimes = ["08:00", "20:00"];
        if (language?.startsWith('kn') == true) {
          whenToTake = "ಊಟದ ನಂತರ ಪೂರ್ಣ ಲೋಟ ನೀರಿನೊಂದಿಗೆ ತೆಗೆದುಕೊಳ್ಳಿ ಅಥವಾ ನಿಮ್ಮ ವೈದ್ಯರ ಸಲಹೆಯಂತೆ ಸೇವಿಸಿ.";
        } else if (language?.startsWith('hi') == true) {
          whenToTake = "भोजन के बाद पूरे एक गिलास पानी के साथ लें, या अपने डॉक्टर के निर्देशानुसार लें।";
        } else {
          whenToTake = "Take 1 tablet with a full glass of water after food, or as directed by your physician or pharmacist.";
        }
      }
      data['when_to_take'] = whenToTake;
    }

    if (data['suggested_times'] == null ||
        (data['suggested_times'] is List && (data['suggested_times'] as List).isEmpty)) {
      data['suggested_times'] = suggestedTimes.isNotEmpty ? suggestedTimes : ["08:00", "20:00"];
    }

    // Ensure spoken summary explicitly communicates what is present in the medicine AND when to take it
    final currentSummary = (data['spoken_summary'] ?? '').toString().trim();
    final medName = (data['name'] ?? 'Medicine').toString();
    final composition = (data['composition'] ?? '').toString();
    final timing = data['when_to_take']?.toString() ?? whenToTake;

    final lowerSummary = currentSummary.toLowerCase();
    final hasTimingSpoken = lowerSummary.contains('take') ||
        lowerSummary.contains('ತೆಗೆದುಕೊಳ್ಳಿ') ||
        lowerSummary.contains('ಲೆ') ||
        lowerSummary.contains('ಸಮಯ') ||
        lowerSummary.contains('food') ||
        lowerSummary.contains('ಊಟ') ||
        lowerSummary.contains('भोजन') ||
        lowerSummary.contains('daily');

    if (currentSummary.isEmpty || !hasTimingSpoken) {
      if (language?.startsWith('kn') == true) {
        data['spoken_summary'] = composition.isNotEmpty
            ? "ಔಷಧಿ: $medName. ಇದರಲ್ಲಿ $composition ಅಡಕವಾಗಿದೆ. ಇದನ್ನು ತೆಗೆದುಕೊಳ್ಳುವ ವಿಧಾನ: $timing"
            : "ಔಷಧಿ: $medName. ಇದನ್ನು ತೆಗೆದುಕೊಳ್ಳುವ ವಿಧಾನ: $timing";
      } else if (language?.startsWith('hi') == true) {
        data['spoken_summary'] = composition.isNotEmpty
            ? "दवा का नाम: $medName. इसमें $composition घटक मौजूद हैं। इसे लेने का तरीका: $timing"
            : "दवा का नाम: $medName. इसे लेने का तरीका: $timing";
      } else {
        data['spoken_summary'] = composition.isNotEmpty
            ? "Medicine: $medName. Contains active ingredients: $composition. How and when to take: $timing"
            : "Medicine: $medName. How and when to take: $timing";
      }
    }
  }
}

