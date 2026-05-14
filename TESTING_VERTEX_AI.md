# 🧪 Guía de Pruebas - Vertex AI

## ✅ Estado Actual

Según tu configuración en Firebase Console:
- ✅ **Vertex AI Gemini API**: Habilitada
- ✅ **Gemini Developer API**: Habilitada
- ✅ **AI Monitoring**: Habilitado (100% sampling)

## 🔍 Servicio que Estamos Usando

**El código usa: `FirebaseAI.vertexAI()`** 
- Esto significa que estamos usando **Vertex AI Gemini API** (servicio de nivel empresarial)
- **NO** estamos usando Gemini Developer API
- Vertex AI requiere billing habilitado

---

## 📋 Pasos para Probar

### Paso 1: Verificar que el Usuario Está Autenticado

1. **Abre la app**
2. **Haz login con Google**
3. **Verifica en los logs que veas:**
   ```
   ✅ USUARIO AUTENTICADO CON GOOGLE
      UID: [tu_uid]
   ```

### Paso 2: Probar el Análisis de Imagen

1. **Ve a la pantalla de guardarropa** (Wardrobe)
2. **Haz tap en cualquier item** para abrir la pantalla de detalle
3. **Busca el botón "Analyze with AI"** (debe estar visible)
4. **Haz tap en "Analyze with AI"**
5. **Observa los logs en la consola**

### Paso 3: Revisar los Logs

**Si funciona correctamente, deberías ver:**
```
📥 Downloading image from: https://firebasestorage.googleapis.com/...
✅ Image downloaded to: /tmp/analyze_...
🔍 Analyzing image with AI...
✅ AI Analysis completed: {type: "bottom", subType: "jeans", colors: [...], ...}
✅ Item analyzed successfully!
```

**Si hay un error, verás algo como:**
```
❌ Error analyzing image: Exception: ...
```

---

## 🔧 Prueba Rápida desde Código

Si quieres probar directamente desde el código, puedes agregar este método temporal en `WardrobeItemDetailPage`:

```dart
Future<void> _testVertexAI() async {
  try {
    debugPrint('🧪 Testing Vertex AI connection...');
    
    final model = FirebaseAI.vertexAI().generativeModel(
      model: 'gemini-1.5-flash',
    );
    
    final response = await model.generateContent([
      Content.text('Say "Hello from Vertex AI" in JSON format: {"message": "your message"}')
    ]);
    
    debugPrint('✅ Vertex AI Response: ${response.text}');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Vertex AI funciona! Respuesta: ${response.text}'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  } catch (e) {
    debugPrint('❌ Vertex AI Error: $e');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
```

Luego agrega un botón temporal en la UI para llamar a `_testVertexAI()`.

---

## ❌ Errores Comunes y Soluciones

### Error 1: "API not enabled"
**Solución:**
- Ya lo habilitaste ✅
- Espera 2-5 minutos más
- Verifica en: https://console.cloud.google.com/apis/dashboard?project=aifit-a7f6b

### Error 2: "Billing not enabled"
**Solución:**
- Ve a: https://console.cloud.google.com/billing?project=aifit-a7f6b
- Vincula una cuenta de facturación
- Google ofrece $300 de crédito gratuito

### Error 3: "Permission denied" o "Unauthorized"
**Solución:**
- Verifica que el usuario esté autenticado
- Verifica permisos IAM en Google Cloud Console
- El servicio de Firebase debe tener rol "Vertex AI User"

### Error 4: "Location not set"
**Solución:**
- Ve a: https://console.cloud.google.com/vertex-ai?project=aifit-a7f6b
- Selecciona una ubicación (recomendado: `us-central1`)

---

## 🎯 Checklist de Verificación

Antes de probar, verifica:

- [ ] Usuario autenticado en la app
- [ ] Vertex AI Gemini API habilitada en Firebase Console ✅
- [ ] Billing habilitado en Google Cloud
- [ ] Esperado 2-5 minutos después de habilitar la API
- [ ] Ubicación de Vertex AI seleccionada (opcional pero recomendado)

---

## 📊 Qué Esperar

### Tiempo de Respuesta
- **Análisis de imagen**: 10-30 segundos
- **Generación de outfit**: 5-15 segundos
- **Chat simple**: 2-5 segundos

### Costos por Prueba
- **gemini-1.5-flash**: ~$0.0001 por request
- **gemini-1.5-pro**: ~$0.001 por request
- Con $300 de crédito gratuito, puedes hacer miles de pruebas

---

## 🚀 Siguiente Paso

**Prueba ahora:**
1. Abre la app
2. Ve a un item del guardarropa
3. Haz tap en "Analyze with AI"
4. Observa los logs

**Si funciona:** ¡Perfecto! Ya puedes usar todas las funcionalidades de IA.

**Si no funciona:** Usa el prompt de ayuda que está en `GEMINI_HELP_PROMPT.md`
