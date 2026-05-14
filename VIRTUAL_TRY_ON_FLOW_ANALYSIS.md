# 🎨 Análisis del Flujo: Virtual Try-On con Gemini 3 Pro Image

## 🎯 Flujo Propuesto (Análisis Detallado)

### Fase 1: Análisis de Intención del Usuario
**Input:** Prompt del usuario (texto libre)  
**Proceso:** Gemini analiza el prompt y determina:
- Tipo de ocasión (casual, formal, deporte, etc.) 
- Estilo deseado (minimalist, streetwear, etc.)
- Colores preferidos
- Temporada/contexto
- Restricciones o preferencias específicas

**Output:** Objeto estructurado con criterios de búsqueda

---

### Fase 2: Algoritmo de Búsqueda y Filtrado
**Input:** Criterios de búsqueda + Wardrobe completo del usuario  
**Proceso:** Algoritmo filtra prendas relevantes basado en:
- Tipo (top, bottom, shoes, outerwear)
- Colores (match exacto o complementarios)
- Style tags (casual, formal, etc.)
- Temporada
- Compatibilidad entre prendas

**Output:** Lista filtrada de prendas candidatas (máximo 20-30 items)

---

### Fase 3: Generación de Outfits (Gemini 2.5 Pro)
**Input:** Lista filtrada de prendas (con imágenes) + Criterios  
**Proceso:** Gemini analiza las imágenes y genera 3 outfits:
- Combina prendas visualmente
- Considera compatibilidad de colores
- Considera estilo y ocasión
- Retorna JSON con IDs de prendas

**Output:** 3 outfits estructurados con:
- IDs de prendas (topId, bottomId, shoesId, outerwearId?)
- Match percentage
- Explicación
- Score de compatibilidad

---

### Fase 4a: Generación de Imagen Base del Usuario (OPCIONAL - Una vez)
**Input:** 
- Fotos del usuario (body + face)

**Proceso:** Gemini 3 Pro Image genera una imagen base optimizada:
- Combina face y body en una sola imagen profesional
- Pose neutral, lista para aplicar outfits
- Se genera UNA VEZ cuando el usuario sube sus fotos
- Se guarda en Storage y Firestore para reutilizar

**Output:** URL de imagen base guardada en `users/{uid}/baseImageUrl`

**OPTIMIZACIÓN:** Esta imagen se reutiliza para todos los outfits futuros, 
ahorrando costos y tiempo (1 imagen en lugar de 2-4 por outfit).

---

### Fase 4b: Generación de Imagen con Outfit (Gemini 3 Pro Image - Nano Banana)
**Input:** 
- Outfit seleccionado (con IDs)
- Imágenes de las prendas
- Imagen base del usuario (o fotos individuales si no existe)

**Proceso:** Nano Banana genera imagen realista:
- Usa la imagen base del usuario (si existe) o fotos individuales
- Aplica prendas a la imagen del usuario
- Crea composición profesional
- Ajusta iluminación y perspectiva

**Output:** URL de imagen generada del usuario usando el outfit

---

## 📊 Diagrama de Flujo

```
Usuario → Prompt
    ↓
[Fase 1] Gemini 2.5 Flash → Análisis de Intención
    ↓
Criterios de Búsqueda
    ↓
[Fase 2] Algoritmo de Búsqueda → Filtrado de Prendas
    ↓
Lista Filtrada (20-30 items)
    ↓
[Fase 3] Gemini 2.5 Pro + Imágenes → Generación de 3 Outfits
    ↓
3 Outfits (JSON con IDs)
    ↓
Usuario selecciona outfit
    ↓
[Fase 4a] (OPCIONAL - Una vez) Gemini 3 Pro Image → Generar Imagen Base
    ↓
Imagen Base guardada (reutilizable)
    ↓
[Fase 4b] Buscar imágenes de prendas + Imagen Base (o fotos)
    ↓
Gemini 3 Pro Image → Generación de Imagen Final
    ↓
Imagen del usuario usando el outfit
```

---

## 🔍 Análisis de Optimización de Costos

### Estrategia Propuesta: ✅ CORRECTA

**Por qué es eficiente:**
1. **Fase 1 (Flash)**: Barato y rápido (~$0.0001)
2. **Fase 2 (Algoritmo local)**: Gratis (sin llamadas a IA)
3. **Fase 3 (Pro con imágenes)**: Moderado (~$0.01-0.02)
   - Solo analiza 20-30 imágenes en lugar de todo el guardarropa
4. **Fase 4a (Generar Base)**: Costoso pero UNA VEZ (~$0.01-0.05)
   - Se ejecuta cuando el usuario sube fotos por primera vez
   - Se guarda y reutiliza para todos los outfits futuros
   
5. **Fase 4b (Nano Banana)**: Costoso pero necesario (~$0.01-0.05)
   - Solo se ejecuta cuando el usuario selecciona un outfit
   - OPTIMIZACIÓN: Usa 1 imagen base en lugar de 2-4 fotos
   - Ahorro: ~50% menos imágenes por request

**Ahorro estimado:**
- Sin filtrado: Analizar 100+ prendas = ~$0.10-0.20
- Con filtrado: Analizar 20-30 prendas = ~$0.02-0.04
- **Ahorro: 70-80%**

---

## 🏗️ Arquitectura Propuesta

### Servicios Necesarios:

1. **`OutfitIntentAnalyzer`** (Fase 1)
   - Analiza prompt del usuario
   - Extrae criterios de búsqueda

2. **`WardrobeSearchAlgorithm`** (Fase 2)
   - Filtra prendas por criterios
   - Algoritmo de compatibilidad
   - Ranking de relevancia

3. **`OutfitGeneratorService`** (Fase 3)
   - Genera outfits con Gemini 2.5 Pro
   - Analiza imágenes de prendas
   - Retorna JSON estructurado

4. **`UserBaseImageService`** (Fase 4a - Nueva Optimización)
   - Genera imagen base del usuario UNA VEZ
   - Combina face + body en imagen optimizada
   - Guarda en Storage y Firestore para reutilizar
   
5. **`VirtualTryOnService`** (Fase 4b)
   - Genera imagen con Gemini 3 Pro Image
   - Combina prendas + imagen base del usuario (optimizado)
   - Fallback a fotos individuales si no hay imagen base

---

## 📝 Modelos de Datos

### OutfitIntent (Fase 1)
```dart
class OutfitIntent {
  final String? occasion; // 'casual', 'formal', 'sport', etc.
  final List<String> preferredColors;
  final List<String> styleTags;
  final String? season;
  final String? weather;
  final Map<String, dynamic>? constraints;
}
```

### FilteredWardrobe (Fase 2)
```dart
class FilteredWardrobe {
  final List<WardrobeItem> tops;
  final List<WardrobeItem> bottoms;
  final List<WardrobeItem> shoes;
  final List<WardrobeItem> outerwear;
}
```

### GeneratedOutfit (Fase 3)
```dart
class GeneratedOutfit {
  final String id;
  final String? topId;
  final String? bottomId;
  final String? shoesId;
  final String? outerwearId; // Optional
  final int matchPercentage;
  final String explanation;
  final double compatibilityScore;
}
```

### VirtualTryOnRequest (Fase 4)
```dart
class VirtualTryOnRequest {
  final GeneratedOutfit outfit;
  final List<String> itemImageUrls; // URLs de las prendas
  final String? userBodyPhotoUrl;
  final String? userFacePhotoUrl;
}
```

---

## 🚀 Próximos Pasos

1. ✅ Crear prompt para Gemini 3 Pro (análisis extenso)
2. ✅ Implementar `OutfitIntentAnalyzer`
3. ✅ Implementar `WardrobeSearchAlgorithm`
4. ✅ Implementar `OutfitGeneratorService`
5. ✅ Implementar `VirtualTryOnService`
6. ✅ Integrar todo el flujo

---

## 💡 Mejoras Futuras

- **Caching**: Cachear outfits generados para evitar regenerar
- **A/B Testing**: Probar diferentes prompts para mejor calidad
- **Feedback Loop**: Aprender de outfits que el usuario guarda/descarta
- **Personalización**: Aprender preferencias del usuario con el tiempo
