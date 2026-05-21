import 'dart:io';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/constants/identity_consistency_prompt.dart';
import '../../../core/utils/image_compression_util.dart';
import '../domain/outfit_models.dart';
import 'user_base_image_service.dart';

/// Genera imagen de Virtual Try-On usando Gemini 3 Pro Image
/// 
/// Fase 4: Combina prendas + imagen base del usuario para generar imagen final
/// 
/// OPTIMIZACIÓN: Usa la imagen base del usuario (generada una vez) en lugar de
/// descargar múltiples fotos cada vez. Esto ahorra costos y tiempo.
class VirtualTryOnService {
  final Dio _dio = Dio();
  final UserBaseImageService _baseImageService = UserBaseImageService();
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Genera imagen del usuario usando el outfit
  /// 
  /// OPTIMIZACIÓN: Usa la imagen base del usuario (si existe) en lugar de
  /// descargar múltiples fotos. Si no existe, usa las fotos proporcionadas.
  /// 
  /// Descarga imágenes de prendas y la imagen base del usuario,
  /// luego usa Gemini 3 Pro Image para generar imagen final.
  Future<VirtualTryOnResult> generateTryOnImage({
    required VirtualTryOnRequest request,
    required String userId,
  }) async {
    try {
      debugPrint('🎨 Generating Virtual Try-On image for outfit: ${request.outfit.id}');

      // 1. Obtener imagen base del usuario (OPTIMIZACIÓN)
      File? userBaseImageFile;
      String? userBaseImageUrl = await _baseImageService.getUserBaseImageUrl(userId);
      
      if (userBaseImageUrl != null) {
        // Usar imagen base existente (OPTIMIZACIÓN)
        debugPrint('✅ Using existing user base image');
        try {
          final tempDir = await getTemporaryDirectory();
          userBaseImageFile = File('${tempDir.path}/user_base_${DateTime.now().millisecondsSinceEpoch}.jpg');
          final response = await _dio.get(
            userBaseImageUrl,
            options: Options(responseType: ResponseType.bytes),
          );
          await userBaseImageFile.writeAsBytes(response.data);
        } catch (e) {
          debugPrint('⚠️ Failed to download user base image, falling back to individual photos: $e');
          userBaseImageFile = null;
        }
      } else {
        // Fallback: usar fotos individuales si no hay imagen base
        debugPrint('⚠️ No base image found, using individual photos');
      }

      // 2. Descargar imágenes necesarias
      final tempDir = await getTemporaryDirectory();
      final downloadedFiles = <String, File>{};

      // Descargar imágenes de prendas
      for (final imageUrl in request.itemImageUrls) {
        try {
          final fileName = imageUrl.split('/').last.split('?').first;
          final file = File('${tempDir.path}/item_${DateTime.now().millisecondsSinceEpoch}_$fileName');
          
          final response = await _dio.get(
            imageUrl,
            options: Options(responseType: ResponseType.bytes),
          );
          
          await file.writeAsBytes(response.data);
          downloadedFiles['item_$fileName'] = file;
        } catch (e) {
          debugPrint('⚠️ Failed to download item image: $e');
        }
      }

      // Descargar fotos individuales solo si no hay imagen base
      if (userBaseImageFile == null) {
        // Descargar foto de cuerpo del usuario (si existe)
        if (request.userBodyPhotoUrl != null) {
          try {
            final userBodyFile = File('${tempDir.path}/user_body_${DateTime.now().millisecondsSinceEpoch}.jpg');
            final response = await _dio.get(
              request.userBodyPhotoUrl!,
              options: Options(responseType: ResponseType.bytes),
            );
            await userBodyFile.writeAsBytes(response.data);
            downloadedFiles['user_body'] = userBodyFile;
          } catch (e) {
            debugPrint('⚠️ Failed to download user body photo: $e');
          }
        }

        // Descargar foto de cara del usuario (si existe)
        if (request.userFacePhotoUrl != null) {
          try {
            final userFaceFile = File('${tempDir.path}/user_face_${DateTime.now().millisecondsSinceEpoch}.jpg');
            final response = await _dio.get(
              request.userFacePhotoUrl!,
              options: Options(responseType: ResponseType.bytes),
            );
            await userFaceFile.writeAsBytes(response.data);
            downloadedFiles['user_face'] = userFaceFile;
          } catch (e) {
            debugPrint('⚠️ Failed to download user face photo: $e');
          }
        }
      }

      debugPrint('📥 Downloaded ${downloadedFiles.length} item images${userBaseImageFile != null ? ' + 1 base image' : ''}');

      final prompt = _buildTryOnPrompt(request);

      // 3. Llamar a Gemini 2.5 Flash Image (mismo modelo que funcionó para base image)
      // Configuración estricta de seguridad para evitar bloqueos
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

      // Construir contenido: primero imágenes comprimidas, luego texto
      final parts = <Part>[];

      // Comprimir y agregar imagen base del usuario (OPTIMIZACIÓN) o fotos individuales
      if (userBaseImageFile != null) {
        debugPrint('⚙️ Encoding identity base image (high quality)');
        final bytes = await ImageCompressionUtil.compressIdentity(
          userBaseImageFile,
        );
        parts.add(InlineDataPart('image/jpeg', bytes));
      } else {
        if (downloadedFiles.containsKey('user_body')) {
          final bytes = await ImageCompressionUtil.compressIdentity(
            downloadedFiles['user_body']!,
          );
          parts.add(InlineDataPart('image/jpeg', bytes));
        }
        if (downloadedFiles.containsKey('user_face')) {
          final bytes = await ImageCompressionUtil.compressIdentity(
            downloadedFiles['user_face']!,
          );
          parts.add(InlineDataPart('image/jpeg', bytes));
        }
      }

      for (final entry in downloadedFiles.entries) {
        if (entry.key != 'user_body' && entry.key != 'user_face') {
          debugPrint('⚙️ Compressing garment: ${entry.key}');
          final bytes = await ImageCompressionUtil.compressGarment(entry.value);
          parts.add(InlineDataPart('image/jpeg', bytes));
        }
      }

      // El texto se agrega al final para dar contexto a las imágenes previas
      parts.add(TextPart(prompt));

      final content = [Content.multi(parts)];

      debugPrint('🤖 Calling Gemini 2.5 Flash Image to generate try-on image...');
      final response = await model.generateContent(content);

      // 4. Procesar respuesta y extraer imagen (usando la misma lógica que user_base_image_service)
      final imageUrl = await _extractImageUrl(response);

      // 5. Limpiar archivos temporales
      if (userBaseImageFile != null) {
        try {
          await userBaseImageFile.delete();
        } catch (_) {
          // Ignore cleanup errors
        }
      }
      for (final file in downloadedFiles.values) {
        try {
          await file.delete();
        } catch (_) {
          // Ignore cleanup errors
        }
      }

      if (imageUrl == null) {
        throw Exception('Failed to extract image URL from response');
      }

      debugPrint('✅ Virtual Try-On image generated: $imageUrl');

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

  /// Extrae URL de imagen de la respuesta
  /// 
  /// Gemini 2.5 Flash Image retorna la imagen en response.inlineDataParts o candidates
  /// Necesitamos subir la imagen a Storage y retornar la URL
  /// Usa la misma lógica que user_base_image_service que ya funciona
  Future<String?> _extractImageUrl(GenerateContentResponse response) async {
    try {
      debugPrint('🔍 Analizando respuesta de Gemini 2.5 Flash Image...');

      // 1. Intentar extraer de los candidatos (Estructura estándar de Gemini)
      if (response.candidates.isNotEmpty) {
        final candidate = response.candidates.first;

        // Buscamos dentro de las partes del contenido del candidato
        for (final part in candidate.content.parts) {
          if (part is InlineDataPart) {
            final mimeType = part.mimeType;
            if (mimeType != null && mimeType.startsWith('image/')) {
              debugPrint('✅ Imagen encontrada en Candidate Part (Mime: $mimeType)');
              final imageBytes = part.bytes;
              
              // Guardar temporalmente
              final tempDir = await getTemporaryDirectory();
              final tempFile = File('${tempDir.path}/tryon_${DateTime.now().millisecondsSinceEpoch}.jpg');
              await tempFile.writeAsBytes(imageBytes);
              
              // Subir a Storage y obtener URL (en carpeta outfits/)
              final userId = _auth.currentUser?.uid;
              if (userId == null) throw Exception('User not authenticated');
              
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              final path = 'users/$userId/outfits/tryon_$timestamp.jpg';
              final ref = _storage.ref().child(path);
              
              await ref.putFile(tempFile);
              final url = await ref.getDownloadURL();
              
              // Limpiar archivo temporal
              try {
                await tempFile.delete();
              } catch (_) {}
              
              return url;
            }
          }
        }
      }

      // 2. Fallback: Revisar inlineDataParts en el nivel superior de la respuesta
      if (response.inlineDataParts.isNotEmpty) {
        final imagePart = response.inlineDataParts.first;
        debugPrint('✅ Imagen encontrada en inlineDataParts directos');
        final imageBytes = imagePart.bytes;
        
        // Guardar temporalmente
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/tryon_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await tempFile.writeAsBytes(imageBytes);
        
        // Subir a Storage y obtener URL (en carpeta outfits/)
        final userId = _auth.currentUser?.uid;
        if (userId == null) throw Exception('User not authenticated');
        
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final path = 'users/$userId/outfits/tryon_$timestamp.jpg';
        final ref = _storage.ref().child(path);
        
        await ref.putFile(tempFile);
        final url = await ref.getDownloadURL();
        
        // Limpiar archivo temporal
        try {
          await tempFile.delete();
        } catch (_) {}
        
        return url;
      }

      // 3. Si llegamos aquí, el modelo no generó una imagen
      debugPrint('❌ El modelo no devolvió partes de imagen.');
      if (response.text != null && response.text!.isNotEmpty) {
        debugPrint('Texto de respuesta (si hubo): ${response.text}');
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Error extracting image URL: $e');
      return null;
    }
  }

}
