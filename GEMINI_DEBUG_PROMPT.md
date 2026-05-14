# Prompt para Gemini: Error Firebase Storage -1017

Copia y pega este prompt completo en Gemini para obtener ayuda con el error:

---

## Contexto del Problema

Estoy desarrollando una aplicación Flutter que usa Firebase Storage para subir imágenes de usuarios. Tengo un error persistente `[firebase_storage/unknown] Unexpected -1017 code from backend` que ocurre al intentar subir archivos, a pesar de que:

1. ✅ El usuario está autenticado correctamente (Firebase Auth)
2. ✅ El `userId` coincide con `request.auth.uid`
3. ✅ Las reglas de Storage pasan el simulador en Firebase Console
4. ✅ El usuario existe en Firebase Authentication

## Información del Proyecto

**Firebase Project ID**: `aifit-a7f6b`

**Usuario Autenticado**: 
- UID: `bjHpPUDv1FMlk2ourMYniXjMpW72`
- Autenticado con Google Sign-In
- Existe en Firebase Authentication

## Reglas de Storage Actuales

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    function signedIn() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return signedIn() && request.auth.uid == userId;
    }

    match /users/{userId}/{allPaths=**} {
      allow read, write: if isOwner(userId);
    }

    match /{allPaths=**} {
      allow read, write: if false;
    }
  }
}
```

**Nota**: Estas reglas están desplegadas en Firebase Console.

## Código Flutter - Función de Upload

**Dependencias relevantes**:
```yaml
firebase_storage: ^13.0.5
firebase_auth: ^6.1.3
firebase_core: ^4.3.0
```

**Código de la función de upload**:

```dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> uploadUserPhoto({
    required String userId,
    required File file,
    required String photoType, // 'body' or 'face'
  }) async {
    try {
      // Verify user is authenticated
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ No authenticated user - cannot upload to Storage');
        throw Exception('User not authenticated. Please log in again.');
      }
      
      if (currentUser.uid != userId) {
        debugPrint('❌ User ID mismatch: current=${currentUser.uid}, provided=$userId');
        throw Exception('User ID mismatch');
      }

      debugPrint('✅ User authenticated: ${currentUser.uid}');

      // Verify file exists and is readable
      if (!await file.exists()) {
        throw Exception('File does not exist');
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${photoType}_$timestamp.jpg';
      final path = 'users/$userId/photos/$fileName';

      debugPrint('📤 Uploading photo to: $path');

      final ref = _storage.ref().child(path);
      
      // Upload file with retry logic for transient errors
      UploadTask uploadTask;
      try {
        uploadTask = ref.putFile(
          file,
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'userId': userId,
              'photoType': photoType,
              'uploadedAt': timestamp.toString(),
            },
          ),
        );
      } catch (e) {
        debugPrint('Error creating upload task: $e');
        // Retry once after a short delay
        await Future.delayed(const Duration(milliseconds: 500));
        uploadTask = ref.putFile(
          file,
          SettableMetadata(
            contentType: 'image/jpeg',
            customMetadata: {
              'userId': userId,
              'photoType': photoType,
              'uploadedAt': timestamp.toString(),
            },
          ),
        );
      }

      // Wait for upload to complete
      final snapshot = await uploadTask;
      
      // Get download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('Photo uploaded successfully: $downloadUrl');

      return downloadUrl;
    } catch (e) {
      debugPrint('❌ Error uploading photo: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Current user: ${_auth.currentUser?.uid ?? "null"}');
      
      // Provide more specific error messages
      final errorString = e.toString();
      if (errorString.contains('-1017') || errorString.contains('unavailable')) {
        debugPrint('❌ Storage error -1017: This usually means authentication/permission issue');
        debugPrint('   - Check if user is logged in: ${_auth.currentUser != null}');
        debugPrint('   - Check Storage rules in Firebase Console');
        throw Exception('Storage service temporarily unavailable. Please log out and log in again.');
      }
      if (errorString.contains('permission') || errorString.contains('unauthorized')) {
        throw Exception('Permission denied. Please check your Storage rules.');
      }
      throw Exception('Failed to upload photo: $e');
    }
  }
}
```

## Logs del Error

```
flutter: ✅ User authenticated: bjHpPUDv1FMlk2ourMYniXjMpW72
flutter: 📤 Uploading photo to: users/bjHpPUDv1FMlk2ourMYniXjMpW72/photos/body_1769311127605.jpg
flutter: ❌ Error uploading photo: [firebase_storage/unknown] Unexpected -1017 code from backend
flutter: ❌ Error type: FirebaseException
flutter: ❌ Current user: bjHpPUDv1FMlk2ourMYniXjMpW72
flutter: ❌ Storage error -1017: This usually means authentication/permission issue
flutter:    - Check if user is logged in: true
flutter:    - Check Storage rules in Firebase Console
```

## Lo que ya he verificado

1. ✅ Usuario está autenticado (`FirebaseAuth.instance.currentUser` no es null)
2. ✅ El `userId` pasado a la función coincide con `currentUser.uid`
3. ✅ Las reglas de Storage pasan el simulador en Firebase Console
4. ✅ El archivo existe antes de intentar subirlo
5. ✅ La ruta es correcta: `users/{userId}/photos/{fileName}`
6. ✅ Las reglas están desplegadas en Firebase Console

## Preguntas Específicas

1. **¿Qué significa exactamente el error -1017 de Firebase Storage?** ¿Hay documentación oficial sobre este código de error?

2. **¿Hay algún problema conocido con Firebase Storage y Google Sign-In** que cause que el token de autenticación no se envíe correctamente?

3. **¿Las reglas de Storage que tengo son correctas?** ¿Hay algún problema con la sintaxis o la lógica?

4. **¿Necesito hacer algo especial con el token de autenticación** antes de subir archivos? Por ejemplo, ¿necesito refrescar el token explícitamente?

5. **¿Hay alguna configuración en Firebase Console** que deba verificar? (App Check, IAM, etc.)

6. **¿El error -1017 puede ser causado por problemas de red/conectividad?** ¿O es exclusivamente un problema de autenticación/permisos?

7. **¿Hay alguna solución conocida o workaround** para este error específico?

8. **¿Debería usar un método diferente para subir archivos?** Por ejemplo, ¿usar `putData` en lugar de `putFile`, o usar `uploadBytes`?

## Flujo de Autenticación

El usuario se autentica usando Google Sign-In v7:

```dart
// 1. Inicializar Google Sign-In
await GoogleSignIn.instance.initialize();

// 2. Autenticar con Google
final googleUser = await GoogleSignIn.instance.authenticate();
final googleAuth = googleUser.authentication;

// 3. Crear credencial de Firebase
final credential = GoogleAuthProvider.credential(
  idToken: googleAuth.idToken,
);

// 4. Sign in con Firebase Auth
final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
```

**Nota importante**: El usuario puede leer de Firestore sin problemas, lo que confirma que la autenticación funciona. El problema es específico de Storage.

## Información Adicional

- **Plataforma**: iOS Simulator (pero también ocurre en otros dispositivos)
- **Versión de Flutter**: SDK ^3.9.2
- **Versión de firebase_storage**: ^13.0.5
- **Versión de firebase_auth**: ^6.1.3
- **Versión de google_sign_in**: ^7.2.0
- **Método de autenticación**: Google Sign-In v7 (usando `GoogleSignIn.instance.authenticate()`)
- **Firebase Project**: `aifit-a7f6b`
- **Storage Bucket**: `gs://aifit-a7f6b.firebasestorage.app`

## Comportamiento Observado

- ✅ Firestore funciona correctamente (lectura y escritura)
- ✅ Firebase Auth funciona (usuario autenticado, `currentUser` no es null)
- ✅ Las reglas de Storage pasan el simulador
- ❌ Cualquier operación de escritura en Storage falla con -1017
- ❌ El error es consistente, no intermitente

Por favor, proporciona:
1. Una explicación detallada de qué causa el error -1017
2. Pasos específicos para solucionarlo
3. Cualquier código o configuración adicional necesaria
4. Referencias a documentación oficial o issues conocidos de GitHub

---

**Nota**: Este error ocurre consistentemente, no es intermitente. El usuario puede leer datos de Firestore sin problemas, pero cualquier operación de escritura en Storage falla con -1017.
