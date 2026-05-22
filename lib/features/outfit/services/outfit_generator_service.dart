import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../../../core/platform/network_image_loader.dart';
import '../../../core/utils/image_compression_util.dart';
import '../../wardrobe/domain/wardrobe_item_model.dart';
import '../domain/outfit_models.dart';

/// Genera outfits usando Gemini 2.5 Pro con análisis de imágenes
///
/// Fase 3: Analiza imágenes de prendas filtradas y genera 3 outfits
class OutfitGeneratorService {
  final Dio _dio = Dio();

  /// Genera 3 outfits basado en prendas filtradas
  ///
  /// Descarga imágenes de prendas, las analiza con Gemini 2.5 Pro,
  /// y retorna 3 outfits estructurados.
  Future<List<GeneratedOutfit>> generateOutfits({
    required FilteredWardrobe filteredWardrobe,
    required OutfitIntent intent,
  }) async {
    try {
      debugPrint(
        '🎨 Generating outfits from ${filteredWardrobe.totalItems} filtered items',
      );

      if (filteredWardrobe.isEmpty) {
        throw Exception('No items available to generate outfits');
      }

      // 1. Preparar contexto de prendas para el prompt
      final wardrobeContext = _buildWardrobeContext(filteredWardrobe);

      // 2. Construir prompt para Gemini
      final prompt = _buildOutfitGenerationPrompt(intent, wardrobeContext);

      // 3. Descargar imágenes de prendas (máximo 20 para optimizar)
      final itemImages = await _downloadItemImages(
        filteredWardrobe,
        maxItems: 12,
      );

      debugPrint('📥 Downloaded ${itemImages.length} item images');

      // 4. Llamar a Gemini 2.5 Flash con imágenes (multimodal que analiza imágenes y genera JSON)
      // Configuración estricta de seguridad para evitar bloqueos
      final model = FirebaseAI.vertexAI().generativeModel(
        model: 'gemini-2.5-flash',
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json', // Garantiza JSON válido
          temperature: 0.3, // Baja temperatura para ser más determinista
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

      // Comprimir y agregar imágenes
      for (final entry in itemImages.entries) {
        debugPrint('⚙️ Compressing garment for item: ${entry.key}');
        final compressedBytes = await ImageCompressionUtil.compressBytes(
          entry.value,
          payload: AiImagePayload.garment,
        );
        parts.add(InlineDataPart('image/jpeg', compressedBytes));
      }

      // El texto se agrega al final para dar contexto a las imágenes previas
      parts.add(TextPart(prompt));

      final content = [Content.multi(parts)];

      debugPrint('🤖 Calling Gemini 2.5 Flash to generate outfits...');
      final response = await model.generateContent(content);

      // 5. Parsear respuesta
      // Al usar responseMimeType: 'application/json', el texto SIEMPRE es JSON válido
      final responseText = response.text;
      if (responseText == null) {
        throw Exception('Empty response from AI');
      }

      debugPrint('✅ Gemini response received');

      // Ya no hace falta limpieza manual de markdown
      final jsonData = jsonDecode(responseText);

      // 6. Convertir a lista de GeneratedOutfit
      final outfits = _parseOutfitsFromJson(jsonData);

      debugPrint('✅ Generated ${outfits.length} outfits');
      return outfits;
    } catch (e) {
      if (e is FirebaseAIException) {
        debugPrint('❌ Firebase AI Error: ${e.message}');
        debugPrint('❌ Code: $e');
        throw Exception('AI Error: ${e.message}');
      } else {
        debugPrint('❌ Error generating outfits: $e');
        throw Exception('Failed to generate outfits: $e');
      }
    }
  }

  static String _metadataSummary(WardrobeItem item) {
    final m = item.aiMetadata;
    if (m == null || m.isEmpty) return '';
    final parts = <String>[];
    if (m.fashionAesthetic?.primary != null) {
      parts.add('aesthetic:${m.fashionAesthetic!.primary}');
    }
    if (m.styleScores?['formality'] != null) {
      parts.add('formality:${m.styleScores!['formality']!.toStringAsFixed(2)}');
    }
    final topOccasion = m.occasionVectors?.entries.toList()
      ?..sort((a, b) => b.value.compareTo(a.value));
    if (topOccasion != null && topOccasion.isNotEmpty) {
      parts.add('best_occasion:${topOccasion.first.key}');
    }
    return parts.isEmpty ? '' : ', AI: ${parts.join(', ')}';
  }

  /// Construye contexto de prendas para el prompt
  String _buildWardrobeContext(FilteredWardrobe wardrobe) {
    final buffer = StringBuffer();

    if (wardrobe.tops.isNotEmpty) {
      buffer.writeln('TOPS:');
      for (final item in wardrobe.tops) {
        buffer.writeln(
          '  - ID: ${item.id}, Type: ${item.subType}, Colors: ${item.colors}, Style: ${item.styleTags}${_metadataSummary(item)}',
        );
      }
    }

    if (wardrobe.bottoms.isNotEmpty) {
      buffer.writeln('BOTTOMS:');
      for (final item in wardrobe.bottoms) {
        buffer.writeln(
          '  - ID: ${item.id}, Type: ${item.subType}, Colors: ${item.colors}, Style: ${item.styleTags}${_metadataSummary(item)}',
        );
      }
    }

    if (wardrobe.shoes.isNotEmpty) {
      buffer.writeln('SHOES:');
      for (final item in wardrobe.shoes) {
        buffer.writeln(
          '  - ID: ${item.id}, Type: ${item.subType}, Colors: ${item.colors}, Style: ${item.styleTags}${_metadataSummary(item)}',
        );
      }
    }

    if (wardrobe.outerwear.isNotEmpty) {
      buffer.writeln('OUTERWEAR:');
      for (final item in wardrobe.outerwear) {
        buffer.writeln(
          '  - ID: ${item.id}, Type: ${item.subType}, Colors: ${item.colors}, Style: ${item.styleTags}${_metadataSummary(item)}',
        );
      }
    }

    return buffer.toString();
  }

  /// Construye prompt para generación de outfits
  String _buildOutfitGenerationPrompt(
    OutfitIntent intent,
    String wardrobeContext,
  ) {
    return """
You are an expert fashion stylist. Analyze the clothing items in the images and create 3 complete, stylish outfits.

USER REQUEST: ${intent.userPrompt ?? 'Create stylish outfits'}

REQUIREMENTS:
${intent.occasion != null ? '- Occasion: ${intent.occasion}' : ''}
${intent.preferredColors.isNotEmpty ? '- Preferred colors: ${intent.preferredColors.join(', ')}' : ''}
${intent.styleTags.isNotEmpty ? '- Style: ${intent.styleTags.join(', ')}' : ''}
${intent.season != null ? '- Season: ${intent.season}' : ''}

AVAILABLE ITEMS (with images):
$wardrobeContext

TASK:
1. Analyze the images of clothing items
2. Create 3 different, complete outfits
3. Each outfit must include: Top + Bottom + Shoes (Outerwear optional)
4. Consider color compatibility, style harmony, and occasion appropriateness
5. Rank outfits by how well they match the user's request

Return a JSON array with exactly 3 outfits in this format:
[
  {
    "id": "outfit_1",
    "topId": "item_id",
    "bottomId": "item_id",
    "shoesId": "item_id",
    "outerwearId": "item_id" // Optional
    "matchPercentage": 95,
    "explanation": "Why this outfit works well...",
    "compatibilityScore": 0.92
  },
  {
    "id": "outfit_2",
    ...
  },
  {
    "id": "outfit_3",
    ...
  }
]

IMPORTANT:
- Use ONLY item IDs from the wardrobe context above
- Each outfit must be unique (different combinations)
- matchPercentage: 0-100 (how well it matches user request)
- compatibilityScore: 0.0-1.0 (how well items work together)
- Return ONLY valid JSON array, no markdown, no explanations
""";
  }

  /// Descarga imágenes de prendas para análisis
  Future<Map<String, Uint8List>> _downloadItemImages(
    FilteredWardrobe wardrobe, {
    int maxItems = 20,
  }) async {
    final downloadedImages = <String, Uint8List>{};

    final allItems = [
      ...wardrobe.tops,
      ...wardrobe.bottoms,
      ...wardrobe.shoes,
      ...wardrobe.outerwear,
    ].take(maxItems).toList();

    for (final item in allItems) {
      try {
        downloadedImages[item.id] = await NetworkImageLoader.downloadBytes(
          _dio,
          item.imageUrl,
        );
      } catch (e) {
        debugPrint('⚠️ Failed to download image for item ${item.id}: $e');
      }
    }

    return downloadedImages;
  }

  /// Parsea JSON de respuesta a lista de GeneratedOutfit
  List<GeneratedOutfit> _parseOutfitsFromJson(dynamic jsonData) {
    try {
      List<dynamic> outfitsList;

      if (jsonData is List) {
        outfitsList = jsonData;
      } else if (jsonData is Map && jsonData.containsKey('outfits')) {
        outfitsList = jsonData['outfits'] as List<dynamic>;
      } else if (jsonData is Map && jsonData.containsKey('results')) {
        outfitsList = jsonData['results'] as List<dynamic>;
      } else {
        // Intentar extraer cualquier array del JSON
        outfitsList = [jsonData];
      }

      return outfitsList
          .map(
            (outfitJson) =>
                GeneratedOutfit.fromJson(outfitJson as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      debugPrint('❌ Error parsing outfits: $e');
      debugPrint('   JSON data: $jsonData');
      throw Exception('Failed to parse outfits from AI response: $e');
    }
  }
}
