import 'dart:convert';
import 'dart:io';
import 'package:aifit/paths.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import '../utils/image_compression_util.dart';

class FirebaseAIServiceImpl implements AIService {
  @override
  Future<AIResponse> generateContent({
    required String prompt,
    List<File>? images,
    String? modelId,
  }) async {
    try {
      // 1. Obtener el modelo (gemini-2.5-flash es rápido y gratuito)
      final model = FirebaseAI.vertexAI().generativeModel(
        model: modelId ?? 'gemini-2.5-flash',
      );

      // 2. Construir el contenido (Texto + Imágenes)
      final parts = <Part>[TextPart(prompt)];

      if (images != null) {
        for (var file in images) {
          final bytes = await ImageCompressionUtil.compressGarment(file);
          parts.add(InlineDataPart('image/jpeg', bytes));
        }
      }

      final content = [Content.multi(parts)];

      // 3. Llamada a la API
      final response = await model.generateContent(content);

      return AIResponse(
        text: response.text ?? "Lo siento, no pude generar una respuesta.",
      );
    } catch (e) {
      throw Exception("Error en FirebaseAI: $e");
    }
  }

  @override
  Future<Map<String, dynamic>> analyzeImageToJson({
    required File image,
    required String promptInstruction,
    AiImagePayload imagePayload = AiImagePayload.garment,
  }) async {
    try {
      // Usamos 'gemini-2.5-pro' porque es mejor siguiendo instrucciones de JSON estricto
      final model = FirebaseAI.vertexAI().generativeModel(
        model: 'gemini-2.5-pro',
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json', // 🚨 Forzamos modo JSON
        ),
      );

      final bytes = await ImageCompressionUtil.compress(
        image,
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

      // Limpieza preventiva por si el modelo incluye markdown ```json ... ```
      final cleanJson = jsonString
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      return jsonDecode(cleanJson) as Map<String, dynamic>;
    } catch (e) {
      debugPrint("Error analizando imagen: $e");
      // Retornar mapa vacío o lanzar error según prefieras
      throw Exception("Fallo al analizar la imagen: $e");
    }
  }
}
