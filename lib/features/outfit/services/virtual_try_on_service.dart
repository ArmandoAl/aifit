import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../../../core/constants/identity_consistency_prompt.dart';
import '../../../core/platform/network_image_loader.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/image_compression_util.dart';
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

      final garmentBytes = <Uint8List>[];

      for (final imageUrl in request.itemImageUrls) {
        try {
          garmentBytes.add(
            await NetworkImageLoader.downloadBytes(_dio, imageUrl),
          );
        } catch (e) {
          debugPrint('⚠️ Failed to download item image: $e');
        }
      }

      Uint8List? userBodyBytes;
      Uint8List? userFaceBytes;

      if (userBaseImageBytes == null) {
        if (request.userBodyPhotoUrl != null) {
          try {
            userBodyBytes = await NetworkImageLoader.downloadBytes(
              _dio,
              request.userBodyPhotoUrl!,
            );
          } catch (e) {
            debugPrint('⚠️ Failed to download user body photo: $e');
          }
        }
        if (request.userFacePhotoUrl != null) {
          try {
            userFaceBytes = await NetworkImageLoader.downloadBytes(
              _dio,
              request.userFacePhotoUrl!,
            );
          } catch (e) {
            debugPrint('⚠️ Failed to download user face photo: $e');
          }
        }
      }

      final prompt = _buildTryOnPrompt(request);

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

      if (userBaseImageBytes != null) {
        final bytes = await ImageCompressionUtil.compressIdentityBytes(
          userBaseImageBytes,
        );
        parts.add(InlineDataPart('image/jpeg', bytes));
      } else {
        if (userBodyBytes != null) {
          final bytes = await ImageCompressionUtil.compressIdentityBytes(
            userBodyBytes,
          );
          parts.add(InlineDataPart('image/jpeg', bytes));
        }
        if (userFaceBytes != null) {
          final bytes = await ImageCompressionUtil.compressIdentityBytes(
            userFaceBytes,
          );
          parts.add(InlineDataPart('image/jpeg', bytes));
        }
      }

      for (final bytes in garmentBytes) {
        final compressed = await ImageCompressionUtil.compressBytes(
          bytes,
          payload: AiImagePayload.garment,
        );
        parts.add(InlineDataPart('image/jpeg', compressed));
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

  String _buildTryOnPrompt(VirtualTryOnRequest request) {
    final outfit = request.outfit;
    final identityBlock = IdentityConsistencyPrompt.buildTryOnBlock(
      request.identityProfile,
    );

    return """
Generate a realistic ecommerce-style photograph: the SAME person wearing a complete outfit.

$identityBlock

OUTFIT DETAILS:
- Top: ${outfit.topId ?? 'N/A'}
- Bottom: ${outfit.bottomId ?? 'N/A'}
- Shoes: ${outfit.shoesId ?? 'N/A'}
${outfit.outerwearId != null ? '- Outerwear: ${outfit.outerwearId}' : ''}

REQUIREMENTS:
- Apply garment images to the person in the identity/base reference image
- Clothing must fit naturally; colors and textures from garment references
- Clean neutral or simple background, soft even lighting
- Natural pose, realistic proportions
- Premium ecommerce quality — NOT editorial or cinematic

Generate one high-quality image of the same individual wearing the full outfit.
""";
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
