import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../interfaces/ai_service.dart';
import '../platform/app_image.dart';
import '../utils/image_compression_util.dart';

class FirebaseAIServiceImpl implements AIService {
  @override
  Future<AIResponse> generateContent({
    required String prompt,
    List<AppImage>? images,
    String? modelId,
  }) async {
    try {
      final model = FirebaseAI.vertexAI().generativeModel(
        model: modelId ?? 'gemini-2.5-flash',
      );

      final parts = <Part>[TextPart(prompt)];

      if (images != null) {
        for (final image in images) {
          final bytes = await ImageCompressionUtil.compressGarment(image);
          parts.add(InlineDataPart('image/jpeg', bytes));
        }
      }

      final response = await model.generateContent([Content.multi(parts)]);

      return AIResponse(
        text: response.text ?? "Lo siento, no pude generar una respuesta.",
      );
    } catch (e) {
      throw Exception("Error en FirebaseAI: $e");
    }
  }

  @override
  Future<Map<String, dynamic>> analyzeImageToJson({
    required AppImage image,
    required String promptInstruction,
    AiImagePayload imagePayload = AiImagePayload.garment,
  }) async {
    try {
      final modelName = imagePayload == AiImagePayload.garment
          ? 'gemini-2.5-flash'
          : 'gemini-2.5-pro';

      final model = FirebaseAI.vertexAI().generativeModel(
        model: modelName,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
      );

      final bytes = imagePayload == AiImagePayload.raw
          ? image.bytes
          : await ImageCompressionUtil.compressBytes(
              image.bytes,
              payload: imagePayload,
            );

      final content = [
        Content.multi([
          TextPart(promptInstruction),
          InlineDataPart('image/jpeg', bytes),
        ]),
      ];

      final response = await model.generateContent(content);
      final jsonString = response.text;

      if (jsonString == null) throw Exception("Respuesta vacía de IA");

      final cleanJson = jsonString
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      return jsonDecode(cleanJson) as Map<String, dynamic>;
    } catch (e) {
      debugPrint("Error analizando imagen: $e");
      throw Exception("Fallo al analizar la imagen: $e");
    }
  }
}
