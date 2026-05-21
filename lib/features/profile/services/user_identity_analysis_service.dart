import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/interfaces/ai_service.dart';
import '../../../core/services/firebase_ai_service_impl.dart';
import '../../../core/services/firestore_service.dart';
import '../domain/user_identity_profile.dart';

/// Generates textual AI face/body profiles from user photos (Firestore-backed).
class UserIdentityAnalysisService {
  final AIService _aiService;
  final FirebaseFirestore _firestore;
  final Dio _dio;

  UserIdentityAnalysisService({
    AIService? aiService,
    FirebaseFirestore? firestore,
    Dio? dio,
  })  : _aiService = aiService ?? FirebaseAIServiceImpl(),
        _firestore = firestore ?? FirestoreService.instance,
        _dio = dio ?? Dio();

  static const _facePrompt = '''
Analyze this face reference photo. Return ONLY valid JSON with snake_case keys:
- skin_tone: descriptive tone (e.g. "medium warm brown")
- face_shape: e.g. oval, round, square
- hair_color: e.g. "dark brown"
- hair_style: e.g. "short curly"
- eye_shape: e.g. rounded, almond
''';

  static const _bodyPrompt = '''
Analyze this body reference photo. Return ONLY valid JSON with snake_case keys:
- body_type: e.g. athletic, slim, average
- height_estimate: one of short, medium, medium_tall, tall
- shoulder_width: narrow, medium, broad
- build: e.g. lean, muscular, average
''';

  /// Analyzes available face/body photos and saves profiles to users/{uid}.
  Future<void> analyzeAndSaveProfiles({
    required String userId,
    List<String> facePhotoUrls = const [],
    List<String> bodyPhotoUrls = const [],
  }) async {
    AiFaceProfile? faceProfile;
    AiBodyProfile? bodyProfile;

    if (facePhotoUrls.isNotEmpty) {
      try {
        final file = await _downloadFirst(facePhotoUrls);
        final data = await _aiService.analyzeImageToJson(
          image: file,
          promptInstruction: _facePrompt,
        );
        faceProfile = AiFaceProfile.fromJson(data);
        await file.delete();
      } catch (e) {
        debugPrint('⚠️ Face profile analysis failed: $e');
      }
    }

    if (bodyPhotoUrls.isNotEmpty) {
      try {
        final file = await _downloadFirst(bodyPhotoUrls);
        final data = await _aiService.analyzeImageToJson(
          image: file,
          promptInstruction: _bodyPrompt,
        );
        bodyProfile = AiBodyProfile.fromJson(data);
        await file.delete();
      } catch (e) {
        debugPrint('⚠️ Body profile analysis failed: $e');
      }
    }

    if ((faceProfile == null || faceProfile.isEmpty) &&
        (bodyProfile == null || bodyProfile.isEmpty)) {
      return;
    }

    final update = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (faceProfile != null && !faceProfile.isEmpty) {
      update['aiFaceProfile'] = faceProfile.toJson();
    }
    if (bodyProfile != null && !bodyProfile.isEmpty) {
      update['aiBodyProfile'] = bodyProfile.toJson();
    }

    await _firestore.collection('users').doc(userId).set(
          update,
          SetOptions(merge: true),
        );
    debugPrint('✅ AI identity profiles saved for user $userId');
  }

  Future<File> _downloadFirst(List<String> urls) async {
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/identity_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    final response = await _dio.get(
      urls.first,
      options: Options(responseType: ResponseType.bytes),
    );
    await file.writeAsBytes(response.data as List<int>);
    return file;
  }
}
