# 🤖 Prompt para Gemini 3 Pro - Análisis Completo de Virtual Try-On

Copia y pega este prompt completo en Gemini 3 Pro para obtener un análisis extenso y recomendaciones de implementación.

---

## 📋 PROMPT COMPLETO

```
Eres un arquitecto de software especializado en aplicaciones de moda con IA. Necesito tu ayuda para diseñar e implementar un sistema completo de Virtual Try-On usando Firebase Vertex AI (Gemini) y Flutter.

CONTEXTO DEL PROYECTO:
- Aplicación: AIFit - Asistente de moda personal con IA
- Stack: Flutter (Dart) + Firebase (Auth, Firestore, Storage, Vertex AI)
- Modelos disponibles: Gemini 2.5 Flash, Gemini 2.5 Pro, Gemini 3 Pro Image
- Estado actual: Análisis de prendas funcionando, generación de outfits (texto) funcionando

FLUJO PROPUESTO (Optimizado para Costos):

FASE 1: Análisis de Intención
- Input: Prompt del usuario (texto libre, ej: "quiero un outfit casual para el fin de semana")
- Proceso: Gemini 2.5 Flash analiza el prompt y extrae criterios estructurados
- Output: Objeto con occasion, preferredColors, styleTags, season, weather, constraints

FASE 2: Algoritmo de Búsqueda Local
- Input: Criterios de búsqueda + Wardrobe completo del usuario (desde Firestore)
- Proceso: Algoritmo en Dart filtra prendas relevantes (sin llamadas a IA)
- Output: Lista filtrada de 20-30 prendas candidatas (separadas por tipo: tops, bottoms, shoes)

FASE 3: Generación de 3 Outfits
- Input: Lista filtrada de prendas (con URLs de imágenes) + Criterios
- Proceso: Gemini 2.5 Pro analiza las imágenes de las prendas y genera 3 outfits
- Output: JSON con 3 outfits, cada uno con:
  {
    "id": "outfit_1",
    "topId": "item_id_123",
    "bottomId": "item_id_456",
    "shoesId": "item_id_789",
    "outerwearId": "item_id_012", // Optional
    "matchPercentage": 95,
    "explanation": "This combination works because...",
    "compatibilityScore": 0.92
  }

FASE 4a: Generación de Imagen Base del Usuario (NUEVA OPTIMIZACIÓN - Una vez)
- Input: Fotos del usuario (body + face)
- Proceso: Gemini 3 Pro Image genera UNA imagen base optimizada que combina face + body
- Output: URL de imagen base guardada en Firestore (`users/{uid}/baseImageUrl`)
- OPTIMIZACIÓN: Esta imagen se reutiliza para todos los outfits, ahorrando costos

FASE 4b: Virtual Try-On (Generación de Imagen con Outfit)
- Input: Outfit seleccionado + URLs de imágenes de prendas + Imagen base del usuario (o fotos si no existe)
- Proceso: Gemini 3 Pro Image genera imagen realista del usuario usando el outfit
- Output: URL de imagen generada
- OPTIMIZACIÓN: Usa 1 imagen base en lugar de 2-4 fotos por request

ESTRUCTURA DE DATOS ACTUAL:

1. WardrobeItem (Modelo de Prenda):
```dart
class WardrobeItem {
  final String id;
  final String name;
  final String type; // 'top', 'bottom', 'shoes', 'outerwear'
  final String subType; // 'jeans', 't-shirt', etc.
  final String imageUrl;
  final List<String> colors;
  final String? brand;
  final List<String> styleTags; // ['casual', 'formal', etc.]
  final List<String> season; // ['spring', 'summer', etc.]
  final DateTime? createdAt;
}
```

2. Firestore Collections:
- `users/{uid}` - Perfil del usuario con bodyPhotos y facePhotos (arrays de URLs)
- `wardrobe_items/{itemId}` - Prendas del usuario con todos los campos arriba

3. Firebase Storage:
- `users/{uid}/photos/` - Fotos del usuario (body_*.jpg, face_*.jpg)
- `users/{uid}/wardrobe/` - Imágenes de prendas (item_*.jpg)

LIBRERÍAS Y SERVICIOS DISPONIBLES:

1. Firebase AI (firebase_ai: ^3.6.1):
```dart
import 'package:firebase_ai/firebase_ai.dart';

// Gemini 2.5 Flash (rápido, barato)
final flashModel = FirebaseAI.vertexAI().generativeModel(
  model: 'gemini-2.5-flash',
);

// Gemini 2.5 Pro (preciso, para análisis de imágenes)
final proModel = FirebaseAI.vertexAI().generativeModel(
  model: 'gemini-2.5-pro',
  generationConfig: GenerationConfig(
    responseMimeType: 'application/json',
  ),
);

// Gemini 3 Pro Image (generación de imágenes)
final imageModel = FirebaseAI.vertexAI().generativeModel(
  model: 'gemini-3-pro-image-preview',
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

3. Storage:
```dart
final storage = FirebaseStorage.instance;
final ref = storage.ref().child('users/$uid/photos/body_123.jpg');
final url = await ref.getDownloadURL();
```

OBJETIVOS Y RESTRICCIONES:

1. Optimización de Costos:
   - Minimizar llamadas a modelos costosos (Pro, Image)
   - Usar Flash para análisis de texto
   - Filtrar localmente antes de enviar a IA
   - Solo generar imagen cuando usuario selecciona outfit

2. Calidad:
   - Outfits deben ser visualmente compatibles
   - Imágenes generadas deben ser realistas
   - Considerar preferencias del usuario

3. Performance:
   - Respuesta rápida (< 30 segundos total)
   - Cachear resultados cuando sea posible
   - Manejar errores gracefully

TAREAS ESPECÍFICAS:

1. DISEÑAR ALGORITMO DE BÚSQUEDA (Fase 2):
   - ¿Qué criterios usar para filtrar prendas?
   - ¿Cómo calcular compatibilidad entre prendas?
   - ¿Cómo rankear prendas por relevancia?
   - ¿Cómo manejar casos edge (pocas prendas, sin matches, etc.)?

2. DISEÑAR PROMPTS PARA GEMINI (Fases 1, 3, 4a, 4b):
   - Fase 1: Prompt para extraer intención del usuario
   - Fase 3: Prompt para generar outfits con imágenes
   - Fase 4a: Prompt para generar imagen base del usuario (NUEVA OPTIMIZACIÓN)
   - Fase 4b: Prompt para generar imagen con nano banana

3. DISEÑAR MODELOS DE DATOS:
   - OutfitIntent (Fase 1)
   - FilteredWardrobe (Fase 2)
   - GeneratedOutfit (Fase 3)
   - VirtualTryOnRequest (Fase 4)

4. DISEÑAR ARQUITECTURA DE SERVICIOS:
   - ¿Cómo estructurar los servicios?
   - ¿Qué métodos necesita cada servicio?
   - ¿Cómo manejar errores y retries?
   - ¿Cómo cachear resultados?

5. OPTIMIZACIONES:
   - ¿Cómo reducir costos sin perder calidad?
   - ¿Qué se puede cachear?
   - ¿Cómo manejar rate limits?

POR FAVOR PROPORCIONA:

1. ANÁLISIS DEL FLUJO:
   - ¿Es el flujo propuesto óptimo?
   - ¿Hay mejoras o alternativas?
   - ¿Qué riesgos o problemas potenciales ves?

2. ALGORITMO DE BÚSQUEDA DETALLADO:
   - Pseudocódigo o descripción paso a paso
   - Función de scoring para relevancia
   - Función de compatibilidad entre prendas
   - Manejo de casos edge

3. PROMPTS OPTIMIZADOS:
   - Prompt para Fase 1 (análisis de intención)
   - Prompt para Fase 3 (generación de outfits con imágenes)
   - Prompt para Fase 4a (generación de imagen base del usuario) - NUEVA OPTIMIZACIÓN
   - Prompt para Fase 4b (generación de imagen con nano banana)
   - Incluye ejemplos de formato JSON esperado

4. MODELOS DE DATOS COMPLETOS:
   - Código Dart para todos los modelos
   - Métodos fromJson/toJson
   - Validaciones necesarias

5. ARQUITECTURA DE SERVICIOS:
   - Estructura de clases y métodos
   - Interfaces/contratos
   - Manejo de errores
   - Logging y debugging

6. CÓDIGO DE IMPLEMENTACIÓN:
   - Código Dart completo para cada servicio
   - Incluye manejo de errores
   - Incluye logging
   - Incluye validaciones

7. OPTIMIZACIONES Y MEJORES PRÁCTICAS:
   - Estrategias de caching
   - Reducción de costos
   - Mejora de performance
   - Manejo de rate limits

8. TESTING Y VALIDACIÓN:
   - Cómo testear cada fase
   - Qué validar en cada paso
   - Cómo manejar respuestas inválidas de la IA

IMPORTANTE:
- El código debe ser en Dart (Flutter)
- Usar las librerías mencionadas
- Considerar optimización de costos
- Incluir manejo robusto de errores
- El flujo debe ser escalable y mantenible

Por favor, proporciona un análisis completo, detallado y listo para implementar.

---

## 📦 CÓDIGO YA IMPLEMENTADO (Para Referencia)

He implementado parcialmente el sistema. Aquí está el código actual:

### 1. Modelos de Datos (outfit_models.dart):
- OutfitIntent: Intención del usuario estructurada
- FilteredWardrobe: Prendas filtradas por tipo
- GeneratedOutfit: Outfit generado con IDs de prendas
- VirtualTryOnRequest: Request para generación de imagen
- VirtualTryOnResult: Resultado con URL de imagen

### 2. Algoritmo de Búsqueda (wardrobe_search_algorithm.dart):
- WardrobeSearchAlgorithm.filterWardrobe(): Filtra prendas por criterios
- WardrobeSearchAlgorithm.calculateCompatibility(): Calcula compatibilidad entre prendas
- Funciones de scoring: _calculateRelevanceScore, _colorsMatch, etc.

### 3. Servicios Implementados:
- OutfitIntentAnalyzer: Analiza prompt del usuario (Fase 1)
- OutfitGeneratorService: Genera outfits con Gemini 2.5 Pro (Fase 3)
- UserBaseImageService: Genera imagen base del usuario UNA VEZ (Fase 4a) - NUEVA OPTIMIZACIÓN
- VirtualTryOnService: Genera imagen con Gemini 3 Pro Image (Fase 4b)
- OutfitService: Orquesta todo el flujo completo

### 4. Estructura Actual:
```
lib/features/outfit/
  ├── domain/
  │   └── outfit_models.dart
  └── services/
      ├── outfit_intent_analyzer.dart
      ├── wardrobe_search_algorithm.dart
      ├── outfit_generator_service.dart
      ├── user_base_image_service.dart (NUEVA - Fase 4a)
      ├── virtual_try_on_service.dart
      └── outfit_service.dart (orquestador principal)
```

---

## 🎯 TAREAS ESPECÍFICAS PARA GEMINI 3 PRO

Basado en el código ya implementado, necesito que:

1. **REVISE Y MEJORE** el algoritmo de búsqueda:
   - ¿El scoring es correcto?
   - ¿Falta alguna consideración importante?
   - ¿Cómo mejorar la compatibilidad entre prendas?

2. **OPTIMICE LOS PROMPTS**:
   - Fase 1: ¿El prompt de análisis de intención es óptimo?
   - Fase 3: ¿El prompt de generación de outfits con imágenes es correcto?
   - Fase 4a: ¿El prompt para generar imagen base del usuario es adecuado? (NUEVA)
   - Fase 4b: ¿El prompt para nano banana es adecuado?

3. **VERIFIQUE LA IMPLEMENTACIÓN**:
   - ¿Hay errores o mejoras en el código?
   - ¿Falta manejo de errores?
   - ¿Hay optimizaciones de performance?

4. **PROPORCIONE MEJORAS**:
   - Código mejorado si es necesario
   - Estrategias de caching
   - Manejo de edge cases

5. **DOCUMENTE**:
   - Cómo testear cada fase
   - Qué validar
   - Cómo debuggear problemas

Por favor, analiza el código proporcionado y proporciona mejoras específicas y listas para implementar.
```

---

## 🎯 Cómo Usar Este Prompt

1. **Copia el prompt completo** de arriba
2. **Pégalo en Gemini 3 Pro** (https://gemini.google.com o en tu aplicación)
3. **Espera el análisis completo**
4. **Comparte la respuesta** conmigo para que podamos implementar juntos

---

## 📝 Información Adicional que Puedes Agregar

Si quieres que Gemini tenga más contexto, agrega al final del prompt:

```
INFORMACIÓN ADICIONAL:

- Número promedio de prendas por usuario: 20-50
- Usuarios típicos tienen: 5-10 tops, 5-10 bottoms, 3-5 shoes, 2-3 outerwear
- Presupuesto mensual para IA: ~$50-100
- Tiempo máximo aceptable: 30 segundos para generar outfit completo
- Preferencias de usuario: Se pueden aprender con el tiempo (futuro)
```

---

¡Buena suerte con el análisis! 🚀
