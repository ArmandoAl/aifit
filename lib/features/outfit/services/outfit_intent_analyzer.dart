import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import '../domain/outfit_models.dart';

/// Analiza el prompt del usuario y extrae intención estructurada
///
/// Fase 1: Usa Gemini 2.5 Flash para análisis rápido y económico
/// 
/// MEJORAS APLICADAS:
/// - Usa responseMimeType: 'application/json' para garantizar JSON válido
/// - Chain of Thought con campo "reasoning" para mejor inferencia
/// - Few-shot examples para mejorar precisión
/// - Context injection con fecha actual para inferencia de temporada
/// - Fallback local robusto si falla la IA
class OutfitIntentAnalyzer {
  // Instancia reutilizable del modelo para aprovechar conexiones keep-alive
  late final GenerativeModel _model;

  OutfitIntentAnalyzer() {
    _model = FirebaseAI.vertexAI().generativeModel(
      model: 'gemini-2.5-flash',
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json', // 🚨 CRÍTICO: Garantiza JSON válido
        temperature: 0.2, // Baja temperatura para ser más determinista
      ),
    );
  }

  /// Analiza el prompt del usuario y retorna intención estructurada
  Future<OutfitIntent> analyzeUserPrompt(String userPrompt) async {
    try {
      debugPrint('🔍 Analyzing intent for: "$userPrompt"');

      // Prompt optimizado con Few-Shot Learning y Chain of Thought
      final promptText = """
You are a fashion AI expert. Analyze the user request to extract structured outfit data.

### CURRENT CONTEXT:
- Date: ${DateTime.now().toIso8601String()} (Use this to infer season if not specified)

### EXAMPLES:
User: "Something specifically for a wedding on the beach"
Output: {
  "reasoning": "User mentioned wedding (formal) but on beach (requires lighter fabrics, potentially casual-formal).",
  "occasion": "party",
  "preferredColors": [],
  "styleTags": ["elegant", "bohemian", "summer"],
  "season": "summer",
  "weather": "sunny",
  "constraints": {
    "mustInclude": "breathable fabric",
    "mustAvoid": null,
    "budget": null
  }
}

User: "I need to look professional but comfy for zoom calls"
Output: {
  "reasoning": "Work from home context. Focus on tops.",
  "occasion": "work",
  "preferredColors": [],
  "styleTags": ["casual", "minimalist", "comfortable"],
  "season": null,
  "weather": null,
  "constraints": {
    "mustInclude": "nice top",
    "mustAvoid": null,
    "budget": "medium"
  }
}

User: "outfit casual para el fin de semana"
Output: {
  "reasoning": "Weekend implies casual, relaxed style.",
  "occasion": "casual",
  "preferredColors": [],
  "styleTags": ["casual", "comfortable"],
  "season": null,
  "weather": null,
  "constraints": null
}

### YOUR TASK:
Analyze this request: "$userPrompt"

Return valid JSON obeying this schema:
{
  "reasoning": "Brief explanation of your logic (required)",
  "occasion": "casual" | "formal" | "sport" | "party" | "work" | "date" | "everyday" | null,
  "preferredColors": ["string"],
  "styleTags": ["string"],
  "season": "spring" | "summer" | "fall" | "winter" | null,
  "weather": "sunny" | "rainy" | "cold" | "warm" | null,
  "constraints": {
    "mustInclude": "string" | null,
    "mustAvoid": "string" | null,
    "budget": "low" | "medium" | "high" | null
  }
}

RULES:
- Extract only information explicitly mentioned or strongly implied
- If information is not clear, use null
- preferredColors: Extract mentioned colors (e.g., "blue", "white", "black")
- styleTags: Extract style preferences (e.g., "casual", "formal", "elegant", "sporty")
- occasion: Infer from context (e.g., "weekend" → "casual", "wedding" → "formal", "gym" → "sport")
- season: Infer from context or use current date (${DateTime.now().month} = ${_getSeasonFromMonth(DateTime.now().month)})
- reasoning: Always provide a brief explanation of your logic
""";

      final response = await _model.generateContent([Content.text(promptText)]);
      
      final responseText = response.text;
      if (responseText == null) {
        throw Exception("Empty response from AI");
      }

      // Al usar responseMimeType: 'application/json', el texto SIEMPRE es JSON válido.
      // Ya no hace falta regex ni limpieza manual.
      final Map<String, dynamic> jsonMap = jsonDecode(responseText);

      debugPrint('🧠 AI Reasoning: ${jsonMap['reasoning']}');
      debugPrint('✅ Intent analysis result: ${jsonMap.toString()}');
      
      // Inyectamos el prompt original para referencia
      jsonMap['userPrompt'] = userPrompt;

      return OutfitIntent.fromJson(jsonMap);

    } catch (e, stackTrace) {
      debugPrint('❌ Error in intent analysis: $e');
      debugPrint('   Stack trace: $stackTrace');
      // Fallback robusto: Analizar palabras clave locales si falla la IA
      return _localFallbackAnalysis(userPrompt);
    }
  }

  /// Fallback local simple por si falla la red o la IA
  OutfitIntent _localFallbackAnalysis(String prompt) {
    final lower = prompt.toLowerCase();
    String? occasion;
    final styleTags = <String>[];
    final preferredColors = <String>[];
    
    // Análisis básico de palabras clave
    if (lower.contains('boda') || lower.contains('wedding') || 
        lower.contains('cena') || lower.contains('formal')) {
      occasion = 'formal';
      styleTags.add('formal');
    } else if (lower.contains('correr') || lower.contains('gym') || 
               lower.contains('deporte') || lower.contains('sport')) {
      occasion = 'sport';
      styleTags.add('sporty');
    } else if (lower.contains('trabajo') || lower.contains('work') || 
               lower.contains('oficina')) {
      occasion = 'work';
      styleTags.add('formal');
    } else {
      occasion = 'casual';
      styleTags.add('casual');
    }
    
    // Extraer colores básicos
    final colorKeywords = {
      'azul': 'blue',
      'blue': 'blue',
      'blanco': 'white',
      'white': 'white',
      'negro': 'black',
      'black': 'black',
      'rojo': 'red',
      'red': 'red',
      'verde': 'green',
      'green': 'green',
    };
    
    for (final entry in colorKeywords.entries) {
      if (lower.contains(entry.key)) {
        preferredColors.add(entry.value);
      }
    }
    
    debugPrint('⚠️ Using local fallback analysis');
    
    return OutfitIntent(
      reasoning: 'Local fallback analysis (AI unavailable)',
      userPrompt: prompt,
      occasion: occasion,
      styleTags: styleTags,
      preferredColors: preferredColors,
    );
  }

  /// Obtiene la temporada basada en el mes
  static String _getSeasonFromMonth(int month) {
    if (month >= 3 && month <= 5) return 'spring';
    if (month >= 6 && month <= 8) return 'summer';
    if (month >= 9 && month <= 11) return 'fall';
    return 'winter';
  }
}
