# 🤖 Prompt para Gemini - Ayuda con Vertex AI

Si el análisis de imágenes no funciona después de seguir todos los pasos, copia y pega este prompt completo en Gemini (o cualquier modelo de IA) para obtener ayuda específica.

---

## 📋 Prompt Completo

```
Estoy desarrollando una aplicación Flutter que usa Firebase Vertex AI para analizar imágenes de prendas de ropa. Tengo un error al intentar usar el servicio y necesito ayuda para diagnosticarlo.

CONTEXTO DEL PROYECTO:
- Proyecto Firebase: aifit-a7f6b
- Servicio usado: Firebase Vertex AI (FirebaseAI.vertexAI())
- Modelos: gemini-1.5-flash y gemini-1.5-pro
- APIs habilitadas: Vertex AI Gemini API y Gemini Developer API (ambas habilitadas en Firebase Console)
- Billing: Habilitado en Google Cloud

LIBRERÍAS Y CÓDIGO CLAVE:

1. Dependencia en pubspec.yaml:
```yaml
firebase_ai: ^3.6.1
```

2. Implementación del servicio (lib/core/services/firebase_ai_service_impl.dart):
```dart
import 'package:firebase_ai/firebase_ai.dart';

class FirebaseAIServiceImpl implements AIService {
  @override
  Future<Map<String, dynamic>> analyzeImageToJson({
    required File image,
    required String promptInstruction,
  }) async {
    try {
      final model = FirebaseAI.vertexAI().generativeModel(
        model: 'gemini-1.5-pro',
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
        ),
      );

      final bytes = await image.readAsBytes();
      final content = [
        Content.multi([
          TextPart(promptInstruction),
          InlineDataPart('image/jpeg', bytes),
        ]),
      ];

      final response = await model.generateContent(content);
      final jsonString = response.text;

      if (jsonString == null) throw Exception("Respuesta vacía de IA");

      final cleanJson = jsonString
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      return jsonDecode(cleanJson) as Map<String, dynamic>;
    } catch (e) {
      throw Exception("Fallo al analizar la imagen: $e");
    }
  }
}
```

3. Uso en la app (lib/features/wardrobe/presentation/pages/wardrobe_item_detail_page.dart):
```dart
final aiData = await _aiService.analyzeImageToJson(
  image: imageFile,
  promptInstruction: """
  Analyze this clothing item carefully.
  Return a JSON with strictly these fields:
  - type: "top", "bottom", "shoes", or "outerwear"
  - subType: specific type (e.g., "jeans", "t-shirt")
  - colors: array of dominant colors
  - styleTags: array of styles (e.g., "casual", "formal")
  - season: array of seasons suitable
  """,
);
```

ERROR ACTUAL:
[PEGA AQUÍ EL ERROR COMPLETO QUE VES EN LOS LOGS]

LOGS DE LA CONSOLA:
[PEGA AQUÍ LOS LOGS COMPLETOS DE LA CONSOLA DE FLUTTER]

CONFIGURACIÓN VERIFICADA:
- ✅ Vertex AI Gemini API habilitada en Firebase Console
- ✅ Gemini Developer API habilitada en Firebase Console
- ✅ Billing habilitado en Google Cloud
- ✅ Usuario autenticado con Firebase Auth
- ✅ Imagen descargada correctamente desde Firebase Storage

PREGUNTAS ESPECÍFICAS:
1. ¿Por qué podría estar fallando la llamada a FirebaseAI.vertexAI()?
2. ¿Hay alguna configuración adicional necesaria en Google Cloud Console?
3. ¿Necesito especificar una ubicación (location) al inicializar vertexAI()?
4. ¿Hay algún problema con los permisos IAM que deba verificar?
5. ¿El error sugiere que debo usar FirebaseAI.googleAI() en lugar de vertexAI()?
6. ¿Hay alguna diferencia entre usar Vertex AI Gemini API vs Gemini Developer API en este contexto?

Por favor, proporciona:
- Diagnóstico del problema
- Pasos específicos para resolverlo
- Código corregido si es necesario
- Verificaciones adicionales que deba hacer
```

---

## 🔍 Información Adicional para el Prompt

Si el error menciona algo específico, agrega esta información al prompt:

### Si el error menciona "location":
```
El error menciona que necesito especificar una ubicación. 
¿Cómo debo modificar el código para especificar la ubicación?
¿Qué ubicación debo usar para us-central1?
```

### Si el error menciona "permissions":
```
El error menciona permisos. 
¿Qué roles IAM específicos necesita el servicio de Firebase?
¿Dónde debo verificar estos permisos?
```

### Si el error menciona "billing":
```
El error menciona billing, pero ya tengo billing habilitado.
¿Hay alguna configuración adicional de billing que necesite?
¿Necesito habilitar algo específico para Vertex AI?
```

### Si el error menciona "API not found":
```
El error dice que la API no se encuentra.
¿Necesito habilitar algo más además de Vertex AI Gemini API?
¿Hay alguna API adicional que deba habilitar?
```

---

## 📝 Cómo Usar Este Prompt

1. **Copia el prompt completo** de arriba
2. **Reemplaza las secciones entre corchetes** con tu información real:
   - `[PEGA AQUÍ EL ERROR COMPLETO]` → El error exacto que ves
   - `[PEGA AQUÍ LOS LOGS COMPLETOS]` → Los logs de Flutter
3. **Pega el prompt en Gemini** (https://gemini.google.com) o cualquier modelo de IA
4. **Comparte la respuesta** conmigo para que podamos implementar la solución

---

## 🎯 Información Clave que Gemini Necesita

Para que Gemini te ayude mejor, asegúrate de incluir:

1. **El error exacto** (copia completo desde los logs)
2. **El stack trace completo** (si está disponible)
3. **La versión de firebase_ai** que estás usando (^3.6.1)
4. **El modelo que intentas usar** (gemini-1.5-pro)
5. **Si el usuario está autenticado** (sí/no)
6. **Si la imagen se descarga correctamente** (sí/no)

---

## 💡 Alternativa: Probar con Gemini Developer API

Si Vertex AI sigue dando problemas, podemos cambiar temporalmente a Gemini Developer API:

```dart
// Cambiar de:
final model = FirebaseAI.vertexAI().generativeModel(...);

// A:
final model = FirebaseAI.googleAI().generativeModel(...);
```

**Nota:** Gemini Developer API tiene límites más estrictos pero es más fácil de configurar. Vertex AI es mejor para producción.

---

¡Buena suerte con las pruebas! 🚀
