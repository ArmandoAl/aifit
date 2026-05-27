import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../../../core/constants/identity_consistency_prompt.dart';
import '../../../core/platform/network_image_loader.dart';
import '../../../core/services/image_byte_cache.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/image_compression_util.dart';
import '../../../core/utils/ui_frame_yield.dart';
import '../domain/outfit_models.dart';
import 'user_base_image_service.dart';

class VirtualTryOnService {
  final Dio _dio = Dio();
  final UserBaseImageService _baseImageService = UserBaseImageService();
  final StorageService _storageService = StorageService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<VirtualTryOnResult> generateTryOnImage({
    required VirtualTryOnRequest request,
    required String userId,
  }) async {
    try {
      debugPrint(
        '🎨 Generating Virtual Try-On image for outfit: ${request.outfit.id}',
      );

      Uint8List? userBaseImageBytes;
      final userBaseImageUrl =
          await _baseImageService.getUserBaseImageUrl(userId);

      if (userBaseImageUrl != null) {
        debugPrint('✅ Using existing user base image');
        try {
          userBaseImageBytes =
              await NetworkImageLoader.downloadBytes(_dio, userBaseImageUrl);
        } catch (e) {
          debugPrint(
            '⚠️ Failed to download user base image, falling back: $e',
          );
          userBaseImageBytes = null;
        }
      }

      // Face anchor improves likeness even when base image exists (close-up detail).
      Uint8List? userFaceBytes;
      if (request.userFacePhotoUrl != null &&
          request.userFacePhotoUrl!.isNotEmpty) {
        try {
          userFaceBytes = await NetworkImageLoader.downloadBytes(
            _dio,
            request.userFacePhotoUrl!,
          );
          debugPrint('✅ Face anchor loaded for try-on');
        } catch (e) {
          debugPrint('⚠️ Failed to download face anchor: $e');
        }
      }

      final garmentBytes = await ImageByteCache.instance.prepareGarmentBytesForUrls(
        dio: _dio,
        urls: request.itemImageUrls,
      );

      Uint8List? userBodyBytes;
      if (userBaseImageBytes == null && request.userBodyPhotoUrl != null) {
        try {
          userBodyBytes = await NetworkImageLoader.downloadBytes(
            _dio,
            request.userBodyPhotoUrl!,
          );
        } catch (e) {
          debugPrint('⚠️ Failed to download user body photo: $e');
        }
      }

      final hasBase = userBaseImageBytes != null;
      final hasFace = userFaceBytes != null;
      final hasBody = userBodyBytes != null;

      debugPrint(
        '📸 Try-on payload: base=$hasBase face=$hasFace body=$hasBody '
        'garments=${garmentBytes.length} '
        'identityProfile=${request.identityProfile != null && !request.identityProfile!.isEmpty}',
      );

      final prompt = IdentityConsistencyPrompt.buildTryOnPrompt(
        profile: request.identityProfile,
        hasBaseImage: hasBase,
        hasFaceAnchor: hasFace,
        garmentCount: garmentBytes.length,
      );

      await yieldToUi();

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

      final parts = <Part>[];

      // Image 1: identity base — send raw to avoid double JPEG loss on face detail.
      if (userBaseImageBytes != null) {
        parts.add(InlineDataPart('image/jpeg', userBaseImageBytes));
      } else if (userBodyBytes != null) {
        final bytes = await ImageCompressionUtil.compressIdentityBytes(
          userBodyBytes,
        );
        parts.add(InlineDataPart('image/jpeg', bytes));
      }

      // Image 2: face close-up anchor (glasses, facial detail).
      if (userFaceBytes != null) {
        final bytes = await ImageCompressionUtil.compressIdentityBytes(
          userFaceBytes,
        );
        parts.add(InlineDataPart('image/jpeg', bytes));
      }

      for (final bytes in garmentBytes) {
        parts.add(InlineDataPart('image/jpeg', bytes));
      }

      parts.add(TextPart(prompt));

      final response = await model.generateContent([Content.multi(parts)]);
      final imageUrl = await _extractAndUploadImage(response);

      if (imageUrl == null) {
        throw Exception('Failed to extract image URL from response');
      }

      return VirtualTryOnResult(
        outfitId: request.outfit.id,
        generatedImageUrl: imageUrl,
        generatedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ Error generating try-on image: $e');
      throw Exception('Failed to generate try-on image: $e');
    }
  }

  Future<String?> _extractAndUploadImage(GenerateContentResponse response) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      Uint8List? imageBytes;

      if (response.candidates.isNotEmpty) {
        for (final part in response.candidates.first.content.parts) {
          if (part is InlineDataPart &&
              part.mimeType.startsWith('image/')) {
            imageBytes = part.bytes;
            break;
          }
        }
      }

      imageBytes ??= response.inlineDataParts.isNotEmpty
          ? response.inlineDataParts.first.bytes
          : null;

      if (imageBytes == null) return null;

      return _storageService.uploadOutfitTryOn(
        userId: userId,
        bytes: imageBytes,
      );
    } catch (e) {
      debugPrint('❌ Error extracting try-on image: $e');
      return null;
    }
  }
}
