# 🔧 Configuración de Firebase Vertex AI - Guía Paso a Paso

## 🎯 Objetivo
Habilitar Firebase Vertex AI API para poder usar Gemini en la aplicación y analizar imágenes de prendas.

---

## ⚠️ Error Actual
```
Firebase AI Logic API has not been used in project aifit-a7f6b before or it is disabled.
Enable it by visiting https://console.developers.google.com/apis/api/firebasevertexai.googleapis.com/overview?project=aifit-a7f6b
```

---

## 📋 Pasos para Habilitar Vertex AI

### Paso 1: Habilitar la API en Google Cloud Console

1. **Abre el enlace directo:**
   ```
   https://console.developers.google.com/apis/api/firebasevertexai.googleapis.com/overview?project=aifit-a7f6b
   ```
   
   O manualmente:
   - Ve a: https://console.cloud.google.com/
   - Selecciona el proyecto: `aifit-a7f6b`
   - En el menú lateral, ve a **"APIs & Services"** → **"Library"**
   - Busca: `Firebase Vertex AI API` o `Vertex AI API`
   - Haz clic en **"Enable"** (Habilitar)

2. **Espera la confirmación**
   - Puede tardar 1-2 minutos
   - Verás un mensaje de confirmación cuando esté habilitada

---

### Paso 2: Verificar Billing (Si es necesario)

Vertex AI requiere que tengas una cuenta de facturación habilitada en Google Cloud:

1. **Ve a Google Cloud Console:**
   - https://console.cloud.google.com/
   - Proyecto: `aifit-a7f6b`

2. **Verifica Billing:**
   - Menú lateral → **"Billing"**
   - Si no tienes una cuenta de facturación:
     - Haz clic en **"Link a billing account"**
     - Sigue las instrucciones para agregar un método de pago
     - ⚠️ **Nota**: Google Cloud ofrece $300 de crédito gratuito para nuevos usuarios

3. **Verifica que el proyecto tenga billing habilitado:**
   - En la página de Billing, verifica que `aifit-a7f6b` esté vinculado

---

### Paso 3: Habilitar Vertex AI en Firebase Console

1. **Abre Firebase Console:**
   - https://console.firebase.google.com/
   - Selecciona el proyecto: `aifit-a7f6b`

2. **Ve a Build → Extensions:**
   - En el menú lateral, busca **"Build"** → **"Extensions"**
   - O directamente: https://console.firebase.google.com/project/aifit-a7f6b/extensions

3. **Busca "Vertex AI":**
   - Busca extensiones relacionadas con Vertex AI
   - O ve directamente a **"Build"** → **"AI & Machine Learning"**

4. **Habilita Vertex AI:**
   - Firebase debería detectar automáticamente que necesitas Vertex AI
   - Si ves alguna opción para habilitar, haz clic en **"Enable"**

---

### Paso 4: Verificar Permisos de IAM

1. **Ve a Google Cloud Console:**
   - https://console.cloud.google.com/
   - Proyecto: `aifit-a7f6b`

2. **Ve a IAM & Admin:**
   - Menú lateral → **"IAM & Admin"** → **"IAM"**

3. **Verifica que el servicio de Firebase tenga permisos:**
   - Busca: `firebase-adminsdk` o `Firebase Service Account`
   - Debe tener el rol: **"Vertex AI User"** o **"AI Platform User"**
   - Si no lo tiene:
     - Haz clic en **"Edit"** (lápiz)
     - Agrega el rol: **"Vertex AI User"**
     - Guarda

---

### Paso 5: Configurar Ubicación (Location) de Vertex AI

Vertex AI requiere que especifiques una ubicación (region):

1. **Ve a Vertex AI Studio:**
   - https://console.cloud.google.com/vertex-ai?project=aifit-a7f6b
   - O busca "Vertex AI" en Google Cloud Console

2. **Selecciona una ubicación:**
   - En la parte superior, verás un selector de ubicación
   - Opciones recomendadas:
     - **`us-central1`** (Iowa, USA) - Más económico
     - **`us-east1`** (South Carolina, USA)
     - **`europe-west1`** (Bélgica) - Si estás en Europa
   - Selecciona la ubicación más cercana a tus usuarios

3. **Nota importante:**
   - La ubicación se usa automáticamente cuando llamas a `FirebaseAI.vertexAI()`
   - El código actual no especifica ubicación, así que usará la predeterminada
   - Si necesitas especificar ubicación, puedes hacerlo así:
     ```dart
     final model = FirebaseAI.vertexAI(location: 'us-central1')
         .generativeModel(model: 'gemini-1.5-pro');
     ```

---

### Paso 6: Verificar que Funciona

1. **Espera 2-5 minutos** después de habilitar la API
   - Google Cloud puede tardar unos minutos en propagar los cambios

2. **Prueba en la app:**
   - Ve a la pantalla de detalle de un item
   - Haz clic en **"Analizar con IA"**
   - Debería funcionar sin errores

3. **Si aún ves el error:**
   - Espera otros 5 minutos
   - Verifica que el billing esté habilitado
   - Verifica que la API esté habilitada en: https://console.cloud.google.com/apis/dashboard?project=aifit-a7f6b

---

## 🔍 Verificación de APIs Habilitadas

Para ver todas las APIs habilitadas en tu proyecto:

1. **Ve a:**
   ```
   https://console.cloud.google.com/apis/dashboard?project=aifit-a7f6b
   ```

2. **Deberías ver estas APIs habilitadas:**
   - ✅ Firebase Authentication API
   - ✅ Cloud Firestore API
   - ✅ Firebase Storage API
   - ✅ **Firebase Vertex AI API** ← Esta es la nueva
   - ✅ Vertex AI API (puede aparecer como separada)

---

## 💰 Costos Estimados

### Vertex AI (Gemini) - Precios (Enero 2026)

| Modelo | Input | Output | Uso Estimado | Costo Mensual |
|--------|-------|--------|--------------|---------------|
| **gemini-1.5-flash** | $0.075 / 1M tokens | $0.30 / 1M tokens | 1000 análisis | ~$1-3 |
| **gemini-1.5-pro** | $1.25 / 1M tokens | $5.00 / 1M tokens | 100 análisis | ~$2-5 |

**Nota:** 
- `gemini-1.5-flash` es más rápido y económico (usado para chat)
- `gemini-1.5-pro` es más preciso (usado para análisis de imágenes)
- Google Cloud ofrece $300 de crédito gratuito para nuevos usuarios

---

## 🧪 Testing

Después de habilitar la API:

1. **Abre la app**
2. **Ve a un item del guardarropa**
3. **Haz clic en "Analizar con IA"**
4. **Deberías ver:**
   ```
   🔍 Analizando imagen con IA...
   ✅ Análisis completado
   ```

Si funciona, la API está correctamente configurada.

---

## ❌ Troubleshooting

### Error: "API not enabled"
- **Solución**: Sigue el Paso 1 y habilita la API
- **Espera**: 2-5 minutos después de habilitar

### Error: "Billing not enabled"
- **Solución**: Sigue el Paso 2 y habilita billing
- **Nota**: Necesitas un método de pago, pero Google ofrece $300 de crédito gratuito

### Error: "Permission denied"
- **Solución**: Sigue el Paso 4 y verifica permisos IAM
- Agrega el rol "Vertex AI User" al servicio de Firebase

### Error: "Location not set"
- **Solución**: Sigue el Paso 5 y selecciona una ubicación
- O especifica la ubicación en el código (ver ejemplo arriba)

---

## 📚 Referencias

- [Firebase Vertex AI Documentation](https://firebase.google.com/docs/vertex-ai)
- [Vertex AI Pricing](https://cloud.google.com/vertex-ai/pricing)
- [Gemini Models](https://ai.google.dev/models/gemini)

---

## ✅ Checklist

- [ ] API habilitada en Google Cloud Console
- [ ] Billing habilitado (si es necesario)
- [ ] Permisos IAM configurados
- [ ] Ubicación de Vertex AI seleccionada
- [ ] Esperado 2-5 minutos después de habilitar
- [ ] Probado en la app con el botón "Analizar"

---

## 🎯 Siguiente Paso

Una vez que hayas completado estos pasos, podrás:
1. ✅ Analizar imágenes de prendas con IA
2. ✅ Generar outfits con IA
3. ✅ Obtener sugerencias de estilo

¡Buena suerte! 🚀
