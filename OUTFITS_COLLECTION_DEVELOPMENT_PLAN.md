# 📋 Plan de Desarrollo: Colección de Outfits Generados

## 🎯 Objetivos

1. **Crear pantalla dedicada** para mostrar outfits generados con todas sus imágenes
2. **Organizar imágenes en carpetas** (try-on images en `users/{uid}/outfits/`)
3. **Crear colección Firestore** para guardar outfits con metadata y etiquetas
4. **Sistema de etiquetas** para organizar y filtrar outfits

---

## 📊 Análisis del Estado Actual

### ✅ Lo que ya funciona:
- Generación de 3 outfits con imágenes
- Imágenes se guardan en Storage (pero en raíz de usuario)
- Outfits se muestran en `GenerateOutfitPage` (básico)

### ❌ Lo que falta:
- Pantalla dedicada y mejorada para mostrar outfits
- Organización de imágenes en carpetas (`outfits/`)
- Colección Firestore para persistir outfits
- Sistema de etiquetas y metadata
- Permisos de Firestore para guardar outfits

---

## 🗂️ Estructura de Datos Propuesta

### 1. Modelo de Datos: `SavedOutfit`

```dart
class SavedOutfit {
  final String id; // ID único del outfit
  final String userId; // ID del usuario
  final String tryOnImageUrl; // URL de la imagen generada
  final GeneratedOutfit outfit; // Datos del outfit (IDs de prendas)
  final OutfitIntent intent; // Intent original (para etiquetas)
  
  // ETIQUETAS Y METADATA
  final List<String> colors; // Colores principales del outfit
  final List<String> styleTags; // Estilos (casual, formal, etc.)
  final String? occasion; // Ocasión (casual, formal, etc.)
  final String? season; // Temporada
  final String? weather; // Clima
  
  // METADATA ADICIONAL
  final int matchPercentage; // Porcentaje de match
  final double compatibilityScore; // Score de compatibilidad
  final String userPrompt; // Prompt original del usuario
  final String? reasoning; // Razonamiento de la IA
  
  // FECHAS
  final DateTime createdAt;
  final DateTime? lastViewedAt;
  final int viewCount; // Cuántas veces se ha visto
  
  // FAVORITOS Y ORGANIZACIÓN
  final bool isFavorite;
  final List<String> customTags; // Tags personalizados del usuario
  final String? notes; // Notas del usuario sobre el outfit
}
```

### 2. Estructura Firestore

**Colección: `saved_outfits`**

```json
{
  "id": "outfit_1_1769338636476",
  "userId": "bjHpPUDv1FMlk2ourMYniXjMpW72",
  "tryOnImageUrl": "https://.../users/.../outfits/tryon_1769338636476.jpg",
  "outfit": {
    "id": "outfit_1",
    "topId": "iL334JNQFEH21Mj5oiph",
    "bottomId": "dDb1eUYgf63jtcyPYFXo",
    "shoesId": "white_sneakers",
    "matchPercentage": 95,
    "explanation": "...",
    "compatibilityScore": 0.92
  },
  "intent": {
    "occasion": "casual",
    "preferredColors": ["white", "beige"],
    "styleTags": ["casual"],
    "season": null,
    "weather": null,
    "userPrompt": "Casual outfits with a white or beige jean"
  },
  "colors": ["white", "beige"],
  "styleTags": ["casual"],
  "occasion": "casual",
  "season": null,
  "weather": null,
  "matchPercentage": 95,
  "compatibilityScore": 0.92,
  "userPrompt": "Casual outfits with a white or beige jean",
  "reasoning": "User explicitly requested...",
  "createdAt": "2026-01-25T02:57:19Z",
  "lastViewedAt": null,
  "viewCount": 0,
  "isFavorite": false,
  "customTags": [],
  "notes": null
}
```

### 3. Estructura de Storage

**Antes:**
```
users/{uid}/
  ├── base_image_1769334900169.jpg
  ├── tryon_1769338636476.jpg
  ├── tryon_1769338665189.jpg
  └── tryon_1769338699350.jpg
```

**Después:**
```
users/{uid}/
  ├── base_image_1769334900169.jpg
  └── outfits/
      ├── tryon_1769338636476.jpg
      ├── tryon_1769338665189.jpg
      └── tryon_1769338699350.jpg
```

---

## 🏗️ Arquitectura Propuesta

### 1. Modelo de Datos (`saved_outfit_model.dart`)
- `SavedOutfit` class con todos los campos
- `fromJson` / `toJson` para Firestore
- Helpers para extraer etiquetas del intent

### 2. Repository (`saved_outfits_repository.dart`)
- `saveOutfit()` - Guardar outfit en Firestore
- `getSavedOutfits()` - Obtener outfits del usuario
- `getOutfitById()` - Obtener outfit específico
- `updateOutfit()` - Actualizar (favoritos, tags, notas)
- `deleteOutfit()` - Eliminar outfit
- `getOutfitsByTags()` - Filtrar por etiquetas

### 3. Servicio Actualizado (`outfit_service.dart`)
- Modificar `_uploadBaseImageToStorage()` para usar carpeta `outfits/`
- Modificar `_saveOutfitsToFirestore()` para usar nueva colección y modelo
- Extraer etiquetas del intent para guardarlas

### 4. Pantalla Nueva (`saved_outfits_page.dart`)
- Lista de outfits guardados
- Filtros por etiquetas (colores, ocasión, temporada)
- Búsqueda
- Vista de detalle de outfit
- Favoritos
- Compartir outfit

### 5. BLoC (`saved_outfits_bloc.dart`)
- Estados: Loading, Loaded, Error
- Eventos: LoadOutfits, FilterByTags, ToggleFavorite, DeleteOutfit

---

## 📝 Tareas de Implementación

### FASE 1: Modelo de Datos y Repository
- [ ] Crear `SavedOutfit` model
- [ ] Crear `SavedOutfitsRepository`
- [ ] Implementar métodos CRUD
- [ ] Agregar helpers para extraer etiquetas

### FASE 2: Actualizar Servicios
- [ ] Modificar `VirtualTryOnService` para guardar en `outfits/`
- [ ] Modificar `OutfitService` para guardar en nueva colección
- [ ] Extraer y guardar etiquetas del intent

### FASE 3: Pantalla de Outfits
- [ ] Crear `SavedOutfitsPage`
- [ ] Crear `SavedOutfitsBloc`
- [ ] Implementar lista con imágenes
- [ ] Agregar filtros y búsqueda
- [ ] Vista de detalle

### FASE 4: Funcionalidades Adicionales
- [ ] Sistema de favoritos
- [ ] Tags personalizados
- [ ] Notas del usuario
- [ ] Compartir outfit
- [ ] Estadísticas (outfits más vistos, etc.)

### FASE 5: Permisos y Reglas
- [ ] Actualizar Firestore rules para `saved_outfits`
- [ ] Verificar permisos de Storage para carpeta `outfits/`

---

## 🔍 Campos Adicionales Útiles

### Metadata de Generación:
- `generationModel`: "gemini-2.5-flash" (para tracking)
- `generationTime`: Tiempo que tomó generar
- `itemCount`: Número de prendas en el outfit

### Metadata de Uso:
- `lastWornDate`: Última vez que se usó (futuro)
- `wearCount`: Cuántas veces se ha usado (futuro)
- `rating`: Rating del usuario (1-5 estrellas)

### Metadata de Búsqueda:
- `searchKeywords`: Palabras clave para búsqueda
- `colorPalette`: Paleta de colores dominantes
- `styleCategory`: Categoría de estilo (minimalist, streetwear, etc.)

---

## 🎨 Diseño de la Pantalla

### Layout Propuesto:
```
┌─────────────────────────────────┐
│  Saved Outfits          [Filter]│
├─────────────────────────────────┤
│  [All] [Casual] [Formal] [Fav] │  ← Filtros rápidos
├─────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐    │
│  │ [Image]  │  │ [Image]  │    │  ← Grid de outfits
│  │ Outfit 1 │  │ Outfit 2 │    │
│  │ 95% match│  │ 88% match│    │
│  └──────────┘  └──────────┘    │
│  ┌──────────┐  ┌──────────┐    │
│  │ [Image]  │  │ [Image]  │    │
│  │ Outfit 3 │  │ Outfit 4 │    │
│  │ 92% match│  │ 90% match│    │
│  └──────────┘  └──────────┘    │
└─────────────────────────────────┘
```

### Vista de Detalle:
- Imagen grande del try-on
- Lista de prendas con miniaturas
- Etiquetas (colores, estilo, ocasión)
- Botones: Favorito, Compartir, Eliminar
- Notas del usuario

---

## 🚀 Prioridades

### Alta Prioridad:
1. ✅ Modelo de datos `SavedOutfit`
2. ✅ Repository básico (save, get)
3. ✅ Actualizar Storage path a `outfits/`
4. ✅ Guardar outfits en Firestore con etiquetas
5. ✅ Pantalla básica para mostrar outfits

### Media Prioridad:
6. Filtros por etiquetas
7. Sistema de favoritos
8. Vista de detalle

### Baja Prioridad:
9. Tags personalizados
10. Notas del usuario
11. Estadísticas
12. Compartir

---

## 📌 Notas Importantes

1. **Migración**: Los outfits ya generados no tendrán la nueva estructura. Considerar migración o empezar desde cero.

2. **Permisos Firestore**: Necesitamos agregar reglas para `saved_outfits`:
   ```javascript
   match /saved_outfits/{outfitId} {
     allow read, write: if request.auth != null && 
       request.auth.uid == resource.data.userId;
   }
   ```

3. **Storage Path**: Cambiar de `users/{uid}/tryon_*.jpg` a `users/{uid}/outfits/tryon_*.jpg`

4. **Backward Compatibility**: Mantener `tryOnImageUrl` en `OutfitGenerationResult` para no romper código existente.

---

## ✅ Checklist de Implementación

- [ ] Crear modelo `SavedOutfit`
- [ ] Crear `SavedOutfitsRepository`
- [ ] Actualizar `VirtualTryOnService` para usar carpeta `outfits/`
- [ ] Actualizar `OutfitService` para guardar en nueva colección
- [ ] Crear `SavedOutfitsPage`
- [ ] Crear `SavedOutfitsBloc`
- [ ] Agregar ruta en router
- [ ] Actualizar Firestore rules
- [ ] Testing básico

---

¿Empezamos con la implementación? 🚀
