import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/interfaces/ai_service.dart';
import '../../../core/services/firebase_ai_service_impl.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/utils/identity_photo_collage.dart';
import '../domain/user_identity_profile.dart';

/// Identity pipeline: local collage → AI JSON profile → Firestore + Storage.
class UserIdentityAnalysisService {
  final AIService _aiService;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final Dio _dio;

  UserIdentityAnalysisService({
    AIService? aiService,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    Dio? dio,
  })  : _aiService = aiService ?? FirebaseAIServiceImpl(),
        _firestore = firestore ?? FirestoreService.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _dio = dio ?? Dio();

  static const _identityAnalysisPrompt = '''
You are a professional biometric and body-proportion analyst for fashion virtual try-on.

Analyze the attached identity reference collage (4 rows: front face, 3/4 face, full body front, full body side).

Return ONLY valid JSON with this structure (snake_case, all fields optional but fill what you can infer):
{
  "identity_version": 1,
  "skin_tone": { "primary": "...", "undertone": "...", "confidence": 0.0-1.0 },
  "face": { "shape": "...", "jaw_definition": "...", "eye_shape": "...", "nose_shape": "..." },
  "hair": { "color": "...", "style": "...", "density": "..." },
  "body": { "type": "...", "height_estimate": "...", "shoulder_width": "...", "build": "...", "proportions": "..." },
  "visual_characteristics": { "contrast_level": "...", "facial_sharpness": "...", "overall_presence": "..." }
}

Rules: concise, deterministic, infer ethnicity consistency from visible features without stereotyping labels in output.
''';

  /// Full identity analysis: collage (local) + Gemini JSON profile + Firestore.
  Future<IdentityProfile?> analyzeUserIdentity({
    required String userId,
    List<String> facePhotoUrls = const [],
    List<String> bodyPhotoUrls = const [],
  }) async {
    final validFace = _filterUrls(facePhotoUrls);
    final validBody = _filterUrls(bodyPhotoUrls);
    if (validFace.isEmpty && validBody.isEmpty) return null;

    final tempDir = await getTemporaryDirectory();
    final downloaded = <File>[];
    IdentityProfile? profile;

    try {
      final faceFiles = await _downloadPhotos(validFace, tempDir.path, 'face');
      final bodyFiles = await _downloadPhotos(validBody, tempDir.path, 'body');
      downloaded.addAll(faceFiles);
      downloaded.addAll(bodyFiles);

      if (downloaded.isEmpty) return null;

      final collageBytes = await IdentityPhotoCollage.buildVertical(
        facePhotos: faceFiles,
        bodyPhotos: bodyFiles,
      );

      final collageUrl = await _uploadCollage(userId, collageBytes);

      final collageFile = File(
        '${tempDir.path}/collage_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await collageFile.writeAsBytes(collageBytes);

      final raw = await _aiService.analyzeImageToJson(
        image: collageFile,
        promptInstruction: _identityAnalysisPrompt,
      );
      profile = IdentityProfile.fromJson(raw);

      if (profile.isEmpty) {
        debugPrint('⚠️ Identity analysis returned empty profile');
        return null;
      }

      await _firestore.collection('users').doc(userId).set({
        'identityProfile': profile.toJson(),
        'identityVersion': profile.identityVersion ?? IdentityProfile.currentVersion,
        'identityCollageUrl': collageUrl,
        'identityGeneratedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Identity profile v${profile.identityVersion} saved');
      return profile;
    } catch (e) {
      debugPrint('❌ analyzeUserIdentity failed: $e');
      return null;
    } finally {
      for (final f in downloaded) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
  }

  /// Backward-compatible entry point used after photo upload.
  Future<void> analyzeAndSaveProfiles({
    required String userId,
    List<String> facePhotoUrls = const [],
    List<String> bodyPhotoUrls = const [],
  }) async {
    await analyzeUserIdentity(
      userId: userId,
      facePhotoUrls: facePhotoUrls,
      bodyPhotoUrls: bodyPhotoUrls,
    );
  }

  List<String> _filterUrls(List<String> urls) {
    return urls
        .where((u) => u.isNotEmpty && !u.startsWith('mock://'))
        .toList();
  }

  Future<List<File>> _downloadPhotos(
    List<String> urls,
    String dirPath,
    String prefix,
  ) async {
    final files = <File>[];
    for (var i = 0; i < urls.length && i < 4; i++) {
      try {
        final file = File('$dirPath/${prefix}_$i.jpg');
        final response = await _dio.get(
          urls[i],
          options: Options(responseType: ResponseType.bytes),
        );
        await file.writeAsBytes(response.data as List<int>);
        files.add(file);
      } catch (e) {
        debugPrint('⚠️ Failed to download $prefix photo $i: $e');
      }
    }
    return files;
  }

  Future<String> _uploadCollage(String userId, List<int> bytes) async {
    final path = 'users/$userId/identity_collage_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child(path);
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    await ref.putData(data, SettableMetadata(contentType: 'image/jpeg'));
    return ref.getDownloadURL();
  }
}
