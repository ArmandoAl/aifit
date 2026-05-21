import 'dart:io';
import '../utils/image_compression_util.dart';

/// Respuesta genérica para desacoplar la librería de la UI
class AIResponse {
  final String text;
  final Map<String, dynamic>? jsonMetadata;

  AIResponse({required this.text, this.jsonMetadata});
}

/// Contrato que debe cumplir cualquier proveedor de IA (Firebase, OpenAI, etc.)
abstract class AIService {
  /// Genera contenido basado en texto y opcionalmente imágenes (Chat / RAG)
  Future<AIResponse> generateContent({
    required String prompt,
    List<File>? images,
    String? modelId, // Permite cambiar entre 'gemini-2.5-flash', 'gemini-2.5-pro', etc.
  });

  /// Analiza una imagen y fuerza una respuesta JSON (Clasificación Wardrobe)
  ///
  /// [imagePayload]: `garment` for wardrobe items (768px JPEG ~82);
  /// `identity` for face/body collages (higher quality).
  Future<Map<String, dynamic>> analyzeImageToJson({
    required File image,
    required String promptInstruction,
    AiImagePayload imagePayload = AiImagePayload.garment,
  });
}
