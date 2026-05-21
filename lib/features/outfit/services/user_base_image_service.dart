import 'dart:io';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/identity_consistency_prompt.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/utils/identity_photo_collage.dart';
import '../../../core/utils/image_compression_util.dart';
import '../../profile/domain/user_identity_profile.dart';
import '../../profile/services/user_identity_analysis_service.dart';

/// Genera y gestiona la imagen base del usuario para Virtual Try-On.
class UserBaseImageService {
  final FirebaseFirestore _firestore = FirestoreService.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Dio _dio = Dio();
  final UserIdentityAnalysisService _identityService =
      UserIdentityAnalysisService();

  Future<String> generateUserBaseImage({
    required String userId,
    required List<String> bodyPhotoUrls,
    required List<String> facePhotoUrls,
  }) async {
    try {
      debugPrint('🎨 Generating user base image for user: $userId');

      final existingBaseImage = await _getExistingBaseImage(userId);
      if (existingBaseImage != null) {
        debugPrint('✅ User base image already exists: $existingBaseImage');
        return existingBaseImage;
      }

      if (bodyPhotoUrls.isEmpty && facePhotoUrls.isEmpty) {
        throw Exception('No photos available to generate base image');
      }

      var identityProfile = await _loadIdentityProfile(userId);
      String? collageUrl = await _getIdentityCollageUrl(userId);

      if (identityProfile == null || identityProfile.isEmpty) {
        identityProfile = await _identityService.analyzeUserIdentity(
          userId: userId,
          bodyPhotoUrls: bodyPhotoUrls,
          facePhotoUrls: facePhotoUrls,
        );
        collageUrl = await _getIdentityCollageUrl(userId);
      }

      final Uint8List collageBytes = await _resolveCollageBytes(
        collageUrl: collageUrl,
        facePhotoUrls: facePhotoUrls,
        bodyPhotoUrls: bodyPhotoUrls,
      );

      final identityPayload = await ImageCompressionUtil.compressIdentityBytes(
        collageBytes,
      );

      final prompt = _buildBaseImagePrompt(identityProfile);

      final model = FirebaseAI.vertexAI().generativeModel(
        model: 'gemini-2.5-flash-image',
        generationConfig: GenerationConfig(
          responseModalities: [ResponseModalities.image],
          candidateCount: 1,
        ),
        safetySettings: [
          SafetySetting(
            HarmCategory.sexuallyExplicit,
            HarmBlockThreshold.none,
            HarmBlockMethod.severity,
          ),
          SafetySetting(
            HarmCategory.harassment,
            HarmBlockThreshold.none,
            HarmBlockMethod.severity,
          ),
          SafetySetting(
            HarmCategory.dangerousContent,
            HarmBlockThreshold.none,
            HarmBlockMethod.severity,
          ),
          SafetySetting(
            HarmCategory.hateSpeech,
            HarmBlockThreshold.none,
            HarmBlockMethod.severity,
          ),
        ],
      );

      final parts = <Part>[
        InlineDataPart('image/jpeg', identityPayload),
        TextPart(prompt),
      ];
      debugPrint('🖼️ Base image input: 1 identity collage (high quality)');

      final response = await model.generateContent([Content.multi(parts)]);

      final baseImageFile = await _extractAndSaveBaseImage(response, userId);
      final imageUrl = await _uploadBaseImageToStorage(userId, baseImageFile);

      await _saveBaseImageUrlToFirestore(userId, imageUrl);

      try {
        await baseImageFile.delete();
      } catch (_) {}

      debugPrint('✅ User base image successfully created: $imageUrl');
      return imageUrl;
    } catch (e) {
      if (e is FirebaseAIException) {
        throw Exception('AI Error: ${e.message}');
      }
      throw Exception('Failed to generate user base image: $e');
    }
  }

  Future<Uint8List> _resolveCollageBytes({
    required String? collageUrl,
    required List<String> facePhotoUrls,
    required List<String> bodyPhotoUrls,
  }) async {
    if (collageUrl != null && collageUrl.isNotEmpty) {
      try {
        final response = await _dio.get(
          collageUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        return Uint8List.fromList(response.data as List<int>);
      } catch (e) {
        debugPrint('⚠️ Could not download stored collage, rebuilding: $e');
      }
    }

    final tempDir = await getTemporaryDirectory();
    final faceFiles = <File>[];
    final bodyFiles = <File>[];

    for (final url in facePhotoUrls.take(4)) {
      final f = await _downloadPhoto(tempDir.path, 'face', url);
      if (f != null) faceFiles.add(f);
    }
    for (final url in bodyPhotoUrls.take(4)) {
      final f = await _downloadPhoto(tempDir.path, 'body', url);
      if (f != null) bodyFiles.add(f);
    }

    try {
      return IdentityPhotoCollage.buildVertical(
        facePhotos: faceFiles,
        bodyPhotos: bodyFiles,
      );
    } finally {
      for (final f in [...faceFiles, ...bodyFiles]) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
  }

  Future<String?> _getExistingBaseImage(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final url = doc.data()?['baseImageUrl'] as String?;
      return (url != null && url.isNotEmpty) ? url : null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getIdentityCollageUrl(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data()?['identityCollageUrl'] as String?;
  }

  Future<IdentityProfile?> _loadIdentityProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return IdentityProfile.fromFirestoreUser(doc.data());
    } catch (e) {
      debugPrint('⚠️ Could not load identity profile: $e');
      return null;
    }
  }

  Future<File?> _downloadPhoto(
    String dirPath,
    String prefix,
    String url,
  ) async {
    try {
      final file = File(
        '$dirPath/${prefix}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final response = await _dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      await file.writeAsBytes(response.data);
      return file;
    } catch (e) {
      debugPrint('⚠️ Failed to download $prefix photo: $e');
      return null;
    }
  }

  String _buildBaseImagePrompt(IdentityProfile? profile) {
    final identityBlock = IdentityConsistencyPrompt.buildBaseImageBlock(
      profile,
    );

    return """
[OUTPUT_SPECIFICATIONS]
MODE: IMAGE_GENERATION
FORMAT: image/jpeg
ASPECT_RATIO: 3:4
RESOLUTION: 1024x1365
QUALITY: PREMIUM_ECOMMERCE

[REFERENCE_IMAGE]
The attached image is a vertical identity collage with 4 rows:
1) front face  2) 3/4 face  3) full body front  4) full body side.
Reconstruct ONE consistent real person from all rows.

$identityBlock

[INSTRUCTION]
Generate a single full-body ecommerce model reference photograph of the SAME person.

[REQUIREMENTS]
- Exact identity match: facial structure, skin tone, ethnicity, hairstyle, body proportions
- Full-body or 3/4 shot, neutral standing pose (A-pose), front-facing
- Clean white or light gray studio background, even soft lighting
- Natural skin texture, neutral expression, no beauty filters
- Simple neutral base-layer clothing (fitted tank + leggings) that shows silhouette

[AVOID]
- Cinematic lighting, editorial fashion, dramatic shadows, stylization, retouching

[FINAL_OBJECTIVE]
Premium virtual try-on base template. Realistic, neutral, identity-accurate.
""";
  }

  Future<File> _extractAndSaveBaseImage(
    GenerateContentResponse response,
    String userId,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final imageFile = File('${tempDir.path}/base_gen_${userId}_$timestamp.jpg');

    if (response.candidates.isNotEmpty) {
      for (final part in response.candidates.first.content.parts) {
        if (part is InlineDataPart && part.mimeType.startsWith('image/')) {
          await imageFile.writeAsBytes(part.bytes);
          return imageFile;
        }
      }
    }

    if (response.inlineDataParts.isNotEmpty) {
      await imageFile.writeAsBytes(response.inlineDataParts.first.bytes);
      return imageFile;
    }

    throw Exception('No image returned from base image generation');
  }

  Future<String> _uploadBaseImageToStorage(
    String userId,
    File imageFile,
  ) async {
    final path =
        'users/$userId/base_image_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child(path);
    await ref.putFile(imageFile);
    return ref.getDownloadURL();
  }

  Future<void> _saveBaseImageUrlToFirestore(
    String userId,
    String imageUrl,
  ) async {
    await _firestore.collection('users').doc(userId).set({
      'baseImageUrl': imageUrl,
      'baseImageGeneratedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<String?> getUserBaseImageUrl(String userId) async {
    return _getExistingBaseImage(userId);
  }

  /// Removes base image from Storage and Firestore (identity profile kept).
  Future<void> deleteUserBaseImage(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final existingUrl = doc.data()?['baseImageUrl'] as String?;

      if (existingUrl != null && existingUrl.isNotEmpty) {
        try {
          await _storage.refFromURL(existingUrl).delete();
        } catch (e) {
          debugPrint('⚠️ Could not delete base image from Storage: $e');
        }
      }

      await _firestore.collection('users').doc(userId).set({
        'baseImageUrl': FieldValue.delete(),
        'baseImageGeneratedAt': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Base image deleted for user $userId');
    } catch (e) {
      debugPrint('❌ Error deleting base image: $e');
      throw Exception('Failed to delete base image: $e');
    }
  }

  Future<String> regenerateUserBaseImage({
    required String userId,
    required List<String> bodyPhotoUrls,
    required List<String> facePhotoUrls,
    bool refreshIdentityProfile = true,
  }) async {
    await deleteUserBaseImage(userId);

    if (refreshIdentityProfile &&
        (bodyPhotoUrls.isNotEmpty || facePhotoUrls.isNotEmpty)) {
      await _identityService.analyzeUserIdentity(
        userId: userId,
        bodyPhotoUrls: bodyPhotoUrls,
        facePhotoUrls: facePhotoUrls,
      );
    }

    return generateUserBaseImage(
      userId: userId,
      bodyPhotoUrls: bodyPhotoUrls,
      facePhotoUrls: facePhotoUrls,
    );
  }
}
