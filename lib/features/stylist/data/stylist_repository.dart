import '../../../core/utils/mock_data.dart';

class StylistRepository {
  Future<Map<String, dynamic>> sendPrompt(String prompt) async {
    // 1. Simular "Thinking..." de la IA
    await Future.delayed(const Duration(seconds: 2));

    // 2. Devolver siempre la respuesta exitosa definida en MockData
    // En una app real, aquí llamarías a tu Backend Python/OpenAI
    return MockData.generatedOutfitResponse;
  }
}
