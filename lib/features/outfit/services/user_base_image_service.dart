import 'dart:io';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/services/firestore_service.dart';
import 'package:image/image.dart' as img;

/// Genera y gestiona la imagen base del usuario para Virtual Try-On
///
/// Esta imagen es una versión optimizada generada por Gemini 3 Pro Image
/// que combina las fotos de face y body del usuario en una sola imagen
/// perfecta para aplicar outfits. Se genera UNA VEZ y se reutiliza.
class UserBaseImageService {
  final FirebaseFirestore _firestore = FirestoreService.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Dio _dio = Dio();

  /// Genera la imagen base del usuario usando sus fotos de face y body
  ///
  /// Esta imagen se genera una vez y se guarda en Storage y Firestore.
  /// Se reutiliza para todos los outfits futuros.
  ///
  /// Retorna la URL de la imagen base generada.
  /// Genera la imagen base del usuario usando sus fotos de face y body
  Future<String> generateUserBaseImage({
    required String userId,
    required List<String> bodyPhotoUrls,
    required List<String> facePhotoUrls,
  }) async {
    try {
      debugPrint('🎨 Generating user base image for user: $userId');

      // Verificar si ya existe una imagen base
      final existingBaseImage = await _getExistingBaseImage(userId);
      if (existingBaseImage != null) {
        debugPrint('✅ User base image already exists: $existingBaseImage');
        return existingBaseImage;
      }

      if (bodyPhotoUrls.isEmpty && facePhotoUrls.isEmpty) {
        throw Exception('No photos available to generate base image');
      }

      // 1. Descargar fotos del usuario
      final tempDir = await getTemporaryDirectory();
      final downloadedFiles = <File>[];

      // Descargar fotos de cuerpo (Máximo 2)
      for (final url in bodyPhotoUrls.take(2)) {
        try {
          final file = File(
            '${tempDir.path}/body_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          final response = await _dio.get(
            url,
            options: Options(responseType: ResponseType.bytes),
          );
          await file.writeAsBytes(response.data);
          downloadedFiles.add(file);
        } catch (e) {
          debugPrint('⚠️ Failed to download body photo: $e');
        }
      }

      // Descargar fotos de cara (Máximo 2)
      for (final url in facePhotoUrls.take(2)) {
        try {
          final file = File(
            '${tempDir.path}/face_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          final response = await _dio.get(
            url,
            options: Options(responseType: ResponseType.bytes),
          );
          await file.writeAsBytes(response.data);
          downloadedFiles.add(file);
        } catch (e) {
          debugPrint('⚠️ Failed to download face photo: $e');
        }
      }

      if (downloadedFiles.isEmpty) {
        throw Exception('Failed to download any user photos');
      }

      // 2. Generar imagen base con Gemini 3 Pro Image (Nano Banana Pro)
      final prompt = _buildBaseImagePrompt();

      // Configuración estricta de seguridad para evitar bloqueos por falsos positivos de desnudez
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

      // --- INTEGRACIÓN DE COMPRESIÓN ---
      final parts = <Part>[];

      for (final file in downloadedFiles) {
        debugPrint('⚙️ Optimizing image: ${file.path.split('/').last}');
        // Comprimimos y redimensionamos a 1024px para asegurar que el payload sea ligero
        final compressedBytes = await _compressImage(file);

        parts.add(InlineDataPart('image/jpeg', compressedBytes));
      }

      // El texto se agrega al final para dar contexto a las imágenes previas
      parts.add(TextPart(prompt));

      final content = [Content.multi(parts)];

      debugPrint('🤖 Calling Gemini 3 Pro Image (Nano Banana Pro)...');
      final response = await model.generateContent(content);

      // 3. Extraer imagen generada
      final baseImageFile = await _extractAndSaveBaseImage(response, userId);

      // 4. Subir a Firebase Storage
      final imageUrl = await _uploadBaseImageToStorage(userId, baseImageFile);

      // 5. Guardar URL en Firestore
      await _saveBaseImageUrlToFirestore(userId, imageUrl);

      // 6. Limpiar archivos temporales
      for (final file in downloadedFiles) {
        try {
          await file.delete();
        } catch (_) {}
      }
      try {
        await baseImageFile.delete();
      } catch (_) {}

      debugPrint('✅ User base image successfully created: $imageUrl');
      return imageUrl;
    } catch (e) {
      if (e is FirebaseAIException) {
        debugPrint('❌ Firebase AI Error: ${e.message}');
        debugPrint('❌ Code: $e');
        throw Exception('AI Error: ${e.message}');
      } else {
        debugPrint('❌ Unexpected Error: $e');
        throw Exception('Failed to generate user base image: $e');
      }
    }
  }

  /// Obtiene la imagen base existente del usuario (si existe)
  Future<String?> _getExistingBaseImage(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final baseImageUrl = doc.data()?['baseImageUrl'] as String?;
      if (baseImageUrl != null && baseImageUrl.isNotEmpty) {
        return baseImageUrl;
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ Error checking existing base image: $e');
      return null;
    }
  }

  /// Construye el prompt para generar la imagen base
  String _buildBaseImagePrompt() {
    return """
[OUTPUT_SPECIFICATIONS]
MODE: IMAGE_GENERATION
FORMAT: image/jpeg
ASPECT_RATIO: 3:4
RESOLUTION: 1024x1024
QUALITY: HIGH_FASHION_EDITORIAL

[INSTRUCTION]
Generate a single, high-quality, professional fashion model photograph.

[REQUIREMENTS]
- Combine the face and body features from the provided reference photos.
- Composition: Full-body shot (from head to feet) or 3/4 shot.
- Pose: Neutral, standing straight, shoulders back, arms slightly away from the body (A-pose or T-pose preferred for virtual try-on).
- Visibility: Face and body must be clearly visible, front-facing, with no obstructions.
- Background: Minimalist, clean, neutral gray or white studio background.
- Lighting: Professional softbox lighting, no harsh shadows.
- Appearance: Natural skin textures, sharp focus, neutral expression.

[CLOTHING_NOTE]
The subject should be wearing very simple, form-fitting, neutral base-layer clothing (like a white or black tank top and leggings) that does not obscure the body's silhouette.

[FINAL_OBJECTIVE]
This image will be used as a base template for a virtual try-on application. It must be anatomically accurate and perfectly lit.
""";
  }

  Future<File> _extractAndSaveBaseImage(
    GenerateContentResponse response,
    String userId,
  ) async {
    final tempDir = await getTemporaryDirectory();
    // Usamos un nombre único para evitar colisiones de caché
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final imageFile = File('${tempDir.path}/base_gen_${userId}_$timestamp.jpg');

    try {
      debugPrint('🔍 Analizando respuesta de Gemini 3...');

      // 1. Intentar extraer de los candidatos (Estructura estándar de Gemini 3)
      if (response.candidates.isNotEmpty) {
        final candidate = response.candidates.first;

        // Buscamos dentro de las partes del contenido del candidato
        for (final part in candidate.content.parts) {
          if (part is InlineDataPart) {
            final mimeType = part.mimeType;
            if (mimeType.startsWith('image/')) {
              debugPrint(
                '✅ Imagen encontrada en Candidate Part (Mime: $mimeType)',
              );
              await imageFile.writeAsBytes(part.bytes);
              return imageFile;
            }
          }
        }
      }

      // 2. Fallback: Revisar inlineDataParts en el nivel superior de la respuesta
      // Algunas versiones del SDK de Firebase AI aplanan la respuesta aquí
      if (response.inlineDataParts.isNotEmpty) {
        final imagePart = response.inlineDataParts.first;
        debugPrint('✅ Imagen encontrada en inlineDataParts directos');
        await imageFile.writeAsBytes(imagePart.bytes);
        return imageFile;
      }

      // 3. Si llegamos aquí, el modelo no generó una imagen
      // Esto puede pasar por filtros de seguridad (SafetySettings)
      debugPrint('❌ El modelo no devolvió partes de imagen.');
      if (response.text != null && response.text!.isNotEmpty) {
        debugPrint('Texto de respuesta (si hubo): ${response.text}');
      }

      throw Exception(
        'No se pudo extraer la imagen. El modelo podría haber bloqueado la generación por políticas de seguridad o falta de instrucciones claras.',
      );
    } catch (e) {
      debugPrint('❌ Error crítico en _extractAndSaveBaseImage: $e');
      rethrow;
    }
  }

  Future<Uint8List> _compressImage(File file) async {
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    // Redimensionar a un máximo de 1024px para mantener calidad pero bajar peso
    final resized = img.copyResize(image, width: 1024);

    // Comprimir a JPG con calidad 80
    return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
  }

  /// Sube la imagen base a Firebase Storage
  Future<String> _uploadBaseImageToStorage(
    String userId,
    File imageFile,
  ) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = 'users/$userId/base_image_$timestamp.jpg';
      final ref = _storage.ref().child(path);

      await ref.putFile(imageFile);
      final url = await ref.getDownloadURL();

      debugPrint('✅ Base image uploaded to Storage: $url');
      return url;
    } catch (e) {
      debugPrint('❌ Error uploading base image to Storage: $e');
      throw Exception('Failed to upload base image: $e');
    }
  }

  /// Guarda la URL de la imagen base en Firestore
  Future<void> _saveBaseImageUrlToFirestore(
    String userId,
    String imageUrl,
  ) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'baseImageUrl': imageUrl,
        'baseImageGeneratedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ Base image URL saved to Firestore');
    } catch (e) {
      debugPrint('❌ Error saving base image URL to Firestore: $e');
      throw Exception('Failed to save base image URL: $e');
    }
  }

  /// Obtiene la URL de la imagen base del usuario (si existe)
  Future<String?> getUserBaseImageUrl(String userId) async {
    return await _getExistingBaseImage(userId);
  }

  /// Regenera la imagen base (útil si el usuario sube nuevas fotos)
  Future<String> regenerateUserBaseImage({
    required String userId,
    required List<String> bodyPhotoUrls,
    required List<String> facePhotoUrls,
  }) async {
    // Eliminar imagen base existente
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      final existingUrl = doc.data()?['baseImageUrl'] as String?;

      if (existingUrl != null) {
        // Intentar eliminar de Storage
        try {
          final ref = _storage.refFromURL(existingUrl);
          await ref.delete();
        } catch (e) {
          debugPrint('⚠️ Could not delete old base image from Storage: $e');
        }

        // Eliminar de Firestore
        await _firestore.collection('users').doc(userId).update({
          'baseImageUrl': FieldValue.delete(),
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error cleaning up old base image: $e');
    }

    // Generar nueva imagen base
    return await generateUserBaseImage(
      userId: userId,
      bodyPhotoUrls: bodyPhotoUrls,
      facePhotoUrls: facePhotoUrls,
    );
  }
}
