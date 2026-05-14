# 🎨 Roadmap: Virtual Try-On (Generación de Imágenes de Outfits)

## 🎯 Objetivo
Generar imágenes realistas de outfits usando las prendas del usuario y sus fotos de cuerpo/cara para crear un "Virtual Try-On".

---

## 📊 Estado Actual

### ✅ Lo que ya tenemos:
- ✅ Análisis de imágenes de prendas con IA (Gemini 2.5 Pro)
- ✅ Generación de combinaciones de outfits (texto + IDs de items)
- ✅ Fotos de usuario (body y face) en Firebase Storage
- ✅ Estructura de datos lista en Firestore

### ❌ Lo que falta:
- ❌ Generación de imágenes realistas de outfits
- ❌ Virtual Try-On (aplicar prendas a fotos del usuario)
- ❌ Servicio de generación de imágenes

---

## 🔍 Opciones Disponibles (2026)

### Opción 1: Gemini 3 Pro Image (Nano Banana) ⭐ RECOMENDADA

**Servicio:** Firebase Vertex AI - Gemini 3 Pro Image  
**Modelo:** `gemini-3-pro-image-preview` (también conocido como "nano banana pro")

**Ventajas:**
- ✅ Integrado con Firebase (ya lo tienes configurado)
- ✅ Diseñado específicamente para generación de imágenes profesionales
- ✅ Soporta Google Search grounding (puede buscar referencias)
- ✅ Buena calidad para assets profesionales

**Desventajas:**
- ⚠️ Requiere billing habilitado
- ⚠️ Puede ser costoso para muchas generaciones
- ⚠️ Modelo en preview (puede cambiar)

**Código de ejemplo:**
```dart
final model = FirebaseAI.vertexAI().generativeModel(
  model: 'gemini-3-pro-image-preview',
);

// Prompt para generar outfit
final prompt = """
Generate a professional fashion image showing a person wearing:
- Top: [descripción del top]
- Bottom: [descripción del bottom]
- Shoes: [descripción de los shoes]

Style: [style tags]
Setting: [contexto/ocasión]
""";

final response = await model.generateContent([
  Content.text(prompt),
]);

// La respuesta incluirá una imagen generada
```

**Costo estimado:** ~$0.01-0.05 por imagen

---

### Opción 2: Stable Diffusion + ControlNet

**Servicio:** APIs externas (Replicate, Fal.ai, Hugging Face)

**Ventajas:**
- ✅ Muy personalizable
- ✅ ControlNet permite usar fotos del usuario como base
- ✅ Open source
- ✅ Varias opciones de proveedores

**Desventajas:**
- ⚠️ Requiere integración con servicios externos
- ⚠️ Más complejo de implementar
- ⚠️ Calidad puede variar

**Proveedores:**
- **Replicate**: https://replicate.com (fácil de usar)
- **Fal.ai**: https://fal.ai (rápido y económico)
- **Hugging Face Inference API**: https://huggingface.co/inference-api

**Código de ejemplo (Replicate):**
```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<String> generateOutfitImage({
  required String userBodyPhotoUrl,
  required String topImageUrl,
  required String bottomImageUrl,
}) async {
  final response = await http.post(
    Uri.parse('https://api.replicate.com/v1/predictions'),
    headers: {
      'Authorization': 'Token YOUR_API_KEY',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'version': 'controlnet-version-id',
      'input': {
        'body_image': userBodyPhotoUrl,
        'top_image': topImageUrl,
        'bottom_image': bottomImageUrl,
        'prompt': 'professional fashion photo, high quality',
      },
    }),
  );
  
  final data = jsonDecode(response.body);
  return data['output'][0]; // URL de la imagen generada
}
```

**Costo estimado:** ~$0.002-0.01 por imagen

---

### Opción 3: APIs Especializadas en Fashion

**Servicios:**
- **ZMO.ai**: https://zmo.ai (especializado en fashion)
- **Outfit Anyone**: Modelo open source
- **VITON (Virtual Try-On)**: Varios modelos disponibles

**Ventajas:**
- ✅ Especializados en moda
- ✅ Mejor calidad para prendas
- ✅ Algunos son open source

**Desventajas:**
- ⚠️ Requieren integración externa
- ⚠️ Pueden tener límites de uso
- ⚠️ Algunos requieren self-hosting

---

## 🎯 Recomendación: Gemini 3 Pro Image

**Por qué:**
1. Ya tienes Firebase configurado
2. Integración más simple
3. Calidad profesional
4. Soporte de Google

---

## 📋 Pasos para Implementar con Gemini 3 Pro Image

### Paso 1: Verificar Disponibilidad

1. **Ve a Firebase Console:**
   - https://console.firebase.google.com/project/aifit-a7f6b/ai-logic
   - Verifica que "Gemini 3 Pro Image" esté disponible

2. **Habilita el modelo:**
   - Si no está disponible, puede que necesites esperar o contactar a Google

### Paso 2: Implementar el Servicio

**Crear:** `lib/core/services/image_generation_service.dart`

```dart
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

class ImageGenerationService {
  Future<String> generateOutfitImage({
    required Map<String, dynamic> outfitData,
    required List<String> itemIds,
  }) async {
    try {
      final model = FirebaseAI.vertexAI().generativeModel(
        model: 'gemini-3-pro-image-preview',
      );

      // Construir prompt detallado
      final prompt = _buildOutfitPrompt(outfitData, itemIds);

      final response = await model.generateContent([
        Content.text(prompt),
      ]);

      // La respuesta debería incluir una URL de imagen
      // O necesitarás parsear la respuesta según la API
      return response.text ?? '';
    } catch (e) {
      debugPrint('Error generating outfit image: $e');
      throw Exception('Failed to generate outfit image: $e');
    }
  }

  String _buildOutfitPrompt(Map<String, dynamic> outfitData, List<String> itemIds) {
    return """
    Generate a professional fashion photograph showing a person wearing a complete outfit.
    
    Outfit details:
    - Items: ${itemIds.join(', ')}
    - Style: ${outfitData['styleTags'] ?? 'casual'}
    - Occasion: ${outfitData['occasion'] ?? 'everyday'}
    
    Requirements:
    - High quality, professional photography style
    - Good lighting and composition
    - Realistic appearance
    - Fashion magazine quality
    """;
  }
}
```

### Paso 3: Integrar en OutfitResultPage

Actualizar `OutfitResultPage` para:
1. Llamar al servicio de generación de imágenes
2. Mostrar loading mientras genera
3. Mostrar la imagen generada en lugar del placeholder

### Paso 4: Guardar en Firestore

Guardar la URL de la imagen generada en:
```javascript
generated_outfits/{outfitId}
  - imageUrl: string (URL de la imagen generada)
  - generatedAt: timestamp
```

---

## 🔄 Flujo Completo

```
1. Usuario pide outfit → StylistRepository.generateOutfitWithItem()
2. IA genera combinación (texto + itemIds) ✅ Ya funciona
3. ImageGenerationService.generateOutfitImage() → Genera imagen
4. Guardar imagen en Storage o usar URL directa
5. Mostrar en OutfitResultPage
```

---

## 💰 Costos Estimados

| Servicio | Costo por Imagen | Calidad | Facilidad |
|----------|------------------|---------|-----------|
| **Gemini 3 Pro Image** | $0.01-0.05 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **Replicate** | $0.002-0.01 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **Fal.ai** | $0.001-0.005 | ⭐⭐⭐ | ⭐⭐⭐⭐ |

---

## 🧪 Testing

Una vez implementado:

1. **Genera un outfit** desde la app
2. **Verifica que la imagen se genere** (puede tardar 10-30 segundos)
3. **Verifica la calidad** de la imagen generada
4. **Ajusta el prompt** si es necesario para mejorar resultados

---

## 📝 Notas Importantes

- **Gemini 3 Pro Image** puede no estar disponible en todas las regiones aún
- Si no está disponible, usa **Replicate** o **Fal.ai** como alternativa
- Las imágenes generadas pueden tardar 10-30 segundos
- Considera cachear imágenes generadas para evitar regenerar

---

## 🚀 Siguiente Paso

1. **Verifica disponibilidad** de Gemini 3 Pro Image en Firebase Console
2. **Si está disponible**: Implementa usando el código de ejemplo arriba
3. **Si no está disponible**: Usa Replicate o Fal.ai como alternativa

---

## 📚 Referencias

- [Firebase AI Logic - Image Generation](https://firebase.google.com/docs/ai-logic)
- [Gemini 3 Pro Image Documentation](https://firebase.google.com/docs/ai-logic/models)
- [Replicate API](https://replicate.com/docs)
- [Fal.ai API](https://fal.ai/docs)

---

¡Buena suerte con la implementación! 🎨
