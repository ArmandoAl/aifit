# 🚀 AIFit - Backend Implementation Plan

## 📊 Estado Actual del Proyecto

### ✅ Completado (Frontend + Mocks)
- Login Page con diseño moderno
- Welcome/Onboarding (3 pasos)
- Photo Setup Page
- Profile Page (upload de fotos)
- Wardrobe Page (grid, filtros, stats)
- Stylist Page (chat UI)
- Outfit Result Page
- Quick Generator Page
- Navigation (GoRouter con auth)
- Image Picker (galería y cámara)

### ⚠️ Estado del Backend
- **Firebase**: Inicializado ✅
- **Auth**: Mock (offline) ⚠️
- **Firestore**: Parcial (reglas configuradas) ⚠️
- **Storage**: Error -1017 (auth requerida) ❌
- **Vertex AI**: Estructura lista, sin implementar ⚠️

---

## 🎯 Plan de Implementación (Ordenado por Dificultad)

### **FASE 1: Autenticación Real (Dificultad: MEDIA)**
**Prioridad: ALTA** - Desbloquea Storage y features protegidas

#### 1.1 Google Sign-In en iOS/macOS
- **Tiempo estimado**: 1-2 horas
- **Complejidad**: Media
- **Dependencias**: Ninguna
- **Archivos a modificar**:
  - `lib/features/auth/data/auth_repository.dart`
  - `ios/Runner/Info.plist` (configuración OAuth)
  - `macos/Runner/Info.plist` (configuración OAuth)

**Pasos**:
1. Configurar OAuth Client ID en Firebase Console
2. Agregar URL schemes en Info.plist
3. Reemplazar mock auth con `google_sign_in` package
4. Implementar stream real de `authStateChanges`
5. Testing: Login → Logout → Login

**Riesgos**: 
- Configuración de OAuth puede ser tediosa en macOS
- Necesita SHA-1/SHA-256 para Android

---

### **FASE 2: Firebase Storage (Dificultad: BAJA)**
**Prioridad: ALTA** - Crítico para fotos de usuario

#### 2.1 Storage con Auth Real
- **Tiempo estimado**: 30 mins
- **Complejidad**: Baja
- **Dependencias**: Fase 1 (Auth)
- **Archivos a modificar**:
  - `storage.rules` (actualizar reglas)
  - Ya implementado en `StorageService` ✅

**Pasos**:
1. Actualizar reglas de Storage para usar `request.auth`
2. Testing con usuario autenticado
3. Verificar subida y descarga de fotos

**Riesgos**:
- Reglas mal configuradas pueden bloquear uploads

---

### **FASE 3: Firestore User Profile (Dificultad: BAJA)**
**Prioridad: ALTA** - Base para todas las features

#### 3.1 CRUD de Usuario
- **Tiempo estimado**: 1 hora
- **Complejidad**: Baja
- **Dependencias**: Fase 1 (Auth)
- **Archivos a modificar**:
  - `lib/features/profile/data/profile_repository.dart` (ya tiene base)
  - Crear listeners en `ProfilePage`

**Pasos**:
1. Implementar `getUserProfile()` real
2. Implementar `updateProfile()` (nombre, avatar)
3. Implementar `updatePreferences()` (estilos, tallas)
4. Stream listener para cambios en tiempo real

**Esquema Firestore**:
```javascript
users/{userId}
  - displayName: string
  - email: string
  - photoUrl: string
  - bodyPhotos: array<string>
  - facePhotos: array<string>
  - preferences: {
      styleTags: array<string>,
      temperatureSensitivity: string,
      sizes: map
    }
  - onboardingCompleted: boolean
  - createdAt: timestamp
  - lastLogin: timestamp
```

---

### **FASE 4: Wardrobe CRUD (Dificultad: MEDIA)**
**Prioridad: ALTA** - Core functionality

#### 4.1 Firestore Wardrobe
- **Tiempo estimado**: 2-3 horas
- **Complejidad**: Media
- **Dependencias**: Fase 1 (Auth), Fase 5 (AI parcial)
- **Archivos a modificar**:
  - `lib/features/wardrobe/data/wardrobe_repository_impl.dart`
  - `lib/features/wardrobe/presentation/bloc/wardrobe_bloc.dart`

**Pasos**:
1. Implementar `getWardrobeItems()` real desde Firestore
2. Implementar `addWardrobeItem()` con AI analysis
3. Implementar `deleteWardrobeItem()`
4. Implementar `updateWardrobeItem()`
5. Stream listener para cambios en tiempo real
6. Testing: Add → Read → Delete

**Esquema Firestore**:
```javascript
wardrobe_items/{itemId}
  - userId: string
  - imageUrl: string
  - type: string (top/bottom/shoes/outerwear)
  - subType: string (jeans, t-shirt, etc)
  - colors: array<string>
  - styleTags: array<string>
  - season: array<string>
  - createdAt: timestamp
```

---

### **FASE 5: Vertex AI - Image Analysis (Dificultad: ALTA)**
**Prioridad: ALTA** - Core AI feature

#### 5.1 AI Service para Wardrobe
- **Tiempo estimado**: 3-4 horas
- **Complejidad**: Alta
- **Dependencias**: Fase 1 (Auth)
- **Archivos a modificar**:
  - `lib/core/services/firebase_ai_service_impl.dart`
  - `lib/features/wardrobe/data/wardrobe_repository_impl.dart`

**Pasos**:
1. Implementar `analyzeImageToJson()` con Gemini Vision
2. Prompt engineering para clothing analysis
3. Parse JSON response (type, colors, style, season)
4. Error handling para respuestas inválidas
5. Testing con diferentes tipos de ropa

**Prompt Template**:
```
Analyze this clothing item carefully.
Return JSON with:
- type: "top"/"bottom"/"shoes"/"outerwear"
- subType: specific type (e.g., "jeans", "t-shirt")
- colors: array of dominant colors
- styleTags: array (e.g., "casual", "formal")
- season: array (e.g., "summer", "winter")
```

**Riesgos**:
- API costs (Vertex AI)
- Respuestas inconsistentes de la IA
- Necesita validación de JSON

---

### **FASE 6: Vertex AI - Outfit Generation (Dificultad: ALTA)**
**Prioridad: MEDIA** - Advanced feature

#### 6.1 Quick Generator con AI
- **Tiempo estimado**: 4-5 horas
- **Complejidad**: Alta
- **Dependencias**: Fase 4 (Wardrobe), Fase 5 (AI)
- **Archivos a modificar**:
  - `lib/features/generator/presentation/pages/quick_generator_page.dart`
  - Crear `GeneratorRepository`
  - Crear `GeneratorBloc`

**Pasos**:
1. RAG: Fetch user's wardrobe from Firestore
2. Build context prompt with wardrobe + user request
3. Call Gemini to generate outfit combination
4. Parse response (top, bottom, shoes, explanation)
5. Save to `generated_outfits` collection
6. Navigate to result page

**Esquema Firestore**:
```javascript
generated_outfits/{outfitId}
  - userId: string
  - occasion: string
  - weather: string
  - prompt: string
  - itemIds: array<string>
  - explanation: string
  - matchPercentage: number
  - createdAt: timestamp
```

---

### **FASE 7: Vertex AI - Chat Stylist (Dificultad: ALTA)**
**Prioridad: MEDIA** - Core conversational feature

#### 7.1 Chat con Contexto
- **Tiempo estimado**: 5-6 horas
- **Complejidad**: Alta
- **Dependencias**: Fase 4 (Wardrobe), Fase 5 (AI)
- **Archivos a modificar**:
  - `lib/features/stylist/data/stylist_repository_impl.dart`
  - `lib/features/stylist/presentation/bloc/chat_bloc.dart`

**Pasos**:
1. Implementar chat history storage en Firestore
2. RAG: Fetch wardrobe + chat history
3. Build conversation context
4. Streaming responses (opcional)
5. Parse AI recommendations
6. Save messages to Firestore

**Esquema Firestore**:
```javascript
chat_sessions/{sessionId}
  - userId: string
  - messages: array<{
      role: string,
      content: string,
      timestamp: timestamp
    }>
  - lastMessageAt: timestamp

chat_memory/{userId}
  - summary: string (resumen de conversaciones pasadas)
  - preferences: map (aprendizajes de la IA)
```

---

### **FASE 8: Imagen Generation - Virtual Try-On (Dificultad: MUY ALTA)**
**Prioridad: BAJA** - Nice to have (MVP no esencial)

#### 8.1 Nano Banana o Alternativas
- **Tiempo estimado**: 8-10 horas
- **Complejidad**: Muy Alta
- **Dependencias**: Todo lo anterior
- **Opciones**:
  - Nano Banana API (si disponible)
  - Stable Diffusion con ControlNet
  - Fal.ai / Replicate APIs

**Riesgos**:
- API costs muy altos
- Calidad inconsistente
- Puede ser MVP v2.0

---

## 📝 Orden de Implementación Recomendado

### Sprint 1 (Día 1-2): Fundamentos
1. ✅ **Auth Real (Google Sign-In)** → Desbloquea todo
2. ✅ **Storage Fix** → Fotos funcionando
3. ✅ **User Profile CRUD** → Base de datos

### Sprint 2 (Día 3-4): Core Features
4. ✅ **Wardrobe CRUD** → Gestión de prendas
5. ✅ **AI Image Analysis** → Scan automático

### Sprint 3 (Día 5-6): AI Features
6. ✅ **Quick Generator** → Generación rápida
7. ✅ **Chat Stylist** → Conversación con IA

### Sprint 4 (Opcional): Advanced
8. ⚠️ **Virtual Try-On** → Feature premium

---

## 🔧 Configuraciones Necesarias

### Firebase Console
- [ ] Habilitar Google Sign-In (Auth)
- [ ] Crear OAuth Client ID (iOS/macOS)
- [ ] Actualizar Storage Rules
- [ ] Verificar Firestore Rules
- [ ] Habilitar Vertex AI API

### Google Cloud Console
- [ ] Habilitar Vertex AI API
- [ ] Configurar billing
- [ ] Revisar quotas

### Código
- [ ] Agregar URL Schemes en Info.plist
- [ ] Configurar SHA-1 para Android
- [ ] Environment variables para API keys (si aplica)

---

## 💰 Estimación de Costos (Mensual - MVP)

| Servicio | Uso Estimado | Costo |
|----------|--------------|-------|
| Firebase Auth | Gratis | $0 |
| Firestore | 100k reads/writes | ~$1-2 |
| Storage | 5GB almacenamiento | ~$0.10 |
| Vertex AI (Gemini Flash) | 1000 requests | ~$5-10 |
| **TOTAL MVP** | | **~$6-12/mes** |

---

## 🎯 Siguiente Paso: Implementar Auth Real

¿Empezamos con la Fase 1 (Google Sign-In)?
