# 🤖 Prompt para Gemini - Análisis y Mejora del Outfit Intent Analyzer

Copia y pega este prompt completo en Gemini para obtener un análisis detallado y mejoras específicas para el sistema de análisis de intención de outfits.

---

## 📋 PROMPT COMPLETO

```
Eres un experto en arquitectura de software, procesamiento de lenguaje natural y sistemas de IA. Necesito tu ayuda para analizar y mejorar el sistema de análisis de intención de outfits en nuestra aplicación Flutter.

CONTEXTO DEL PROYECTO:
- Aplicación: AIFit - Asistente de moda personal con IA
- Stack: Flutter (Dart) + Firebase (Auth, Firestore, Storage, Vertex AI)
- Modelos disponibles: Gemini 2.5 Flash, Gemini 2.5 Pro, Gemini 3 Pro Image
- Arquitectura: Repository pattern, BLoC para state management

FLUJO COMPLETO DE GENERACIÓN DE OUTFITS:

FASE 1: Análisis de Intención (OutfitIntentAnalyzer)
- Input: Prompt del usuario (texto libre, ej: "quiero un outfit casual para el fin de semana")
- Proceso: Gemini 2.5 Flash analiza el prompt y extrae criterios estructurados
- Output: OutfitIntent (occasion, preferredColors, styleTags, season, weather, constraints)

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

CÓDIGO ACTUAL - OutfitIntentAnalyzer:

```dart
import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import '../domain/outfit_models.dart';

/// Analiza el prompt del usuario y extrae intención estructurada
///
/// Fase 1: Usa Gemini 2.5 Flash para análisis rápido y económico
class OutfitIntentAnalyzer {
  /// Analiza el prompt del usuario y retorna intención estructurada
  Future<OutfitIntent> analyzeUserPrompt(String userPrompt) async {
    try {
      debugPrint('🔍 Analyzing user prompt: "$userPrompt"');

      final model = FirebaseAI.vertexAI().generativeModel(
        model: 'gemini-2.5-flash',
      );

      final prompt =
          """
Analyze this user request for an outfit and extract structured information.

User request: "$userPrompt"

Return a JSON object with these exact fields:
{
  "occasion": "casual" | "formal" | "sport" | "party" | "work" | "date" | "everyday" | null,
  "preferredColors": ["array", "of", "colors"],
  "styleTags": ["casual", "formal", "sporty", "elegant", "streetwear", "minimalist", "vintage", "bohemian"],
  "season": "spring" | "summer" | "fall" | "winter" | null,
  "weather": "sunny" | "rainy" | "cold" | "warm" | null,
  "constraints": {
    "mustInclude": "item description" | null,
    "mustAvoid": "item description" | null,
    "budget": "low" | "medium" | "high" | null
  }
}

Rules:
- Extract only information explicitly mentioned or strongly implied
- If information is not clear, use null
- preferredColors: Extract mentioned colors (e.g., "blue", "white", "black")
- styleTags: Extract style preferences (e.g., "casual", "formal")
- occasion: Infer from context (e.g., "weekend" → "casual", "wedding" → "formal")
- season: Infer from context or current date
- Return ONLY valid JSON, no markdown, no explanations
""";

      final response = await model.generateContent([Content.text(prompt)]);

      final responseText = response.text ?? '{}';

      // Limpiar respuesta (puede venir con markdown)
      final cleanJson = responseText
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      debugPrint('✅ Intent analysis result: $cleanJson');

      // Parse JSON
      final jsonData = _parseJson(cleanJson);

      // Agregar prompt original
      jsonData['userPrompt'] = userPrompt;

      return OutfitIntent.fromJson(jsonData);
    } catch (e) {
      debugPrint('❌ Error analyzing intent: $e');
      // Retornar intent básico si falla
      return OutfitIntent(
        userPrompt: userPrompt,
        styleTags: ['casual'], // Default
      );
    }
  }

  /// Parsea JSON de forma segura
  dynamic _parseJson(String jsonString) {
    try {
      // Intentar parse directo
      return jsonDecode(jsonString);
    } catch (e) {
      debugPrint('⚠️ JSON parse error, trying to fix: $e');

      // Intentar extraer JSON del texto
      final jsonMatch = RegExp(
        r'\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}',
      ).firstMatch(jsonString);

      if (jsonMatch != null) {
        try {
          return jsonDecode(jsonMatch.group(0)!);
        } catch (_) {
          // Si falla, retornar objeto vacío
        }
      }

      return {};
    }
  }
}
```

MODELO DE DATOS - OutfitIntent:

```dart
class OutfitIntent {
  final String? occasion; // 'casual', 'formal', 'sport', 'party', 'work', 'date', 'everyday'
  final List<String> preferredColors;
  final List<String> styleTags; // ['casual', 'formal', 'minimalist', etc.]
  final String? season; // 'spring', 'summer', 'fall', 'winter'
  final String? weather; // 'sunny', 'rainy', 'cold', 'warm'
  final Map<String, dynamic>? constraints; // Restricciones adicionales
  final String? userPrompt; // Prompt original del usuario

  OutfitIntent({
    this.occasion,
    this.preferredColors = const [],
    this.styleTags = const [],
    this.season,
    this.weather,
    this.constraints,
    this.userPrompt,
  });

  factory OutfitIntent.fromJson(Map<String, dynamic> json) {
    return OutfitIntent(
      occasion: json['occasion'],
      preferredColors: json['preferredColors'] != null
          ? List<String>.from(json['preferredColors'])
          : [],
      styleTags: json['styleTags'] != null
          ? List<String>.from(json['styleTags'])
          : [],
      season: json['season'],
      weather: json['weather'],
      constraints: json['constraints'] as Map<String, dynamic>?,
      userPrompt: json['userPrompt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (occasion != null) 'occasion': occasion,
      'preferredColors': preferredColors,
      'styleTags': styleTags,
      if (season != null) 'season': season,
      if (weather != null) 'weather': weather,
      if (constraints != null) 'constraints': constraints,
      if (userPrompt != null) 'userPrompt': userPrompt,
    };
  }
}
```

CÓDIGO RELACIONADO - WardrobeSearchAlgorithm (usa OutfitIntent):

```dart
class WardrobeSearchAlgorithm {
  /// Filtra prendas basado en intención del usuario
  static FilteredWardrobe filterWardrobe({
    required List<WardrobeItem> allItems,
    required OutfitIntent intent,
  }) {
    // Separar por tipo
    final tops = allItems.where((item) => item.type == 'top').toList();
    final bottoms = allItems.where((item) => item.type == 'bottom').toList();
    final shoes = allItems.where((item) => item.type == 'shoes').toList();
    final outerwear = allItems.where((item) => item.type == 'outerwear').toList();

    // Filtrar y rankear cada tipo
    final filteredTops = _filterAndRankItems(tops, intent);
    final filteredBottoms = _filterAndRankItems(bottoms, intent);
    final filteredShoes = _filterAndRankItems(shoes, intent);
    final filteredOuterwear = _filterAndRankItems(outerwear, intent);

    // Limitar a máximo 10 items por tipo para optimizar costos
    final maxItemsPerType = 10;
    
    return FilteredWardrobe(
      tops: filteredTops.take(maxItemsPerType).toList(),
      bottoms: filteredBottoms.take(maxItemsPerType).toList(),
      shoes: filteredShoes.take(maxItemsPerType).toList(),
      outerwear: filteredOuterwear.take(maxItemsPerType).toList(),
    );
  }

  /// Calcula score de relevancia (0.0 - 1.0)
  static double _calculateRelevanceScore(
    WardrobeItem item,
    OutfitIntent intent,
  ) {
    double score = 0.5; // Base score

    // 1. Match de colores (30% del score)
    if (intent.preferredColors.isNotEmpty) {
      final colorMatches = item.colors
          .where((color) => intent.preferredColors
              .any((pref) => _colorsMatch(color, pref)))
          .length;
      if (colorMatches > 0) {
        score += 0.3 * (colorMatches / intent.preferredColors.length);
      } else {
        score -= 0.1; // Penalizar si no hay match de colores
      }
    }

    // 2. Match de style tags (25% del score)
    if (intent.styleTags.isNotEmpty) {
      final styleMatches = item.styleTags
          .where((tag) => intent.styleTags.contains(tag))
          .length;
      if (styleMatches > 0) {
        score += 0.25 * (styleMatches / intent.styleTags.length);
      }
    }

    // 3. Match de temporada (15% del score)
    if (intent.season != null && item.season.isNotEmpty) {
      if (item.season.contains(intent.season)) {
        score += 0.15;
      } else {
        score -= 0.05; // Penalizar si no coincide la temporada
      }
    }

    // 4. Bonus por tener brand (5% del score)
    if (item.brand != null && item.brand!.isNotEmpty) {
      score += 0.05;
    }

    // Normalizar a 0.0-1.0
    return score.clamp(0.0, 1.0);
  }
}
```

ESTRUCTURA DE DATOS - WardrobeItem:

```dart
class WardrobeItem {
  final String id;
  final String name;
  final String type; // 'top', 'bottom', 'shoes', 'outerwear'
  final String subType; // e.g., 'jeans', 't-shirt', 'sweater', 'pants'
  final String imageUrl;
  final List<String> colors; // Array of colors
  final String? brand; // Optional
  final List<String> styleTags; // e.g., ['casual', 'formal']
  final List<String> season; // e.g., ['spring', 'summer']
  final DateTime? createdAt;
}
```

LIBRERÍAS Y SERVICIOS:

1. Firebase AI (firebase_ai: ^3.6.1):
```dart
import 'package:firebase_ai/firebase_ai.dart';

// Gemini 2.5 Flash (rápido, barato)
final flashModel = FirebaseAI.vertexAI().generativeModel(
  model: 'gemini-2.5-flash',
);
```

2. Firestore:
```dart
final firestore = FirebaseFirestore.instance;
final snapshot = await firestore
    .collection('wardrobe_items')
    .where('userId', isEqualTo: uid)
    .get();
```

OBJETIVOS Y RESTRICCIONES:

1. Optimización de Costos:
   - Minimizar llamadas a modelos costosos (Pro, Image)
   - Usar Flash para análisis de texto (Fase 1)
   - Filtrar localmente antes de enviar a IA
   - Solo generar imagen cuando usuario selecciona outfit

2. Calidad:
   - Extracción precisa de intención del usuario
   - Manejo robusto de prompts ambiguos o incompletos
   - Inferencia inteligente de contexto (ej: "fin de semana" → "casual")

3. Performance:
   - Respuesta rápida (< 5 segundos para Fase 1)
   - Manejo de errores gracefully
   - Fallbacks cuando la IA falla

PREGUNTAS ESPECÍFICAS:

1. ¿EL PROMPT ACTUAL ES ÓPTIMO?
   - ¿Está bien estructurado para Gemini 2.5 Flash?
   - ¿Falta alguna instrucción importante?
   - ¿Hay mejores prácticas para prompts de extracción estructurada?
   - ¿Deberíamos usar few-shot examples?

2. ¿EL MANEJO DE RESPUESTAS ES ROBUSTO?
   - ¿El parsing de JSON es suficiente?
   - ¿Hay casos edge que no estamos manejando?
   - ¿Deberíamos validar los valores extraídos?
   - ¿Cómo manejar respuestas malformadas o inesperadas?

3. ¿LA ESTRUCTURA DE DATOS ES ADECUADA?
   - ¿Faltan campos importantes en OutfitIntent?
   - ¿Los valores posibles (occasion, weather, etc.) son completos?
   - ¿Deberíamos agregar más granularidad?

4. ¿MEJORAS DE PROMPT ENGINEERING?
   - ¿Cómo mejorar la inferencia de contexto?
   - ¿Cómo manejar prompts ambiguos mejor?
   - ¿Deberíamos usar system instructions?
   - ¿Hay técnicas de chain-of-thought que ayudarían?

5. ¿OPTIMIZACIONES DE COSTOS Y PERFORMANCE?
   - ¿Podemos cachear resultados similares?
   - ¿Deberíamos usar streaming para respuestas más rápidas?
   - ¿Hay formas de reducir tokens sin perder calidad?

6. ¿MEJORAS DE CÓDIGO?
   - ¿El manejo de errores es adecuado?
   - ¿Falta logging o debugging?
   - ¿Deberíamos agregar retries con exponential backoff?
   - ¿Hay validaciones que deberíamos agregar?

7. ¿INTEGRACIÓN CON OTRAS FASES?
   - ¿La salida de OutfitIntent es suficiente para Fase 2?
   - ¿Hay información que deberíamos extraer pero no estamos extrayendo?
   - ¿Cómo mejorar la comunicación entre fases?

EJEMPLOS DE PROMPTS DE USUARIO:

1. "quiero un outfit casual para el fin de semana"
   - Esperado: occasion: "casual", styleTags: ["casual"]

2. "necesito algo elegante para una cena"
   - Esperado: occasion: "formal" o "date", styleTags: ["elegant", "formal"]

3. "outfit para el verano, colores claros"
   - Esperado: season: "summer", preferredColors: ["white", "beige", "light blue"]

4. "algo cómodo para trabajar desde casa"
   - Esperado: occasion: "work", styleTags: ["casual", "comfortable"]

5. "outfit deportivo para correr"
   - Esperado: occasion: "sport", styleTags: ["sporty"]

6. "quiero usar mi camisa azul con algo que combine"
   - Esperado: preferredColors: ["blue"], constraints: {mustInclude: "blue shirt"}

POR FAVOR PROPORCIONA:

1. ANÁLISIS DEL PROMPT ACTUAL:
   - ¿Qué está bien?
   - ¿Qué se puede mejorar?
   - ¿Qué falta?

2. PROMPT MEJORADO:
   - Versión optimizada del prompt
   - Incluye few-shot examples si es útil
   - Mejores instrucciones para inferencia de contexto

3. MEJORAS DE CÓDIGO:
   - Manejo de errores mejorado
   - Validaciones adicionales
   - Retries y fallbacks
   - Logging mejorado

4. ESTRUCTURA DE DATOS MEJORADA:
   - Campos adicionales si es necesario
   - Valores posibles más completos
   - Validaciones de datos

5. OPTIMIZACIONES:
   - Estrategias de caching
   - Reducción de costos
   - Mejora de performance

6. CASOS EDGE:
   - Cómo manejar prompts muy ambiguos
   - Cómo manejar prompts muy específicos
   - Cómo manejar prompts en otros idiomas
   - Cómo manejar prompts con información contradictoria

7. TESTING:
   - Cómo testear el analyzer
   - Qué casos de prueba son importantes
   - Cómo validar la calidad de extracción

IMPORTANTE:
- El código debe ser en Dart (Flutter)
- Debe usar Firebase Vertex AI (Gemini 2.5 Flash)
- Debe mantener compatibilidad con el código existente
- Debe ser robusto y manejar errores gracefully
- Debe optimizar costos y performance

Por favor, proporciona un análisis completo, detallado y listo para implementar.
```

---

## 🎯 Cómo Usar Este Prompt

1. **Copia el prompt completo** de arriba (desde "Eres un experto..." hasta el final)
2. **Pégalo en Gemini** (https://gemini.google.com o en tu aplicación)
3. **Espera el análisis completo**
4. **Comparte la respuesta** conmigo para que podamos implementar las mejoras juntas

---

## 📝 Información Adicional

Este prompt incluye:
- ✅ Código completo del `OutfitIntentAnalyzer`
- ✅ Modelos de datos relacionados
- ✅ Flujo completo del sistema
- ✅ Código de algoritmos que usan la salida
- ✅ Ejemplos de prompts de usuario
- ✅ Preguntas específicas sobre mejoras
- ✅ Contexto del proyecto y objetivos

---

## 💡 Notas

- El prompt está diseñado para obtener análisis específico y mejoras concretas
- Incluye todo el contexto necesario para que Gemini entienda el sistema completo
- Las preguntas están dirigidas a obtener respuestas accionables
- El código proporcionado es el código real actual del proyecto

¡Buena suerte con el análisis! 🚀
