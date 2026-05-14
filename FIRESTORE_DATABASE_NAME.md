# Configuración del Nombre de Base de Datos Firestore

## ¿Necesitas Configurar el Nombre?

**Respuesta corta**: Probablemente **NO**, pero depende de cómo creaste la base de datos.

### Escenario 1: Base de Datos "(default)" ✅ (Más común)

Si cuando creaste la base de datos en Firebase Console:
- Seleccionaste **"Start in production mode"** o **"Start in test mode"**
- Firebase te asignó automáticamente la base de datos **(default)**
- El nombre "aifitdbex" que le diste es solo un **nombre de visualización** en la consola

**En este caso**: **NO necesitas hacer nada**. El código actual funciona correctamente porque usa `FirebaseFirestore.instance`, que automáticamente se conecta a la base de datos "(default)".

### Escenario 2: Base de Datos con ID Personalizado ⚠️ (Menos común)

Si explícitamente creaste una base de datos con un **database ID** personalizado (no "(default)"), entonces **SÍ necesitas configurarlo**.

**Cómo verificar**:
1. Ve a Firebase Console → Firestore Database
2. En la parte superior, verás el nombre de la base de datos
3. Si dice **"(default)"** → No necesitas configurar nada
4. Si dice **"aifitdbex"** o cualquier otro nombre → Necesitas configurarlo

---

## Si Necesitas Configurar el Nombre

Si tu base de datos tiene un ID personalizado (no "(default)"), necesitas usar `FirebaseFirestore.instanceFor()` en lugar de `FirebaseFirestore.instance`.

### Paso 1: Crear un Helper para Firestore

Crea un archivo `lib/core/services/firestore_service.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

class FirestoreService {
  // Cambia esto si tu base de datos NO es "(default)"
  static const String databaseId = "(default)"; // o "aifitdbex" si es personalizado
  
  static FirebaseFirestore get instance {
    // Si es "(default)", usa el método estándar
    if (databaseId == "(default)") {
      return FirebaseFirestore.instance;
    }
    
    // Si es personalizado, usa instanceFor
    return FirebaseFirestore.instanceFor(
      app: Firebase.app(),
      databaseId: databaseId,
    );
  }
}
```

### Paso 2: Actualizar los Repositorios

Reemplaza `FirebaseFirestore.instance` con `FirestoreService.instance` en:

1. `lib/features/auth/data/auth_repository.dart`
2. `lib/features/wardrobe/data/wardrobe_repository_impl.dart`
3. `lib/features/profile/data/profile_repository.dart`
4. Cualquier otro archivo que use `FirebaseFirestore.instance`

**Ejemplo**:
```dart
// Antes:
final FirebaseFirestore _firestore = FirebaseFirestore.instance;

// Después:
final FirebaseFirestore _firestore = FirestoreService.instance;
```

---

## Verificación Rápida

**Prueba esto primero** (sin cambiar código):

1. Ejecuta la app: `flutter run`
2. Intenta agregar una prenda
3. Si funciona → **No necesitas configurar nada** ✅
4. Si ves error `NOT_FOUND` → Entonces sí necesitas configurar el nombre

---

## Comandos de Terminal

**NO necesitas ejecutar ningún comando de terminal** para configurar el nombre de la base de datos. Todo se hace en el código Flutter.

Los únicos comandos que podrías necesitar son:

```bash
# Limpiar y reconstruir (si cambiaste código)
flutter clean
flutter pub get
flutter run
```

---

## Resumen

- **Si la base de datos es "(default)"**: No hagas nada, ya funciona ✅
- **Si la base de datos tiene ID personalizado**: Crea `FirestoreService` y actualiza los repositorios
- **No necesitas comandos de terminal**: Todo es configuración de código
- **Prueba primero**: Intenta usar la app antes de cambiar código

---

## ¿Cómo Saber Cuál Es Tu Caso?

1. Ve a [Firebase Console](https://console.firebase.google.com/)
2. Selecciona tu proyecto: **aifit-a7f6b**
3. Ve a **Firestore Database**
4. Mira el nombre en la parte superior:
   - Si dice **"(default)"** → No necesitas hacer nada
   - Si dice **"aifitdbex"** o cualquier otro → Necesitas configurarlo
