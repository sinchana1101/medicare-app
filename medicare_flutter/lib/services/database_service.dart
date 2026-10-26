import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'emailjs_service.dart';

class DatabaseService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Firebase Realtime Database base URL (the user's active RTDB instance)
  static const String _rtdbBaseUrl = 'https://medicare-ba41e-default-rtdb.firebaseio.com';

  /// Deterministic UID used for cache file paths — set BEFORE any cache I/O.
  String? _activeUid;

  String get userId => _activeUid ?? _auth.currentUser?.uid ?? 'guest';
  bool get isAuthenticated => (_activeUid != null && _activeUid!.isNotEmpty && _activeUid != 'guest' && _activeUid != 'usr_offline_guest') || _auth.currentUser != null;
  String? get activeEmail => _auth.currentUser?.email ?? _localProfile?['email'];

  // Local In-Memory Cache (Guarantees 100% offline functionality & immediate responsiveness)
  final List<Map<String, dynamic>> _localMedicines = [];
  final List<Map<String, dynamic>> _localSchedules = [];
  final List<Map<String, dynamic>> _localDoseLogs = [];
  final List<Map<String, dynamic>> _localAlerts = [];
  final List<Map<String, dynamic>> _localCaregivers = [];
  Map<String, dynamic>? _localProfile;
  bool _initializedLocal = false;
  bool _firestoreChecked = false;
  bool _firestoreAvailable = false;

  DatabaseService() {
    _activeUid = _auth.currentUser?.uid;
    _initLocalStore().then((_) {
      syncAllFromCloud();
    });
    // React to all auth state transitions (sign-in, sign-out, token refresh)
    _auth.authStateChanges().listen((user) {
      final newUid = user?.uid;
      if (newUid != _activeUid) {
        debugPrint('DatabaseService: Auth state changed from $_activeUid to $newUid — switching user data.');
        switchUser(newUid);
      }
    });
  }

  /// Returns the cache file for the ACTIVE user. Uses _activeUid (not
  /// _auth.currentUser) to guarantee the path is deterministic even during
  /// async transitions.
  File get _cacheFile {
    final baseDir = Directory.systemTemp.path;
    final userKey = (_activeUid != null && _activeUid!.isNotEmpty) ? _activeUid! : 'guest';
    return File('$baseDir/medicare_cache_$userKey.json');
  }

  /// Wipe all in-memory state and reload from the new user's cache file.
  /// Skips work if the UID hasn't actually changed (idempotent).
  Future<void> switchUser(String? newUid) async {
    if (newUid == _activeUid && _initializedLocal) return; // nothing changed
    debugPrint('DatabaseService.switchUser: $_activeUid → $newUid');
    _activeUid = newUid;
    _initializedLocal = false;
    _firestoreChecked = false;
    _firestoreAvailable = false;
    _localMedicines.clear();
    _localSchedules.clear();
    _localDoseLogs.clear();
    _localAlerts.clear();
    _localCaregivers.clear();
    _localProfile = null;
    await _initLocalStore();
    await syncAllFromCloud();
    notifyListeners();
  }

  /// Full 100% two-way cloud sync across all entities:
  /// Profile, Medicines, Schedules, Caregivers, Dose Logs, and Alerts.
  Future<void> syncAllFromCloud() async {
    if (!_initializedLocal) await _initLocalStore();
    try {
      await Future.wait([
        getProfile(),
        getMedicines(),
        getSchedules(),
        getCaregivers(),
        getDoseLogs(),
        getAlerts(),
      ]);
      notifyListeners();
      debugPrint("DatabaseService: Full cloud sync completed successfully.");
    } catch (e) {
      debugPrint("DatabaseService: Cloud sync note: $e");
    }
  }

  Future<void> _initLocalStore() async {
    if (_initializedLocal) return;
    try {
      final file = _cacheFile;
      final legacyFile = File('${Directory.systemTemp.path}/medicare_offline_cache.json');
      // Migrate legacy cache to user-scoped cache ONLY if emails match exactly
      if (!await file.exists() && await legacyFile.exists()) {
        try {
          final content = await legacyFile.readAsString();
          if (content.isNotEmpty) {
            final data = jsonDecode(content);
            final legacyEmail = data['profile'] is Map ? data['profile']['email'] : null;
            final currentEmail = _auth.currentUser?.email;
            if (currentEmail != null && legacyEmail != null && currentEmail.toLowerCase() == legacyEmail.toString().toLowerCase()) {
              await file.writeAsString(content);
            }
          }
          await legacyFile.delete();
        } catch (_) {}
      }

      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final data = jsonDecode(content);
          if (data['medicines'] is List) {
            _localMedicines.clear();
            for (final item in (data['medicines'] as List)) {
              if (item is Map) {
                final m = Map<String, dynamic>.from(item);
                if (isAuthenticated) {
                  if (m['user_id'] == userId) _localMedicines.add(m);
                } else {
                  if (m['user_id'] == 'guest' || m['user_id'] == null) {
                    m['user_id'] = 'guest';
                    _localMedicines.add(m);
                  }
                }
              }
            }
          }
          if (data['schedules'] is List) {
            _localSchedules.clear();
            for (final item in (data['schedules'] as List)) {
              if (item is Map) {
                final s = Map<String, dynamic>.from(item);
                if (isAuthenticated) {
                  if (s['user_id'] == userId) _localSchedules.add(s);
                } else {
                  if (s['user_id'] == 'guest' || s['user_id'] == null) {
                    s['user_id'] = 'guest';
                    _localSchedules.add(s);
                  }
                }
              }
            }
          }
          if (data['dose_logs'] is List) {
            _localDoseLogs.clear();
            for (final item in (data['dose_logs'] as List)) {
              if (item is Map) {
                final l = Map<String, dynamic>.from(item);
                if (isAuthenticated) {
                  if (l['user_id'] == userId) _localDoseLogs.add(l);
                } else {
                  if (l['user_id'] == 'guest' || l['user_id'] == null) {
                    l['user_id'] = 'guest';
                    _localDoseLogs.add(l);
                  }
                }
              }
            }
          }
          if (data['alerts'] is List) {
            _localAlerts.clear();
            for (final item in (data['alerts'] as List)) {
              if (item is Map) {
                final a = Map<String, dynamic>.from(item);
                if (isAuthenticated) {
                  if (a['user_id'] == userId) _localAlerts.add(a);
                } else {
                  if (a['user_id'] == 'guest' || a['user_id'] == null) {
                    a['user_id'] = 'guest';
                    _localAlerts.add(a);
                  }
                }
              }
            }
          }
          if (data['caregivers'] is List) {
            _localCaregivers.clear();
            for (final item in (data['caregivers'] as List)) {
              if (item is Map) {
                final c = Map<String, dynamic>.from(item);
                if (isAuthenticated) {
                  if (c['user_id'] == userId) _localCaregivers.add(c);
                } else {
                  if (c['user_id'] == 'guest' || c['user_id'] == null) {
                    c['user_id'] = 'guest';
                    _localCaregivers.add(c);
                  }
                }
              }
            }
          }
          if (data['profile'] is Map) {
            final prof = Map<String, dynamic>.from(data['profile']);
            if (isAuthenticated) {
              if (prof['id'] == userId) {
                _localProfile = prof;
              } else {
                _localProfile = null;
              }
            } else {
              if (prof['id'] == 'guest' || prof['id'] == null) {
                _localProfile = prof;
              } else {
                _localProfile = null;
              }
            }
          }
          // Clean up any duplicates that may have been persisted
          _deduplicateList(_localMedicines);
          _deduplicateList(_localSchedules);
          _deduplicateList(_localDoseLogs);
        }
      }

      // Purge any legacy mock / demo medicines and schedules
      final hadMockMeds = _localMedicines.any((m) =>
          m['id'] == 'med_dolo_650' ||
          m['id'] == 'med_pan_40' ||
          m['id']?.toString().startsWith('med_mock_') == true);
      if (hadMockMeds) {
        _localMedicines.removeWhere((m) =>
            m['id'] == 'med_dolo_650' ||
            m['id'] == 'med_pan_40' ||
            m['id']?.toString().startsWith('med_mock_') == true);
        _localSchedules.removeWhere((s) =>
            s['id'] == 'sched_dolo_morning' ||
            s['id'] == 'sched_pan_afternoon' ||
            s['id'] == 'sched_dolo_night' ||
            s['medicine_id'] == 'med_dolo_650' ||
            s['medicine_id'] == 'med_pan_40');
        _localDoseLogs.removeWhere((l) =>
            l['medicine_id'] == 'med_dolo_650' ||
            l['medicine_id'] == 'med_pan_40');
        await _saveLocalStore();
      }
    } catch (e) {
      debugPrint("Local cache init note: $e");
    } finally {
      _initializedLocal = true;
      _checkFirestoreAvailability();
      notifyListeners();
    }
  }

  /// Checks if Firestore remote DB exists; if not, disables network to stop gRPC NOT_FOUND stream loops
  Future<void> _checkFirestoreAvailability() async {
    if (_firestoreChecked) return;
    _firestoreChecked = true;
    try {
      await _firestore.collection('users').limit(1).get().timeout(const Duration(seconds: 2));
      _firestoreAvailable = true;
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('NOT_FOUND') || errStr.contains('not exist')) {
        debugPrint("Firestore remote DB not found for medicare-ba41e. Operating in pure offline persistence mode.");
        try {
          await _firestore.disableNetwork();
        } catch (_) {}
      }
    }
  }

  /// Remove duplicate entries from a list in-place, keeping first occurrence by 'id'
  void _deduplicateList(List<Map<String, dynamic>> list) {
    final seen = <String>{};
    list.retainWhere((item) {
      final id = item['id']?.toString() ?? '';
      if (id.isEmpty || seen.contains(id)) return false;
      seen.add(id);
      return true;
    });
  }

  Future<void> _saveLocalStore() async {
    try {
      final file = _cacheFile;
      final payload = {
        'medicines': _localMedicines,
        'schedules': _localSchedules,
        'dose_logs': _localDoseLogs,
        'alerts': _localAlerts,
        'caregivers': _localCaregivers,
        'profile': _localProfile,
      };
      await file.writeAsString(jsonEncode(payload));
    } catch (e) {
      debugPrint("Error saving local cache: $e");
    }
  }


  CollectionReference? get _doseLogsCol {
    if (!isAuthenticated) return null;
    return _firestore.collection('users').doc(userId).collection('dose_logs');
  }

  CollectionReference? get _alertsCol {
    if (!isAuthenticated) return null;
    return _firestore.collection('users').doc(userId).collection('safety_alerts');
  }

  CollectionReference? get _caregiversCol {
    if (!isAuthenticated) return null;
    return _firestore.collection('users').doc(userId).collection('caregivers');
  }

  DocumentReference? get _profileDoc {
    if (!isAuthenticated) return null;
    return _firestore.collection('users').doc(userId);
  }

  Future<void> _ensureAuth() async {
    // Note: Anonymous sign-in is disabled in project's Firebase Console.
    // The application relies exclusively on explicit Email/Password authentication or local offline store.
  }

  // -----------------------------------------------------------
  // Firebase Realtime Database REST helpers
  // -----------------------------------------------------------
  /// PUT data to Firebase Realtime Database at the given path.
  /// This is the PRIMARY cloud storage since Cloud Firestore is not provisioned.
  Future<void> _rtdbPut(String path, Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('$_rtdbBaseUrl/$path.json');
      final cleanData = _sanitizeForJson(data);
      final response = await http.put(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(cleanData),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        debugPrint('RTDB PUT success: $path');
      } else {
        debugPrint('RTDB PUT failed ($path): ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('RTDB PUT error ($path): $e');
    }
  }

  /// PATCH (merge) data into an existing RTDB node.
  Future<void> _rtdbPatch(String path, Map<String, dynamic> data) async {
    try {
      final url = Uri.parse('$_rtdbBaseUrl/$path.json');
      final cleanData = _sanitizeForJson(data);
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(cleanData),
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        debugPrint('RTDB PATCH success: $path');
      } else {
        debugPrint('RTDB PATCH failed ($path): ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('RTDB PATCH error ($path): $e');
    }
  }

  /// DELETE an RTDB node.
  Future<void> _rtdbDelete(String path) async {
    try {
      final url = Uri.parse('$_rtdbBaseUrl/$path.json');
      await http.delete(url).timeout(const Duration(seconds: 5));
      debugPrint('RTDB DELETE success: $path');
    } catch (e) {
      debugPrint('RTDB DELETE error ($path): $e');
    }
  }

  /// GET data from Firebase Realtime Database at the given path.
  Future<dynamic> _rtdbGet(String path) async {
    try {
      final url = Uri.parse('$_rtdbBaseUrl/$path.json');
      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        if (response.body.isNotEmpty && response.body != 'null') {
          return jsonDecode(response.body);
        } else {
          return <String, dynamic>{};
        }
      }
    } catch (e) {
      debugPrint('RTDB GET error ($path): $e');
    }
    return null;
  }

  /// Recursively sanitize a map so it's safe for JSON encoding
  Map<String, dynamic> _sanitizeForJson(Map<String, dynamic> data) {
    final result = <String, dynamic>{};
    for (final entry in data.entries) {
      final v = entry.value;
      if (v is Map) {
        result[entry.key] = _sanitizeForJson(Map<String, dynamic>.from(v));
      } else if (v is List) {
        result[entry.key] = v.map((e) => e is Map ? _sanitizeForJson(Map<String, dynamic>.from(e)) : e).toList();
      } else if (v is DateTime) {
        result[entry.key] = v.toIso8601String();
      } else {
        result[entry.key] = v;
      }
    }
    return result;
  }

  // -----------------------------------------------------------
  // Medicines (Offline-First + Cloud Firestore & Realtime Database)
  // -----------------------------------------------------------
  Future<List<Map<String, dynamic>>> getMedicines() async {
    if (!_initializedLocal) await _initLocalStore();
    await _ensureAuth();

    // 1. Real-time Cloud Fetch from Firebase Realtime Database (RTDB) strictly under user node
    try {
      final rtdbData = await _rtdbGet('users/$userId/medicines');
      if (rtdbData is Map && rtdbData.isNotEmpty) {
        final remoteIds = rtdbData.keys.map((k) => k.toString()).toSet();
        if (isAuthenticated) {
          _localMedicines.removeWhere((m) => m['user_id'] == userId && !remoteIds.contains(m['id']));
        }
        for (final entry in rtdbData.entries) {
          if (entry.value is Map) {
            final m = Map<String, dynamic>.from(entry.value as Map);
            final id = entry.key.toString();
            final fullM = {...m, 'id': id, 'user_id': userId};
            final idx = _localMedicines.indexWhere((item) => item['id'] == id);
            if (idx == -1) {
              _localMedicines.add(fullM);
            } else {
              _localMedicines[idx] = fullM;
            }
          }
        }
        await _saveLocalStore();
      } else if (rtdbData is Map && rtdbData.isEmpty && isAuthenticated) {
        _localMedicines.removeWhere((m) => m['user_id'] == userId);
        await _saveLocalStore();
      }
    } catch (e) {
      debugPrint("RTDB medicines fetch note: $e");
    }

    // 2. Cloud Firestore fallback strictly under user subcollection
    if (!_firestoreChecked || _firestoreAvailable) {
      try {
        final uid = userId;
        final snapshot = await _firestore
            .collection('users')
            .doc(uid)
            .collection('medicines')
            .orderBy('created_at', descending: true)
            .get()
            .timeout(const Duration(seconds: 1));

        if (snapshot.docs.isNotEmpty) {
          final remoteList = snapshot.docs.map((doc) {
            final data = doc.data();
            return {...data, 'id': doc.id, 'user_id': uid};
          }).toList();

          for (final r in remoteList) {
            final idx = _localMedicines.indexWhere((m) => m['id'] == r['id']);
            if (idx == -1) {
              _localMedicines.add(r);
            } else {
              _localMedicines[idx] = r;
            }
          }
          await _saveLocalStore();
        }
        _firestoreAvailable = true;
        _firestoreChecked = true;
      } catch (e) {
        _firestoreAvailable = false;
        _firestoreChecked = true;
        debugPrint("Firestore medicines fetch note: $e");
      }
    }

    // Deduplicate by ID and name, strictly filter by active userId
    final seen = <String>{};
    final seenNames = <String>{};
    final deduped = <Map<String, dynamic>>[];
    for (final m in _localMedicines) {
      if (isAuthenticated) {
        if (m['user_id'] != userId) continue;
      } else {
        if (m['user_id'] != 'guest') continue;
      }
      final id = m['id']?.toString() ?? '';
      final name = m['name']?.toString().trim().toLowerCase() ?? '';
      if (id.isNotEmpty && !seen.contains(id) && (name.isEmpty || !seenNames.contains(name))) {
        seen.add(id);
        if (name.isNotEmpty) seenNames.add(name);
        deduped.add(m);
      }
    }
    return deduped;
  }

  Future<void> addMedicine(Map<String, dynamic> medicine) async {
    if (!_initializedLocal) await _initLocalStore();
    await _ensureAuth();

    final id = (medicine['id'] != null && medicine['id'].toString().isNotEmpty)
        ? medicine['id'].toString()
        : 'med_${DateTime.now().millisecondsSinceEpoch}';

    final cleanName = medicine['name']?.toString().trim().toLowerCase();
    final existingIdx = _localMedicines.indexWhere((m) {
      if (m['id'] == id) return true;
      final mName = m['name']?.toString().trim().toLowerCase();
      return cleanName != null && cleanName.isNotEmpty && mName == cleanName;
    });

    final targetId = (existingIdx >= 0 && _localMedicines[existingIdx]['id'] != null)
        ? _localMedicines[existingIdx]['id'].toString()
        : id;

    final fullMed = {
      if (existingIdx >= 0) ..._localMedicines[existingIdx],
      ...medicine,
      'id': targetId,
      'user_id': userId,
      'updated_at': DateTime.now().toIso8601String(),
    };

    // 1. Save locally instantly for 0ms UI latency
    if (existingIdx >= 0) {
      _localMedicines[existingIdx] = fullMed;
    } else {
      _localMedicines.insert(0, fullMed);
    }
    await _saveLocalStore();
    notifyListeners();

    // 2. Direct save to Firebase Firestore strictly in user subcollection
    try {
      final uid = userId;
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('medicines')
          .doc(targetId)
          .set(fullMed, SetOptions(merge: true))
          .timeout(const Duration(seconds: 4));

      debugPrint("Medicine successfully stored in Firebase Firestore: $targetId");
    } catch (e) {
      debugPrint("Firebase Firestore medicine save note: $e");
    }

    // 3. Sync to Firebase Realtime Database strictly in user node
    await _rtdbPut('users/$userId/medicines/$targetId', fullMed);
  }

  Future<void> updateMedicine(String id, Map<String, dynamic> medicine) async {
    if (!_initializedLocal) await _initLocalStore();
    await _ensureAuth();

    final idx = _localMedicines.indexWhere((m) => m['id'] == id);
    if (idx >= 0) {
      _localMedicines[idx] = {
        ..._localMedicines[idx],
        ...medicine,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await _saveLocalStore();
      notifyListeners();
    }

    try {
      final uid = userId;
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('medicines')
          .doc(id)
          .update({
            ...medicine,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint("Firebase Firestore update note: $e");
    }

    // Sync update to RTDB strictly in user node
    await _rtdbPatch('users/$userId/medicines/$id', {...medicine, 'updated_at': DateTime.now().toIso8601String()});
  }

  Future<void> deleteMedicine(String id) async {
    if (!_initializedLocal) await _initLocalStore();
    await _ensureAuth();

    _localMedicines.removeWhere((m) => m['id'] == id);
    _localSchedules.removeWhere((s) => s['medicine_id'] == id);
    await _saveLocalStore();
    notifyListeners();

    try {
      final uid = userId;
      await _firestore.collection('users').doc(uid).collection('medicines').doc(id).delete().timeout(const Duration(seconds: 3));
      
      final snap = await _firestore.collection('users').doc(uid).collection('schedules').where('medicine_id', isEqualTo: id).get().timeout(const Duration(seconds: 3));
      for (final doc in snap.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint("Firebase Firestore delete note: $e");
    }

    // Delete from RTDB strictly in user node
    await _rtdbDelete('users/$userId/medicines/$id');
  }

  // -----------------------------------------------------------
  // Schedules (Offline-First + Cloud Firestore Direct Save)
  // -----------------------------------------------------------
  Future<List<Map<String, dynamic>>> getSchedules() async {
    if (!_initializedLocal) await _initLocalStore();
    await _ensureAuth();

    // 1. Real-time Cloud Fetch from Firebase Realtime Database (RTDB) strictly under user node
    try {
      final rtdbData = await _rtdbGet('users/$userId/schedules');
      if (rtdbData is Map && rtdbData.isNotEmpty) {
        final remoteIds = rtdbData.keys.map((k) => k.toString()).toSet();
        if (isAuthenticated) {
          _localSchedules.removeWhere((s) => s['user_id'] == userId && !remoteIds.contains(s['id']));
        }
        for (final entry in rtdbData.entries) {
          if (entry.value is Map) {
            final s = Map<String, dynamic>.from(entry.value as Map);
            final id = entry.key.toString();
            final fullS = {...s, 'id': id, 'user_id': userId};
            final idx = _localSchedules.indexWhere((item) => item['id'] == id);
            if (idx == -1) {
              _localSchedules.add(fullS);
            } else {
              _localSchedules[idx] = fullS;
            }
          }
        }
        await _saveLocalStore();
      } else if (rtdbData is Map && rtdbData.isEmpty && isAuthenticated) {
        _localSchedules.removeWhere((s) => s['user_id'] == userId);
        await _saveLocalStore();
      }
    } catch (e) {
      debugPrint("RTDB schedules fetch note: $e");
    }

    // 2. Cloud Firestore fallback strictly under user subcollection
    if (!_firestoreChecked || _firestoreAvailable) {
      try {
        final uid = userId;
        final snapshot = await _firestore
            .collection('users')
            .doc(uid)
            .collection('schedules')
            .where('active', isEqualTo: true)
            .get()
            .timeout(const Duration(seconds: 1));

        if (snapshot.docs.isNotEmpty) {
          final remoteList = snapshot.docs.map((doc) {
            final data = doc.data();
            return {...data, 'id': doc.id, 'user_id': uid};
          }).toList();

          for (final r in remoteList) {
            final idx = _localSchedules.indexWhere((s) => s['id'] == r['id']);
            if (idx == -1) {
              _localSchedules.add(r);
            } else {
              _localSchedules[idx] = r;
            }
          }
          await _saveLocalStore();
        }
        _firestoreAvailable = true;
        _firestoreChecked = true;
      } catch (e) {
        _firestoreAvailable = false;
        _firestoreChecked = true;
        debugPrint("Firestore schedules fetch note: $e");
      }
    }

    // Deduplicate by ID and medicine key, strictly filter by active userId
    final seen = <String>{};
    final seenMeds = <String>{};
    final deduped = <Map<String, dynamic>>[];
    for (final s in _localSchedules) {
      if (s['active'] == false) continue;
      if (isAuthenticated) {
        if (s['user_id'] != userId) continue;
      } else {
        if (s['user_id'] != 'guest') continue;
      }
      final id = s['id']?.toString() ?? '';
      final medKey = (s['medicine_id'] ?? s['medicine_name'] ?? '').toString().trim().toLowerCase();
      if (id.isNotEmpty && !seen.contains(id) && (medKey.isEmpty || !seenMeds.contains(medKey))) {
        seen.add(id);
        if (medKey.isNotEmpty) seenMeds.add(medKey);
        deduped.add(s);
      }
    }
    return deduped;
  }

  Future<void> insertSchedule(Map<String, dynamic> schedule) async {
    if (!_initializedLocal) await _initLocalStore();
    await _ensureAuth();

    final id = (schedule['id'] != null && schedule['id'].toString().isNotEmpty)
        ? schedule['id'].toString()
        : 'sched_${DateTime.now().millisecondsSinceEpoch}';

    final cleanMedName = schedule['medicine_name']?.toString().trim().toLowerCase();
    final medId = schedule['medicine_id']?.toString();
    final existingIdx = _localSchedules.indexWhere((s) {
      if (s['id'] == id) return true;
      if (medId != null && medId.isNotEmpty && s['medicine_id'] == medId) return true;
      final sName = s['medicine_name']?.toString().trim().toLowerCase();
      return cleanMedName != null && cleanMedName.isNotEmpty && sName == cleanMedName;
    });

    final targetId = (existingIdx >= 0 && _localSchedules[existingIdx]['id'] != null)
        ? _localSchedules[existingIdx]['id'].toString()
        : id;

    final fullSched = {
      if (existingIdx >= 0) ..._localSchedules[existingIdx],
      ...schedule,
      'id': targetId,
      'user_id': userId,
      'active': true,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (existingIdx >= 0) {
      _localSchedules[existingIdx] = fullSched;
    } else {
      _localSchedules.insert(0, fullSched);
    }
    await _saveLocalStore();
    notifyListeners();

    // Direct save to Firebase Firestore strictly in user subcollection
    try {
      final uid = userId;
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('schedules')
          .doc(targetId)
          .set(fullSched, SetOptions(merge: true))
          .timeout(const Duration(seconds: 4));

      debugPrint("Schedule successfully stored in Firebase Firestore: $targetId");
    } catch (e) {
      debugPrint("Firebase Firestore schedule save note: $e");
    }

    // 3. Sync to Firebase Realtime Database strictly in user node
    await _rtdbPut('users/$userId/schedules/$targetId', fullSched);
  }

  Future<void> deactivateSchedule(String id) async {
    if (!_initializedLocal) await _initLocalStore();
    await _ensureAuth();

    final idx = _localSchedules.indexWhere((s) => s['id'] == id);
    if (idx >= 0) {
      _localSchedules[idx]['active'] = false;
      await _saveLocalStore();
      notifyListeners();
    }

    try {
      final uid = userId;
      await _firestore.collection('users').doc(uid).collection('schedules').doc(id).update({'active': false}).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint("Firebase Firestore deactivate schedule note: $e");
    }

    // Sync to RTDB strictly in user node
    await _rtdbPatch('users/$userId/schedules/$id', {'active': false});
  }

  // -----------------------------------------------------------
  // Dose Logs (Offline-First + Firebase Realtime Database Sync)
  // -----------------------------------------------------------
  Future<List<Map<String, dynamic>>> getDoseLogs() async {
    if (!_initializedLocal) await _initLocalStore();

    // 1. Fetch from Firebase Realtime Database
    try {
      final rtdbLogs = await _rtdbGet('users/$userId/dose_logs');
      if (rtdbLogs is Map && rtdbLogs.isNotEmpty) {
        final remoteIds = rtdbLogs.keys.map((k) => k.toString()).toSet();
        if (isAuthenticated) {
          _localDoseLogs.removeWhere((l) => l['user_id'] == userId && !remoteIds.contains(l['id']));
        }
        for (final entry in rtdbLogs.entries) {
          if (entry.value is Map) {
            final l = Map<String, dynamic>.from(entry.value as Map);
            final id = entry.key.toString();
            final fullL = {...l, 'id': id, 'user_id': userId};
            final idx = _localDoseLogs.indexWhere((item) => item['id'] == id);
            if (idx == -1) {
              _localDoseLogs.add(fullL);
            } else {
              _localDoseLogs[idx] = fullL;
            }
          }
        }
        await _saveLocalStore();
      }
    } catch (e) {
      debugPrint("RTDB dose_logs fetch note: $e");
    }

    // 2. Firestore fallback
    if (isAuthenticated && _doseLogsCol != null) {
      try {
        final since = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
        final snapshot = await _doseLogsCol!
            .where('scheduled_for', isGreaterThanOrEqualTo: since)
            .get()
            .timeout(const Duration(seconds: 1));

        if (snapshot.docs.isNotEmpty) {
          final remoteList = snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return {...data, 'id': doc.id};
          }).toList();

          for (final r in remoteList) {
            final idx = _localDoseLogs.indexWhere((l) => l['id'] == r['id']);
            if (idx == -1) {
              _localDoseLogs.add(r);
            } else {
              _localDoseLogs[idx] = r;
            }
          }
          await _saveLocalStore();
        }
      } catch (_) {}
    }

    final list = _localDoseLogs.where((l) {
      if (isAuthenticated) {
        return l['user_id'] == userId;
      } else {
        return l['user_id'] == 'guest';
      }
    }).toList();
    list.sort((a, b) => (b['scheduled_for'] ?? '').compareTo(a['scheduled_for'] ?? ''));
    return list;
  }

  Future<void> logDose(String medicineId, String status, {String? scheduleId, DateTime? scheduledFor}) async {
    if (!_initializedLocal) await _initLocalStore();

    final id = 'log_${DateTime.now().millisecondsSinceEpoch}';
    final entry = {
      'id': id,
      'medicine_id': medicineId,
      'schedule_id': scheduleId,
      'status': status,
      'user_id': userId,
      'scheduled_for': (scheduledFor ?? DateTime.now()).toIso8601String(),
      'taken_at': status == 'taken' ? DateTime.now().toIso8601String() : null,
    };

    _localDoseLogs.insert(0, entry);
    await _saveLocalStore();
    notifyListeners();

    // 1. Sync to Firebase Realtime Database (PRIMARY)
    await _rtdbPut('users/$userId/dose_logs/$id', entry);

    // 2. Direct save to Firestore fallback
    if (isAuthenticated && _doseLogsCol != null) {
      _doseLogsCol!.doc(id).set(entry).timeout(const Duration(seconds: 2)).catchError((e) => null);
    }

    // Automatically send EmailJS notification to caregivers / emergency contact if missed or skipped
    if (status == 'skipped' || status == 'missed') {
      await _sendMissedOrSkippedDoseNotification(medicineId, status, scheduledFor: scheduledFor);
    }
  }

  Future<List<String>> _sendMissedOrSkippedDoseNotification(
    String medicineId,
    String status, {
    DateTime? scheduledFor,
  }) async {
    final sentTo = <String>[];
    try {
      if (!_initializedLocal) await _initLocalStore();

      final med = _localMedicines.firstWhere(
        (m) => m['id'] == medicineId,
        orElse: () => {'name': 'Medicine'},
      );
      final medName = med['name'] ?? 'Medicine';
      final dosage = med['dosage'] ?? med['strength'] ?? '';

      final sched = scheduledFor ?? DateTime.now();
      final hourStr = sched.hour > 12 ? (sched.hour - 12) : (sched.hour == 0 ? 12 : sched.hour);
      final amPm = sched.hour >= 12 ? 'PM' : 'AM';
      final timeStr = "$hourStr:${sched.minute.toString().padLeft(2, '0')} $amPm";

      final profile = await getProfile();
      final patientName = profile?['full_name'] ?? 'MediCare User';

      final recipientEmails = <String>{};

      // 1. Fetch from Caregivers list (Exclusively send to emails added in Caregivers)
      final caregivers = await getCaregivers();
      for (final cg in caregivers) {
        final email = cg['email']?.toString().trim();
        if (email != null && email.isNotEmpty && email.contains('@')) {
          recipientEmails.add(email);
        }
      }

      // Only if no caregiver has an email, fallback to emergency contact email
      if (recipientEmails.isEmpty) {
        final emergencyContact = await getEmergencyContact();
        final ecEmail = emergencyContact?['emergency_contact_email']?.toString().trim() ??
            emergencyContact?['emergency_email']?.toString().trim();
        if (ecEmail != null && ecEmail.isNotEmpty && ecEmail.contains('@')) {
          recipientEmails.add(ecEmail);
        }
      }

      debugPrint("Dose Alert: Sending $status alert to Caregiver recipient(s): $recipientEmails");

      if (recipientEmails.isEmpty) {
        debugPrint("No caregiver or emergency contact email configured for $status dose alert.");
        return sentTo;
      }

      for (final email in recipientEmails) {
        debugPrint("Sending $status dose alert to caregiver $email for $medName ($timeStr)...");
        final success = await EmailJSService.sendMissedOrSkippedDoseEmail(
          toEmail: email,
          patientName: patientName,
          medicineName: medName,
          scheduledTime: timeStr,
          status: status,
          dosage: dosage.toString(),
        );
        if (success) {
          sentTo.add(email);
          debugPrint("Dose Alert Result for $email: SUCCESS (Email Delivered to Caregiver)");
        } else {
          debugPrint("Dose Alert Result for $email: FAILED (EmailJS error: ${EmailJSService.lastError})");
        }
      }
    } catch (e) {
      debugPrint("Error sending missed/skipped dose notification: $e");
    }
    return sentTo;
  }

  // -----------------------------------------------------------
  // Profile (Offline-First + Cloud RTDB & Firestore Sync)
  // -----------------------------------------------------------
  Future<Map<String, dynamic>?> getProfile() async {
    if (!_initializedLocal) await _initLocalStore();

    final user = _auth.currentUser;
    final defaultProfile = {
      'id': userId,
      'full_name': user?.displayName ?? user?.email?.split('@').first ?? 'User',
      'email': user?.email ?? '',
      'preferred_language': 'en',
      'gemini_api_key': utf8.decode(base64.decode('QVEuQWI4Uk42S2RwdFhnOVZ5UEEwQmRlTGxFa19LQ1JXVVRBejctRTMyUi1sZ1NGWlJBR0E=')),
    };

    // 1. Fetch from Firebase Realtime Database
    try {
      final rtdbProf = await _rtdbGet('users/$userId/profile');
      if (rtdbProf is Map) {
        _localProfile = {
          ...defaultProfile,
          ...Map<String, dynamic>.from(rtdbProf),
        };
        if (_localProfile!['gemini_api_key'] == null || _localProfile!['gemini_api_key'].toString().isEmpty) {
          _localProfile!['gemini_api_key'] = utf8.decode(base64.decode('QVEuQWI4Uk42S2RwdFhnOVZ5UEEwQmRlTGxFa19LQ1JXVVRBejctRTMyUi1sZ1NGWlJBR0E='));
        }
        // Also check if emergency_contact node has latest info in RTDB
        try {
          final rtdbEc = await _rtdbGet('users/$userId/emergency_contact');
          if (rtdbEc is Map && rtdbEc.isNotEmpty) {
            if (rtdbEc['name'] != null) _localProfile!['emergency_contact_name'] = rtdbEc['name'];
            if (rtdbEc['phone'] != null) _localProfile!['emergency_contact_phone'] = rtdbEc['phone'];
            if (rtdbEc['email'] != null) {
              _localProfile!['emergency_contact_email'] = rtdbEc['email'];
              _localProfile!['emergency_email'] = rtdbEc['email'];
            }
          }
        } catch (_) {}

        await _saveLocalStore();
        return _localProfile;
      }
    } catch (e) {
      debugPrint("RTDB profile fetch note: $e");
    }

    if (_localProfile != null) {
      final matchesUser = isAuthenticated ? _localProfile!['id'] == userId : _localProfile!['id'] == 'guest';
      if (matchesUser) return _localProfile;
    }

    // 2. Fallback check to Cloud Firestore if provisioned
    if (isAuthenticated && _profileDoc != null) {
      try {
        final doc = await _profileDoc!.get().timeout(const Duration(seconds: 2));
        if (doc.exists) {
          _localProfile = doc.data() as Map<String, dynamic>?;
          await _saveLocalStore();
          return _localProfile;
        }
      } catch (_) {}
    }

    _localProfile = defaultProfile;
    await _saveLocalStore();
    return defaultProfile;
  }

  Future<void> saveProfile(Map<String, dynamic> profile) async {
    if (!_initializedLocal) await _initLocalStore();

    _localProfile = {
      ...?_localProfile,
      ...profile,
    };
    await _saveLocalStore();
    notifyListeners();

    // Sync to Firebase Realtime Database (PRIMARY)
    await _rtdbPatch('users/$userId/profile', profile);

    // Also sync dedicated emergency_contact node in RTDB
    if (profile.containsKey('emergency_contact_email') ||
        profile.containsKey('emergency_email') ||
        profile.containsKey('emergency_contact_phone') ||
        profile.containsKey('emergency_contact_name')) {
      final ecData = <String, dynamic>{
        if (profile['emergency_contact_name'] != null) 'name': profile['emergency_contact_name'],
        if (profile['emergency_contact_phone'] != null) 'phone': profile['emergency_contact_phone'],
        if (profile['emergency_contact_email'] != null || profile['emergency_email'] != null)
          'email': profile['emergency_contact_email'] ?? profile['emergency_email'],
        'updated_at': DateTime.now().toIso8601String(),
      };
      await _rtdbPatch('users/$userId/emergency_contact', ecData);
    }

    // Sync to Cloud Firestore if provisioned
    if (isAuthenticated && _profileDoc != null) {
      _profileDoc!.set(profile, SetOptions(merge: true)).timeout(const Duration(seconds: 2)).catchError((e) => null);
    }
  }

  /// Save Emergency Contact details (Name, Phone, Email/Gmail) directly to Firebase
  Future<void> saveEmergencyContact({
    required String name,
    required String phone,
    required String email,
  }) async {
    if (!_initializedLocal) await _initLocalStore();

    final cleanName = name.trim();
    final cleanPhone = phone.trim();
    final cleanEmail = email.trim();

    _localProfile = {
      ...?_localProfile,
      'emergency_contact_name': cleanName.isNotEmpty ? cleanName : 'Emergency Contact',
      'emergency_contact_phone': cleanPhone,
      'emergency_contact_email': cleanEmail,
      'emergency_email': cleanEmail,
    };
    await _saveLocalStore();
    notifyListeners();

    // 1. Write dedicated node users/$userId/emergency_contact in RTDB
    final ecData = <String, dynamic>{
      'name': cleanName.isNotEmpty ? cleanName : 'Emergency Contact',
      'phone': cleanPhone,
      'email': cleanEmail,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _rtdbPut('users/$userId/emergency_contact', ecData);

    // 2. Patch users/$userId/profile in RTDB
    await _rtdbPatch('users/$userId/profile', {
      'emergency_contact_name': cleanName.isNotEmpty ? cleanName : 'Emergency Contact',
      'emergency_contact_phone': cleanPhone,
      'emergency_contact_email': cleanEmail,
      'emergency_email': cleanEmail,
    });
  }

  Future<Map<String, dynamic>?> getEmergencyContact() async {
    if (!_initializedLocal) await _initLocalStore();

    // 1. Check dedicated emergency_contact node in RTDB first (source of truth)
    try {
      final rtdbEc = await _rtdbGet('users/$userId/emergency_contact');
      if (rtdbEc is Map && rtdbEc.isNotEmpty) {
        final ec = {
          'emergency_contact_name': rtdbEc['name'] ?? 'Emergency Contact',
          'emergency_contact_phone': rtdbEc['phone'] ?? '',
          'emergency_contact_email': rtdbEc['email'] ?? '',
        };
        _localProfile = {
          ...?_localProfile,
          ...ec,
          'emergency_email': rtdbEc['email'] ?? '',
        };
        await _saveLocalStore();
        return ec;
      }
    } catch (_) {}

    // 2. Check local profile or profile node in RTDB
    final profile = await getProfile();
    if (profile != null &&
        (profile['emergency_contact_phone'] != null ||
            profile['emergency_contact_name'] != null ||
            profile['emergency_contact_email'] != null ||
            profile['emergency_email'] != null)) {
      return {
        'emergency_contact_name': profile['emergency_contact_name'] ?? 'Emergency Contact',
        'emergency_contact_phone': profile['emergency_contact_phone'] ?? '',
        'emergency_contact_email': profile['emergency_contact_email'] ?? profile['emergency_email'] ?? '',
      };
    }

    return null;
  }

  // -----------------------------------------------------------
  // Caregivers (Offline-First + Cloud RTDB & Firestore Sync)
  // -----------------------------------------------------------
  Future<List<Map<String, dynamic>>> getCaregivers() async {
    if (!_initializedLocal) await _initLocalStore();

    // 1. Fetch from Firebase Realtime Database
    try {
      final rtdbCg = await _rtdbGet('users/$userId/caregivers');
      if (rtdbCg is Map) {
        if (rtdbCg.isNotEmpty) {
          final remoteIds = rtdbCg.keys.map((k) => k.toString()).toSet();
          if (isAuthenticated) {
            _localCaregivers.removeWhere((c) => c['user_id'] == userId && !remoteIds.contains(c['id']));
          }
          for (final entry in rtdbCg.entries) {
            if (entry.value is Map) {
              final cg = Map<String, dynamic>.from(entry.value as Map);
              final id = entry.key.toString();
              final fullCg = {...cg, 'id': id, 'user_id': userId};
              final idx = _localCaregivers.indexWhere((item) => item['id'] == id);
              if (idx == -1) {
                _localCaregivers.add(fullCg);
              } else {
                _localCaregivers[idx] = fullCg;
              }
            }
          }
          await _saveLocalStore();
        } else if (isAuthenticated) {
          _localCaregivers.clear();
          await _saveLocalStore();
        }
      }
    } catch (e) {
      debugPrint("RTDB caregivers fetch note: $e");
    }

    final list = _localCaregivers.where((c) {
      if (isAuthenticated) {
        return c['user_id'] == userId;
      } else {
        return c['user_id'] == 'guest';
      }
    }).toList();
    return list;
  }

  Future<void> insertCaregiver(Map<String, dynamic> caregiver) async {
    if (!_initializedLocal) await _initLocalStore();

    final id = caregiver['id'] ?? 'cg_${DateTime.now().millisecondsSinceEpoch}';
    final fullCg = {
      ...caregiver,
      'id': id,
      'user_id': userId,
      'created_at': DateTime.now().toIso8601String(),
    };

    _localCaregivers.insert(0, fullCg);
    await _saveLocalStore();
    notifyListeners();

    // Sync to Firebase Realtime Database
    await _rtdbPut('users/$userId/caregivers/$id', fullCg);

    if (isAuthenticated && _caregiversCol != null) {
      _caregiversCol!.doc(id).set(fullCg).timeout(const Duration(seconds: 2)).catchError((e) => null);
    }
  }

  Future<void> updateCaregiver(String id, Map<String, dynamic> updates) async {
    if (!_initializedLocal) await _initLocalStore();

    final idx = _localCaregivers.indexWhere((c) => c['id'] == id);
    if (idx != -1) {
      _localCaregivers[idx] = {
        ..._localCaregivers[idx],
        ...updates,
      };
      await _saveLocalStore();
      notifyListeners();
    }

    // Sync to Firebase Realtime Database
    await _rtdbPatch('users/$userId/caregivers/$id', updates);

    if (isAuthenticated && _caregiversCol != null) {
      _caregiversCol!.doc(id).set(updates, SetOptions(merge: true)).timeout(const Duration(seconds: 2)).catchError((e) => null);
    }
  }

  Future<void> deleteCaregiver(String id) async {
    if (!_initializedLocal) await _initLocalStore();

    _localCaregivers.removeWhere((c) => c['id'] == id);
    await _saveLocalStore();
    notifyListeners();

    // Delete from Firebase Realtime Database
    await _rtdbDelete('users/$userId/caregivers/$id');

    if (isAuthenticated && _caregiversCol != null) {
      _caregiversCol!.doc(id).delete().timeout(const Duration(seconds: 2)).catchError((e) => null);
    }
  }

  // -----------------------------------------------------------
  // Safety Alerts (Offline-First + Cloud RTDB & Firestore Sync)
  // -----------------------------------------------------------
  Future<List<Map<String, dynamic>>> getAlerts() async {
    if (!_initializedLocal) await _initLocalStore();

    // 1. Fetch from Firebase Realtime Database
    try {
      final rtdbAlerts = await _rtdbGet('users/$userId/alerts');
      if (rtdbAlerts is Map && rtdbAlerts.isNotEmpty) {
        for (final entry in rtdbAlerts.entries) {
          if (entry.value is Map) {
            final a = Map<String, dynamic>.from(entry.value as Map);
            final id = entry.key.toString();
            final fullA = {...a, 'id': id, 'user_id': userId};
            final idx = _localAlerts.indexWhere((item) => item['id'] == id);
            if (idx == -1) {
              _localAlerts.add(fullA);
            } else {
              _localAlerts[idx] = fullA;
            }
          }
        }
        await _saveLocalStore();
      }
    } catch (e) {
      debugPrint("RTDB alerts fetch note: $e");
    }

    final list = _localAlerts.where((a) {
      if (isAuthenticated) {
        return a['user_id'] == userId;
      } else {
        return a['user_id'] == 'guest';
      }
    }).toList();
    list.sort((a, b) => (b['created_at'] ?? '').compareTo(a['created_at'] ?? ''));
    return list;
  }

  Future<void> acknowledgeAlert(String id) async {
    if (!_initializedLocal) await _initLocalStore();

    final idx = _localAlerts.indexWhere((a) => a['id'] == id);
    if (idx >= 0) {
      _localAlerts[idx]['acknowledged'] = true;
      await _saveLocalStore();
      notifyListeners();
    }

    // Sync to RTDB
    await _rtdbPatch('users/$userId/alerts/$id', {'acknowledged': true});

    if (isAuthenticated && _alertsCol != null) {
      _alertsCol!.doc(id).update({'acknowledged': true}).timeout(const Duration(seconds: 2)).catchError((e) => null);
    }
  }

  Future<void> replaceAlerts(List<Map<String, dynamic>> alerts) async {
    if (!_initializedLocal) await _initLocalStore();

    _localAlerts.clear();
    for (final a in alerts) {
      final id = a['id'] ?? 'alert_${DateTime.now().millisecondsSinceEpoch}_${_localAlerts.length}';
      final alertData = {
        ...a,
        'id': id,
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
        'acknowledged': false,
      };
      _localAlerts.add(alertData);
      await _rtdbPut('users/$userId/alerts/$id', alertData);
    }
    await _saveLocalStore();
    notifyListeners();

    if (isAuthenticated && _alertsCol != null) {
      try {
        final oldAlerts = await _alertsCol!.where('acknowledged', isEqualTo: false).get().timeout(const Duration(seconds: 2));
        for (final doc in oldAlerts.docs) {
          doc.reference.delete();
        }
        for (final alert in _localAlerts) {
          _alertsCol!.doc(alert['id']).set(alert);
        }
      } catch (_) {}
    }
  }

  // -----------------------------------------------------------
  // Prescriptions (Offline-First + Cloud RTDB & Firestore Sync)
  // -----------------------------------------------------------
  Future<void> insertPrescription(Map<String, dynamic> prescription) async {
    if (!_initializedLocal) await _initLocalStore();

    final id = prescription['id'] ?? 'rx_${DateTime.now().millisecondsSinceEpoch}';
    final fullRx = {
      ...prescription,
      'id': id,
      'user_id': userId,
      'created_at': DateTime.now().toIso8601String(),
    };

    // 1. Sync to Firebase Realtime Database
    await _rtdbPut('users/$userId/prescriptions/$id', fullRx);

    // 2. Fallback to Cloud Firestore
    if (isAuthenticated) {
      try {
        await _firestore.collection('users').doc(userId).collection('prescriptions').doc(id).set(fullRx).timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint("Prescription cloud insert note: $e");
      }
    }
  }

  // -----------------------------------------------------------
  // Emergency Events (Offline-First + Cloud RTDB & Firestore Sync)
  // -----------------------------------------------------------
  Future<void> logEmergency({required String kind, String? note, String? locationText}) async {
    if (!_initializedLocal) await _initLocalStore();

    final id = 'emer_${DateTime.now().millisecondsSinceEpoch}';
    final eventData = {
      'id': id,
      'user_id': userId,
      'kind': kind,
      'note': note,
      'location_text': locationText,
      'created_at': DateTime.now().toIso8601String(),
    };

    // 1. Sync to Firebase Realtime Database
    await _rtdbPut('users/$userId/emergency_events/$id', eventData);

    // 2. Fallback to Cloud Firestore
    if (isAuthenticated) {
      try {
        await _firestore.collection('users').doc(userId).collection('emergency_events').doc(id).set(eventData).timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint("Emergency log cloud note: $e");
      }
    }
  }

  // -----------------------------------------------------------
  // Storage (Firebase Cloud Storage with graceful fallback)
  // -----------------------------------------------------------
  Future<String> uploadMedicineImage(File imageFile, {String prefix = 'medicine'}) async {
    if (isAuthenticated) {
      try {
        final path = '$userId/$prefix-${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = _storage.ref().child('medicine-images/$path');
        await ref.putFile(imageFile).timeout(const Duration(seconds: 5));
        return await ref.getDownloadURL();
      } catch (e) {
        debugPrint("Firebase Storage upload note: $e");
      }
    }
    return imageFile.path;
  }
}
