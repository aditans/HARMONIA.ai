import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_ai/firebase_ai.dart';

class AIService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'us-central1');
  static const List<String> _fallbackModels = <String>[
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-1.5-flash',
  ];

  static final RegExp _weeklyIntentRegex = RegExp(
    r'(weekly|week|routine|schedule|this week|last week|weekly routine)',
    caseSensitive: false,
  );

  Future<String> _callGetAIResponse({
    required String message,
    required String uid,
  }) async {
    final callable = _functions.httpsCallable(
      'getAIResponse',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );

    final response = await callable.call(<String, dynamic>{
      'message': message,
      'uid': uid,
    });

    final data = response.data;
    if (data is Map) {
      final reply = data['reply'] as String?;
      if (reply != null) {
        return reply;
      }
    }

    throw Exception('Invalid response format from AI service');
  }

  Future<String> _buildWeeklyContext(String uid) async {
    final userDoc = await _firestore.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? const <String, dynamic>{};

    final now = DateTime.now();
    final weekStart = now.subtract(const Duration(days: 7));

    final sessionsSnapshot = await _firestore
        .collection('sessions')
        .where('uid', isEqualTo: uid)
        .where('startedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .orderBy('startedAt', descending: true)
        .get();

    int exerciseCount = 0;
    int yogaCount = 0;
    int focusCount = 0;
    int totalMinutes = 0;

    final sessionLines = <String>[];

    for (final doc in sessionsSnapshot.docs) {
      final data = doc.data();
      final type = (data['type'] as String?) ?? 'unknown';
      final durationSec = (data['durationSeconds'] as num?)?.toInt() ?? 0;
      final durationMin = (durationSec / 60).round();
      totalMinutes += durationMin;

      if (type == 'exercise') exerciseCount++;
      if (type == 'yoga') yogaCount++;
      if (type == 'focus') focusCount++;

      sessionLines.add('- $type: ${durationMin}min');
    }

    final displayName = (userData['displayName'] as String?) ?? 'User';
    final streakDays = (userData['streakDays'] as num?)?.toInt() ?? 0;
    final totalSessions = (userData['totalSessions'] as num?)?.toInt() ?? 0;

    return [
      'User profile:',
      '- Name: $displayName',
      '- Streak days: $streakDays',
      '- Total sessions: $totalSessions',
      '',
      'Last 7 days summary:',
      '- Total sessions this week: ${sessionsSnapshot.docs.length}',
      '- Exercise sessions: $exerciseCount',
      '- Yoga sessions: $yogaCount',
      '- Focus sessions: $focusCount',
      '- Total active minutes this week: $totalMinutes',
      '',
      'Sessions:',
      if (sessionLines.isEmpty) '- No sessions found for this week.' else ...sessionLines,
    ].join('\n');
  }

  Future<String> _callFirebaseAIFallback({
    required String message,
    required String uid,
  }) async {
    String weeklyContext = '';
    if (_weeklyIntentRegex.hasMatch(message)) {
      try {
        weeklyContext = await _buildWeeklyContext(uid);
      } catch (_) {
        weeklyContext = 'Weekly data could not be loaded from Firestore.';
      }
    }

    final prompt = [
      'You are Harmonia, a warm and practical wellness coach.',
      'Give concise and safe advice.',
      if (weeklyContext.isNotEmpty) weeklyContext,
      'User message: $message',
    ].join('\n\n');

    Object? lastError;

    for (final modelName in _fallbackModels) {
      try {
        final model = FirebaseAI.googleAI().generativeModel(model: modelName);
        final response = await model.generateContent([
          Content.text(prompt),
        ]);

        final text = response.text?.trim();
        if (text != null && text.isNotEmpty) {
          return text;
        }
      } catch (e) {
        lastError = e;
      }
    }

    throw Exception(
      'AI fallback models are unavailable. Last error: ${lastError ?? 'Unknown error'}',
    );
  }

  /// Get the current user's UID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  /// Send a message to the AI and get a response
  Future<String> sendMessage(String message) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Ensure latest auth token is available before invoking callable.
      await _auth.currentUser?.reload();
      await _auth.currentUser?.getIdToken(true);

      return await _callGetAIResponse(message: message, uid: userId);
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'unauthenticated' && _auth.currentUser != null) {
        // Retry once after forcing another token refresh.
        await _auth.currentUser?.getIdToken(true);
        try {
          return await _callGetAIResponse(
            message: message,
            uid: _auth.currentUser!.uid,
          );
        } on FirebaseFunctionsException catch (retryError) {
          if (retryError.code == 'unauthenticated') {
            // Final fallback: use Firebase AI Logic SDK directly.
            return await _callFirebaseAIFallback(
              message: message,
              uid: _auth.currentUser!.uid,
            );
          }
          throw Exception(
            'AI function error (${retryError.code}): ${retryError.message ?? 'Unknown error'}',
          );
        }
      }
      throw Exception('AI function error (${e.code}): ${e.message ?? 'Unknown error'}');
    } catch (e) {
      throw Exception('Failed to get AI response: $e');
    }
  }

  /// Load chat history for the current user
  Future<List<Map<String, dynamic>>> loadChatHistory({
    int limit = 50,
  }) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) {
        return [];
      }

      final snapshot = await _firestore
          .collection('chatHistory')
          .doc(userId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => doc.data())
          .toList()
          .reversed
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Save a user message to chat history
  Future<void> saveChatMessage({
    required String role,
    required String content,
  }) async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) return;

      await _firestore
          .collection('chatHistory')
          .doc(userId)
          .collection('messages')
          .add({
        'role': role,
        'content': content,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Silent fail - don't disrupt user experience
    }
  }

  /// Clear chat history for the current user
  Future<void> clearChatHistory() async {
    try {
      final userId = getCurrentUserId();
      if (userId == null) return;

      final collection = _firestore
          .collection('chatHistory')
          .doc(userId)
          .collection('messages');

      final docs = await collection.get();
      for (final doc in docs.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      // Silent fail
    }
  }
}
