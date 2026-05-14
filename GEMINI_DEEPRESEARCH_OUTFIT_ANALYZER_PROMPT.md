# 🤖 Prompt para Gemini con DeepResearch - Análisis Avanzado del Outfit Intent Analyzer

**IMPORTANTE: Activa DeepResearch en Gemini antes de usar este prompt**

Copia y pega este prompt completo en Gemini con DeepResearch activado para obtener un análisis profundo y mejoras específicas basadas en la documentación más reciente de Firebase AI.

---

## 📋 PROMPT COMPLETO PARA DEEPRESEARCH

```
IMPORTANTE: Por favor, activa DeepResearch y busca información actualizada sobre Firebase AI para Flutter/Dart antes de responder.

Eres un experto en arquitectura de software, procesamiento de lenguaje natural, sistemas de IA y la librería Firebase AI para Flutter/Dart. Necesito tu ayuda para analizar y mejorar el sistema de análisis de intención de outfits en nuestra aplicación Flutter.

CONTEXTO DEL PROYECTO:
- Aplicación: AIFit - Asistente de moda personal con IA
- Stack: Flutter (Dart) + Firebase (Auth, Firestore, Storage, Vertex AI)
- Modelos disponibles: Gemini 2.5 Flash, Gemini 2.5 Pro, Gemini 3 Pro Image
- Arquitectura: Repository pattern, BLoC para state management
- Librería CORRECTA: `firebase_ai` (NO `firebase_vertexai` que está descontinuada)

⚠️ NOTA CRÍTICA SOBRE LA LIBRERÍA:
- Estamos usando: `package:firebase_ai/firebase_ai.dart` (versión actual y correcta)
- NO usar: `package:firebase_vertexai/firebase_vertexai.dart` (descontinuada)
- Por favor, investiga la documentación oficial más reciente de `firebase_ai` para Flutter/Dart
- Verifica la sintaxis correcta para `FirebaseAI.vertexAI().generativeModel()`
- Verifica cómo usar `GenerationConfig` con `responseMimeType: 'application/json'`
- Verifica los modelos disponibles: 'gemini-2.5-flash', 'gemini-2.5-pro', 'gemini-3-pro-image-preview'

FLUJO COMPLETO DE GENERACIÓN DE OUTFITS:

FASE 1: Análisis de Intención (OutfitIntentAnalyzer)
- Input: Prompt del usuario (texto libre, ej: "quiero un outfit casual para el fin de semana")
- Proceso: Gemini 2.5 Flash analiza el prompt y extrae criterios estructurados
- Output: OutfitIntent (reasoning, occasion, preferredColors, styleTags, season, weather, constraints)

FASE 2: Algoritmo de Búsqueda Local
- Input: Criterios de búsqueda + Wardrobe completo del usuario (desde Firestore)
- Proceso: Algoritmo en Dart filtra prendas relevantes (sin llamadas a IA)
- Output: FilteredWardrobe (tops, bottoms, shoes, outerwear)

FASE 3: Generación de 3 Outfits
- Input: Lista filtrada de prendas (con URLs de imágenes) + Criterios
- Proceso: Gemini 2.5 Pro analiza las imágenes de las prendas y genera 3 outfits
- Output: List<GeneratedOutfit> con IDs de prendas

FASE 4: Virtual Try-On
- Input: Outfit seleccionado + URLs de imágenes de prendas + Imagen base del usuario
- Proceso: Gemini 3 Pro Image genera imagen realista del usuario usando el outfit
- Output: URL de imagen generada

CÓDIGO ACTUAL - OutfitIntentAnalyzer (YA MEJORADO):

```dart
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
""";

      final response = await _model.generateContent([Content.text(promptText)]);
      
      final responseText = response.text;
      if (responseText == null) {
        throw Exception("Empty response from AI");
      }

      // Al usar responseMimeType: 'application/json', el texto SIEMPRE es JSON válido.
      final Map<String, dynamic> jsonMap = jsonDecode(responseText);

      debugPrint('🧠 AI Reasoning: ${jsonMap['reasoning']}');
      
      // Inyectamos el prompt original para referencia
      jsonMap['userPrompt'] = userPrompt;

      return OutfitIntent.fromJson(jsonMap);

    } catch (e, stackTrace) {
      debugPrint('❌ Error in intent analysis: $e');
      // Fallback robusto: Analizar palabras clave locales si falla la IA
      return _localFallbackAnalysis(userPrompt);
    }
  }

  /// Fallback local simple por si falla la red o la IA
  OutfitIntent _localFallbackAnalysis(String prompt) {
    final lower = prompt.toLowerCase();
    String? occasion;
    final styleTags = <String>[];
    
    if (lower.contains('boda') || lower.contains('wedding') || 
        lower.contains('cena') || lower.contains('formal')) {
      occasion = 'formal';
      styleTags.add('formal');
    } else if (lower.contains('correr') || lower.contains('gym') || 
               lower.contains('deporte') || lower.contains('sport')) {
      occasion = 'sport';
      styleTags.add('sporty');
    } else {
      occasion = 'casual';
      styleTags.add('casual');
    }
    
    return OutfitIntent(
      reasoning: 'Local fallback analysis (AI unavailable)',
      userPrompt: prompt,
      occasion: occasion,
      styleTags: styleTags,
    );
  }
}
```

MODELO DE DATOS - OutfitIntent:

```dart
class OutfitIntent {
  final String? reasoning; // Explicación del razonamiento de la IA (Chain of Thought)
  final String? occasion; // 'casual', 'formal', 'sport', 'party', 'work', etc.
  final List<String> preferredColors;
  final List<String> styleTags; // ['casual', 'formal', 'minimalist', etc.]
  final String? season; // 'spring', 'summer', 'fall', 'winter'
  final String? weather; // 'sunny', 'rainy', 'cold', 'warm'
  final Map<String, dynamic>? constraints; // Restricciones adicionales
  final String? userPrompt; // Prompt original del usuario
}
```

LIBRERÍA Y SINTAXIS ACTUAL:

```dart
import 'package:firebase_ai/firebase_ai.dart';

// Sintaxis actual que estamos usando:
final model = FirebaseAI.vertexAI().generativeModel(
  model: 'gemini-2.5-flash',
  generationConfig: GenerationConfig(
    responseMimeType: 'application/json',
    temperature: 0.2,
  ),
);

final response = await model.generateContent([Content.text(prompt)]);
final responseText = response.text;
```

PREGUNTAS ESPECÍFICAS (INVESTIGA CON DEEPRESEARCH):

1. ¿LA SINTAXIS DE `firebase_ai` ES CORRECTA?
   - ¿`FirebaseAI.vertexAI().generativeModel()` es la forma correcta?
   - ¿`GenerationConfig` se usa así en la versión actual?
   - ¿`responseMimeType: 'application/json'` está correctamente implementado?
   - ¿Hay alguna forma mejor o más reciente de configurar el modelo?

2. ¿LOS MODELOS DISPONIBLES SON CORRECTOS?
   - ¿'gemini-2.5-flash' es el nombre correcto del modelo?
   - ¿Hay modelos más recientes o mejores para esta tarea?
   - ¿Cuál es la diferencia entre 'gemini-2.5-flash' y 'gemini-1.5-flash'?
   - ¿Cuándo usar cada uno?

3. ¿EL USO DE `responseMimeType` ES ÓPTIMO?
   - ¿Garantiza realmente JSON válido sin necesidad de limpieza?
   - ¿Hay casos edge donde aún puede fallar?
   - ¿Deberíamos usar alguna otra configuración adicional?

4. ¿HAY MEJORES PRÁCTICAS DE PROMPT ENGINEERING?
   - ¿El prompt con few-shot examples es óptimo?
   - ¿Deberíamos usar system instructions de otra forma?
   - ¿Hay técnicas más avanzadas de Chain of Thought?

5. ¿OPTIMIZACIONES DE COSTOS Y PERFORMANCE?
   - ¿Cómo podemos reducir tokens sin perder calidad?
   - ¿Hay formas de cachear resultados similares?
   - ¿Deberíamos usar streaming para respuestas más rápidas?

6. ¿MANEJO DE ERRORES Y FALLBACKS?
   - ¿El fallback local es adecuado?
   - ¿Hay mejores estrategias de retry?
   - ¿Cómo manejar rate limits de Vertex AI?

7. ¿INTEGRACIÓN CON OTRAS FASES?
   - ¿La salida de OutfitIntent es suficiente para Fase 2?
   - ¿Hay información que deberíamos extraer pero no estamos extrayendo?
   - ¿Cómo mejorar la comunicación entre fases?

POR FAVOR PROPORCIONA (USANDO DEEPRESEARCH):

1. VERIFICACIÓN DE SINTAXIS:
   - Confirma que la sintaxis de `firebase_ai` es correcta según la documentación más reciente
   - Si hay diferencias, proporciona la sintaxis correcta
   - Verifica que `GenerationConfig` y `responseMimeType` se usen correctamente

2. ANÁLISIS DEL PROMPT:
   - ¿El prompt actual es óptimo según las mejores prácticas de 2025?
   - ¿Hay mejoras específicas que puedas sugerir?
   - ¿Deberíamos usar técnicas más avanzadas?

3. MEJORAS DE CÓDIGO:
   - Código mejorado si es necesario (usando la sintaxis correcta de `firebase_ai`)
   - Manejo de errores mejorado
   - Optimizaciones de performance

4. RECOMENDACIONES ESPECÍFICAS:
   - ¿Qué modelo usar: 1.5-flash, 2.5-flash, u otro?
   - ¿Qué configuración de temperatura es óptima?
   - ¿Hay otras configuraciones de `GenerationConfig` que deberíamos usar?

5. CASOS EDGE Y SOLUCIONES:
   - Cómo manejar prompts muy ambiguos
   - Cómo manejar prompts en otros idiomas
   - Cómo manejar prompts con información contradictoria

6. TESTING Y VALIDACIÓN:
   - Cómo testear el analyzer
   - Qué casos de prueba son importantes
   - Cómo validar la calidad de extracción

IMPORTANTE:
- Usa DeepResearch para buscar la documentación más reciente de `firebase_ai` para Flutter/Dart
- Verifica que toda la sintaxis sea correcta según la versión actual
- Proporciona código que funcione con `package:firebase_ai/firebase_ai.dart` (NO `firebase_vertexai`)
- Considera optimización de costos y performance
- El código debe ser robusto y manejar errores gracefully

Por favor, usa DeepResearch para investigar a fondo y proporciona un análisis completo, detallado y basado en la documentación más reciente.
```

---

## 🎯 Cómo Usar Este Prompt

1. **Abre Gemini** (https://gemini.google.com)
2. **Activa DeepResearch** (botón o opción en la interfaz)
3. **Copia el prompt completo** de arriba (desde "IMPORTANTE: Por favor..." hasta el final)
4. **Pégalo en Gemini con DeepResearch activado**
5. **Espera el análisis completo** (DeepResearch tomará más tiempo pero será más preciso)
6. **Comparte la respuesta** conmigo para que podamos implementar las mejoras juntas

---

## 📝 Información Adicional

Este prompt incluye:
- ✅ Advertencia clara sobre la librería correcta (`firebase_ai`)
- ✅ Instrucciones para usar DeepResearch
- ✅ Código actual mejorado con las sugerencias previas
- ✅ Preguntas específicas sobre sintaxis y mejores prácticas
- ✅ Contexto completo del proyecto
- ✅ Solicitud explícita de verificación de documentación oficial

---

## 💡 Notas

- DeepResearch permitirá a Gemini buscar la documentación más reciente de Firebase AI
- El prompt está diseñado para obtener respuestas basadas en la documentación oficial actual
- Las preguntas están dirigidas a verificar que estamos usando la sintaxis correcta
- El código proporcionado es el código real actual del proyecto (ya mejorado)

¡Buena suerte con el análisis! 🚀
